# Windows Updates

How to automate Windows Updates using Powershell.

**Important:** The following scripts are intended to be used across multiple servers at once!
Make sure to fill the `$servers` variable first!

- can be the current server: `$servers = $env:COMPUTERNAME` or `$servers = "localhost"`
- can be a single item: `$servers = "srv01"`
- can be a list of servers: `$servers = "srv01", "srv02", "srv03"`
- can be filled using a list of servers out of a text file: `$servers = Get-Content servers.txt`
- can by dynamically selected using the Active Directory Module:
  - `$servers = Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*' } | Sort Name | Select -ExpandProperty Name`
  - `$servers = Get-ADComputer -Filter { Name -like '*HV*' } | Select-Object -ExpandProperty Name`
  - `$servers = Get-ADComputer -Filter { Name -like 'RDS-*' } | Select-Object -ExpandProperty Name`

Also, all commands return their result into `$result` variable, to enable further analysis + filtering after the command was run

## PSWindowsUpdate Installation

```powershell
Invoke-Command -ComputerName $servers -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module PSWindowsUpdate -Force
} -OutVariable result
```

## Search for Updates

```powershell
Invoke-Command -ComputerName $servers -ScriptBlock {
    Get-WUList
} -OutVariable result
```

## Install Update

```powershell
# CAUTION: Autopilot active: 
# CAUTION: this will Reboot the Computer when finished
Invoke-Command -ComputerName $servers -ScriptBlock {
    Install-WindowsUpdate -AcceptAll -AutoReboot
} -OutVariable result

###############################################################################
# With scheduled reboot at specified time. 
# please adjust accordingly to your needs and maintenance window
# for example: today @ 22:20
$reboot = Get-Date -Hour 22 -Minute 20 -Second 00

Invoke-Command -ComputerName $servers -ScriptBlock {
    Install-WindowsUpdate -AcceptAll -ScheduleReboot $Using:reboot
} -OutVariable result
```

## Show History

```powershell
# show updates installed in the last 3 month
$since = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(-3)

Invoke-Command -ComputerName $servers -ScriptBlock {
    Get-WUHistory -MaxDate $Using:since
} -OutVariable result
```

### Show unsuccessful Updates only

```powershell
$since = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(-3)
Invoke-Command -ComputerName $servers -ScriptBlock {
    Get-WUHistory -MaxDate $Using:since
} | Where-Object Result -ne "Succeeded" -Outvariable $result
```
