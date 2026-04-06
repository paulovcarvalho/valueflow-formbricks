# Localhost Runbook

## Default Formbricks + RustFS stack

1. Copy `.env.example` to `.env`.
2. Replace all `CHANGE_ME_*` secrets with generated values.
3. Start the default stack:

```bash
docker compose up -d
```

4. Open:

- Formbricks: `http://localhost:3000`
- RustFS S3 API: `http://localhost:9000`

Current runtime note:

- The RustFS S3 API is working on `9000`.
- The RustFS console port `9001` is mapped in compose, but the current image did not bind a console listener during verification and still needs follow-up.

## Cal.com stack

1. Copy `calcom/.env.example` to `calcom/.env`.
2. Replace all `CHANGE_ME_*` secrets with generated values.
3. Start the Cal.com add-on stack:

```bash
docker compose --env-file calcom/.env -f docker-compose.calcom.yml up -d
```

4. Open:

- Cal.com: `http://localhost:3001`

## Migration notes

- Existing MinIO object data in `minio-data/` should be retained until RustFS validation is complete.
- The current implementation bootstraps the RustFS bucket during compose startup.
- If you are migrating an existing compose project, restart with `docker compose up -d --remove-orphans` after confirming you no longer need the old `minio` and `nginx` containers.
- For local uploads and server-side file fetches, use `S3_ENDPOINT_URL=http://localhost:9000`.
- The compose topology makes `localhost:9000` resolve to RustFS from both the browser and Formbricks by sharing Formbricks with RustFS' network namespace.
- Public-domain examples such as `forms.valueflow.eco` are intentionally left as commented alternatives in env templates and are not the active local defaults.
