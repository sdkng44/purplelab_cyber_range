param(
    [string]$ExpectedWazuhAgentName = "win-endpoint-01",
    [string]$LabUser = "labuser",
    [string]$ShareName = "PurpleShare",
    [string]$SharePath = "C:\PurpleShare",
    [string]$RedTaskName = "CalderaSandcatRed",
    [string]$S13TaskName = "CalderaSandcatS13",
    [string]$RedBinaryPath = "C:\Users\Public\splunkd-red.exe",
    [string]$S13BinaryPath = "C:\Users\Public\splunkd-s13.exe"
)

$ErrorActionPreference = "SilentlyContinue"
$global:ValidationFailures = 0

function Write-Check {
    param(
        [string]$Status,
        [string]$Name,
        [string]$Details = ""
    )
    $line = "[{0}] {1}" -f $Status.ToUpper(), $Name
    if ($Details) {
        $line += " - $Details"
    }
    Write-Host $line
}

function Pass {
    param([string]$Name, [string]$Details = "")
    Write-Check -Status "PASS" -Name $Name -Details $Details
}

function Warn {
    param([string]$Name, [string]$Details = "")
    Write-Check -Status "WARN" -Name $Name -Details $Details
}

function Fail {
    param([string]$Name, [string]$Details = "")
    Write-Check -Status "FAIL" -Name $Name -Details $Details
    $global:ValidationFailures++
}

function Test-ServiceState {
    param(
        [string[]]$Names,
        [string]$FriendlyName
    )

    $svc = Get-Service | Where-Object { $Names -contains $_.Name } | Select-Object -First 1
    if (-not $svc) {
        Fail $FriendlyName "Service not found"
        return
    }

    if ($svc.Status -eq "Running") {
        Pass $FriendlyName "$($svc.Name) is running"
    } else {
        Fail $FriendlyName "$($svc.Name) is $($svc.Status)"
    }
}

function Test-RegistryDword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Expected,
        [string]$FriendlyName
    )

    $value = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -eq $value) {
        Fail $FriendlyName "Registry value not found"
        return
    }

    if ([int]$value -eq $Expected) {
        Pass $FriendlyName "$Name=$value"
    } else {
        Fail $FriendlyName "$Name=$value expected=$Expected"
    }
}

function Test-EventChannelConfigured {
    param([string]$Location)

    $cfg = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    if (-not (Test-Path $cfg)) {
        Fail "Wazuh eventchannel $Location" "ossec.conf not found"
        return
    }

    $match = Select-String -Path $cfg -Pattern $Location -SimpleMatch -ErrorAction SilentlyContinue
    if ($null -ne $match) {
        Pass "Wazuh eventchannel $Location"
    } else {
        Fail "Wazuh eventchannel $Location" "Missing from ossec.conf"
    }
}

function Test-ScheduledTaskState {
    param(
        [string]$TaskName,
        [string]$BinaryPath
    )

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Fail "Scheduled task $TaskName" "Task not found"
        return
    }

    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    $action = $task.Actions | Select-Object -First 1

    if ($action -and $action.Execute -eq $BinaryPath) {
        Pass "Scheduled task $TaskName" "Binary=$BinaryPath LastResult=$($info.LastTaskResult)"
    } else {
        Fail "Scheduled task $TaskName" "Unexpected action path"
    }
}

function Test-ProcessForBinary {
    param(
        [string]$BinaryPath,
        [string]$FriendlyName
    )

    $proc = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $BinaryPath } | Select-Object -First 1
    if ($proc) {
        Pass $FriendlyName "PID=$($proc.ProcessId)"
    } else {
        Fail $FriendlyName "Process not running from $BinaryPath"
    }
}

function Test-DefenderExclusionPath {
    param([string]$Path)

    try {
        $prefs = Get-MpPreference
        if ($prefs.ExclusionPath -contains $Path) {
            Pass "Defender exclusion path" $Path
        } else {
            Fail "Defender exclusion path" $Path
        }
    } catch {
        Warn "Defender exclusion path" "Could not query Defender preferences"
    }
}

function Test-DefenderExclusionProcess {
    param([string]$Path)

    try {
        $prefs = Get-MpPreference
        if ($prefs.ExclusionProcess -contains $Path) {
            Pass "Defender exclusion process" $Path
        } else {
            Fail "Defender exclusion process" $Path
        }
    } catch {
        Warn "Defender exclusion process" "Could not query Defender preferences"
    }
}

Write-Host "=== Windows Endpoint Validation ==="

# WinRM
$winrm = Get-Service -Name WinRM
if ($winrm -and $winrm.Status -eq "Running") {
    Pass "WinRM service" "Running"
} else {
    Fail "WinRM service" "Not running"
}

# Network profiles
$profiles = Get-NetConnectionProfile
$nonPrivate = $profiles | Where-Object { $_.NetworkCategory -notin @("Private", "DomainAuthenticated") }
if (-not $nonPrivate) {
    Pass "Network profile state" "All active profiles are Private or DomainAuthenticated"
} else {
    Warn "Network profile state" (($nonPrivate | ForEach-Object { "$($_.Name):$($_.NetworkCategory)" }) -join ", ")
}

# Local user
$user = Get-LocalUser -Name $LabUser
if ($user) {
    Pass "Local user $LabUser"
} else {
    Fail "Local user $LabUser" "User not found"
}

# Share
$share = Get-SmbShare -Name $ShareName
if ($share -and (Test-Path $SharePath)) {
    Pass "SMB share $ShareName" $SharePath
} else {
    Fail "SMB share $ShareName" "Share or path missing"
}

# Auditing / logging
Test-RegistryDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Expected 1 -FriendlyName "PowerShell Script Block Logging"
Test-RegistryDword -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -Expected 1 -FriendlyName "Process Creation Command Line Logging"

# Wazuh
$wazuhConfig = "C:\Program Files (x86)\ossec-agent\ossec.conf"
if (Test-Path $wazuhConfig) {
    Pass "Wazuh agent installed" $wazuhConfig
} else {
    Fail "Wazuh agent installed" "ossec.conf not found"
}
Test-ServiceState -Names @("Wazuh", "WazuhSvc") -FriendlyName "Wazuh service"
Test-EventChannelConfigured -Location "Microsoft-Windows-PowerShell/Operational"
Test-EventChannelConfigured -Location "Microsoft-Windows-TaskScheduler/Operational"

# Sandcat binaries
if (Test-Path $RedBinaryPath) { Pass "Red Sandcat binary" $RedBinaryPath } else { Fail "Red Sandcat binary" $RedBinaryPath }
if (Test-Path $S13BinaryPath) { Pass "S13 Sandcat binary" $S13BinaryPath } else { Fail "S13 Sandcat binary" $S13BinaryPath }

# Tasks
Test-ScheduledTaskState -TaskName $RedTaskName -BinaryPath $RedBinaryPath
Test-ScheduledTaskState -TaskName $S13TaskName -BinaryPath $S13BinaryPath

# Processes
Test-ProcessForBinary -BinaryPath $RedBinaryPath -FriendlyName "Red Sandcat process"
Test-ProcessForBinary -BinaryPath $S13BinaryPath -FriendlyName "S13 Sandcat process"

# Defender exclusions
Test-DefenderExclusionPath -Path "C:\Users\Public"
Test-DefenderExclusionPath -Path "C:\ProgramData\caldera"
Test-DefenderExclusionProcess -Path $RedBinaryPath
Test-DefenderExclusionProcess -Path $S13BinaryPath

Write-Host "=== Validation Summary ==="
if ($global:ValidationFailures -eq 0) {
    Write-Host "Validation successful. No failures found."
    exit 0
} else {
    Write-Host "Validation completed with $global:ValidationFailures failure(s)."
    exit 1
}
