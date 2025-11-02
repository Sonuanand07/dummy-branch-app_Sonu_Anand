# Simplified certificate generation for older PowerShell versions
$certsDir = "."  # Current directory (we're already in certs)

# Generate self-signed certificate
$cert = New-SelfSignedCertificate `
    -Subject "CN=localhost" `
    -DnsName "localhost","api" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(1) `
    -CertStoreLocation "Cert:\LocalMachine\My"

# Export certificate
$pwd = ConvertTo-SecureString -String "password" -Force -AsPlainText
$pfxPath = Join-Path $certsDir "server.pfx"
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwd | Out-Null

Write-Host "Generated $pfxPath"
Write-Host "Note: You'll need OpenSSL to convert this to PEM format for use with gunicorn."