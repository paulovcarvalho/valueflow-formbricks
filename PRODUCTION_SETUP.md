# Production-Ready Formbricks + Google Drive S3 Setup

## Current Status ✅

Your Formbricks instance is configured with:
- ✅ Google Drive Shared Drive ("vfi-apps") as S3 storage backend
- ✅ rclone S3 emulation working
- ✅ Server-side S3 access configured
- ⚠️ Client-side CSP requires custom proxy (current solution)

## The Problem

Formbricks generates **presigned S3 URLs** for file uploads/downloads. These URLs must be accessible from:
1. **Server** (Formbricks container) - to upload files
2. **Browser** (user's web browser) - to download files

The challenge: Formbricks' Content Security Policy (CSP) is hardcoded and cannot be modified via environment variables.

## Current Non-Portable Solution

**What we did:**
1. Added `s3.local` to host's `/etc/hosts`
2. Added nginx reverse proxy to modify CSP headers
3. Set `S3_ENDPOINT_URL=http://s3.local:9000`

**Why it's not portable:**
- Requires manual `/etc/hosts` modification on every machine
- Doesn't work in cloud environments
- Breaks if you move containers

## Recommended Production Solutions

### Option 1: Use Public Domain with DNS (RECOMMENDED)

**Setup:**
1. Add a DNS A record: `s3.yourdomain.com` → Your server IP
2. Configure SSL certificate for `s3.yourdomain.com`
3. Update docker-compose.yml:
   ```yaml
   S3_ENDPOINT_URL: https://s3.yourdomain.com
   ```
4. Configure nginx to listen on port 443 with SSL
5. Update Formbricks CSP (requires custom build or waiting for Formbricks to add env var support)

**Pros:**
- Works from anywhere
- Secure with HTTPS
- Professional solution
- No /etc/hosts hacks

**Cons:**
- Requires domain and DNS setup
- Requires SSL certificate
- Still needs CSP modification

### Option 2: Fork Formbricks and Add CSP Environment Variable

**What to do:**
1. Fork https://github.com/formbricks/formbricks
2. Find CSP configuration in Next.js config
3. Add environment variable: `CSP_CONNECT_SRC_ADDITIONAL`
4. Build custom Docker image
5. Use your custom image instead of official one

**Pros:**
- Full control over CSP
- Portable solution
- Can contribute back to Formbricks

**Cons:**
- Requires maintaining fork
- Need to rebuild on Formbricks updates

### Option 3: Use Formbricks Cloud Storage (Simplest)

**What to do:**
1. Remove rclone and S3 configuration
2. Configure Formbricks to use local storage or dedicated S3
3. Set up external sync from local storage to Google Drive

**Pros:**
- No CSP issues
- Simpler setup
- Official Formbricks behavior

**Cons:**
- Files not immediately in Google Drive
- Requires separate sync process

### Option 4: Contribute CSP Environment Variable to Formbricks

**What to do:**
1. Open issue on Formbricks GitHub requesting `CSP_CONNECT_SRC_ADDITIONAL` env var
2. Submit PR adding this feature
3. Wait for merge and release
4. Update to new Formbricks version

**Pros:**
- Benefits entire Formbricks community
- Official solution
- No maintenance burden

**Cons:**
- Takes time
- Depends on Formbricks team approval

## Immediate Workaround (Current Setup)

### Architecture

```
User Browser (with s3.local in /etc/hosts)
    ↓
http://localhost:3100 → formbricks-proxy (modifies CSP)
    ↓
formbricks:3000 → S3_ENDPOINT_URL=http://s3.local:9000
    ↓
host-gateway (192.168.65.254)
    ↓
nginx-proxy on host port 9000
    ↓
rclone-s3 → Google Drive Shared Drive
```

### Files Modified

1. **`docker-compose.yml`**:
   - Added `formbricks-proxy` service
   - Added `extra_hosts: s3.local:host-gateway` to formbricks
   - Set `S3_ENDPOINT_URL: http://s3.local:9000`

2. **`formbricks-proxy.conf`**:
   - Nginx reverse proxy that modifies CSP headers
   - Adds `http://s3.local:9000` to `connect-src`

3. **`nginx.conf`**:
   - S3 endpoint proxy
   - Listens on port 9000
   - Accepts both `localhost` and `s3.local` hostnames

4. **`/etc/hosts` (host machine)**:
   - Added `127.0.0.1 s3.local`

### Setup on New Machine

```bash
# 1. Clone your repository
cd /path/to/valueflow-formbricks

# 2. Add s3.local to /etc/hosts
./add-s3-local-to-hosts.sh

# 3. Start services
docker-compose up -d

# 4. Verify setup
curl http://s3.local:9000  # Should return S3 XML
curl -I http://localhost:3100 | grep CSP  # Should include s3.local:9000
```

## Future Improvements

1. **Submit PR to Formbricks** for CSP environment variable support
2. **Use real domain** instead of s3.local when deploying to production
3. **Remove formbricks-proxy** once Formbricks supports CSP customization
4. **Add monitoring** for Google Drive API quota usage

## Troubleshooting

### Issue: CSP still blocks s3.local

**Check:**
```bash
curl -I http://localhost:3100 | grep CSP
# Should show: connect-src 'self' http://localhost:9000 http://s3.local:9000 ...
```

**Fix:**
```bash
docker-compose restart formbricks-proxy
```

### Issue: Server Actions failing (500 errors)

**Symptom:** `x-forwarded-host header does not match origin header`

**Fix:** Check formbricks-proxy.conf has:
```nginx
proxy_set_header Host $host:$server_port;
proxy_set_header X-Forwarded-Host $host:$server_port;
```

### Issue: Formbricks can't access S3

**Check container access:**
```bash
docker-compose exec formbricks curl http://s3.local:9000
```

**Fix:** Verify extra_hosts in docker-compose.yml:
```yaml
extra_hosts:
  - "s3.local:host-gateway"
```

## Migration to Production

When moving to production server:

1. **Get a domain**: e.g., `formbricks.yourdomain.com`
2. **Add subdomain for S3**: `s3-formbricks.yourdomain.com`
3. **Setup SSL certificates** (Let's Encrypt)
4. **Update DNS** A records
5. **Update configuration**:
   ```yaml
   WEBAPP_URL: https://formbricks.yourdomain.com
   S3_ENDPOINT_URL: https://s3-formbricks.yourdomain.com
   ```
6. **Remove /etc/hosts hack**
7. **Still need CSP modification** via formbricks-proxy or custom build

## Links

- [Formbricks GitHub](https://github.com/formbricks/formbricks)
- [rclone Google Drive Documentation](https://rclone.org/drive/)
- [Next.js CSP Configuration](https://nextjs.org/docs/app/building-your-application/configuring/content-security-policy)
- [Docker extra_hosts](https://docs.docker.com/compose/compose-file/compose-file-v3/#extra_hosts)

---

**Note:** This setup works but is a **workaround**. The proper long-term solution is to contribute CSP environment variable support to Formbricks or use a public domain with proper DNS.
