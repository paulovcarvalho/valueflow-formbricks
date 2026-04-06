# Requirements: RustFS + Cal.com + Localhost-First Networking

## Purpose

This document defines the implementation requirements for simplifying the current self-hosted Formbricks stack by:

1. Replacing MinIO with RustFS.
2. Removing the in-stack nginx reverse proxy from the default local deployment path.
3. Adding a self-hosted Cal.com deployment for team allocation via forms.
4. Making localhost the default testing topology, while keeping future public-domain settings as commented alternatives.

## Current State Summary

The repository currently uses:

- `formbricks` backed by PostgreSQL and Valkey/Redis.
- `minio` as the S3-compatible object store.
- `nginx` as an internal TLS/reverse-proxy layer.
- Domain-oriented configuration centered on `forms.valueflow.eco` and `formbricks.local`.

This creates unnecessary complexity for local testing because:

- local startup depends on reverse-proxy behavior,
- TLS is handled inside the compose stack,
- the storage path is coupled to nginx routing,
- the configuration mixes local and public-domain concerns.

## Scope

In scope:

- Docker Compose topology changes for Formbricks, RustFS, and Cal.com.
- Environment variable changes required by Formbricks and Cal.com.
- Localhost-first defaults for development and testing.
- Optional commented production alternatives for future public DNS.
- Documentation updates for startup, migration, and validation.

Out of scope unless explicitly added later:

- Production-grade external reverse proxy implementation.
- DNS cutover to live domains.
- Automated data migration tooling beyond documented/manual migration steps.
- SSO, email delivery, and external calendar/provider integrations beyond baseline Cal.com bring-up.

## Target Architecture

Default local topology:

- `formbricks` exposed directly on localhost, without nginx in front of it.
- `rustfs` exposed directly on localhost as the S3-compatible storage backend.
- `cal.com` exposed directly on localhost on its own port.
- PostgreSQL and Valkey/Redis remain internal compose services unless direct host access is required for debugging.

Future optional production topology:

- Public URL values are parameterized and documented as commented examples.
- A future edge proxy may terminate TLS and map public domains to the same containers, but that is not required for the default local stack.

## Functional Requirements

### 1. Replace MinIO with RustFS

- The compose stack must remove the `minio` service and replace it with a `rustfs` service.
- RustFS must provide S3-compatible access for Formbricks uploads.
- Formbricks must continue to use S3-compatible environment variables already supported by the application.
- RustFS data must be persisted on disk using a dedicated bind mount or named volume.
- The implementation must include a documented migration path for existing MinIO object data.
- The implementation must include a health check or equivalent readiness validation for RustFS.

### 2. Remove nginx from the default path

- The default local deployment must not depend on the `nginx` container.
- Formbricks must be reachable directly on a localhost port.
- RustFS S3 API and admin/console endpoints must be reachable directly on localhost ports.
- Cal.com must be reachable directly on a localhost port.
- No host-based routing, custom local DNS, or local reverse proxy should be required for default testing.

### 3. Localhost-first configuration

- `.env.example` and related docs must use localhost defaults for local testing.
- Domain names such as `forms.valueflow.eco` must be retained only as commented optional alternatives.
- The configuration must clearly separate:
  - local defaults used for testing now,
  - future production/public-domain examples.
- The local configuration should prefer plain HTTP unless the application strictly requires HTTPS.

### 4. Add self-hosted Cal.com

- The repository must gain a documented and reproducible self-hosted Cal.com deployment path using Docker.
- Cal.com must use its own persistent PostgreSQL database or schema isolation with clearly documented boundaries.
- Cal.com secrets and runtime variables must be defined separately from Formbricks values where appropriate.
- Cal.com must be accessible locally for admin setup and routing-form testing.
- The deployment must support team-based routing/allocation through Cal.com routing forms or team routing features.
- The implementation must document how Formbricks will hand off users to Cal.com:
  - embedded link,
  - redirect,
  - or API-driven integration.

### 5. Security requirements

- All default credentials and placeholder secrets must be replaced with explicit generated-secret requirements in documentation.
- RustFS access keys and secrets must be unique and stored in environment configuration, not hard-coded in compose.
- Cal.com admin setup must document the current admin security expectations from Cal.com, including strong password and 2FA for admin accounts.
- Internal service exposure must be minimized to only the ports required for localhost access and testing.
- The design must avoid setting insecure TLS bypass flags by default.
- If future HTTPS/TLS is needed for public deployment, those settings must be documented as optional commented alternatives.

### 6. Documentation requirements

- README and environment examples must describe the new default local startup flow.
- Documentation must include:
  - service purpose,
  - exposed ports,
  - startup order,
  - migration steps,
  - validation checks,
  - rollback steps.
- Documentation must explicitly call out the difference between:
  - direct localhost access for local testing,
  - later public-domain deployment.

## Non-Functional Requirements

- The default stack must be simpler than the current nginx-based topology.
- A fresh developer/operator should be able to start the full stack with Docker Compose and a single `.env` file.
- The local path should avoid extra host file edits such as custom DNS entries.
- Persistent data for Formbricks, RustFS, PostgreSQL, Redis/Valkey, and Cal.com must survive container restarts.
- The change set should preserve existing Formbricks behavior for file uploads.

## Configuration Requirements

### Formbricks

- Local defaults should use localhost-based URLs.
- Storage configuration must point to the RustFS service endpoint.
- Production/public-domain examples should remain as comments.

Preferred local pattern:

- `WEBAPP_URL=http://localhost:<formbricks-port>`
- `NEXTAUTH_URL=http://localhost:<formbricks-port>`
- `S3_ENDPOINT_URL=http://localhost:<s3-port>` with the local topology arranged so the browser and Formbricks container both reach RustFS on that same loopback address.

Optional commented future examples:

- `WEBAPP_URL=https://forms.valueflow.eco`
- `NEXTAUTH_URL=https://forms.valueflow.eco`

### Cal.com

- Local defaults should use localhost for the browser-facing URL.
- Internal callback/auth behavior must be documented carefully because Cal.com’s auth flows can fail if the container cannot resolve the configured host.
- Production/public-domain examples should be comments only.

Preferred local pattern:

- `NEXT_PUBLIC_WEBAPP_URL=http://localhost:<cal-port>`
- `NEXTAUTH_URL=http://localhost:<cal-port>/api/auth`

Optional commented future examples:

- `NEXT_PUBLIC_WEBAPP_URL=https://calendar.valueflow.eco`
- `NEXTAUTH_URL=https://calendar.valueflow.eco/api/auth`

Note:
- The future Cal.com public hostname is an implementation decision. `calendar.valueflow.eco` is a practical example, but can be changed before production cutover.

## Data Migration Requirements

- Existing uploaded objects in `minio-data/` must be preserved until migration is verified.
- The implementation must document whether migration is:
  - object-level copy between S3-compatible endpoints, or
  - filesystem-level import.
- Bucket naming must remain compatible with Formbricks expectations unless there is a documented reason to change it.
- Migration validation must confirm that previously uploaded files remain accessible from Formbricks after the cutover.

## Validation and Acceptance Criteria

The implementation is complete when all of the following are true:

1. `docker compose up -d` starts Formbricks, RustFS, PostgreSQL, Redis/Valkey, and Cal.com without nginx.
2. Formbricks is reachable directly on localhost.
3. RustFS S3 API is reachable directly on localhost.
4. RustFS console is reachable directly on localhost.
5. Formbricks file uploads succeed using RustFS.
6. Cal.com is reachable directly on localhost and completes first-run setup.
7. A Cal.com routing/team allocation flow can be configured and demonstrated for form-based handoff.
8. `.env.example` defaults to local testing values, with future public-domain values left as comments.
9. The README reflects the new topology and no longer describes MinIO/nginx as the default architecture.

## Risks and Design Notes

- RustFS documentation explicitly notes that the container runs as user `10001`, so host-mounted data and TLS certificate paths must be readable by that user.
- RustFS single-node single-disk mode is suitable for local testing and small-scale deployment, but it should not be treated as a high-availability production design by itself.
- Cal.com self-hosting is officially documented for Docker, but routing/org/team capabilities may have licensing or feature-gating implications. This must be validated during implementation before promising a production workflow around it.
- Removing nginx simplifies local testing, but future public HTTPS deployment will still need an edge termination strategy outside the default local stack.

## Source Notes

Official references used for these requirements:

- RustFS Docker installation: https://docs.rustfs.com/installation/docker/index.html
- RustFS TLS configuration: https://docs.rustfs.com/integration/tls-configured.html
- RustFS S3 compatibility: https://docs.rustfs.com/ja/features/s3-compatibility/
- Cal.com Docker self-hosting: https://cal.com/docs/self-hosting/docker
- Cal.com installation overview: https://cal.com/docs/self-hosting/installation
- Cal.com admin security requirements: https://cal.com/docs/self-hosting/admin-security-requirements
- Cal.com routing overview: https://cal.com/help/routing/routing-overview
- Cal.com round-robin scheduling: https://cal.com/help/event-types/round-robin
- Cal.com team routing forms API: https://cal.com/docs/api-reference/v2/orgs-teams-routing-forms/get-team-routing-forms
