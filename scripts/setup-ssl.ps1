$ErrorActionPreference = "Stop"

# Create certs directory if it doesn't exist
$certsDir = ".\certs"
if (-not (Test-Path $certsDir)) {
    New-Item -ItemType Directory -Path $certsDir | Out-Null
}

# Generate private key and certificate
Write-Host "Generating self-signed certificate..."
$commonName = "localhost"
$cert = New-SelfSignedCertificate `
    -Subject "CN=$commonName" `
    -DnsName @("localhost", "api") `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(1) `
    -CertStoreLocation "Cert:\LocalMachine\My"

# Export certificate and private key
$password = ConvertTo-SecureString -String "temp1234" -Force -AsPlainText
$certPath = Join-Path $certsDir "server.pfx"
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $password | Out-Null

Write-Host "Converting to PEM format..."
# Using OpenSSL to convert PFX to PEM format (requires OpenSSL in PATH)
if (Get-Command "openssl.exe" -ErrorAction SilentlyContinue) {
    $env:OPENSSL_CONF = $null  # Avoid potential OpenSSL config issues
    
    # Extract private key
    openssl pkcs12 -in "$certPath" -nocerts -nodes -out ".\certs\server.key" -password pass:temp1234
    
    # Extract certificate
    openssl pkcs12 -in "$certPath" -clcerts -nokeys -out ".\certs\server.crt" -password pass:temp1234
    
    # Clean up PFX
    Remove-Item $certPath
    
    Write-Host "`nCertificate files generated successfully:"
    Write-Host "  - .\certs\server.key (private key)"
    Write-Host "  - .\certs\server.crt (certificate)"
} else {
    Write-Host "OpenSSL not found. Please install OpenSSL or add it to your PATH to convert the certificate."
    Write-Host "Certificate exported as: $certPath"
}