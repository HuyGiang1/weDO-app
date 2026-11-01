# Phase D2 — artifact review và CI readiness

Ngày: 2026-11-01. Baseline HEAD/cached origin/dev:
`0dbb7bf155a557b441dfff01489def058f15d874`.
Worktree vẫn `integration/r9-qa-checkpoint`; không tạo branch, stage, commit, push,
PR, activate workflow, publish image hay SSH. D1 vẫn chưa commit. D2 không xác nhận
container run hoặc CI PASS khi chưa có execution.

## 1. Findings và sửa đổi đã thực hiện

| Finding từ code D1 | Kết quả D2 |
| --- | --- |
| Smoke actual image chỉ health + `/me`401; login/WS chỉ ở Maven in-process test, không chứng minh image đúng | Bổ sung register/login, authenticated `/me`/groups, unauth WS401 + authorized WS101/Accept validation trên chính container image |
| D1 chỉ recreate PG, chưa recreate application container như gate yêu cầu | Recreate backend, xác nhận container ID thay, login/data còn, legacy-avatar volume ghi được bằng UID10001 và còn sau recreation; vẫn kiểm PG recreation riêng |
| Không có sanitized failure diagnostics | Report JSON allow-list service/status/exit/OOM/health/probe exit codes + checks hoàn tất; Java report chỉ counts, không raw XML/exception/log/config/env/body |
| Cleanup D1 để lại named CI volumes | `down --volumes` chỉ cho project UUID mới đã kiểm collision và render config không external/shared/bind mounts; không prune/images/QA cleanup |
| Guard chỉ check `GITHUB_ACTIONS`/`CI`, có thể chạy trên self-hosted | Bắt buộc `RUNNER_ENVIRONMENT=github-hosted`, local Unix Docker, Linux amd64, exact40hex CI image tag, non-root image, disk threshold; từ chối Mac trước Docker |
| Validation job có packages:write và gộp publication | Validation chỉ contents:read; publication job riêng, needs validation, chỉ manual trên dev + publish=true + protected environment approval |
| Checkout chưa ghi rõ PR head, export image thiếu immutable handoff giữa jobs | Checkout exact SOURCE_SHA, kiểm HEAD/OCI revision; docker save đúng image đã smoke; checksum archive + image ID từ validation outputs, publisher verify/load/tag/push không rebuild |
| PG/Redis dùng mutable major tags | Pin public registry index digests, đã kiểm có linux/amd64; template đồng bộ, validator bắt digest |
| Context cho phép mọi application*.yml | Thu hẹp chỉ application.yml và application-staging.yml; local/teammate/test config không vào image context |

Không phát hiện qua code review một lỗi bắt buộc phải sửa business Java/API/DB.
Không thay Flutter, JDK version, Maven dependencies, Flyway SQL hay source domain.

## 2. File đã kiểm tra chính xác

Toàn bộ 14 paths thuộc D1:

```
.gitignore
backend/.dockerignore
backend/Dockerfile
backend/docker/Healthcheck.java
backend/src/main/resources/application-staging.yml
backend/src/test/java/com/wedo/backend/deployment/StagingBootstrapIntegrationTest.java
backend/src/test/java/com/wedo/backend/deployment/StagingProfileTest.java
docs/STAGING_DEPLOYMENT_D1.md
docs/AGENT_CURRENT_HANDOFF.md
infra/compose.staging.yml
infra/staging.env.example
infra/staging/ghcr-workflow.proposal.yml
scripts/staging-container-smoke.py
scripts/validate-staging.py
```

Đối chiếu thêm AGENTS/skill/context/decision log; backend/pom.xml, mvnw,
.mvn/wrapper/maven-wrapper.properties; main resource inventory V0–V20;
application.yml/local/teammate; SecurityConfig, JwtService, AuthService,
AuthController, RegisterRequest/Response, LoginResponse, MediaController,
ChatWebSocketConfig/HandshakeInterceptor, FirebaseAdminConfiguration,
DisabledPushConfiguration, OptionalPushConfigurationTest và existing
`backend/src/test/resources/docker-java.properties` (api.version1.44 cho Docker Java).
Xem metadata/diff iOS signing để kiểm bảo toàn, không dùng làm deployment input.

Review thiết kế không thay đổi: build JDK21 -> runtime JRE21, pinned Temurin images,
UID10001, read-only root + tmpfs, exec Java/SIGTERM. JVM heap768MiB dưới limit1.5GiB
để chừa native/metaspace/probe; chưa có RSS/load benchmark. Root health hiện được
SecurityConfig permit, group subpaths không permit nên không đổi security matcher.
Health tổng kiểm PG/Redis, không chứng minh real S3. Configtree bắt buộc, no fallback
keys; Flyway clean disabled, baseline false, Hibernate validate; no QA seeder.
PG/Redis networks internal, no published ports; only backend loopback18280 candidate.
Named volumes/restart/resource/log limits giữ nguyên. Redis AOF/noeviction hợp staging
nhỏ nhưng cần disk/memory monitoring; chưa test AOF durability bằng actual recreation.
Base image pin không làm Maven/plugins/transitive dependencies bit-reproducible;
wrapper version pinned nhưng chưa có distribution checksum: supply-chain follow-up,
không tuyên bố đã giải quyết hết reproducibility bằng pin image.

## 3. File local thay đổi trong D2

Sửa 7 artifacts D1:

```
backend/.dockerignore
infra/compose.staging.yml
infra/staging.env.example
infra/staging/ghcr-workflow.proposal.yml
scripts/staging-container-smoke.py
scripts/validate-staging.py
docs/STAGING_DEPLOYMENT_D1.md
```

Tạo `scripts/tests/test_staging_ci.py`, `docs/STAGING_DEPLOYMENT_D2_REVIEW.md`.
Cập nhật thêm handoff bắt buộc nhưng **không stage/commit handoff đang có unrelated
notes**. `.gitignore`, Dockerfile, health probe, Java tests/profile là D1 được giữ;
không nhận là source mới viết D2. Signing project có3 dòng thay đổi có trước D1,
không thuộc D1/D2. Raw focused Maven log chỉ ở `/tmp/wedo-d2-focused.log`.

## 4. Workflow được chuẩn bị, chưa activate

`infra/staging/ghcr-workflow.proposal.yml` nằm ngoài `.github/workflows`.

Sau approval activation:

- `pull_request` target `dev`: validation exact PR head SHA (không claim là merge
  result SHA), readonly token, không GitHub secrets/registry login/publication.
- `workflow_dispatch`: validate chosen commit; publish mặc định false. GitHub chỉ
  đăng ký manual dispatch nếu workflow hiện diện trên **default branch**. Chưa xác
  minh default branch remote trong D2; không sửa default branch hay main. **First
  build nên qua PR vào dev**, không hứa `gh workflow run --ref feature` sẽ hoạt động
  nếu workflow chưa registered. Owner quyết định manual bootstrap sau này.
- Kiểm HEAD bằng SOURCE_SHA; Git credentials không persist; runner Ubuntu22.04 amd64,
  trước build cần >=15GiB free, trước Compose smoke >=10GiB. Không auto-dọn runner.
- Focused Maven tests trước image, buildx `platforms:linux/amd64`, `load:true`,
  `push:false`. Static validator/unit helpers luôn trước runtime smoke.
- Runtime smoke trên unique `wedo-d2-ci-<UUID>` mới, six random synthetic temp keys,
  ephemeral localhost port, private CI DB. Không dùng external real S3/FCM/QA.
- Diagnostics chỉ JSON sanitized được upload `always()` và giữ7days. Raw Maven
  logs, raw Surefire XML, env/config, HTTP responses/tokens, DB dumps, secret files
  **không upload**. Metadata fail giúp biết service exit/OOM/unhealthy và bước đã
  xong, chưa tự chẩn đoán sâu stacktrace; review log sâu cần cách sanitize riêng.
- Sau smoke PASS, export image gzip bằng docker save, ghi image ID/archive SHA256,
  upload artifact immutable cùng run, retention7days. Không tạo OCI registry digest
  trước push: local image ID, archive checksum và registry digest là ba thứ khác nhau.
- Cleanup đúng new CI project kể cả smoke failure; no prune/remove images. Nếu job
  bị runner cưỡng bức timeout, runner disposable là fallback; không mở đường cleanup
  trên shared host. Các Maven Testcontainers là new isolated runner fixtures, tự
  teardown qua JUnit/Ryuk; không kết nối Mac/VPS.

## 5. Test coverage và kết quả thực tế

**Đã chạy local D2, không Docker/new DB:**

- `python3 scripts/validate-staging.py`: PASS (Compose config, limits/isolation,
  digest refs, six secret refs, V0–V20, context guard structure).
- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p test_staging_ci.py -v`:
  **11 PASS**: reject Mac/self-hosted/remote daemon/wrong tag; metadata excludes
  env/mount/health Output; generic errors không echo raw output; mocked WS401/101,
  bad status và wrong Accept fail. Đây là helper tests, **không actual socket test**.
- Maven Java21 offline focused: **9 PASS, 0 failures/errors/skipped**;
  `StagingProfileTest`6 + `OptionalPushConfigurationTest`3. Mockito Java agent giống
  D1 để bypass sandbox self-attach; không đổi pom/runtime. Final BUILD SUCCESS.
- Workflow YAML structure, action SHA pin shapes, từng run block `bash -n`, Python
  AST và git diff whitespace: PASS. Không thay thế actionlint/full Actions runtime.
- Public manifests của cả2 pinned Temurin images và PostgreSQL17/Redis7 đã xác minh
  linux/amd64, không pull. HEAD Maven wrapper3.9.16 ZIP và Boot parent4.1.1 POM trên
  Maven Central đều HTTP200; không tải ZIP hay dùng cache Mac làm bằng chứng clean
  build. Disk local khoảng3.9GiB, không build/testcontainers. Health probe
  4/4 là bằng chứng D1, không rerun/nhận là phép thử Docker D2.

**CI tests đã chuẩn bị nhưng CHƯA CHẠY:**

1. Maven isolated integration: fresh PG/Redis, Flyway21, no seed/no Firebase,
   health, login/me/groups, WS denial + authorized handshake.
2. Actual built image: amd64/non-root, health PG/Redis, fresh migrations/users0,
   HTTP register synthetic user (201), fixture-only activate user trong DB CI,
   login200/me200/groups200; unauth WS401 + valid WS101/Accept.
3. Application recreate ID thay: same synthetic account/login, DB còn; legacy
   media volume ghi bằng UID10001 và giữ file. PG recreate: same account, migrations
   preserved by volume; bounded readiness + auth recovery. Không mutation tài chính.
4. Export/publish artifact transport và digest recording chưa chạy.

Mail verification bypass chỉ là SQL fixture trong new CI DB, không phải public
API bypass, không account seed thật. External S3 báo **PENDING**, FCM **DISABLED**;
không dùng presign offline/synthetic keys làm bằng chứng upload/media thật. Chưa có
full auth/revocation/WS event delivery regression của staging image; đây là smoke.

## 6. Publication stage riêng và quyền

`publish` needs validation success; điều kiện manual dispatch, publish=true,
refs/heads/dev và đúng HuyGiang1/weDO-app; protected environment
`staging-image-publication` phải có required reviewer/approved branch restrictions
**trước activation publication** (khả dụng phụ thuộc GitHub plan/private repo).
Nếu không cấu hình được protection phù hợp, không bật publish; giữ validate-only.
Job có contents:read + packages:write, dùng ephemeral GITHUB_TOKEN/login-action.
Không tạo/copy PAT/registry/QA/Firebase secrets. Không privilege bằng PR target hoặc
workflow_run. Artifact chỉ từ validation cùng run, không arbitrary run-id input.

Publisher không checkout/run project scripts, verify checksum từ validated output,
docker load, verify image ID và OCI revision bằng full SHA, rồi tag/push chính image
đó. Không Docker build lại. SHA tag giúp định danh, **digest mới là immutable pin**;
tag vẫn có thể overwrite nếu registry cho phép. Ghi registry@sha256 digest sau push;
S3/push verification không bị nâng thành PASS khi image publish.

Owner chọn GHCR visibility; public phải review compiled source/config metadata;
private cần VPS read:packages credential lưu ngoài Git, không ghi token vào shell
history/log. VPS tương lai chỉ pull bằng immutable digest, không Maven/Docker build.
Giữ tối thiểu last2 known-good digests + deployment config/DB/legacy-media backups;
retention không xóa image còn deployed/rollback. GitHub artifact7days không thay
registry retention. Schema compatibility quyết định rollback; không tự down-migrate.

## 7. Exact Git/approval plan — chưa thực hiện

Proposed feature branch: **feat/staging-d2-ci-readiness**, từ origin/dev baseline
sau fresh fetch được phép; recheck origin/dev chưa drift. Dùng separate worktree
để tránh checkout/ghi đè Mac QA. Copy **chỉ** reviewed artifacts từ QA worktree;
không copy ignored secrets, signing hoặc QA data.

Một commit đề xuất: `chore(deploy): prepare isolated staging image validation`.
Exact15paths cho source/docs (không handoff/signing):

```
.gitignore
backend/.dockerignore
backend/Dockerfile
backend/docker/Healthcheck.java
backend/src/main/resources/application-staging.yml
backend/src/test/java/com/wedo/backend/deployment/StagingBootstrapIntegrationTest.java
backend/src/test/java/com/wedo/backend/deployment/StagingProfileTest.java
docs/STAGING_DEPLOYMENT_D1.md
docs/STAGING_DEPLOYMENT_D2_REVIEW.md
infra/compose.staging.yml
infra/staging.env.example
infra/staging/ghcr-workflow.proposal.yml
scripts/staging-container-smoke.py
scripts/validate-staging.py
scripts/tests/test_staging_ci.py
```

Nếu user đồng ý **activation**, thay proposal path bằng
`.github/workflows/staging-validation.yml` trong commit feature, không giữ hai
workflow active. Validate-only PR trigger sẽ hoạt động khi được phép mở PR vào dev.
Manual publication vẫn cần approval riêng/environment protection/default-branch
registration decision; không đổi main/default branch để tiện chạy.

Cần user duyệt riêng rõ ràng: (a) feature worktree/branch + stage/commit đúng scope,
(b) push feature branch, (c) activate workflow + mở PR vào dev và chạy CI. Chưa được
duyệt nên **STOP trước remote commit/PR/CI**. Không direct merge/fast-forward dev.
Publication/GHCR permissions và deployment VPS hoàn toàn là approval sau.

## 8. Security và blockers còn lại

- Không phát sinh real secret trong artifacts; template/config chứa reference và
  synthetic test fixtures. Raw private signing/secret files không đọc/copy/upload.
  Staged index trống; historical secret remediation của checkpoint không bị undo.
- Secret host file mount vẫn cần external provisioning/UID permissions theo D1;
  fixture file0444 chỉ trên disposable CI không phải production recommendation.
- Local disk không đủ build; remote Git/Actions chưa authorized. **Không có image
  build PASS / CI PASS / container startup PASS mới**. Cần actual Linux run để xác
  minh base images, Maven downloads, image user/volume ownership, Docker Compose và
  dynamic host-port recreation. Static review không chứng minh các bước đó.
- External S3/provider/private bucket/HTTPS/key chưa provision; real media test
  blocked. APNs/FCM+iOS push/tap vẫn pending R9. Chưa reserve18280/domain/DNS/TLS.
- VPS/breast-health-staging/CV demo và mọi existing app không bị truy cập/thay đổi.
  Không SSH, prune/pull/build/restart/migration trên shared host, không thay Mac QA.

Nguồn chính thức cho quyết định CI:
[GitHub workflow events/manual dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows),
[Artifacts giữa jobs và checksum](https://docs.github.com/en/actions/tutorials/store-and-share-data),
[Compose down/volume scope](https://docs.docker.com/reference/cli/docker/compose/down/).
