#!/bin/bash
set -e

# Directory for certificates
CERT_DIR="./certs"
mkdir -p "$CERT_DIR"

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.crt" \
  -subj "/CN=localhost" \
  -addext "subjectAltName = DNS:localhost,DNS:api,IP:127.0.0.1"

# Set permissions
chmod 644 "$CERT_DIR/server.crt"
chmod 600 "$CERT_DIR/server.key"

echo "Generated certificates in $CERT_DIR:"
echo "  - server.crt (public certificate)"
echo "  - server.key (private key)"