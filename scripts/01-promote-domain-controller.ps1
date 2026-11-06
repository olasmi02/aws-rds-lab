<#
  Phase 2: rename DC01 and create the leyelab.internal forest.
  Run on DC01 in 64-bit PowerShell as Administrator.
  Step 1 restarts the server. Run step 2 after logging back in.
#>

# Step 1: rename (restarts the server)
Rename-Computer -NewName DC01 -Restart

# Step 2: install AD DS and create the forest (restarts the server when done).
# Paste the Install-ADDSForest command as ONE line; if it gets cut off,
# the domain can come up without its DNS server.
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName "leyelab.internal" -DomainNetbiosName "LEYELAB" -InstallDns -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password") -Force

# Step 3: after the restart, log in as LEYELAB\Administrator and check
Get-WindowsFeature DNS                      # Install State must be Installed
Add-DnsServerForwarder -IPAddress 10.0.0.2  # AWS VPC resolver (VPC base + 2)
Resolve-DnsName amazon.com
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, PDCEmulator
