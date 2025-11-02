# PowerShell script to generate self-signed certificates for development
param(
    [string]$OutDir = ".\certs",
    [string]$Domain = "localhost"
)

# Ensure output directory exists
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$certPath = Join-Path $OutDir "server.crt"
$keyPath = Join-Path $OutDir "server.key"

# Check if openssl is available
if (Get-Command "openssl.exe" -ErrorAction SilentlyContinue) {
    Write-Host "Generating certificates using OpenSSL..."
    & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout $keyPath -out $certPath `
        -subj "/CN=$Domain" `
        -addext "subjectAltName = DNS:$Domain,DNS:localhost,IP:127.0.0.1"
} else {
    Write-Host "OpenSSL not found, using PowerShell New-SelfSignedCertificate..."
    
    # Generate certificate
    $cert = New-SelfSignedCertificate `
        -Subject "CN=$Domain" `
        -DnsName $Domain,"localhost" `
        -IPAddress "127.0.0.1" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -NotAfter (Get-Date).AddDays(365) `
        -CertStoreLocation "Cert:\LocalMachine\My"

    # Export certificate
    $pwd = ConvertTo-SecureString -String "password" -Force -AsPlainText
    $certPath = Join-Path $OutDir "server.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $pwd | Out-Null
    
    # Convert to PEM format if OpenSSL is available later
    Write-Host "Certificate generated at: $certPath"
    Write-Host "Note: You may need to convert the PFX to PEM format using OpenSSL later"
}

Write-Host "Certificate files generated:"
Write-Host "Certificate: $certPath"
Write-Host "Private Key: $keyPath"