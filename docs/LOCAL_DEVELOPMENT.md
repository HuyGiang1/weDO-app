# Local development

Start:

```powershell
.\scripts\dev-run.cmd
```

Stop app: `Ctrl+C`

Stop backend:

```powershell
.\scripts\dev-stop.cmd
```

Stop backend and infrastructure:

```powershell
.\scripts\dev-stop.cmd -StopInfra
```

## Private Media Storage (M16-A1)

The local Compose stack starts single-node AIStor Free from
`quay.io/minio/aistor/minio:RELEASE.2026-09-19T17-05-25Z`. It does not require a
`minio/mc` helper container. `scripts/dev-run.ps1` uses the process-scoped
`WEDO_AISTOR_LICENSE_PATH` variable (defaulting to the external
`D:\secrets\minio.license`) and mounts that file read-only at `/minio.license`;
the license must remain outside the repository and must not be added to `.env`.
When Spring Boot starts with the `local` profile, it checks for the private
`wedo-media` bucket and creates it only when missing. An existing bucket and
its contents/policy are left untouched. Set `WEDO_MEDIA_BOOTSTRAP_BUCKET=false`
to disable this behavior. The application-wide and production default is
`false`; production must opt in explicitly if infrastructure provisioning is
intended. MinIO's S3 API is bound to host loopback port `9000`; its admin console
is bound to host loopback port `9001` and must not be exposed to the network.
The local Compose defaults are development-only. Override credentials through
`WEDO_MEDIA_ACCESS_KEY` and `WEDO_MEDIA_SECRET_KEY`; never reuse these local
values in production.

Backend storage configuration uses `WEDO_MEDIA_S3_ENDPOINT`,
`WEDO_MEDIA_PUBLIC_ENDPOINT`, `WEDO_MEDIA_BUCKET`, `WEDO_MEDIA_REGION`,
`WEDO_MEDIA_ACCESS_KEY`, and `WEDO_MEDIA_SECRET_KEY`. The backend endpoint is
for container/host-side S3 operations. The public signing endpoint must be
reachable by the mobile device. For the USB-connected Samsung used by the
local runner, configure `WEDO_MEDIA_PUBLIC_ENDPOINT=http://127.0.0.1:9000`
and add `adb reverse tcp:9000 tcp:9000` alongside the existing backend reverse
on port 8080. The local runner installs this reverse for the configured device;
never reverse or expose the admin console on port 9001. Do not send backend
bearer tokens to the S3 endpoint.

Presigned avatar PUT requests expire after 10 minutes. The private bucket is
not made public; Flutter requests an authorized short-lived read URL through
the backend. Only `image/jpeg`, `image/png`, and `image/webp` are accepted for
profile/group avatars, up to 5 MiB per image.

## Local QA Accounts

LOCAL DEVELOPMENT ONLY. `dev-run.cmd` enables the idempotent local QA seed for
the backend process it starts. It creates the `weDO QA Team` group and these
accounts with password `WeDOTest@123`:

- `owner@wedo.local` - OWNER
- `admin@wedo.local` - ADMIN
- `member1@wedo.local` - MEMBER
- `member2@wedo.local` - MEMBER
- `outsider@wedo.local` - OUTSIDER (not a member of the QA group)

The seeder requires the `local` Spring profile and the explicit
`wedo.local-test-data.enabled=true` opt-in. `dev-run.cmd` sets the matching
environment variable only for the backend child process; it does not change
the machine's execution policy or enable seed data in other profiles. The
multi-account integration harness is test-only and can be rerun with:

```powershell
cd D:\weDO-app\backend
.\mvnw.cmd -Dtest=M8MultiAccountIntegrationTest test
```

## M11 Expense + Balance Verification

The local QA group's `owner`, `admin`, `member1`, and `member2` accounts can
exercise Expense create/list/detail/edit/cancel. `outsider` is not a member and
must not read group expenses or balances. Backend multi-account assertions run
with:

```powershell
cd D:\weDO-app\backend
.\mvnw.cmd -Dtest=ExpenseServiceIntegrationTest test
```

An Expense is cancelled rather than deleted; its history remains while its
derived balance effect returns to zero. M11 reuses V7 finance tables, adds no
migration, and does not implement receipt uploads or M12 settlement actions.

## M9 Chat REST Smoke

With an authenticated user, open a group's conversation using
`POST /api/v1/groups/{groupId}/conversation`, load pages from
`GET /api/v1/conversations/{conversationId}/messages`, and send text using
`POST /api/v1/conversations/{conversationId}/messages`. Group membership,
archive state, direct-message privacy, request status and message mutation
windows are enforced by the backend. M9 physical device verification on Samsung
(`R58M36JQYVY`) passed user acceptance with healthy backend (`UP`), active
`adb reverse tcp:8080`, and foreground APK.

## M10 Chat Realtime (WebSocket + Redis)

M10 adds authenticated WebSocket endpoints `/ws` and `/api/v1/ws` backed by
`ChatRealtimeTransactionalBridge` (`TransactionPhase.AFTER_COMMIT`) and
`ChatRealtimeCoordinator` (Redis channel `wedo:chat:realtime`, typing TTL
`typing:{conversationId}:{userId}`, and multi-session presence
`presence:user:{userId}:sessions`). Run the multi-account realtime integration
suite with:

```powershell
cd D:\weDO-app\backend
.\mvnw.cmd -Dtest="ChatRealtimeIntegrationTest,ChatControllerTest,ChatServiceIntegrationTest" test
```
