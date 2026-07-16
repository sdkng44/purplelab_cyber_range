param(
    [string]$BootstrapScriptPath = ".\bootstrap_win_endpoint.ps1",
    [string]$ValidateScriptPath = ".\validate_win_endpoint.ps1"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[ensure_win_endpoint] $Message"
}

if (-not (Test-Path $ValidateScriptPath)) {
    throw "Validate script not found: $ValidateScriptPath"
}

if (-not (Test-Path $BootstrapScriptPath)) {
    throw "Bootstrap script not found: $BootstrapScriptPath"
}

Write-Log "Running initial validation..."
& $ValidateScriptPath
$initialExit = $LASTEXITCODE

if ($initialExit -eq 0) {
    Write-Log "Validation already passed. No bootstrap actions needed."
    exit 0
}

Write-Log "Validation reported missing or failed components. Running bootstrap..."
try {
    & $BootstrapScriptPath
}
catch {
    Write-Log "Bootstrap failed: $($_.Exception.Message)"
    exit 1
}

Write-Log "Running final validation..."
& $ValidateScriptPath
$finalExit = $LASTEXITCODE

if ($finalExit -eq 0) {
    Write-Log "Ensure completed successfully."
    exit 0
}

Write-Log "Ensure completed, but final validation still reports issues."
exit $finalExit
