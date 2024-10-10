# Powershell Utilities & Scripts Collection

(c) 2024, Tobias Düthorn

This repo is my digital brain extension, the purpose is to collect and share some common powershell scripts and lines in order to make my life as a sysadmin easier.

## App Installer

> [!CAUTION]
> Please do not run these commands without checking the files first
> Trusting random strangers of the internet is the worst idea you can do!
>
> You have been warned.

```powershell
$installer = Join-Path $env:TEMP "installer.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/kantholy/psmgmt/refs/heads/master/apps/firefox.ps1 -OutFile $installer
. $installer

# available flags:
# -updateonly
# -autoupdate:$false
```
