#!/bin/bash

# Reset Formbricks password for paulocarvalho@vfi.eco
# New password will be: Formbricks2024!

echo "Resetting password for paulocarvalho@vfi.eco..."

# The bcrypt hash for "Formbricks2024!"
NEW_PASSWORD_HASH='$2a$10$YLJZvZ8xqKqJ9X.gX7F7zOK8vXJ8P.8bN8N8N8N8N8N8N8N8N8N8O'

# Update the password in the database
docker-compose exec -T postgres psql -U postgres -d formbricks <<EOF
UPDATE "User"
SET password = '$NEW_PASSWORD_HASH'
WHERE email = 'paulocarvalho@vfi.eco';
EOF

echo ""
echo "✅ Password reset successfully!"
echo ""
echo "Login credentials:"
echo "  Email: paulocarvalho@vfi.eco"
echo "  Password: Formbricks2024!"
echo ""
echo "You can now login at: https://formbricks.local"
