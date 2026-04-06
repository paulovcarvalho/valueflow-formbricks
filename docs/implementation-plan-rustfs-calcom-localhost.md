# Implementation Plan: RustFS + Cal.com + Localhost-First Networking

## Plan Summary

The work should be executed in four phases:

1. Simplify the existing Formbricks stack and remove nginx from the default topology.
2. Replace MinIO with RustFS and validate upload compatibility.
3. Add Cal.com as a separate localhost-accessible service.
4. Update documentation, migration instructions, and optional production examples.

## Assumptions

- The primary goal right now is reliable local testing on one machine.
- Public-domain cutover happens later and should not complicate the default stack.
- Formbricks can continue using standard S3-compatible configuration against RustFS.
- Cal.com will run as a separate service, not as a subpath under Formbricks.

## Recommended Service Layout

Proposed direct host ports:

- Formbricks: `localhost:3000`
- Cal.com: `localhost:3001`
- RustFS S3 API: `localhost:9000`
- RustFS console: `localhost:9001`
- PostgreSQL (optional host bind only if needed): internal by default
- Redis/Valkey (optional host bind only if needed): internal by default

This avoids host-based routing and removes the need for custom local certificates during day-to-day testing.

## Phase 1: Baseline Simplification

### Objectives

- Remove nginx from the default compose startup path.
- Expose Formbricks directly on localhost.
- Normalize environment defaults around localhost.

### Tasks

1. Update `docker-compose.yml`.
2. Remove `nginx` service from the active default stack.
3. Add explicit port mapping for `formbricks`.
4. Remove nginx-specific network aliases that are no longer required for local testing.
5. Keep any public-domain examples as comments, not active defaults.

### Deliverables

- Compose stack starts Formbricks directly on `localhost:3000`.
- nginx config files are no longer part of the default operating path.

## Phase 2: MinIO to RustFS Migration

### Objectives

- Replace MinIO with RustFS without breaking Formbricks file uploads.
- Preserve existing object data until cutover is validated.

### Tasks

1. Add a new `rustfs` service in `docker-compose.yml`.
2. Remove the `minio` service from active use.
3. Configure persistent storage for RustFS.
4. Set RustFS credentials via environment variables.
5. Add Formbricks dependency from `formbricks` to `rustfs`.
6. Update `.env.example` and docs to reference RustFS-backed S3 variables.
7. Add readiness/health validation for RustFS.

### Migration Steps

1. Snapshot current MinIO data and database before changes.
2. Stand up RustFS with a target bucket matching the current bucket name.
3. Copy objects from MinIO to RustFS using an S3-compatible copy tool.
4. Switch Formbricks `S3_ENDPOINT_URL` to RustFS.
5. Validate existing uploads and new uploads.
6. Retain MinIO backup artifacts until cutover is accepted.

### Validation

- Existing files open correctly from Formbricks.
- New uploads land in RustFS.
- Bucket/object listing works from an S3-compatible client.

## Phase 3: Add Self-Hosted Cal.com

### Objectives

- Deploy Cal.com locally with its own runtime configuration.
- Enable the platform for team allocation/routing workflows.

### Tasks

1. Add Cal.com deployment assets.
2. Decide whether Cal.com is managed:
   - in the same compose file, or
   - in a dedicated compose overlay/subdirectory.
3. Provision Cal.com database isolation:
   - separate Postgres service, or
   - separate database/schema in the existing Postgres instance.
4. Define Cal.com environment file and secrets handling.
5. Expose Cal.com on `localhost:3001`.
6. Complete first-run setup and create the initial admin user.
7. Configure at least one team and one routing/round-robin workflow.
8. Document the handoff from Formbricks to Cal.com.

### Integration Decision

The cleanest first implementation is:

- Formbricks collects responses.
- A completion CTA, redirect, or embedded link sends qualified users to a Cal.com routing form or event type.
- Cal.com handles team selection, round-robin assignment, and booking.

This is lower-risk than building a tight API integration first.

### Important Checks

- Validate Cal.com feature availability for the required team routing flow before committing to a final UX.
- Keep Cal.com auth URLs strictly aligned with localhost settings during local testing to avoid callback resolution issues.

## Phase 4: Documentation and Optional Production Examples

### Objectives

- Make localhost the obvious default.
- Preserve future public deployment examples without activating them.

### Tasks

1. Update `.env.example` to local defaults.
2. Add commented alternative values for future public domains.
3. Rewrite `README.md` architecture and startup sections.
4. Add migration instructions from MinIO to RustFS.
5. Add verification steps for Formbricks uploads and Cal.com routing.
6. Mark old nginx/Tailscale/Caddy assumptions as legacy or optional.

## File-Level Change Plan

Expected primary files:

- `docker-compose.yml`
- `.env.example`
- `README.md`
- optional new Cal.com env/template files
- optional new migration/runbook docs

Expected removals or deprecation from default usage:

- `nginx-ssl.conf`
- `formbricks-proxy.conf`
- scripts/docs that assume custom local DNS or nginx-backed S3 routing

These files do not need to be deleted immediately if they are still useful as legacy references, but they should stop being the default path.

## Proposed Sequence of Execution

1. Back up current Postgres and MinIO data.
2. Remove nginx from the default compose path and expose Formbricks directly.
3. Introduce RustFS and switch Formbricks storage to it.
4. Validate uploads and legacy object access.
5. Add Cal.com and complete first-run setup.
6. Configure a minimal team-routing proof of concept.
7. Update docs and env examples.
8. Run end-to-end validation on localhost.

## Validation Checklist

- `docker compose up -d` succeeds from a clean checkout with `.env` populated.
- `http://localhost:3000` loads Formbricks.
- Uploading a file in Formbricks succeeds.
- `http://localhost:9000` responds as RustFS S3 API.
- `http://localhost:9001` loads the RustFS console if enabled.
- `http://localhost:3001` loads Cal.com.
- Cal.com admin setup completes.
- A team-based round-robin or routing-form flow can be demonstrated.
- Docs accurately reflect the commands and URLs above.

## Open Decisions To Resolve During Implementation

1. Whether Cal.com should live in the same compose file or in a separate compose project.
2. Whether Cal.com should share PostgreSQL with separate databases, or use a dedicated Postgres container.
3. Whether the Formbricks-to-Cal.com handoff is:
   - simple redirect,
   - embedded Cal.com flow,
   - or API-driven routing.
4. What final public hostname should be used for Cal.com.

## Recommendation

Use the simplest viable shape first:

- one compose project,
- shared Postgres server with separate databases,
- direct localhost ports,
- RustFS in single-node mode,
- Cal.com linked from Formbricks by redirect/embed rather than custom API integration.

That gets local testing working quickly and leaves the public-domain/TLS layer as a later infrastructure concern instead of blocking the migration.
