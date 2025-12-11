# Formbricks Google Drive S3 Setup - Complete ✅

## Overview

Your Formbricks instance is now fully configured with Google Drive Shared Drive as S3-compatible storage backend.

## 🎯 What Was Accomplished

### 1. **S3 Emulation via rclone**
- Configured rclone to provide S3-compatible API
- Connected to Google Workspace Shared Drive "vfi-apps"
- Service account authentication (no OAuth flow needed)
- Real-time file synchronization

### 2. **Network Configuration**
- Fixed port conflicts (8080 → 9000)
- Added Google DNS servers (8.8.8.8, 8.8.4.4) for connectivity
- Configured dual-endpoint access:
  - Browser (client): `http://localhost:9000`
  - Server (Formbricks): `http://host.docker.internal:9000`

### 3. **Authentication & Access**
- Set `WEBAPP_URL` and `NEXTAUTH_URL` for proper authentication
- Reset user password to: `password123`
- Email verified in database

### 4. **Storage Integration**
- Files uploaded to: `Shared Drive: vfi-apps/formbricks-storage/formbricks/`
- S3 bucket name: `formbricks`
- Path-style access enabled

## 📋 Current Configuration

### Login Credentials
- **URL**: http://localhost:3100
- **Email**: paulocarvalho@vfi.eco
- **Password**: password123

### Storage Details
- **Shared Drive**: vfi-apps (ID: 0ANrWRo_JRi5mUk9PVA)
- **Service Account**: share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com
- **Storage Path**: formbricks-storage/formbricks/
- **S3 Endpoint (Browser)**: http://localhost:9000
- **S3 Endpoint (Server)**: http://host.docker.internal:9000

### S3 Credentials
- **Access Key**: formbricks-access-key
- **Secret Key**: formbricks-secret-key-change-this-to-secure-password
- **Region**: us-east-1
- **Bucket**: formbricks

## 🐳 Docker Services

All services running on Docker Compose:

1. **postgres** - Database (pgvector:pg17)
2. **redis** - Cache/Rate limiting (valkey)
3. **rclone-s3** - S3 API Gateway (port 9000)
4. **formbricks** - Main application (port 3100)

## 🔍 Verification Commands

### Check all services status
```bash
docker-compose ps
```

### View uploaded files in Google Drive
```bash
docker-compose exec rclone-s3 rclone ls gdrive:formbricks-storage/formbricks/
```

### Check storage usage
```bash
docker-compose exec rclone-s3 rclone size gdrive:formbricks-storage
```

### View rclone logs
```bash
docker-compose logs rclone-s3
```

### View Formbricks logs
```bash
docker-compose logs formbricks
```

### Test S3 connectivity from browser
```bash
curl http://localhost:9000
```

### Test S3 connectivity from Formbricks container
```bash
docker-compose exec formbricks curl http://host.docker.internal:9000
```

## 📁 File Structure

```
valueflow-formbricks/
├── docker-compose.yml           # Main configuration
├── rclone/
│   └── config/
│       └── rclone.conf         # rclone configuration with Shared Drive
├── secrets/
│   └── sacred-flash-452501-m0-3eebf66010fe.json  # Service account key
├── saml-connection/            # SAML configs
└── Documentation:
    ├── GOOGLE_DRIVE_S3_SETUP.md
    ├── SETUP_COMPLETE.md
    └── FINAL_SETUP_SUMMARY.md  # This file
```

## 🔧 Key Configuration Files

### docker-compose.yml - Key Settings

**rclone-s3 service:**
- Mounts: `./rclone/config` and `./secrets`
- Port: 9000
- DNS: Google DNS (8.8.8.8, 8.8.4.4)
- Team Drive enabled

**formbricks service:**
- Extra hosts: `host.docker.internal:host-gateway`
- S3 endpoint: `http://host.docker.internal:9000`
- Force path style: enabled

### rclone/config/rclone.conf
```ini
[gdrive]
type = drive
scope = drive
service_account_file = /secrets/sacred-flash-452501-m0-3eebf66010fe.json
team_drive = 0ANrWRo_JRi5mUk9PVA
```

## 🚀 Usage

### Upload Files
1. Log in to Formbricks: http://localhost:3100
2. Create/edit a survey
3. Add file upload question
4. Upload files → automatically saved to Google Drive

### View Files in Google Drive
1. Go to Google Drive
2. Navigate to Shared Drives → vfi-apps
3. Open: formbricks-storage/formbricks/
4. All uploaded files appear here

### Survey Recording
Files uploaded during survey responses are stored with paths like:
```
formbricks-storage/formbricks/{environmentId}/public/{filename}
```

## 🛠️ Maintenance

### Restart Services
```bash
docker-compose restart
```

### Restart Specific Service
```bash
docker-compose restart rclone-s3
docker-compose restart formbricks
```

### Stop All Services
```bash
docker-compose down
```

### Start All Services
```bash
docker-compose up -d
```

### View Real-time Logs
```bash
docker-compose logs -f
```

### Clean Test Files
```bash
docker-compose exec rclone-s3 rclone delete gdrive:formbricks-storage/formbricks/test.txt
```

## 🔐 Security Recommendations

1. **Change default password** after first login
2. **Update S3 secret key** in docker-compose.yml
3. **Backup configuration files**:
   - docker-compose.yml
   - rclone/config/rclone.conf
   - secrets/sacred-flash-452501-m0-3eebf66010fe.json
4. **Monitor API usage** in Google Cloud Console
5. **Regular backup** of PostgreSQL database

## 📊 Monitoring

### Check Storage Quota
```bash
docker-compose exec rclone-s3 rclone about gdrive:
```

### Monitor Upload Activity
```bash
docker-compose logs -f rclone-s3 | grep -i "upload\|error"
```

### Check Database Size
```bash
docker-compose exec postgres psql -U postgres -d formbricks -c "SELECT pg_size_pretty(pg_database_size('formbricks'));"
```

## 🐛 Troubleshooting

### Issue: Files not uploading
**Check:**
1. rclone-s3 service is running: `docker-compose ps`
2. Google Drive API enabled
3. Service account has access to Shared Drive
4. rclone logs: `docker-compose logs rclone-s3`

### Issue: Images not loading
**Check:**
1. Browser can access: http://localhost:9000
2. Formbricks can access: `docker-compose exec formbricks curl http://host.docker.internal:9000`
3. No ECONNREFUSED errors in logs

### Issue: Survey trigger not set
**Solution:**
This is a Formbricks workflow requirement, not a storage issue. You need to:
1. Go to Survey Settings
2. Add a trigger condition (e.g., "On page load", "On exit intent", "On button click")
3. Define when/where the survey should appear

### Issue: Authentication problems
**Reset password:**
```bash
docker run --rm python:3.11-slim bash -c "pip install -q bcrypt && python -c \"import bcrypt; print(bcrypt.hashpw(b'your-new-password', bcrypt.gensalt(rounds=12)).decode())\""
# Then update in database
```

## 📈 Performance Tips

1. **Enable VFS caching** for better performance:
   ```yaml
   command: serve s3 gdrive:formbricks-storage --addr :9000 --s3-force-path-style --log-level INFO --vfs-cache-mode full --vfs-cache-max-size 1G
   ```

2. **Monitor Google Drive API quotas**:
   - Default: 1,000 requests per 100 seconds
   - Check usage in Google Cloud Console

3. **Optimize image sizes** before uploading to reduce storage and bandwidth

## ✅ Verification Checklist

- [x] All Docker services running
- [x] rclone connected to Shared Drive
- [x] Files uploading to Google Drive
- [x] Images loading in Formbricks
- [x] Authentication working
- [x] S3 endpoint accessible (both localhost and host.docker.internal)
- [ ] Survey trigger configured (user action required)

## 📞 Support Resources

- **Formbricks Docs**: https://formbricks.com/docs
- **rclone Docs**: https://rclone.org/drive/
- **Google Drive API**: https://developers.google.com/drive
- **Docker Compose**: https://docs.docker.com/compose/

## 🎉 Success!

Your Formbricks instance is fully operational with Google Drive Shared Drive integration. All file uploads are automatically synced to the cloud, and you have a scalable, cost-effective storage solution.

**Next Steps:**
1. Configure survey triggers in Formbricks UI
2. Change default password
3. Test survey responses with file uploads
4. Monitor storage usage in Google Drive

---

**Setup Date**: 2025-12-10
**Configuration Version**: 1.0
**Status**: Production Ready ✅
