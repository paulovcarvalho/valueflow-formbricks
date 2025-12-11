#!/bin/bash

# Script to add s3.local to /etc/hosts on macOS/Linux
# This allows the browser to resolve s3.local to localhost

echo "Checking if s3.local is already in /etc/hosts..."

if grep -q "s3.local" /etc/hosts; then
    echo "✅ s3.local is already configured in /etc/hosts"
    grep "s3.local" /etc/hosts
else
    echo "Adding s3.local to /etc/hosts (requires sudo)..."
    echo "127.0.0.1 s3.local" | sudo tee -a /etc/hosts
    echo "✅ Added s3.local to /etc/hosts"
fi

echo ""
echo "Verifying configuration..."
getent hosts s3.local || dscacheutil -q host -a name s3.local

echo ""
echo "Testing S3 endpoint access..."
curl -s http://s3.local:9000 | head -3

echo ""
echo "✅ Setup complete! Your browser can now access http://s3.local:9000"
