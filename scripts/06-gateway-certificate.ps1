<#
  Phase 7: add RD Gateway and create a certificate browsers and clients accept.
  Run on RDS01 as LEYELAB\Administrator.
  Replace <gateway-name> with RDS01's public DNS name (fixed by an Elastic IP).

  Why New-SelfSignedCertificate: certificates Windows creates automatically can
  lack the key usage modern TLS needs, and Chrome/Edge then fail with
  ERR_SSL_KEY_USAGE_INCOMPATIBLE. Production would use a publicly trusted
  certificate instead.
#>

$cb = "RDS01.leyelab.internal"
Add-RDServer -Server $cb -Role "RDS-GATEWAY" -ConnectionBroker $cb -GatewayExternalFqdn "<gateway-name>"
New-Item -ItemType Directory -Path C:\certs -Force

$cert = New-SelfSignedCertificate -DnsName "<gateway-name>", "rds01.leyelab.internal" `
    -CertStoreLocation Cert:\LocalMachine\My `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -KeyExportPolicy Exportable -NotAfter (Get-Date).AddYears(1)

$pw = Read-Host -AsSecureString "Certificate password"
Export-PfxCertificate -Cert $cert -FilePath C:\certs\rdgw.pfx -Password $pw

# Then, in Server Manager > Remote Desktop Services > Deployment Properties >
# Certificates, assign C:\certs\rdgw.pfx to all four roles.

# Confirm which certificate the gateway is actually using:
Get-RDCertificate -Role RDGateway -ConnectionBroker $cb | Select-Object Subject, Thumbprint
