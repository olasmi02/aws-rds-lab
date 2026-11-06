<#
  Fix for a domain that came up without its DNS server.
  Symptom: Add-DnsServerForwarder "is not recognized", and
  Get-WindowsFeature DNS shows "Available" instead of "Installed".
  Run on DC01 in 64-bit PowerShell as Administrator, one block at a time.
#>

# 1. Install the DNS Server role and its tools
Install-WindowsFeature DNS -IncludeManagementTools

# 2. Make sure the AD application partitions for DNS exist
#    (an "already exists" message is fine)
dnscmd /CreateBuiltinDirectoryPartitions /Forest
dnscmd /CreateBuiltinDirectoryPartitions /Domain

# 3. Create the zones. Error 9609 (ResourceExists) means they are already
#    stored in Active Directory, which is fine: confirm with Get-DnsServerZone.
Add-DnsServerPrimaryZone -Name "leyelab.internal" -ReplicationScope "Domain" -DynamicUpdate Secure
Add-DnsServerPrimaryZone -Name "_msdcs.leyelab.internal" -ReplicationScope "Forest" -DynamicUpdate Secure
Get-DnsServerZone

# 4. Point DC01 at itself and re-register its records
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses 10.0.0.10,127.0.0.1
ipconfig /registerdns
Restart-Service Netlogon

# 5. Wait a minute, then verify
Add-DnsServerForwarder -IPAddress 10.0.0.2
Resolve-DnsName dc01.leyelab.internal                              # expect 10.0.0.10
Resolve-DnsName _ldap._tcp.dc._msdcs.leyelab.internal -Type SRV    # expect dc01.leyelab.internal, port 389
Resolve-DnsName amazon.com
