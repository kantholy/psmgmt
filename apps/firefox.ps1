#Requires -Version 5.1

param(
    [switch]$updateonly = $false,
    [switch]$autoupdate = $true
)

$appName = "Mozilla Firefox"

###############################################################################
#region Functions
function Get-OnlineVersion {
    try {
        $json = Invoke-RestMethod -Uri "https://product-details.mozilla.org/1.0/firefox_versions.json"
        $version = $json.FIREFOX_ESR
    }
    catch {
        return $null
    }

    $version = $version -replace "[^\d\.]", ""
    $bits = $version.Split(".")
    return [Version]::new($bits[0], $bits[1], $bits[2], 0)
}

function Get-MsiDownloadLink {
    try {
        $url = "https://download.mozilla.org/?product=firefox-esr-msi-latest-ssl&os=win64&lang=de"
        if ($PSVersionTable.PSVersion -gt 5) {
            $req = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction:SilentlyContinue
            $msiUrl = $req.Headers.Location | Select-Object -First 1
        } else {
            $req = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction:SilentlyContinue
            $msiUrl = $req.Headers.Location
        }
        
        $fileName = [System.IO.Path]::GetFileName([system.uri]::UnescapeDataString($msiUrl))

        $version = $fileName -replace "[^\d\.]", ""
        $bits = $version.Split(".")
        $version = [Version]::new($bits[0], $bits[1], $bits[2], 0)

        return [pscustomobject]@{
            Url      = $msiUrl
            FileName = $fileName
            Version  = $version
        }
    }
    catch {
        Write-Error $_
        return $null
    }
}

function Get-InstalledVersion {
    # search Uninstall Registry for Mozilla Firefox
    $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Mozilla Firefox*" }
    if (-not $uninstall) {
        return $null
    }

    $bits = $uninstall.DisplayVersion.Split(".")
    return [Version]::new($bits[0], $bits[1], $bits[2], 0)
}

#endregion
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
    Write-Host "$appName is installed and up to date!" -ForegroundColor Green
    exit 0
} elseif ($installedVersion -gt $onlineVersion) {
    Write-Host "SKIPPED: Your installed $appName version is higher than the available version." -ForegroundColor Yellow
    exit 0
}


#endregion
###############################################################################
#region Download and Install

Write-Host "Downloading $appName $onlineVersion..." -ForegroundColor Cyan


$msi = Get-MsiDownloadLink

if(-not $msi) {
    Write-Host "ERROR: Unable to fetch MSI Installer." -ForegroundColor Red
    exit 1
}

$tmpFolder = [System.IO.Path]::GetTempPath()
$targetFile = Join-Path -Path $tmpFolder -ChildPath $msi.FileName

Start-BitsTransfer -Source $msi.Url -Destination $targetFile -DisplayName $msi.FileName -Description "to $targetFile"

Write-Host "Installing..." -ForegroundColor Cyan


# see https://support.mozilla.org/en-US/kb/deploy-firefox-msi-installers#w_configuration-options
$params = @(
    "/i", 
    "`"$($targetFile)`"", 
    "/passive", 
    "/norestart", 
    "TASKBAR_SHORTCUT=false", 
    "DESKTOP_SHORTCUT=false", 
    "OPTIONAL_EXTENSIONS=false", 
    "INSTALL_MAINTENANCE_SERVICE=false", 
    "PRIVATE_BROWSING_SHORTCUT=false"
)

if($autoupdate) {
    $params += "INSTALL_MAINTENANCE_SERVICE=false"
}

$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $params -PassThru -Wait

if ($proc.ExitCode -eq 0) {
    Write-Host "Installation successful!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Installation failed with ExitCode $($proc.ExitCode)" -ForegroundColor Red
}

exit $proc.ExitCode

#endregion
###############################################################################
# <EOF>