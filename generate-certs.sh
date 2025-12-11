#!/bin/bash

# Create certs directory
mkdir -p certs

# Generate self-signed SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/formbricks.key \
  -out certs/formbricks.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=*.formbricks.local" \
  -addext "subjectAltName=DNS:formbricks.local,DNS:files.formbricks.local,DNS:*.formbricks.local"

echo "SSL certificates generated successfully!"
echo "Located at: ./certs/"
