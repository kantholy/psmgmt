#Requires -Version 5.1

param(
    [switch]$updateonly = $false
)

$appName = "7-Zip"
###############################################################################
#region Functions
function Get-OnlineVersion {
    try {
        $json = Invoke-RestMethod -Uri "https://api.github.com/repos/ip7z/7zip/releases/latest"
        $bits = $json.tag_name.Split(".")
        return [Version]::new($bits[0], $bits[1], $bits[2], 0)
    }
    catch {
        return $null
    }
}

function Get-DownloadLink {
    try {
        $json = Invoke-RestMethod -Uri "https://api.github.com/repos/ip7z/7zip/releases/latest"
        return $json.assets | Where-Object { $_.Name -like "7z*-x64.msi" } | Select-Object -ExpandProperty browser_download_url
    }
    catch {
        return $null
    }
}

function Get-InstalledVersion {
    $path = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path $path)) {
        return $null
    }

    $version = (Get-Command $path).FileVersionInfo.ProductVersion
    $bits = $version.Split(".")
    return [Version]::new($bits[0], $bits[1], $bits[2], 0)
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
    Write-Host "SKIPPED: Your installed $appName version is higher than the available version." -ForegroundColor Yellow
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

$params = @(
    "/i", 
    "`"$($targetFile)`"", 
    "/passive", 
    "/norestart"
)

$proc = Start-Process -FilePath "msiexec.exe"-ArgumentList $params -PassThru -Wait

if ($proc.ExitCode -eq 0) {
    Write-Host "Installation successful!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Installation failed with ExitCode $($proc.ExitCode)" -ForegroundColor Red
}

exit $proc.ExitCode

#endregion
###############################################################################
# <EOF>