# Simple Formbricks + Google Drive Setup

## Current Configuration (Clean & Simple)

### Services
1. **postgres** - Database
2. **redis** - Cache
3. **rclone-s3** - Google Drive S3 emulation (internal)
4. **formbricks** - Main application

### Configuration
- **S3_ENDPOINT_URL**: `http://rclone-s3:9000` (internal Docker network)
- **Google Drive**: Shared Drive "vfi-apps"
- **rclone**: Service account authentication

## What Works ✅
- ✅ Server-side file uploads (Formbricks → rclone-s3 → Google Drive)
- ✅ Files stored in Google Drive Shared Drive
- ✅ Simple, clean configuration (no proxies)

## What Doesn't Work ❌
- ❌ Browser downloading files (CSP blocks presigned URLs)
- **Why**: Formbricks generates presigned URLs like `http://rclone-s3:9000/file.jpg` which the browser cannot access due to CSP restrictions

## The Problem

Formbricks' Content Security Policy (CSP) only allows:
```
connect-src 'self' http://localhost:9000 ...
```

But presigned URLs from S3 will be:
```
http://rclone-s3:9000/formbricks/file.jpg?signature=...
```

The browser blocks these URLs because `rclone-s3` is not in the CSP whitelist.

## Solutions

### Option 1: Wait for Formbricks Feature (RECOMMENDED)
Submit a feature request to Formbricks for a `CSP_CONNECT_SRC_ADDITIONAL` environment variable to allow custom S3 endpoints.

### Option 2: Use Real Domain (Production)
1. Get a domain: `s3.yourdomain.com`
2. Point it to your server
3. Setup SSL
4. Update: `S3_ENDPOINT_URL=https://s3.yourdomain.com`
5. Still need CSP modification (proxy or custom build)

### Option 3: Fork Formbricks
Fork Formbricks and add CSP customization, then use your custom image.

## To Restart Fresh

The database was accidentally destroyed. To start fresh:

```bash
# Stop all containers
docker-compose down

# Remove volumes (THIS DELETES ALL DATA!)
docker volume rm valueflow-formbricks_postgres valueflow-formbricks_redis

# Start fresh
docker-compose up -d

# Wait for migrations (requires internet access)
docker-compose logs -f formbricks
```

## Current Issue

Formbricks container cannot reach `registry.npmjs.org` to download pnpm for database migrations. This is blocking startup.

**To fix**: Ensure your Docker host has internet access, then restart:
```bash
docker-compose restart formbricks
```

## Files in This Setup

- `docker-compose.yml` - Main configuration (simple, no proxies)
- `rclone/config/rclone.conf` - Google Drive Shared Drive config
- `secrets/` - Service account JSON key
- `nginx.conf` - NOT USED (leftover from proxy attempts)
- `formbricks-proxy.conf` - NOT USED (leftover from proxy attempts)

## Next Steps

1. Fix database migration issue (needs internet)
2. Get Formbricks running
3. Decide on long-term solution for CSP issue
4. Consider submitting PR to Formbricks for CSP customization

---

**Bottom Line**: The S3 integration works perfectly server-side. The only blocker is Formbricks' hardcoded CSP preventing browsers from downloading files.
