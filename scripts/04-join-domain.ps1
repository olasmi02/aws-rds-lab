<#
  Phase 4: rename RDS01, point it at DC01 for DNS and join the domain
  straight into the Servers OU. Run on RDS01 as the local Administrator.
#>

# Step 1: rename (restarts the server)
Rename-Computer -NewName RDS01 -Restart

# Step 2: DNS must work before the join. Stop if the lookup fails.
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses 10.0.0.10
Resolve-DnsName leyelab.internal    # expect 10.0.0.10

# Step 3: join (asks for the LEYELAB\Administrator password, then restarts)
Add-Computer -DomainName leyelab.internal `
    -OUPath "OU=Servers,OU=LeyeLab,DC=leyelab,DC=internal" `
    -Credential LEYELAB\Administrator -Restart

# After the restart, always log in to RDS01 as LEYELAB\Administrator.
