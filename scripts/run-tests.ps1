[CmdletBinding()]
param(
    [switch]$InstallPester5 = $true,
    [switch]$FailOnError = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$testsPath = Join-Path $PSScriptRoot "..\tests"
$minVersion = [version]"5.0.0"

function Get-LatestPesterModule {
    Get-Module -ListAvailable -Name Pester |
        Sort-Object Version -Descending |
        Select-Object -First 1
}

$pester = Get-LatestPesterModule

if (-not $pester -or $pester.Version -lt $minVersion) {
    if ($InstallPester5) {
        Write-Host "[INFO] Installing Pester 5.x for consistent test execution..."
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
        $pester = Get-LatestPesterModule
    }
}

if (-not $pester) {
    throw "Pester module is not available. Install Pester and try again."
}

Import-Module Pester -RequiredVersion $pester.Version -Force
Write-Host "[INFO] Running tests with Pester $($pester.Version)"

if ($pester.Version.Major -ge 5) {
    $result = Invoke-Pester -Path $testsPath -Output Detailed -PassThru
    if ($FailOnError -and $result.FailedCount -gt 0) {
        exit 1
    }
}
else {
    $result = Invoke-Pester -Path $testsPath -PassThru
    if ($FailOnError -and $result.FailedCount -gt 0) {
        exit 1
    }
}
