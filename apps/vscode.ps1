#Requires -Version 5.1

param(
    [switch]$updateonly = $false
)


$appName = "Visual Studio Code"

###############################################################################
#region Functions
function Get-OnlineVersion {
     try {
        $json = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/vscode/releases/latest"
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
        $url = "https://update.code.visualstudio.com/latest/win32-x64/stable"

        if ($PSVersionTable.PSVersion -gt [Version]::new(5, 2, 0, 0)) {
            $req = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction:SilentlyContinue
            $msiUrl = $req.Headers.Location | Select-Object -First 1
        } else {
            $req = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction:SilentlyContinue
            $msiUrl = $req.Headers.Location
        }

        $fileName = [System.IO.Path]::GetFileName([system.uri]::UnescapeDataString($msiUrl))

        if($fileName -match "-([0-9.]+)\.exe") {
            $bits = $matches[1].Split(".")
            $version = [Version]::new($bits[0], $bits[1], $bits[2], 0)
        } else  {
            $version = $null
        }

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
    $uninstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Microsoft Visual Studio Code*" }
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


$setup = Get-DownloadLink

if(-not $setup) {
    Write-Host "ERROR: Unable to fetch Installer." -ForegroundColor Red
    exit 1
}

$tmpFolder = [System.IO.Path]::GetTempPath()
$targetFile = Join-Path -Path $tmpFolder -ChildPath $setup.FileName

Start-BitsTransfer -Source $setup.Url -Destination $targetFile -DisplayName $setup.FileName -Description "to $targetFile"

Write-Host "Installing..." -ForegroundColor Cyan


$params = "/SP- /SILENT /ALLUSERS /NORESTART /LOG /MERGETASKS=!runcode,!desktopicon,!quicklaunchicon"


if($autoupdate) {
    $params += "INSTALL_MAINTENANCE_SERVICE=false"
}

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