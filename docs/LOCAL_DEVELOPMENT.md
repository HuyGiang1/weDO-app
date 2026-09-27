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
