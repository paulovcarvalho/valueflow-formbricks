#!/bin/bash

# Add local DNS entries for Formbricks
echo "Adding DNS entries to /etc/hosts..."
echo "127.0.0.1 formbricks.local files.formbricks.local" | sudo tee -a /etc/hosts

echo "DNS entries added successfully!"
echo "You can now access:"
echo "  - Formbricks: https://formbricks.local"
echo "  - MinIO: https://files.formbricks.local"
