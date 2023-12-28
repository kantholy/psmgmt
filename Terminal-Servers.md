# Terminal Server Management

Terminal Session Management made easy!

**Important:** The following scripts are intended to be used across multiple servers at once!
Make sure to fill the `$servers` variable first!

- can be the current server: `$servers = $env:COMPUTERNAME` or `$servers = "localhost"`
- can be a single item: `$servers = "srv01"`
- can be a list of servers: `$servers = "srv01", "srv02", "srv03"`
- can be filled using a list of servers out of a text file: `$servers = Get-Content servers.txt`
- can by dynamically selected using the Active Directory Module:
  - `$servers = Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*' } | Sort Name | Select -ExpandProperty Name`
  - `$servers = Get-ADComputer -Filter { Name -like 'RDS-*' } | Select-Object -ExpandProperty Name`

Also, all commands return their result into `$result` variable, to enable further analysis + filtering after the command was run!

Further Docs:

- [imseandavis/PSTerminalServices](https://github.com/imseandavis/PSTerminalServices)

## Prerequisites

- the following commands rely heavily on **PSTerminalServices**!
- The Module only needs to be installed on Jump-Host / Admin-VM, not on all target computers

```powershell
# install Prerequisites 
Install-Module PSTerminalServices -Force
```

## Get a list of all RDS Servers

```powershell
# get a list of all RDS servers from RDS session broker
$broker = "rds-broker"
Get-RDServer -ConnectionBroker $broker -Role RDS-RD-SERVER | Select-Object -ExpandProperty Server -OutVariable servers
```

## List Sessions

```powershell
$servers | % { Get-TSSession -ComputerName $_ } -OutVariable result
```

### List only active sessions

```powershell
$servers | % { Get-TSSession -ComputerName $_ -State Active } -OutVariable result
```

### List all active + disconnected sessions

```powershell
$servers | % { Get-TSSession -ComputerName $_ -Filter { $_.ConnectionState -match "(Active|Disconnected)" -and $_.WindowStationName -ne "Services" }} -OutVariable result
```

## Send a Message to all active Sessions

```powershell
$caption = "Wartungsarbeiten"
$message = "Es müssen dringende Wartungsarbeiden durchgeführt werden.`n`nBitte speicherne Sie Ihre Daten, beenden Sie alle Remote-Apps und melden Sie sich umgehend vom Server ab.`n`nVielen Dank, Ihre IT."
$servers | % { Get-TSSession -ComputerName $_ -State Active } | Foreach-Object {
    Send-TSMessage -ComputerName $_.Server.ServerName -Id $_.SessionId -Caption $caption -Text $message
}
```

## Disconnect all Sessions

- [Docs: Disconnect-TSSession](https://github.com/imseandavis/PSTerminalServices/blob/master/PSTerminalServices/en-US/Disconnect-TSSession.md)

```powershell
# CAUTION: this command will **disconnect** all active sessions
# by default, the command is run in "interactive" mode: all disconnects must be confirmed
# to override, use the -Force Parameter (commeted out)
$servers | % { Get-TSSession -ComputerName $_ -State Active } -OutVariable result
$result | Disconnect-TSSession #-Force
```

## Logoff all Sessions

```powershell
# CAUTION: this command will **logoff** all active and disconnected sessions!
$servers | % { Get-TSSession -ComputerName $_ -Filter { $_.ConnectionState -match "(Active|Disconnected)" -and $_.WindowStationName -ne "Services" }} -OutVariable result
$result | Foreach-Object {
    $server = [string]$_.Server.ServerName
    logoff $_.SessionID /SERVER:$server
}

```