# Windows + Android Emulator local development

This is a separate development environment, not a copy of Mac QA. No database,
media, session, signing key or provider credential is distributed. The shared checkpoint branch is `integration/r9-qa-checkpoint`. The checkpoint
records approved QA key rotation and removes runtime secret defaults; retired
values remain in history and must never be reused. Confirm the branch is visible
on origin before running the checkout commands. No QA credentials are distributed.

## Requirements

- Windows 10/11 with virtualization and Docker Desktop using Linux containers
  (WSL2 backend); Docker Compose v2 supporting `bind.create_host_path`.
- Git and Windows PowerShell 5.1 or PowerShell 7. Corporate execution policies
  may require IT approval; do not change machine-wide execution policy.
- JDK **21**, with `JAVA_HOME` and `java` pointing to it. Backend uses Java21;
  use the Maven wrapper, not a separately guessed Maven version.
- Flutter **3.47.1 stable**, Dart **3.13.1** (observed development versions);
  `pubspec.yaml` requires Dart `^3.13.1`. Keep `pubspec.lock`; no `pub upgrade`.
- Android Studio, Android SDK **API37**, command-line tools, platform-tools,
  Emulator and an API37 x86_64 system image on Intel/AMD Windows. Use a Google
  Play image if testing FCM. AGP9.1.0/Gradle9.3.1 are pinned by the project;
  NDK version follows the Flutter SDK. Run `flutter doctor -v` and install any
  missing SDK/NDK components it identifies. Native Windows ARM is not validated.
- Comfortable build disk headroom (at least10GiB, preferably20GiB) and RAM
  for Docker + emulator (16GiB recommended). Do not copy Mac caches or binaries.

## Modes and external prerequisites

| Mode | Required private setup | Available |
|---|---|---|
| Core development | None; generate independent local secrets | Login via synthetic seed, groups, activities/RSVP, Chat text/history/shared WebSocket, Poll, Task, finance, in-app notifications and text social flows. Existing permissions still apply. |
| Media | Valid **independently obtained AIStor license** plus image access, or an independently authorized compatible S3 endpoint | Upload/download, photos, videos, evidence/check-in media, avatars and albums. Never copy the Mac QA license/objects. |
| Android OS push | Approved Android Firebase client config + external Firebase Admin credential for the same developer project | Actual FCM notification delivery/tap; requires eligible emulator Play services and network. |
| iOS | macOS/Xcode + approved Apple/Firebase/APNs configuration | Not buildable on this Windows laptop; R9 iOS physical push gate remains open. |

**Limitation:** existing `infra/docker-compose.yml` uses AIStor with a mandatory
external `/minio.license` bind. It is not a credential-free MinIO setup. Public
community-image probes were denied/unavailable in the verification environment;
no unverified replacement image is presented as reproducible. Core mode does
not start MinIO, and media operations cannot work until the separate media
prerequisite is supplied. SMTP/account-email verification also needs its own
configuration; synthetic seed login avoids that dependency for local work.

## 1. Clone and create your feature branch (after checkpoint publication)

```powershell
git clone https://github.com/HuyGiang1/weDO-app.git
Set-Location weDO-app
git fetch origin
git switch --track origin/integration/r9-qa-checkpoint
git switch -c feat/yourname-your-task
java -version
flutter --version
flutter doctor -v
flutter doctor --android-licenses
docker version
docker compose version
```

Configure `JAVA_HOME` locally if needed, e.g. to your installed JDK21 directory;
do not commit someone else's absolute SDK path. Start Docker Desktop before
continuing. Create/start an API37 virtual device in Android Studio Device
Manager, then use `flutter devices` to obtain its actual ID.

## 2. Generate and load private local settings

Run at repository root, in the terminal that will start the backend:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\teammate-env.ps1 -Initialize
git check-ignore .env.teammate
```

The script creates ignored `.env.teammate` from `infra/teammate.env.example`,
generates independent32-byte signing/pepper values and random DB/S3/seed
passwords, and exports variables into **this process** without printing them.
Re-running `-Initialize` preserves an existing file; it does not rotate values.
The template contains placeholders only. Do not paste credentials into chat or
commit the generated file. In each new terminal run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\teammate-env.ps1
```

Do not import the Mac's environment. Default backend profiles are `local,teammate`;
the latter requires the generated secrets instead of historical committed local
fallbacks. Never point the synthetic seeder at a shared/production database.
The helper rejects seed-enabled database URLs outside localhost:15432/wedo.

## 3. Start separate PostgreSQL and Redis

```powershell
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml up -d postgres redis
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml ps
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml exec -T postgres pg_isready -U wedo -d wedo
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml exec -T redis redis-cli ping
```

| Service | Host / backend address | Android Emulator address |
|---|---|---|
| Backend | `http://127.0.0.1:8080` | `http://10.0.2.2:8080` |
| PostgreSQL | `127.0.0.1:15432` | App never connects directly |
| Redis | `127.0.0.1:16379` | App never connects directly |
| MinIO API, optional | `http://127.0.0.1:19000` | `http://10.0.2.2:19000` |
| MinIO console, optional | `http://127.0.0.1:19001` | Use host browser |

All host ports bind to loopback. This Compose project has its own generated
container names and `wedo-teammate_*` volumes, with no `wedo-postgres`,
`wedo-redis` or `wedo-minio` container names. Do not run the old Mac QA launch
scripts. Do not use `down -v`, prune or shared database restore commands.

## 4. Start backend; Flyway initializes the empty database

In the terminal that loaded `.env.teammate`:

```powershell
Set-Location backend
.\mvnw.cmd spring-boot:run
```

Keep it running. In another terminal at repository root:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/actuator/health
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml exec -T postgres psql -U wedo -d wedo -c "SELECT version,success FROM flyway_schema_history ORDER BY installed_rank;"
```

Flyway runs committed V0–V20 (21 migrations), then Hibernate validates schema.
Do not import a QA SQL dump or manually create tables. First startup enables
the existing **local-only, opt-in synthetic seeder**: owner/admin/member1/member2
and outsider at `@wedo.local`, plus one synthetic group. Login as
`owner@wedo.local` or `member1@wedo.local` using your generated
`WEDO_LOCAL_TEST_PASSWORD` in your own ignored file. These are independently
created identities, not copied QA users/sessions/media. No fixed seed password
is required by teammate mode. Disable `WEDO_LOCAL_TEST_DATA_ENABLED` in your
file after initial setup if testing membership removal, custom passwords or
other seed-sensitive flows; otherwise restart can recreate synthetic membership
or restore the seed password. Stop/restart only your local backend to apply it.

With `WEDO_PUSH_ENABLED=false` the backend creates no Firebase Admin beans and
never loads ADC credentials. Canonical inbox/WebSocket notifications continue;
the disabled gateway returns EXTERNAL_CONFIG_BLOCKED if called, never delivery success. Recipients without registered devices may instead retain NO_ACTIVE_DEVICES.

## 5. Run Android Emulator without Firebase

Open a new terminal and start the emulator, then:

```powershell
Set-Location mobile
flutter pub get
flutter devices
# Replace emulator-5554 if flutter devices shows a different emulator ID.
flutter run -d emulator-5554 --dart-define=WEDO_API_BASE_URL=http://10.0.2.2:8080 --dart-define=WEDO_PUSH_ENABLED=false
```

No `google-services.json` is required in this mode. Gradle applies the Google
Services plugin only when that real local file is present. The explicit Dart
flag prevents Firebase initialization. WebSocket uses the same host/API config.
Do not use `localhost` inside the emulator for the host backend and do not
copy a physical device's LAN address. Android's `10.0.2.2` is the emulator's
special alias for host loopback: [Android network reference](https://developer.android.com/studio/run/emulator-networking-address).
This address is not for a physical phone, WSL-internal-only backend or a remote
server. Run the backend on the Windows host; if deliberately running it in WSL,
host forwarding must be verified separately. Do not disable the firewall
globally to solve a connection problem.

## 6. Optional media: independently licensed MinIO

Obtain your own valid AIStor license/image access; do not take the QA copy.
Store it outside the repository. Edit **your ignored .env.teammate**:

```dotenv
WEDO_AISTOR_LICENSE_PATH=C:/path-outside-repository/minio.license
WEDO_MEDIA_BOOTSTRAP_BUCKET=true
```

Keep the generated S3 credentials. Load that file in a fresh terminal:

```powershell
.\scripts\teammate-env.ps1
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml --profile media up -d minio
Invoke-WebRequest http://127.0.0.1:19000/minio/health/ready -UseBasicParsing
```

Restart your backend from a terminal that reloaded the changed environment.
Bucket bootstrap creates only your new empty private bucket. The backend S3
client uses `WEDO_MEDIA_S3_ENDPOINT=http://127.0.0.1:19000`; presigned client
URLs use **`WEDO_MEDIA_PUBLIC_ENDPOINT=http://10.0.2.2:19000`**. Therefore the
emulator can PUT/GET without a private LAN relay or Mac-specific allowlist.
Keep both endpoints targeting the same storage and preserve the returned
signed URL/Host exactly; replacing its hostname manually invalidates signatures.
Do not make a bucket public or bypass application authorization. Verify an
independently uploaded development image in Chat/Moments/evidence. Host health
alone is not physical emulator upload/download acceptance.

An approved S3-compatible alternative can be configured using the same endpoint,
public-endpoint, bucket, region and credentials variables. Do not call an
untested endpoint interchangeable or copy a production bucket. Full media
reproducibility without any external license/authorized endpoint is **not
established** for the current AIStor infrastructure.

## 7. Optional Android FCM (separate from core app functionality)

1. Use an approved development Firebase project and Android app matching
   **com.wedo.mobile**. Reuse an existing app rather than creating duplicates.
2. Download its client `google-services.json` to `mobile/android/app/` locally.
   That path is ignored. It is a client configuration, not an Admin private key,
   but this checkpoint does not publish the owner's real Firebase project file.
3. Obtain an authorized **development-only** Firebase Admin credential outside
   the repo, or use approved ADC. Set `GOOGLE_APPLICATION_CREDENTIALS` to its
   external Windows path in the backend process only. Never add its contents
   or a credential-bearing environment file to Git.
4. Set `WEDO_PUSH_ENABLED=true` in your ignored backend env, reload and restart
   your backend. Run Flutter again with `--dart-define=WEDO_PUSH_ENABLED=true`
   and the emulator backend URL. This is a rebuild: defines are compile-time.
5. Use Google Play-enabled emulator, allow notifications, confirm Android token
   registration then test actual OS receipt/tap. In-app inbox success or provider
   acceptance is not OS receipt evidence. Keep private token values out of logs.

Firebase client config alone does not provide server push credentials. Lack of
FCM credentials does not block REST/group/Chat/WebSocket/in-app workflows in
core mode. Email verification and any other external services remain distinct.

## Stop and collaborate

Stop the foreground backend/Flutter processes with Ctrl+C. To pause your own
containers while retaining data:

```powershell
docker compose --project-name wedo-teammate --env-file .env.teammate -f infra/compose.teammate.yml --profile media stop
git status --short
# Review and stage exact source/documentation paths, never generated secrets.
git push -u origin feat/yourname-your-task
```

Open a GitHub Pull Request with base `integration/r9-qa-checkpoint` and your
feature branch as compare; do not push directly to main/dev or rewrite another
person's branch. Follow AGENTS.md/DESIGN_SYSTEM.md. Before publishing, finish
the separate checkpoint security review; these instructions are not evidence
that the integration branch already exists.

## Verification and limits

- New context tests: empty disposable PostgreSQL V0–V20, synthetic configurable
  seed/idempotency and no Firebase beans; real separate Redis. No Mac QA data
  copied or modified. Optional push defaults preserve existing provider mode.
- Compose syntax validated with generated temporary values only; no teammate
  Compose services were started on the Mac. Existing Mac compose/env unchanged.
- Exact results, no-Firebase Android build status and remaining Windows/media
  acceptance limits are recorded in the current handoff. PowerShell/Windows
  Emulator were not executed on this Mac; do not infer Windows physical PASS.

### Executed checks — 2026-10-30

- Initial affected backend batch: **8PASS/0FAIL/0ERROR/0SKIP** (OptionalPushConfigurationTest, LocalTestDataSeederGuardTest, LocalTestDataSeederIntegrationTest, initial TeammateBootstrapIntegrationTest). Final expanded bootstrap class: **2PASS**, one overlapping bootstrap case plus new presigned URL case; **9 unique backend cases total**, not10. Logs `/tmp/wedo-teammate-backend.log`, `/tmp/wedo-teammate-bootstrap-final.log` (local diagnostics, not required setup files).
- Real fresh PostgreSQL migrates V0–V20; custom generated seed password and idempotent synthetic seed verified; no Firebase mocks/ADC in teammate context. Existing default real-FCM selection and legacy seed guards remain verified.
- Actual storage signer emits **PUT and GET host10.0.2.2/port19000**. This proves configured URL generation, not an emulator upload to a licensed MinIO instance.
- **38focused FlutterPASS**, analyzer**clean2.9s**. No unrelated fullsuite rerun.
- An isolated copy of current mobile source **without google-services.json** built Androiddebug **x86_64** successfully with no-push/emulatordefines,38.4s. Existing Mac source/clientconfig/build artifacts and installed phones not replaced. NoAPK is included in source control. Existing Flutter KGP compatibility warning retained, no dependency migration attempted.
- `docker compose ... config --quiet` PASS with newly generated temporary environment values; no teammate Compose containers started on the Mac. PowerShell/Windows/actual Emulator/MinIO license-media/FCM receipt **not physically verified**. Mac QA backend remainedHTTP200; no QA restarts/DB/volume/device/session operations.
- QA rotation was separately approved and verified: runtime defaults are removed from current source and private keys stay outside Git. Teammate mode generates independent values. Historical values remain in Git history; no history rewrite or credential reuse is implied.
