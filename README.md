# Formbricks with Google Drive S3 Storage

## Overview

This setup integrates Formbricks with Google Drive Shared Drive storage using rclone as an S3-compatible translation layer.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Browser                             │
│                               │                                  │
│         ┌─────────────────────┼─────────────────────┐           │
│         │                     │                     │           │
│   http://localhost:3100 http://host.docker.internal:9000       │
└─────────┼─────────────────────┼─────────────────────┼───────────┘
          │                     │                     │
          ▼                     │                     ▼
  ┌──────────────┐             │          ┌───────────────────┐
  │ nginx-proxy  │             │          │   rclone-s3       │
  │  (port 3100) │             │          │   (port 9000)     │
  └──────┬───────┘             │          └─────────┬─────────┘
         │                     │                    │
         ▼                     │                    ▼
  ┌──────────────┐             │          ┌───────────────────┐
  │  Formbricks  │─────────────┘          │  Google Drive     │
  │  (port 3000) │                        │  Shared Drive     │
  └──────────────┘                        │   "vfi-apps"      │
                                          └───────────────────┘
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| postgres | pgvector/pgvector:pg17 | 5432 | Database |
| redis | valkey/valkey | 6379 | Cache & rate limiting |
| rclone-s3 | rclone/rclone | 9000 | S3 API for Google Drive |
| formbricks | formbricks:latest | 3000 | Main application |
| formbricks-proxy | nginx:alpine | 3100 | CSP modification proxy |

## Configuration

### S3 Storage
- **Endpoint**: `http://host.docker.internal:9000`
- **Access Key**: `formbricks-access-key`
- **Secret Key**: `formbricks-secret-key-change-this-to-secure-password`
- **Bucket**: `formbricks`
- **Region**: `us-east-1`

### Google Drive
- **Type**: Shared Drive (Team Drive)
- **Name**: vfi-apps
- **ID**: 0ANrWRo_JRi5mUk9PVA
- **Service Account**: share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com
- **Config Path**: `rclone/config/rclone.conf`
- **Credentials Path**: `secrets/sacred-flash-452501-m0-3eebf66010fe.json`

## How It Works

1. **Server-side uploads** (Formbricks → S3):
   - Formbricks uses `S3_ENDPOINT_URL=http://host.docker.internal:9000`
   - Container resolves `host.docker.internal` to host machine
   - Connects to rclone-s3 on port 9000
   - rclone translates S3 API calls to Google Drive API

2. **Client-side downloads** (Browser → S3):
   - Formbricks generates presigned URLs: `http://host.docker.internal:9000/...`
   - Browser uses these URLs to download files directly from rclone-s3
   - nginx-proxy modifies CSP to allow `host.docker.internal:9000`

## Quick Start

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Access Formbricks
open http://localhost:3100
```

## Testing File Uploads

1. Navigate to [http://localhost:3100](http://localhost:3100)
2. Create an account or login
3. Create a survey with a file upload question
4. Test uploading a file
5. Verify the file appears in Google Drive Shared Drive "vfi-apps"

## Troubleshooting

### Check S3 Endpoint

```bash
# From host
curl http://localhost:9000
# Should return S3 error (expected)

# From Formbricks container
docker-compose exec formbricks curl http://host.docker.internal:9000
# Should return S3 error (expected)
```

### Check Google Drive Connection

```bash
# View rclone logs
docker-compose logs rclone-s3

# Test rclone manually
docker-compose exec rclone-s3 rclone ls gdrive:
```

### Check CSP Headers

```bash
curl -I http://localhost:3100 | grep CSP
# Should include: http://host.docker.internal:9000
```

### Common Issues

**Issue**: File uploads fail with CORS error
- **Solution**: Check rclone-s3 logs for authentication errors

**Issue**: Browser blocks file downloads
- **Solution**: Verify CSP includes `host.docker.internal:9000`

**Issue**: Formbricks can't connect to S3
- **Solution**: Verify `host.docker.internal` resolves correctly in container

## File Structure

```
valueflow-formbricks/
├── docker-compose.yml           # Main orchestration
├── formbricks-proxy.conf        # nginx CSP proxy config
├── nginx.conf                   # (not used, leftover)
├── rclone/
│   └── config/
│       └── rclone.conf          # Google Drive config
├── secrets/
│   └── sacred-flash-*.json      # Service account key
└── saml-connection/             # SAML config (if needed)
```

## Environment Variables

All configuration is in [docker-compose.yml](docker-compose.yml). Key variables:

- `WEBAPP_URL`: `http://localhost:3100`
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `S3_ENDPOINT_URL`: `http://host.docker.internal:9000`
- `S3_ACCESS_KEY`: rclone authentication
- `S3_SECRET_KEY`: rclone authentication
- `S3_BUCKET_NAME`: `formbricks`
- `S3_FORCE_PATH_STYLE`: `1` (required for rclone)

## Production Deployment

For production:

1. **Use a real domain** for S3:
   ```
   S3_ENDPOINT_URL: https://s3.yourdomain.com
   ```

2. **Setup SSL** certificates

3. **Update CSP** to use your domain instead of `host.docker.internal`

4. **Secure credentials**: Use Docker secrets or environment files

5. **Monitor Google Drive API quota**

## Maintenance

### Backup Database

```bash
docker-compose exec postgres pg_dump -U postgres formbricks > backup.sql
```

### Update Formbricks

```bash
docker-compose pull formbricks
docker-compose up -d formbricks
```

### Clean Restart

```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker volume rm valueflow-formbricks_postgres valueflow-formbricks_redis

# Start fresh
docker-compose up -d
```

## Sources

- [Formbricks File Uploads Documentation](https://formbricks.com/docs/self-hosting/configuration/file-uploads)
- [rclone Google Drive Documentation](https://rclone.org/drive/)
- [MinIO Google Cloud Storage Integration](https://blog.min.io/minio-object-storage-running-on-the-google-cloud-platform/)
