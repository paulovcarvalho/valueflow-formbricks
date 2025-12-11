# Formbricks + Google Drive S3 Setup

## Overview

This setup uses **rclone** to provide an S3-compatible API for Google Drive Shared Drive.

## Architecture

```
User Browser → http://localhost:9000 → rclone-s3 → Google Drive Shared Drive (vfi-apps)
Formbricks App → http://localhost:9000 → rclone-s3 → Google Drive Shared Drive (vfi-apps)
```

## Services

1. **postgres** - Database (pgvector/pg17)
2. **redis** - Cache (Valkey)
3. **rclone-s3** - S3 API translator for Google Drive (port 9000)
4. **formbricks** - Main application (port 3100)

## Configuration

### S3 Storage
- **S3_ENDPOINT_URL**: `http://localhost:9000`
- **S3_ACCESS_KEY**: `formbricks-access-key`
- **S3_SECRET_KEY**: `formbricks-secret-key-change-this-to-secure-password`
- **S3_BUCKET_NAME**: `formbricks`
- **S3_REGION**: `us-east-1`
- **S3_FORCE_PATH_STYLE**: `1`

### Google Drive
- **Shared Drive**: vfi-apps (ID: 0ANrWRo_JRi5mUk9PVA)
- **Service Account**: share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com
- **Config**: `rclone/config/rclone.conf`
- **Credentials**: `secrets/sacred-flash-452501-m0-3eebf66010fe.json`

## Current Status

### What Works ✅
- ✅ rclone-s3 running on port 9000
- ✅ Google Drive Shared Drive access configured
- ✅ Formbricks web interface running on port 3100
- ✅ Browser can access localhost:9000

### What Needs Testing ❌
- ❓ Formbricks container access to localhost:9000
- ❓ File upload functionality
- ❓ File download via presigned URLs

## Known Issue: Container localhost Resolution

The Formbricks container needs to access `localhost:9000` but `localhost` inside a container refers to the container itself, not the host.

### Current Workaround Attempt
Added `extra_hosts: localhost:host-gateway` to formbricks service. This attempts to map `localhost` to the host machine.

### If This Doesn't Work
We may need to:
1. Change S3_ENDPOINT_URL to use a different hostname
2. Modify Formbricks CSP to allow that hostname
3. Use a proxy (nginx) to modify CSP headers

## Testing File Uploads

1. Access Formbricks: http://localhost:3100
2. Create a survey with file upload question
3. Upload a test file
4. Check if file appears in Google Drive Shared Drive
5. Try to download the uploaded file

## Logs

```bash
# Check all services
docker-compose ps

# Check rclone-s3 logs
docker-compose logs rclone-s3

# Check formbricks logs
docker-compose logs formbricks

# Test S3 endpoint from host
curl http://localhost:9000

# Test S3 endpoint from formbricks container
docker-compose exec formbricks curl http://localhost:9000
```

## Next Steps

1. Test if Formbricks can connect to localhost:9000
2. If not, implement alternative solution
3. Test file upload functionality
4. Verify files are stored in Google Drive
5. Test file download functionality
