# Formbricks with MinIO Storage via Tailscale

Self-hosted Formbricks survey platform with MinIO S3-compatible local storage, accessible via public domain through Tailscale VPN.

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
│   └─ HTTPS → MinIO (files.vfi.eco)           │
└───────────────────────────────────────────────┘
        ↓                           ↓
┌──────────────┐          ┌─────────────────┐
│  Formbricks  │          │     MinIO       │
│  (port 3000) │          │   (port 9000)   │
└──────┬───────┘          └────────┬────────┘
       │                           │
       ├─ PostgreSQL (5432)        │
       ├─ Redis/Valkey (6379)      │
       │                           │
       └─────────────────────────  ↓
                        Local Persistent Storage
                        (Docker volume: minio-data)
```

## Services

| Service | Port | Purpose |
|---------|------|---------|
| nginx | 80, 453 | Reverse proxy with SSL (port 453 mapped to internal 443) |
| formbricks | 3000 | Survey application |
| postgres | 5432 | Database (pgvector/pg17) |
| redis | 6379 | Cache & rate limiting (Valkey) |
| minio | 9000, 9001 | S3-compatible object storage |

## Domain Configuration

### Public Domains
- **Main App**: `https://forms.vfi.eco` → Formbricks UI
- **File Storage**: `https://files.vfi.eco` → MinIO S3 API
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

### MinIO Local Storage
- **Type**: S3-compatible object storage
- **Storage**: Docker volume `minio-data` (persistent)
- **Bucket**: `formbricks-storage` (auto-created)
- **Access**: Internal only (through nginx proxy)
- **Console**: http://localhost:9001

### S3 Configuration
```bash
S3_ENDPOINT_URL=https://forms.vfi.eco
S3_BUCKET_NAME=formbricks-storage
S3_REGION=us-east-1
S3_FORCE_PATH_STYLE=1
```

Files are stored in a persistent Docker volume and accessible through the nginx proxy at `https://forms.vfi.eco/formbricks-storage/`.

## Quick Start

### Prerequisites
1. **Tailscale** must be running and connected
2. Environment variables in `.env` file
3. **External Caddy** configured for `forms.vfi.eco`

### External Reverse Proxy Setup

Your external Caddy server only needs to handle `forms.vfi.eco`. File storage is proxied through the main domain at the `/formbricks-storage/` path, eliminating the need for a separate `files.vfi.eco` domain.

On the external Caddy server (57.129.23.170), configure:

```caddy
forms.vfi.eco {
    reverse_proxy <your-tailscale-ip>:453
}
```

This simpler configuration:
- ✅ Single domain, single certificate
- ✅ File uploads work through `/formbricks-storage/` path on main domain
- ✅ No separate `files.vfi.eco` configuration needed
- ✅ No CSP violations (same origin)

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
- **MinIO Console**: http://localhost:9001
  - Username: `formbricks-access-key`
  - Password: (value from .env S3_SECRET_KEY)

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

# S3 Storage (MinIO)
S3_ACCESS_KEY=formbricks-access-key
S3_SECRET_KEY=formbricks-secret-key-change-this-to-secure-password
S3_REGION=us-east-1
S3_BUCKET_NAME=formbricks-storage
S3_ENDPOINT_URL=http://minio:9000
S3_FORCE_PATH_STYLE=1

# OAuth (optional)
GOOGLE_CLIENT_ID=<your-client-id>
GOOGLE_CLIENT_SECRET=<your-client-secret>
```

### nginx Configuration (nginx-ssl.conf)
- **Files Server** (first in config): `files.vfi.eco`, `files.formbricks.local`
  - Proxies to `minio:9000`
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

**Error**: File upload returns 404 or timeout

**Cause**: S3 endpoint URL not correctly configured or MinIO not reachable

**Check MinIO logs**:
```bash
docker-compose logs minio
```

**Test MinIO from Formbricks**:
```bash
docker-compose exec formbricks curl http://minio:9000
```

**Verify nginx routing**:
```bash
# Should return MinIO XML error
curl -I -k https://localhost:453/ -H "Host: files.vfi.eco"
```

**Verify S3 endpoint**:
```bash
# Should return HTTP 403 (Access Denied - no credentials)
curl -I https://forms.vfi.eco/formbricks-storage/

# Check environment variable
docker-compose exec formbricks env | grep S3_ENDPOINT_URL
# Should show: S3_ENDPOINT_URL=https://forms.vfi.eco
```

**Check external access**:
```bash
# Test S3 proxy is accessible
curl -I https://forms.vfi.eco/formbricks-storage/
```

### Local testing

**Test nginx locally**:
```bash
# Formbricks
curl -I -k -H "Host: forms.vfi.eco" https://localhost:453/

# MinIO through /formbricks-storage/ proxy
curl -I -k -H "Host: forms.vfi.eco" https://localhost:453/formbricks-storage/
```

**Test containers directly**:
```bash
# Formbricks
docker exec valueflow-formbricks-nginx-1 wget -qO- http://formbricks:3000/

# MinIO
docker exec valueflow-formbricks-nginx-1 wget -qO- http://minio:9000/
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

### Backup MinIO Storage
```bash
# Backup MinIO data volume
docker run --rm \
  -v valueflow-formbricks_minio-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/minio-backup-$(date +%Y%m%d).tar.gz /data

# Restore MinIO data
docker run --rm \
  -v valueflow-formbricks_minio-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/minio-backup-YYYYMMDD.tar.gz -C /
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
docker-compose logs -f minio

# Last 50 lines
docker-compose logs --tail 50 formbricks
```

## Security Notes

1. **Secrets**: Never commit `.env` file
2. **Environment**: `.env` is gitignored - keep credentials secure
3. **SSL**: Port 453 (not 443) is used to avoid conflicts
4. **CORS**: Files endpoint has origin allowlist protection
5. **Tailscale**: Provides encrypted VPN tunnel for external access
6. **MinIO**: Console exposed only on localhost (not externally accessible)

## File Structure

```
valueflow-formbricks/
├── docker-compose.yml           # Main orchestration
├── .env                         # Environment variables (gitignored)
├── .env.example                 # Template for .env
├── nginx-ssl.conf               # nginx reverse proxy config
├── certs/
│   ├── formbricks.crt           # SSL certificate
│   └── formbricks.key           # SSL private key
└── saml-connection/             # SAML config (optional)
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

### MinIO Storage
- All uploaded files stored in Docker volume `minio-data`
- Volume persists across container restarts
- Located at: `/var/lib/docker/volumes/valueflow-formbricks_minio-data/_data`
- Can be backed up using Docker commands (see Maintenance section)

## Volumes

All data is stored in Docker volumes:

```bash
# List volumes
docker volume ls | grep formbricks

# Inspect MinIO volume
docker volume inspect valueflow-formbricks_minio-data

# Volume names:
# - postgres: Database data
# - redis: Cache data
# - minio-data: File uploads (S3 objects) - PERSISTENT
# - uploads: Formbricks local uploads directory
```

## Links

- [Formbricks Documentation](https://formbricks.com/docs)
- [MinIO Documentation](https://min.io/docs/)
- [Tailscale VPN](https://tailscale.com)
- [pgvector Extension](https://github.com/pgvector/pgvector)
