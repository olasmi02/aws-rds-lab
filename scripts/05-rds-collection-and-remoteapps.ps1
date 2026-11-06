<#
  Phase 5: after the Server Manager wizard has deployed RD Connection Broker,
  RD Web Access and RD Session Host on RDS01, create the collection,
  licensing and RemoteApps. Run on RDS01 as LEYELAB\Administrator.
#>

$cb = "RDS01.leyelab.internal"

New-RDSessionCollection -CollectionName "LabDesktops" -SessionHost $cb -ConnectionBroker $cb -CollectionDescription "Desktops for LeyeLab staff"
Set-RDSessionCollectionConfiguration -CollectionName "LabDesktops" -UserGroup "LEYELAB\RDS-Users" -ConnectionBroker $cb

# Lab only: licensing runs on the 120-day grace period, no CALs installed.
Add-RDServer -Server $cb -Role "RDS-LICENSING" -ConnectionBroker $cb
Set-RDLicenseConfiguration -LicenseServer $cb -Mode PerUser -ConnectionBroker $cb -Force

New-RDRemoteApp -CollectionName "LabDesktops" -DisplayName "Notepad" -FilePath "C:\Windows\System32\notepad.exe" -ConnectionBroker $cb
New-RDRemoteApp -CollectionName "LabDesktops" -DisplayName "Paint"   -FilePath "C:\Windows\System32\mspaint.exe"  -ConnectionBroker $cb

# Verify Group Policy on RDS01 later (Phase 6)
# gpupdate /force
# gpresult /r /scope computer
