# Google Drive S3 Emulation Setup for Formbricks

This setup uses **rclone** to provide S3-compatible API access to Google Drive, allowing Formbricks to store files directly in your Google Drive.

## Architecture

```
Formbricks → rclone S3 API → Google Drive
```

- **Formbricks** uses standard S3 API calls
- **rclone** translates S3 API to Google Drive API
- Files are stored in real-time to `formbricks-storage/formbricks/` folder in your Google Drive

## Prerequisites

✅ Google OAuth2 credentials (already configured in `/secrets`)
✅ Docker and Docker Compose installed
✅ Google Drive with sufficient storage space

## Setup Steps

### Step 1: Grant Service Account Access to Google Drive

Since we're using a **service account** for authentication, you need to share the Google Drive folder with the service account email.

1. **Find the service account email**: `share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com`

2. **Share Google Drive folder with service account**:
   - Go to your Google Drive
   - Create a folder named `formbricks-storage` (or it will be created automatically)
   - Right-click the folder → Share
   - Add the service account email: `share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com`
   - Give it **Editor** permissions
   - Click Send

**Note**: With service account authentication, no OAuth browser flow is needed! The service account uses the JSON key file directly.

### Step 2: Verify rclone Configuration

Check if the configuration is valid:

```bash
docker run --rm \
  -v $(pwd)/rclone/config:/config/rclone \
  rclone/rclone listremotes
```

You should see: `gdrive:`

### Step 3: Create the Storage Folder in Google Drive

Create the bucket folder structure:

```bash
docker run --rm \
  -v $(pwd)/rclone/config:/config/rclone \
  rclone/rclone mkdir gdrive:formbricks-storage/formbricks
```

### Step 4: Test rclone S3 Service

Test the S3 service before starting the full stack:

```bash
docker-compose up rclone-s3
```

You should see logs indicating the S3 server is running on port 8080.
Press `Ctrl+C` to stop the test.

### Step 5: Start All Services

```bash
docker-compose up -d
```

Check service status:

```bash
docker-compose ps
```

All services should be "Up" and healthy.

### Step 6: Verify S3 Integration

Check Formbricks logs for S3 connection:

```bash
docker-compose logs formbricks | grep -i s3
```

Check rclone logs:

```bash
docker-compose logs rclone-s3
```

## Configuration Details

### S3 Credentials (configured in docker-compose.yml)

- **Access Key**: `formbricks-access-key`
- **Secret Key**: `formbricks-secret-key-change-this-to-secure-password`
- **Region**: `us-east-1` (dummy region for rclone)
- **Bucket**: `formbricks`
- **Endpoint**: `http://rclone-s3:8080`

**Security Note**: Change the secret key to a strong password for production use!

### Google Drive Storage Location

Files will be stored in:
```
Google Drive Root/
  └── formbricks-storage/
      └── formbricks/
          └── [uploaded files]
```

## Troubleshooting

### Issue: "Failed to configure token: failed to get token" or "403 Forbidden"

**Solution**: Make sure you've shared the Google Drive folder with the service account:
- Service account email: `share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com`
- Folder needs **Editor** permissions
- Check that Google Drive API is enabled in Cloud Console

### Issue: "Permission denied" errors

**Solution**: Check Google Drive API is enabled:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: `sacred-flash-452501-m0`
3. Enable "Google Drive API"
4. Verify the service account has access to the shared folder

### Issue: rclone-s3 container keeps restarting

**Solution**: Check logs for errors:
```bash
docker-compose logs rclone-s3
```

Common causes:
- Service account key file not found (check `/secrets` volume mount)
- Service account doesn't have access to Google Drive folder
- Google Drive API not enabled in Cloud Console

### Issue: Formbricks can't connect to S3

**Solution**:
1. Verify rclone-s3 service is running: `docker-compose ps`
2. Check network connectivity: `docker-compose exec formbricks ping rclone-s3`
3. Verify S3 environment variables in docker-compose.yml

### Issue: Slow upload/download speeds

**Possible causes**:
- Google Drive API rate limits (quota: 1,000 requests/100 seconds)
- Large file sizes
- Network bandwidth

**Solutions**:
- Enable rclone VFS caching (advanced configuration)
- Use `--transfers` flag to limit concurrent operations
- Monitor Google Drive API quotas in Cloud Console

## Testing File Upload

Once services are running, test file upload:

1. Access Formbricks: http://localhost:3100
2. Create a survey with file upload question
3. Upload a test file
4. Check Google Drive folder: `formbricks-storage/formbricks/`

## Monitoring

### View rclone logs in real-time:
```bash
docker-compose logs -f rclone-s3
```

### View all service logs:
```bash
docker-compose logs -f
```

### Check Google Drive storage usage:
```bash
docker run --rm \
  -v $(pwd)/rclone/config:/config/rclone \
  rclone/rclone size gdrive:formbricks-storage
```

## Advanced Configuration

### Enable VFS Caching (for better performance)

Edit the rclone-s3 service command in docker-compose.yml:

```yaml
command: serve s3 gdrive:formbricks-storage --addr :8080 --s3-force-path-style --log-level INFO --vfs-cache-mode full --vfs-cache-max-size 1G
```

Add volume for cache:
```yaml
volumes:
  - ./rclone/config:/config/rclone
  - ./rclone/cache:/cache
```

### Change S3 Credentials

1. Update `RCLONE_S3_ACCESS_KEY_ID` and `RCLONE_S3_SECRET_ACCESS_KEY` in rclone-s3 service
2. Update `S3_ACCESS_KEY` and `S3_SECRET_KEY` in Formbricks environment
3. Restart services: `docker-compose restart`

### Use Team Drive (Google Workspace)

Edit `rclone/config/rclone.conf`:
```ini
[gdrive]
type = drive
scope = drive
client_id = YOUR_GOOGLE_CLIENT_ID
client_secret = YOUR_GOOGLE_CLIENT_SECRET
team_drive = YOUR_TEAM_DRIVE_ID
```

## Backup and Migration

### Backup rclone configuration:
```bash
cp rclone/config/rclone.conf rclone/config/rclone.conf.backup
```

### Migrate existing S3 files to Google Drive:
```bash
# If you have existing S3 bucket data
docker run --rm \
  -v $(pwd)/rclone/config:/config/rclone \
  rclone/rclone copy s3:old-bucket gdrive:formbricks-storage/formbricks \
  --progress
```

## Security Recommendations

1. **Change default S3 credentials** in docker-compose.yml
2. **Restrict OAuth scope** to minimum required permissions
3. **Enable 2FA** on Google Account
4. **Regular backups** of rclone configuration
5. **Monitor API usage** in Google Cloud Console
6. **Use environment files** for sensitive credentials instead of docker-compose.yml

## Support

- Formbricks Documentation: https://formbricks.com/docs
- rclone Documentation: https://rclone.org/drive/
- Google Drive API: https://developers.google.com/drive

## Summary

✅ S3-compatible API provided by rclone
✅ Direct integration with Google Drive
✅ Real-time file synchronization
✅ No local storage required
✅ Standard S3 API for Formbricks
✅ Easy to monitor and manage
