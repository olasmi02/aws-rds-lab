<#
  Quick checks used during the break-and-fix scenarios.
  Run each line on its own; the comment says where.
#>

# Laptop: can I reach the gateway at all? (False = firewall rule or home IP changed)
Test-NetConnection <gateway-name> -Port 443

# RDS01: why was a user refused at the gateway? (event 201, error 23003 = not in an allowed group)
Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-Gateway/Operational" -MaxEvents 10 | Format-List TimeCreated, Id, Message
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=6273} -MaxEvents 5 | Format-List TimeCreated, Message

# DC01: is the account locked, and where did the bad attempts come from?
Get-ADUser grace.eze -Properties LockedOut, BadLogonCount | Select-Object Name, LockedOut, BadLogonCount
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 5 | Format-List TimeCreated, Message
Unlock-ADAccount grace.eze

# RDS01: is domain DNS and the domain trust healthy?
Resolve-DnsName leyelab.internal
Test-ComputerSecureChannel
gpupdate /force

# RDS01: is the gateway service running?
Get-Service TSGateway
Start-Service TSGateway

# RDS01: can it reach the domain controller's LDAP port?
Test-NetConnection 10.0.0.10 -Port 389

# Which machine is this gpresult from? Check the computer account in the output.
gpresult /r /scope computer
