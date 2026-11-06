# Troubleshooting log

Real problems I ran into while building and testing the lab, none of them planned. Each is written as situation, cause, fix and lesson.

## 1. The server launch failed: IP outside the subnet

- **Situation:** launching DC01 failed with "Address 10.0.1.10 does not fall within the subnet's address range".
- **Cause:** the subnet was created as `10.0.0.0/24`, not the `10.0.1.0/24` I'd planned, and a subnet's address range can't be changed after it's created.
- **Fix:** kept the existing subnet and re-planned the server addresses to `10.0.0.10` and `10.0.0.20`, both inside the range and clear of the five addresses AWS reserves in every subnet.
- **Lesson:** check the subnet's actual CIDR before assigning fixed IPs.

## 2. The free plan didn't allow the planned instance size

- **Situation:** the plan had RDS01 on t3.medium.
- **Cause:** new AWS accounts on the free plan can only launch certain instance types, and t3.medium isn't one of them.
- **Fix:** checked the eligible list and the account's vCPU quota, then used m7i-flex.large (2 vCPUs, 8 GiB) for the session host. DC01 stayed on t3.small, which is enough for a small domain controller.
- **Lesson:** size each server for its own job. A domain controller does light work; a session host carries everyone's desktop.

## 3. The domain came up without its DNS server

- **Situation:** after promoting DC01, `Add-DnsServerForwarder` failed with "is not recognized".
- **Cause:** `Get-WindowsFeature` showed the DNS Server role as Available, not Installed. The domain existed (`Get-ADDomain` worked), but its DNS server didn't, so other servers would have had no way to find the domain.
- **Fix:** installed the DNS role. Creating the zones returned error 9609, which meant `leyelab.internal` and `_msdcs.leyelab.internal` already existed in Active Directory, confirmed with `Get-DnsServerZone`. Pointed DC01's DNS at itself, ran `ipconfig /registerdns`, restarted Netlogon to re-register the SRV records, and confirmed `_ldap._tcp.dc._msdcs.leyelab.internal` resolved to `dc01.leyelab.internal` on port 389. ([script](../scripts/02-repair-dc-dns.ps1))
- **Lesson:** confirm each layer after a wizard runs: role installed, zones present, records registered.

## 4. Chrome refused the RD Web Access page

- **Situation:** `https://rds01.leyelab.internal/RDWeb` failed with `ERR_SSL_KEY_USAGE_INCOMPATIBLE`, and there was no option to continue.
- **Cause:** the certificate Windows created automatically for the web server wasn't marked for the digital signatures modern TLS needs. Current browsers reject that outright, unlike a merely untrusted certificate.
- **Fix:** created a new certificate with `New-SelfSignedCertificate -KeyUsage DigitalSignature, KeyEncipherment` and bound it to the HTTPS site in IIS. I created the gateway certificate the same way later, so the problem couldn't come back. ([script](../scripts/06-gateway-certificate.ps1))
- **Lesson:** an *untrusted* certificate and an *unusable* certificate fail differently. Know which one you're looking at.

## 5. Two certificates with the same name

- **Situation:** the certificate store on RDS01 had two certificates issued to the gateway's name.
- **Cause:** installing the RD Gateway role creates a placeholder certificate (Server Authentication only). Mine also had Client Authentication in its Enhanced Key Usage.
- **Fix:** confirmed which one the gateway used by matching thumbprints with `Get-RDCertificate -Role RDGateway`, then exported that one for the client.
- **Lesson:** Key Usage says what a key can do; Enhanced Key Usage says what the certificate is for. Thumbprints settle any doubt.

## 6. Deleting the firewall rule didn't end my session

- **Situation:** after I deleted the RDP rule from the security group, my remote desktop session carried on working.
- **Cause:** security groups are stateful. Removing a rule blocks new connections but lets tracked, already-open connections continue.
- **Fix:** closed the session and tried to reconnect on port 3389, which failed, proving the rule change worked.
- **Lesson:** during an incident, closing a firewall rule isn't enough. You also have to end the live session.

## 7. A Group Policy seemed not to apply

- **Situation:** `gpresult` didn't list the new `RDP Security - Servers` GPO.
- **Cause:** I'd run it on DC01, not RDS01. The output listed the Default Domain Controllers Policy, and the computer account was `DC01$`. Group Policy Management also never shows computers, which made it look as if RDS01 wasn't in the Servers OU.
- **Fix:** ran `gpresult /r /scope computer` on RDS01, which showed the GPO applied; confirmed RDS01's OU in Active Directory Users and Computers.
- **Lesson:** check which machine the output belongs to before deciding a policy failed.

## 8. Gateway refusals weren't being logged

- **Situation:** testing a user who shouldn't get in, I found nothing in the gateway log or the Security log, even with NPS auditing switched on.
- **Cause:** my home internet IP had changed since the previous session, so the security group's HTTPS rule no longer matched. My connection never reached the server, so there was nothing to log.
- **Fix:** `Test-NetConnection <gateway> -Port 443` confirmed the path was blocked; updated the rule's source to my current IP. The refusal then appeared as gateway event 201, error 23003.
- **Lesson:** empty logs can mean the traffic never arrived. Check the network path before digging into logs.

## 9. A locked account didn't say it was locked

- **Situation:** after five wrong passwords, the client only showed "The logon attempt failed".
- **Cause:** through the gateway, Windows gives the same vague message for every login failure, so an attacker can't learn which accounts exist or are locked.
- **Fix:** proved the lockout by entering the correct password (still failed) and checking `Get-ADUser grace.eze -Properties LockedOut`, then found the source in event 4740.
- **Lesson:** don't rely on the user's error message; confirm the account state directly.

## 10. A different refusal than expected

- **Situation:** testing a certificate name mismatch, I got "Your user account is not authorized to access the RD Gateway" instead of a certificate error.
- **Cause:** I'd put the IP in the target computer box instead of the gateway box. The gateway accepted me, then its Resource Authorization Policy refused to forward me to an address it didn't recognise.
- **Fix:** moved the IP to the gateway box, which produced the expected failure (`0x3000008`).
- **Lesson:** the gateway has two policies: the CAP decides *who* can connect, the RAP decides *where* they can go.

## 11. Stopping the domain controller cut off server management

- **Situation:** with DC01 stopped, Session Manager couldn't connect to RDS01: "lookup ssmmessages.eu-west-1.amazonaws.com: no such host".
- **Cause:** RDS01 used DC01 as its only DNS server. With DC01 down, it couldn't resolve any name, including the AWS endpoint its SSM Agent needs.
- **Fix:** started DC01 and waited until RDS01 showed Online again in Fleet Manager.
- **Lesson:** a single domain controller is a single point of failure for logins, DNS and anything that depends on DNS. Production needs two. Adding a public DNS server as a backup isn't the answer, because domain members would sometimes ask it about the domain and fail.
