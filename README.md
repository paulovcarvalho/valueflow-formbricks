# Formbricks on Localhost with RustFS

This repository now targets a localhost-first self-hosted setup:

- Formbricks on `http://localhost:3000`
- RustFS S3 storage on `http://localhost:9000`
- RustFS console planned on `http://localhost:9001`
- Optional self-hosted Cal.com on `http://localhost:3001`

The default stack no longer depends on an in-stack nginx reverse proxy for local testing. Public-domain values such as `forms.valueflow.eco` are retained only as commented configuration alternatives for a later edge-proxy deployment.

## Services

| Service | Port | Purpose |
| --- | --- | --- |
| `formbricks` | `3000` | Survey application |
| `postgres` | internal | Formbricks database |
| `redis` | internal | Cache, rate limiting, audit log support |
| `rustfs` | `9000`, `9001` | S3-compatible object storage and console |
| `calcom` | `3001` | Optional team routing / scheduling stack |
| `calcom-postgres` | internal | Optional Cal.com database |

## Quick start

```bash
cp .env.example .env
docker compose up -d
```

Then open:

- `http://localhost:3000`
- `http://localhost:9000`

## Cal.com add-on

```bash
cp calcom/.env.example calcom/.env
docker compose --env-file calcom/.env -f docker-compose.calcom.yml up -d
```

Then open:

- `http://localhost:3001`

## Notes

- Formbricks storage should use `S3_ENDPOINT_URL=http://localhost:9000`.
- Formbricks shares RustFS' network namespace in Docker, so `localhost:9000` works both in the browser and inside the Formbricks container.
- The compose stack bootstraps the `formbricks-storage` bucket automatically.
- The current RustFS image is serving the S3 API correctly on `9000`, but the console listener on `9001` still needs image-specific follow-up before it can be treated as working.
- Keep `minio-data/` backups until you have validated object migration into RustFS.
- Future public-domain alternatives remain in the env templates as commented examples and are not active by default.

Additional implementation notes live in:

- [docs/requirements-rustfs-calcom-localhost.md](/Users/valueflow-ai/valueflow-formbricks/docs/requirements-rustfs-calcom-localhost.md)
- [docs/implementation-plan-rustfs-calcom-localhost.md](/Users/valueflow-ai/valueflow-formbricks/docs/implementation-plan-rustfs-calcom-localhost.md)
- [docs/localhost-runbook.md](/Users/valueflow-ai/valueflow-formbricks/docs/localhost-runbook.md)
