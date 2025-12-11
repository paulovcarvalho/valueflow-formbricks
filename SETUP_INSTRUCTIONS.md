# Formbricks with MinIO - Setup Instructions

## ✅ Setup Complete

Your Formbricks instance is now configured with MinIO S3-compatible storage following the official documentation.

## Configuration Summary

### Services
- **Formbricks**: https://formbricks.local
- **MinIO (S3 API)**: https://files.formbricks.local
- **MinIO Console**: http://localhost:9001

### S3 Configuration
```
S3_ACCESS_KEY=formbricks-access-key
S3_SECRET_KEY=formbricks-secret-key-change-this-to-secure-password
S3_REGION=us-east-1
S3_BUCKET_NAME=formbricks-uploads
S3_ENDPOINT_URL=https://files.formbricks.local
S3_FORCE_PATH_STYLE=1
```

### Bucket
- **Name**: `formbricks-uploads`
- **Access**: Public read (required for image display)
- **Status**: ✅ Created automatically

## Required Setup Steps

### 1. Add DNS Entries to /etc/hosts

Run the provided script:
```bash
./add-dns-entries.sh
```

Or manually add to `/etc/hosts`:
```
127.0.0.1 formbricks.local files.formbricks.local
```

### 2. Trust the Self-Signed Certificate

Since we're using self-signed SSL certificates for local development:

**On macOS:**
1. Open Keychain Access
2. File → Import Items
3. Select `certs/formbricks.crt`
4. Double-click the certificate
5. Expand "Trust" section
6. Set "When using this certificate" to "Always Trust"

**On Chrome:**
- Navigate to https://formbricks.local
- Click "Advanced" → "Proceed to formbricks.local (unsafe)"
- Repeat for https://files.formbricks.local

**On Firefox:**
- Navigate to https://formbricks.local
- Click "Advanced" → "Accept the Risk and Continue"
- Repeat for https://files.formbricks.local

### 3. Verify Services are Running

```bash
docker-compose ps
```

All services should show "Up" status:
- postgres
- redis
- minio
- formbricks
- nginx

## Access URLs

- **Formbricks Application**: https://formbricks.local
- **MinIO S3 API**: https://files.formbricks.local
- **MinIO Console**: http://localhost:9001
  - Username: `formbricks-access-key`
  - Password: `formbricks-secret-key-change-this-to-secure-password`

## Testing File Uploads

1. Navigate to https://formbricks.local
2. Create an account or log in
3. Go to Project Settings
4. Try uploading a project logo
5. Or create a survey with file upload question
6. Upload a test file
7. Verify file appears in MinIO at http://localhost:9001

## Architecture

```
Browser → https://formbricks.local (port 443)
          ↓
       nginx (SSL termination)
          ↓
       formbricks:3000

Browser → https://files.formbricks.local (port 443)
          ↓
       nginx (SSL termination + CORS)
          ↓
       minio:9000
```

## File Structure

```
valueflow-formbricks/
├── docker-compose.yml           # Main configuration
├── nginx-ssl.conf               # Nginx SSL reverse proxy
├── certs/
│   ├── formbricks.crt          # SSL certificate
│   └── formbricks.key          # SSL private key
├── add-dns-entries.sh          # Script to add /etc/hosts entries
└── generate-certs.sh           # Script to generate SSL certs
```

## Troubleshooting

### Cannot access https://formbricks.local
- Check `/etc/hosts` has the DNS entries
- Verify nginx container is running: `docker-compose ps nginx`
- Check nginx logs: `docker-compose logs nginx`

### SSL certificate errors
- Trust the self-signed certificate in your browser
- Or accept the security warning

### Files not uploading
- Check MinIO is running: `docker-compose ps minio`
- Verify bucket exists: http://localhost:9001
- Check formbricks logs: `docker-compose logs formbricks`

### Images not displaying
- Verify bucket is public: `docker-compose exec minio mc anonymous get myminio/formbricks-uploads`
- Check CORS headers in browser dev tools
- Verify nginx is proxying correctly

## MinIO Console Access

Access MinIO console at http://localhost:9001:
- **Username**: `formbricks-access-key`
- **Password**: `formbricks-secret-key-change-this-to-secure-password`

Here you can:
- View uploaded files
- Manage buckets
- Check storage usage
- Configure access policies

## Production Deployment

For production, replace:
1. `formbricks.local` → your actual domain
2. `files.formbricks.local` → your S3 subdomain
3. Self-signed certificates → Let's Encrypt or proper SSL cert
4. Update DNS to point to your server IP
5. Configure firewall to allow ports 80 and 443

## Security Notes

- ✅ SSL/TLS encryption via nginx
- ✅ CORS properly configured on MinIO
- ✅ Public read access on bucket (required for image display)
- ⚠️  Self-signed certificates (for local development only)
- ⚠️  Use strong passwords in production

## References

- [Formbricks File Uploads Documentation](https://formbricks.com/docs/self-hosting/configuration/file-uploads)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
