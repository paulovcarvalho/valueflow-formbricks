# Formbricks with Google Drive Storage via Tailscale

Self-hosted Formbricks survey platform with Google Drive Shared Drive storage backend, accessible via public domain through Tailscale VPN.

## Architecture

```
Public Internet (forms.vfi.eco)
        ↓
External Caddy Reverse Proxy (57.129.23.170)
        ↓
    Tailscale VPN
        ↓
Local Machine (Docker Containers)
        ↓
┌───────────────────────────────────────────────┐
│ nginx (ports 80, 453)                         │
│   ├─ HTTP → HTTPS redirect                    │
│   ├─ HTTPS → Formbricks (forms.vfi.eco)      │
│   └─ HTTPS → rclone-s3 (files.vfi.eco)       │
└───────────────────────────────────────────────┘
        ↓                           ↓
┌──────────────┐          ┌─────────────────┐
│  Formbricks  │          │   rclone-s3     │
│  (port 3000) │          │   (port 9000)   │
└──────┬───────┘          └────────┬────────┘
       │                           │
       ├─ PostgreSQL (5432)        │
       ├─ Redis/Valkey (6379)      │
       └─ MinIO Console (9001)     │
                                   ↓
                        Google Drive Shared Drive
                             "vfi-apps"
```

## Services

| Service | Port | Purpose |
|---------|------|---------|
| nginx | 80, 453 | Reverse proxy with SSL (port 453 mapped to internal 443) |
| formbricks | 3000 | Survey application |
| postgres | 5432 | Database (pgvector/pg17) |
| redis | 6379 | Cache & rate limiting (Valkey) |
| rclone-s3 | 9000 | S3 API gateway to Google Drive |
| minio | 9001 | MinIO console (optional) |

## Domain Configuration

### Public Domains
- **Main App**: `https://forms.vfi.eco` → Formbricks UI
- **File Storage**: `https://files.vfi.eco` → S3/Google Drive files
- **DNS**: Points to `57.129.23.170` (external Caddy reverse proxy)

### Network Flow
1. Public domain resolves to external Caddy server
2. Caddy connects to local machine via **Tailscale VPN**
3. Caddy forwards HTTPS traffic to local port **453**
4. nginx proxies to appropriate backend service

### SSL Certificates
- Certificate: `certs/formbricks.crt`
- Private Key: `certs/formbricks.key`
- SANs: `forms.vfi.eco`, `files.vfi.eco`, `formbricks.local`, `files.formbricks.local`

## Storage Backend

### Google Drive Integration
- **Type**: Shared Drive (Team Drive)
- **Name**: vfi-apps
- **Drive ID**: 0ANrWRo_JRi5mUk9PVA
- **Service Account**: `share-drive@sacred-flash-452501-m0.iam.gserviceaccount.com`
- **Credentials**: `secrets/sacred-flash-452501-m0-*.json` (not tracked in git)
- **Config**: `rclone/config/rclone.conf`

### S3 Configuration
```bash
S3_ENDPOINT_URL=https://files.vfi.eco
S3_BUCKET_NAME=formbricks-storage
S3_REGION=us-east-1
S3_FORCE_PATH_STYLE=1
```

rclone serves Google Drive over S3 API on port 9000, with nginx proxying external requests through SSL.

## Quick Start

### Prerequisites
1. **Tailscale** must be running and connected
2. Google service account JSON in `secrets/` directory
3. Environment variables in `.env` file

### Start Services
```bash
# Ensure Tailscale is connected
open -a Tailscale
# Click "Connect" in menu bar

# Start all containers
docker-compose up -d

# Verify status
docker-compose ps

# Check logs
docker-compose logs -f formbricks
```

### Access
- **Public URL**: https://forms.vfi.eco
- **Local (for testing)**: http://localhost:80 (redirects to HTTPS)

## Configuration Files

### Environment Variables (.env)
```bash
# Application URLs
WEBAPP_URL=https://forms.vfi.eco
NEXTAUTH_URL=https://forms.vfi.eco

# Database
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/formbricks?schema=public

# Security Keys (generated with: openssl rand -hex 32)
NEXTAUTH_SECRET=<your-secret>
ENCRYPTION_KEY=<your-key>
CRON_SECRET=<your-secret>

# S3 Storage
S3_ACCESS_KEY=formbricks-access-key
S3_SECRET_KEY=formbricks-secret-key-change-this-to-secure-password
S3_REGION=us-east-1
S3_BUCKET_NAME=formbricks-storage
S3_ENDPOINT_URL=https://files.vfi.eco
S3_FORCE_PATH_STYLE=1

# OAuth (optional)
GOOGLE_CLIENT_ID=<your-client-id>
GOOGLE_CLIENT_SECRET=<your-client-secret>
```

### nginx Configuration (nginx-ssl.conf)
- **Files Server** (first in config): `files.vfi.eco`, `files.formbricks.local`
  - Proxies to `rclone-s3:9000`
  - CORS origin allowlist for forms.vfi.eco
  - Handles file uploads/downloads

- **Formbricks Server**: `forms.vfi.eco`, `formbricks.local`
  - Proxies to `formbricks:3000`
  - Main application UI

- **HTTP Redirect**: Redirects all HTTP to HTTPS

## Troubleshooting

### Forms.vfi.eco returns 502 Bad Gateway

**Cause**: Tailscale VPN is disconnected

**Solution**:
```bash
# Check Tailscale status
/Applications/Tailscale.app/Contents/MacOS/Tailscale status

# If stopped, start it
open -a Tailscale
# Click "Connect" in menu bar

# Wait 10 seconds, then test
curl -I https://forms.vfi.eco/
```

### File uploads fail

**Check rclone-s3 logs**:
```bash
docker-compose logs rclone-s3
```

**Test Google Drive connection**:
```bash
docker-compose exec rclone-s3 rclone ls gdrive:
```

**Verify nginx routing**:
```bash
# Should return 403 (CORS protection working)
curl -I -k https://localhost:453/ -H "Host: files.vfi.eco"
```

### Local testing

**Test nginx locally**:
```bash
# Formbricks
curl -I -k -H "Host: forms.vfi.eco" https://localhost:453/

# Files
curl -I -k -H "Host: files.vfi.eco" https://localhost:453/
```

**Test containers directly**:
```bash
# Formbricks
docker exec valueflow-formbricks-nginx-1 wget -qO- http://formbricks:3000/

# rclone-s3
docker exec valueflow-formbricks-nginx-1 wget -qO- http://rclone-s3:9000/
```

### Database connection issues

```bash
# Check PostgreSQL is running
docker-compose exec postgres psql -U postgres -d formbricks -c "SELECT 1;"

# View Formbricks startup logs
docker-compose logs formbricks | grep -i database
```

## Maintenance

### Backup Database
```bash
docker-compose exec postgres pg_dump -U postgres formbricks > backup-$(date +%Y%m%d).sql
```

### Update Formbricks
```bash
docker-compose pull formbricks
docker-compose up -d formbricks
```

### Restart Services
```bash
# Restart specific service
docker-compose restart nginx

# Restart all
docker-compose restart

# Full recreate (preserves volumes)
docker-compose down
docker-compose up -d
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f formbricks
docker-compose logs -f nginx
docker-compose logs -f rclone-s3

# Last 50 lines
docker-compose logs --tail 50 formbricks
```

## Security Notes

1. **Secrets**: Never commit files in `secrets/` directory
2. **Environment**: `.env` is gitignored - keep credentials secure
3. **SSL**: Port 453 (not 443) is used to avoid conflicts
4. **CORS**: Files endpoint has origin allowlist protection
5. **Tailscale**: Provides encrypted VPN tunnel for external access

## File Structure

```
valueflow-formbricks/
├── docker-compose.yml           # Main orchestration
├── .env                         # Environment variables (gitignored)
├── .env.example                # Template for .env
├── nginx-ssl.conf              # nginx reverse proxy config
├── nginx-ssl.conf.backup       # Backup of working config
├── certs/
│   ├── formbricks.crt          # SSL certificate
│   └── formbricks.key          # SSL private key
├── rclone/
│   └── config/
│       └── rclone.conf         # Google Drive configuration
├── secrets/
│   ├── README.md               # Instructions
│   └── *.json                  # Service account keys (gitignored)
├── gcs-mount/                  # MinIO data directory
└── saml-connection/            # SAML config (optional)
```

## Important Notes

### Port 453 vs 443
- **External**: Caddy forwards to port **453** on local machine
- **Internal**: nginx listens on **443** inside container
- **Mapping**: `453:443` in docker-compose.yml
- **Reason**: Avoids conflicts with other services using 443

### Tailscale Dependency
**CRITICAL**: Tailscale must be running for external access to work. If Tailscale is stopped:
- ✅ HTTP (port 80) still works (redirects to HTTPS)
- ❌ HTTPS returns 502 Bad Gateway
- External Caddy cannot reach local machine

**Always check Tailscale before troubleshooting 502 errors!**

## Links

- [Formbricks Documentation](https://formbricks.com/docs)
- [rclone Google Drive Setup](https://rclone.org/drive/)
- [Tailscale VPN](https://tailscale.com)
- [pgvector Extension](https://github.com/pgvector/pgvector)
