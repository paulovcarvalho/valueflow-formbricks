# Formbricks S3 Network Architecture

## Problem Statement

Formbricks generates **presigned S3 URLs** for file uploads/downloads. These URLs are accessed by:
1. **Server-side** (Formbricks Node.js app) - for uploading files
2. **Client-side** (User's browser) - for downloading uploaded files

## Challenge

**Content Security Policy (CSP)** in Formbricks only allows:
- `connect-src 'self' http://localhost:9000 https://*.intercom.io ...`

This means the browser can ONLY make fetch requests to:
- The same origin (Formbricks at localhost:3100)
- `http://localhost:9000` (S3 endpoint)
- Intercom and other whitelisted domains

## Current Architecture

```
┌─────────────────┐
│   User Browser  │
│                 │
│  localhost:3100 │  ← Formbricks UI
│  localhost:9000 │  ← S3 API (via nginx)
└────────┬────────┘
         │
         │ HTTP
         │
         ▼
┌─────────────────┐
│  nginx-proxy    │  (Port 9000 on host)
│                 │
│  Bridge Network │
└────────┬────────┘
         │
         │ Proxy to
         │
         ▼
┌─────────────────┐
│   rclone-s3     │  (Internal port 9000)
│                 │
│  Google Drive   │
│  S3 Emulation   │
└─────────────────┘

┌─────────────────┐
│   Formbricks    │  (Container)
│                 │
│  /etc/hosts:    │
│  192.168.65.254 │
│    → s3.local   │
└────────┬────────┘
         │
         │ HTTP to s3.local:9000
         │
         ▼
┌─────────────────┐
│  host-gateway   │  (192.168.65.254)
│  = Host Machine │
│                 │
│  port 9000      │
└────────┬────────┘
         │
         │
         ▼
┌─────────────────┐
│  nginx-proxy    │
│  (on host)      │
└─────────────────┘
```

## Current Configuration

### S3 Endpoint
- **S3_ENDPOINT_URL**: `http://s3.local:9000`
- **Formbricks access**: ✅ via `extra_hosts: s3.local:host-gateway`
- **Browser access**: ❌ CSP blocks `s3.local` (only allows `localhost`)

### Network Details
- **host-gateway IP**: 192.168.65.254 (Docker Desktop for Mac)
- **nginx-proxy**: Bridge network, ports 9000:9000
- **rclone-s3**: Bridge network, internal only
- **Formbricks**: Bridge network, with extra_hosts

## Problem

1. Formbricks generates presigned URLs like: `http://s3.local:9000/formbricks/file.jpg?signature=...`
2. Browser tries to fetch this URL
3. CSP blocks the request because `s3.local` is not in the whitelist

## Potential Solutions

### Option 1: Modify Formbricks CSP ❌
- **Status**: Not possible via environment variables
- **Reason**: CSP is hard-coded in Next.js config
- **Alternative**: Would require forking/modifying Formbricks source code

### Option 2: Use localhost:9000 for both ❌
- **Status**: Failed due to DNS resolution issues
- **Reason**: Inside container, `localhost` resolves to `::1` (IPv6) or `127.0.0.1` (container itself)
- **extra_hosts limitation**: Doesn't override built-in localhost resolution

### Option 3: Proxy presigned URLs through Formbricks ❌
- **Status**: Not supported by Formbricks
- **Reason**: Formbricks always generates direct S3 presigned URLs
- **Alternative**: Would require code changes

### Option 4: Add s3.local to host /etc/hosts + CSP bypass 🤔
- **Browser /etc/hosts**: Add `127.0.0.1 s3.local`
- **CSP bypass**: Use browser extension or reverse proxy header injection
- **Status**: Requires manual user configuration

### Option 5: Use Nginx URL Rewriting 🎯 (RECOMMENDED)
Configure nginx to:
1. Accept requests at `localhost:9000`
2. Rewrite presigned URL signatures to work with different hostnames
3. Proxy to rclone-s3

**Challenge**: S3 presigned URLs include the hostname in the signature, so simple proxying won't work.

### Option 6: Network Mode Host for nginx ❌
- **Status**: Failed
- **Reason**: Docker for Mac doesn't support host networking properly
- **Result**: nginx listens but not accessible from host

## Next Steps

### Recommended Approach

**Use Formbricks File Proxy Feature (if available)**:
1. Check if Formbricks has an environment variable to proxy S3 files
2. If yes, enable it so files are served through Formbricks app instead of direct S3 URLs
3. This would bypass CSP issues entirely

**If proxy not available**, we need to either:
1. Manually add `s3.local` to browser /etc/hosts and modify Formbricks CSP
2. Use a custom reverse proxy that rewrites presigned URLs
3. Fork Formbricks and add CSP customization

## Testing Commands

```bash
# Test browser access to S3
curl -s http://localhost:9000

# Test Formbricks container access to S3
docker-compose exec formbricks curl -s http://s3.local:9000 --max-time 5

# Test direct IP access (bypass DNS)
docker-compose exec formbricks curl -s http://192.168.65.254:9000 --max-time 5

# Check /etc/hosts in Formbricks
docker-compose exec formbricks cat /etc/hosts | grep s3

# Check CSP violations in browser console
# Open browser DevTools → Console → look for CSP errors
```

## Status

✅ **Formbricks server** can access S3 at `http://s3.local:9000`
✅ **Browser** can access S3 at `http://localhost:9000`
❌ **Browser CSP** blocks `http://s3.local:9000` (presigned URLs)

**Root Cause**: Formbricks uses presigned URLs with S3_ENDPOINT_URL hostname, but CSP only allows localhost.

## References

- [Formbricks File Upload API Documentation](https://formbricks.com/docs/api-v2-reference/client-api-%3E-file-upload/upload-private-file)
- [Content-Security-Policy connect-src](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/connect-src)
- [Docker extra_hosts documentation](https://docs.docker.com/compose/compose-file/compose-file-v3/#extra_hosts)
- [S3 Presigned URLs Guide](https://fourtheorem.com/the-illustrated-guide-to-s3-pre-signed-urls/)
