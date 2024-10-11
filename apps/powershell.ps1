#Requires -Version 5.1

param(
    [switch]$updateonly = $false
)

$appName = "PowerShell"
###############################################################################
#region Functions
function Get-OnlineVersion {
    try {
        $json = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $version = $json.tag_name -replace "[^\d\.]", ""
        $bits = $version.Split(".")
        return [Version]::new($bits[0], $bits[1], $bits[2], 0)
    }
    catch {
        return $null
    }
}

function Get-DownloadLink {
    try {
        $json = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        return $json.assets | Where-Object { $_.Name -like "PowerShell*-x64.msi" } | Select-Object -ExpandProperty browser_download_url
    }
    catch {
        return $null
    }
}

function Get-InstalledVersion {
    return $PSVersionTable.PSVersion
}

#endregion
###############################################################################

###############################################################################
#region Check Versions

$installedVersion = Get-InstalledVersion

if (-not $installedVersion -and $updateonly) {
    Write-Host "$appName is not yet installed and script is set to -updateonly -- exiting now." -ForegroundColor Yellow
    exit 0
}

$onlineVersion = Get-OnlineVersion
if (-not $onlineVersion) {
    Write-Host "Unable to fetch $appName Version -- exiting now." -ForegroundColor Red
    exit 1
}

if ($installedVersion -eq $onlineVersion) {
    Write-Host "$appName $installedVersion is installed and up to date!" -ForegroundColor Green
    exit 0
} elseif ($installedVersion -gt $onlineVersion) {
    Write-Host "SKIPPED: Your installed $appName version ($installedVersion) is higher than the available version. ($onlineVersion)" -ForegroundColor Yellow
    exit 0
}


#endregion
###############################################################################
#region Download and Install

Write-Host "Downloading $appName $onlineVersion..." -ForegroundColor Cyan

$url = Get-DownloadLink

if(-not $url) {
    Write-Host "ERROR: Unable to fetch $appName Installer." -ForegroundColor Red
    exit 1
}

$tmpFolder = [System.IO.Path]::GetTempPath()
$fileName = [System.IO.Path]::GetFileName([system.uri]::UnescapeDataString($url))
$targetFile = Join-Path -Path $tmpFolder -ChildPath $fileName

Start-BitsTransfer -Source $url -Destination $targetFile -DisplayName $url -Description "to $targetFile"

Write-Host "Installing..." -ForegroundColor Cyan

# Params:
# https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#install-the-msi-package-from-the-command-line
$params = @(
    "/i", 
    "`"$($targetFile)`"", 
    "/passive", 
    "/norestart",
    "DISABLE_TELEMETRY=1", # for obvious reasons
    "USE_MU=1", # Opts into updating through Microsoft Update, WSUS or SCCM
    "ENABLE_MU=1" # Opts into updating through Microsoft Update
)

$proc = Start-Process -FilePath "msiexec.exe"-ArgumentList $params -Verb runAs-PassThru -Wait

if ($proc.ExitCode -eq 0) {
    Write-Host "Installation successful!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Installation failed with ExitCode $($proc.ExitCode)" -ForegroundColor Red
}

exit $proc.ExitCode

#endregion
###############################################################################
# <EOF>