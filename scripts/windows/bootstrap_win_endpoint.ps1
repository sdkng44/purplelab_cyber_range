param(
    [string]$WazuhManager = "192.168.56.10",
    [string]$WazuhAgentName = "win-endpoint-01",
    [string]$CalderaServer = "http://192.168.56.10:8888",
    [string]$PrimarySandcatPaw = "win-endpoint-01",
    [string]$PrimarySandcatGroup = "red",
    [string]$S13SandcatPaw = "win-endpoint-01-s13",
    [string]$S13SandcatGroup = "s13-flow",
    [string]$LabUser = "labuser",
    [string]$LabPassword = "WinPassword123!",
    [string]$ShareName = "PurpleShare",
    [string]$SharePath = "C:\PurpleShare",
    [string]$SandcatDir = "C:\Users\Public",
    [string]$WazuhMsiUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.5-1.msi"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[bootstrap_win_endpoint] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Ensure-LocalUser {
    param(
        [string]$UserName,
        [string]$Password,
        [string]$FullName = "",
        [string]$Description = ""
    )

    $existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    if (-not $existing) {
        Write-Log "Creating local user $UserName..."
        New-LocalUser -Name $UserName -Password $securePassword -FullName $FullName -Description $Description | Out-Null
    } else {
        Write-Log "Updating password for local user $UserName..."
        Set-LocalUser -Name $UserName -Password $securePassword
    }
}

function Ensure-LocalGroupMembership {
    param(
        [string]$GroupName,
        [string]$MemberName
    )

    $isMember = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "\\$MemberName$" }
    if (-not $isMember) {
        Write-Log "Adding $MemberName to local group $GroupName..."
        Add-LocalGroupMember -Group $GroupName -Member $MemberName
    }
}

function Ensure-DefenderExclusionPath {
    param([string]$Path)

    try {
        $prefs = Get-MpPreference
        if ($prefs.ExclusionPath -notcontains $Path) {
            Write-Log "Adding Defender exclusion path: $Path"
            Add-MpPreference -ExclusionPath $Path
        }
    } catch {
        Write-Log "Defender exclusion path could not be set for ${Path}: $($_.Exception.Message)"
    }
}

function Ensure-DefenderExclusionProcess {
    param([string]$Path)

    try {
        $prefs = Get-MpPreference
        if ($prefs.ExclusionProcess -notcontains $Path) {
            Write-Log "Adding Defender exclusion process: $Path"
            Add-MpPreference -ExclusionProcess $Path
        }
    } catch {
        Write-Log "Defender exclusion process could not be set for ${Path}: $($_.Exception.Message)"
    }
}

function Enable-PowerShellLogging {
    Write-Log "Enabling PowerShell Script Block Logging..."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -PropertyType DWord -Force | Out-Null

    Write-Log "Enabling PowerShell Operational log..."
    & wevtutil sl Microsoft-Windows-PowerShell/Operational /e:true | Out-Null
}

function Enable-TaskSchedulerLogging {
    Write-Log "Enabling Task Scheduler Operational log..."
    & wevtutil sl Microsoft-Windows-TaskScheduler/Operational /e:true | Out-Null
}

function Enable-ProcessCreationLogging {
    Write-Log "Enabling Process Creation auditing..."
    & auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null

    New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
}

function Enable-LogonAuditing {
    Write-Log "Enabling Logon and Logoff auditing..."
    & auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
    & auditpol /set /subcategory:"Logoff" /success:enable /failure:enable | Out-Null
}

function Ensure-WinRM {
    Write-Log "Ensuring WinRM is enabled..."
    Enable-PSRemoting -Force | Out-Null
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service WinRM
    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" | Out-Null
}

function Ensure-FileAndPrinterSharing {
    Write-Log "Enabling File and Printer Sharing firewall rules..."
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" | Out-Null
}

function Ensure-NetworkProfiles {
    Write-Log "Setting non-domain network profiles to Private when possible..."
    Get-NetConnectionProfile | ForEach-Object {
        if ($_.NetworkCategory -ne "DomainAuthenticated" -and $_.NetworkCategory -ne "Private") {
            try {
                Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private
            } catch {
                Write-Log "Could not change network profile for interface index $($_.InterfaceIndex): $($_.Exception.Message)"
            }
        }
    }
}

function Ensure-LabShare {
    param(
        [string]$Name,
        [string]$Path,
        [string]$ReadUser
    )

    Ensure-Directory -Path $Path

    $readmePath = Join-Path $Path "readme.txt"
    if (-not (Test-Path $readmePath)) {
        "Purple Lab SMB test share" | Out-File -FilePath $readmePath -Encoding utf8
    }

    $share = Get-SmbShare -Name $Name -ErrorAction SilentlyContinue
    if (-not $share) {
        Write-Log "Creating SMB share $Name..."
        New-SmbShare -Name $Name -Path $Path -ReadAccess $ReadUser | Out-Null
    } else {
        Write-Log "SMB share $Name already exists."
    }
}

function Ensure-WazuhAgent {
    param(
        [string]$Manager,
        [string]$AgentName,
        [string]$MsiUrl
    )

    $wazuhConfigPath = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    $wazuhLogPath = "C:\Program Files (x86)\ossec-agent\ossec.log"

    if (-not (Test-Path $wazuhConfigPath)) {
        Write-Log "Installing Wazuh agent..."
        $msiPath = Join-Path $env:TEMP "wazuh-agent.msi"
        Invoke-WebRequest -Uri $MsiUrl -OutFile $msiPath
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msiPath`" /q WAZUH_MANAGER=`"$Manager`" WAZUH_AGENT_NAME=`"$AgentName`""
    } else {
        Write-Log "Wazuh agent already installed."
    }

    Write-Log "Trying to start Wazuh service..."
    try { Start-Service -Name Wazuh -ErrorAction SilentlyContinue } catch {}
    try { Start-Service -Name WazuhSvc -ErrorAction SilentlyContinue } catch {}
    try { cmd /c "NET START Wazuh" | Out-Null } catch {}
    try { cmd /c "NET START WazuhSvc" | Out-Null } catch {}

    try { Set-Service -Name Wazuh -StartupType Automatic -ErrorAction SilentlyContinue } catch {}
    try { Set-Service -Name WazuhSvc -StartupType Automatic -ErrorAction SilentlyContinue } catch {}

    if (Test-Path $wazuhLogPath) {
        Write-Log "Wazuh log path found: $wazuhLogPath"
    }
}

function Ensure-WazuhEventChannel {
    param(
        [string]$Location
    )

    $cfg = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    if (-not (Test-Path $cfg)) {
        Write-Log "Wazuh config not found yet, skipping localfile insertion for $Location"
        return
    }

    [xml]$xml = Get-Content $cfg
    $existing = $xml.ossec_config.localfile | Where-Object { $_.location -eq $Location }

    if (-not $existing) {
        Write-Log "Adding Wazuh eventchannel localfile: $Location"
        $localfile = $xml.CreateElement("localfile")

        $locationNode = $xml.CreateElement("location")
        $locationNode.InnerText = $Location

        $formatNode = $xml.CreateElement("log_format")
        $formatNode.InnerText = "eventchannel"

        $localfile.AppendChild($locationNode) | Out-Null
        $localfile.AppendChild($formatNode) | Out-Null
        $xml.ossec_config.AppendChild($localfile) | Out-Null

        $xml.Save($cfg)
    }
}

function Restart-WazuhService {
    try { Restart-Service -Name Wazuh -ErrorAction SilentlyContinue } catch {}
    try { Restart-Service -Name WazuhSvc -ErrorAction SilentlyContinue } catch {}
}

function Install-SandcatBinary {
    param(
        [string]$TargetPath,
        [string]$Server
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers.add("platform", "windows")
    $wc.Headers.add("file", "sandcat.go")
    $data = $wc.DownloadData("$Server/file/download")
    [io.file]::WriteAllBytes($TargetPath, $data) | Out-Null
}

function Ensure-SandcatTask {
    param(
        [string]$TaskName,
        [string]$BinaryPath,
        [string]$Server,
        [string]$Group,
        [string]$Paw
    )

    Ensure-Directory -Path (Split-Path $BinaryPath -Parent)
    Ensure-DefenderExclusionPath -Path (Split-Path $BinaryPath -Parent)
    Ensure-DefenderExclusionProcess -Path $BinaryPath

    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    $runningProc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ExecutablePath -eq $BinaryPath } | Select-Object -First 1

    if ((Test-Path $BinaryPath) -and $existingTask -and $runningProc) {
        Write-Log "Sandcat task $TaskName is already present and running. Skipping reinstall."
        return
    }

    if ($runningProc) {
        Write-Log "Stopping running process for $TaskName before reinstall..."
        Stop-Process -Id $runningProc.ProcessId -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    Write-Log "Installing Sandcat binary for $TaskName..."
    Install-SandcatBinary -TargetPath $BinaryPath -Server $Server

    $action = New-ScheduledTaskAction -Execute $BinaryPath -Argument "-server $Server -group $Group -paw $Paw"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    Write-Log "Registering scheduled task $TaskName..."
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

    Write-Log "Starting scheduled task $TaskName..."
    Start-ScheduledTask -TaskName $TaskName
}

function Validate-Bootstrap {
    Write-Log "Validation summary"
    Write-Host "==== SERVICES ===="
    Get-Service WinRM -ErrorAction SilentlyContinue
    Get-Service *Wazuh* -ErrorAction SilentlyContinue

    Write-Host "==== SCHEDULED TASKS ===="
    Get-ScheduledTask -TaskName "CalderaSandcatRed" -ErrorAction SilentlyContinue
    Get-ScheduledTask -TaskName "CalderaSandcatS13" -ErrorAction SilentlyContinue

    Write-Host "==== PROCESSES ===="
    Get-Process | Where-Object { $_.Path -like "C:\Users\Public\*" } | Select-Object Name, Id, Path

    Write-Host "==== SHARE ===="
    Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue

    Write-Host "==== DEFENDER EXCLUSIONS ===="
    $prefs = Get-MpPreference
    $prefs.ExclusionPath
    $prefs.ExclusionProcess

    Write-Host "==== WAZUH CONFIG CHECK ===="
    Select-String -Path "C:\Program Files (x86)\ossec-agent\ossec.conf" -Pattern "Microsoft-Windows-PowerShell/Operational|Microsoft-Windows-TaskScheduler/Operational" -ErrorAction SilentlyContinue
}

Write-Log "Starting Windows endpoint bootstrap..."

Ensure-NetworkProfiles
Ensure-WinRM
Ensure-FileAndPrinterSharing

Ensure-LocalUser -UserName $LabUser -Password $LabPassword -FullName "Lab User" -Description "Purple Lab test user"
Ensure-LocalGroupMembership -GroupName "Users" -MemberName $LabUser

Ensure-LabShare -Name $ShareName -Path $SharePath -ReadUser $LabUser

Enable-LogonAuditing
Enable-PowerShellLogging
Enable-TaskSchedulerLogging
Enable-ProcessCreationLogging

Ensure-WazuhAgent -Manager $WazuhManager -AgentName $WazuhAgentName -MsiUrl $WazuhMsiUrl
Ensure-WazuhEventChannel -Location "Microsoft-Windows-PowerShell/Operational"
Ensure-WazuhEventChannel -Location "Microsoft-Windows-TaskScheduler/Operational"
Restart-WazuhService

Ensure-SandcatTask -TaskName "CalderaSandcatRed" -BinaryPath "C:\Users\Public\splunkd-red.exe" -Server $CalderaServer -Group $PrimarySandcatGroup -Paw $PrimarySandcatPaw
Ensure-SandcatTask -TaskName "CalderaSandcatS13" -BinaryPath "C:\Users\Public\splunkd-s13.exe" -Server $CalderaServer -Group $S13SandcatGroup -Paw $S13SandcatPaw

Validate-Bootstrap

Write-Log "Bootstrap completed."
