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

## M9 Chat REST Smoke

With an authenticated user, open a group's conversation using
`POST /api/v1/groups/{groupId}/conversation`, load pages from
`GET /api/v1/conversations/{conversationId}/messages`, and send text using
`POST /api/v1/conversations/{conversationId}/messages`. Group membership,
archive state, direct-message privacy, request status and message mutation
windows are enforced by the backend. M9 is REST-only; WebSocket delivery,
typing, presence and push are M10. V4 reserves attachment persistence, but
upload, storage ownership, and rendering are deferred beyond M9. M9 physical
device verification on Samsung (`R58M36JQYVY`) passed user acceptance with
healthy backend (`UP`), active `adb reverse tcp:8080`, and foreground APK.
