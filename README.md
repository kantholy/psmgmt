# Powershell Utilities & Scripts Collection

(c) 2024, Tobias Düthorn

This repo is my digital brain extension, the purpose is to collect and share some common powershell scripts and lines in order to make my life as a sysadmin easier.

## App Installer

> [!CAUTION]
> Please do not run these commands without checking the files first<br>
> Trusting random strangers of the internet is the worst idea you can do!
>
> **You have been warned.**

### 7-zip

```powershell
$installer = Join-Path $env:TEMP "installer.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/kantholy/psmgmt/refs/heads/master/apps/7zip.ps1 -OutFile $installer
. $installer
```

> [!NOTE] 
> available flags:
>
> * `-updateonly` only updates 7zip if installed already

### Firefox

```powershell
$installer = Join-Path $env:TEMP "installer.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/kantholy/psmgmt/refs/heads/master/apps/firefox.ps1 -OutFile $installer
. $installer
```

> [!NOTE] 
> available flags:
>
> * `-updateonly` only updates firefox if installed already
> * `-autoupdate:$false` prevents the installation of the firefox maintenance service
