#Requires -Version 5.1

param(
    [switch]$updateonly = $false
)

$appName = "VLC Player"
###############################################################################
#region Functions
function Get-OnlineVersion {
    try {
        $baseUrl = "https://get.videolan.org/vlc/last/win64/"
        $http = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing

        $link = $http.Links | Where-Object { $_.href -like "vlc-*-win64.exe" } | Select-Object -First 1 -ExpandProperty href

        # extract version from link
        if($link -match "vlc-([0-9.]+)-win64.exe") {
            $bits = $matches[1].Split(".")
            return [Version]::new($bits[0], $bits[1], $bits[2], 0)
        }

        return $null
    }
    catch {
        return $null
    }
}

function Get-DownloadLink {
    try {
        $baseUrl = "https://get.videolan.org/vlc/last/win64/"
        $http = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing

        $link = $http.Links | Where-Object { $_.href -like "vlc-*-win64.exe" } | Select-Object -First 1 -ExpandProperty href

        return "$baseUrl$link"
    }
    catch {
        return $null
    }
}

function Get-InstalledVersion {
    # search Uninstall Registry
    $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "VLC*" }
    if (-not $uninstall) {
        return $null
    }

    $bits = $uninstall.DisplayVersion.Split(".")
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

$locale = Get-WinSystemLocale | Select-Object -ExpandProperty LCID
$params = @(
    "/L=$locale",
    "/S"
)

$proc = Start-Process -FilePath $targetFile -ArgumentList $params -PassThru -Wait

if ($proc.ExitCode -eq 0) {
    Write-Host "Installation successful!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Installation failed with ExitCode $($proc.ExitCode)" -ForegroundColor Red
}

exit $proc.ExitCode

#endregion
###############################################################################
# <EOF>