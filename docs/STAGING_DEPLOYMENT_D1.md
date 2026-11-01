# Phase D1 — staging artifacts, chưa triển khai

> D2 review: [STAGING_DEPLOYMENT_D2_REVIEW.md](STAGING_DEPLOYMENT_D2_REVIEW.md)
> ghi exact findings/changes/approval scope. Artifacts hiện tại đã được harden trong
> D2; vẫn chưa build image hay chạy CI. D2 local:9 Java +11 CI-helper tests PASS.

Ngày: 2026-11-01. Baseline: `0dbb7bf155a557b441dfff01489def058f15d874`.
Canonical branch là `dev`; thư mục QA vẫn trên `integration/r9-qa-checkpoint` cùng
baseline. D1 là thay đổi **chưa commit**, không phải image đã publish của baseline.

## Phạm vi và trạng thái thật

- Đã chuẩn bị Dockerfile Java 21, profile staging, Compose riêng, template không
  chứa secret, validator, focused tests và workflow CI **chưa kích hoạt**.
- Local: 9/9 focused tests PASS; Java health probe 4/4 PASS; Compose schema/isolation
  PASS; Python syntax PASS. Không chạy full regression, Flutter hoặc backend QA.
- Chưa build/pull image, chạy PostgreSQL/Redis mới, Flyway thực tế, auth/WS integration
  hoặc recreation volume: **BLOCKED tại Mac vì closeout chỉ còn khoảng 4.5 GiB disk**.
  Integration test/CI smoke đã viết nhưng **chưa chạy**. Không suy ra PASS từ syntax.
- External S3 upload/download, authorization/media/video: **BLOCKED — chưa có provider,
  private bucket và credentials staging được duyệt**. Presigning chỉ được test offline.
- Không SSH, không mua/cấu hình domain, không Nginx/Certbot/firewall, không deploy,
  không publish GHCR, không tạo GitHub secrets, không đổi QA/runtime/mobile/signing.

## Artifact và thiết kế

| File | Vai trò |
| --- | --- |
| `backend/Dockerfile` | Multi-stage Temurin JDK/JRE 21 Jammy, base digest cố định; build từ source bằng Maven wrapper; runtime UID/GID 10001; exec Java, SIGTERM, probe JRE |
| `backend/.dockerignore` | Allow-list chỉ Maven wrapper/pom, Java main, application YAML và SQL; loại target/tests/env/keys/media/Firebase files |
| `backend/docker/Healthcheck.java` | Chỉ GET loopback `/actuator/health`, timeout, không follow redirect/log body/secret |
| `backend/src/main/resources/application-staging.yml` | Explicit staging, required configtree secrets, PG/Redis riêng, Flyway validate/clean disabled, push/QA seed off, Swagger off |
| `infra/compose.staging.yml` | Pull-only backend + PG17 + Redis7; namespaces, health dependencies, limits/logging/volumes |
| `infra/staging.env.example` | Origins/image/region/secret-directory placeholders; không có secret value |
| `scripts/validate-staging.py` | Offline Compose/schema/isolation + migration inventory; không gọi daemon |
| `scripts/staging-container-smoke.py` | CI-only disposable image/PG/Redis/volume test, không chạy ở Mac/VPS |
| `backend/src/test/java/com/wedo/backend/deployment/` | 6 profile tests + 1 prepared isolated PG/Redis/auth/WS integration test |
| `infra/staging/ghcr-workflow.proposal.yml` | Inactive CI/publish proposal, nằm ngoài `.github/workflows` |

Java 21 và Spring Boot 4.1.1 được xác nhận từ pom; Maven wrapper dùng Maven 3.9.16.
21 migrations **V0–V20**, không đổi migration/schema/domain/API contract.
Upstream image manifests có linux/amd64; image weDO linux/amd64 vẫn phải build/test.
Base images được pin digest trong Dockerfile; D2 đã pin cả PG/Redis template bằng
public manifest digest có linux/amd64, chưa pull/test runtime. Không claim bit-for-bit reproducibility
cho các dependency/plugin tải từ registry/repository bên ngoài.

Backend root filesystem read-only, drop capabilities, no-new-privileges, init,
tmpfs `/tmp` 128 MiB, graceful stop 45s. Image không chứa curl/credentials.
Probe dùng `/actuator/health` vì security hiện tại chỉ public đường này; không sửa
SecurityConfig để mở thêm URL. Composite health bao gồm DB/Redis; group readiness
DB/Redis cũng được cấu hình nhưng không dùng subpath bị auth chặn làm Docker probe.
Health details/components luôn ẩn; S3/push không thuộc readiness nên **UP không chứng
minh media/push hoạt động**. Nginx sau này có thể hạn chế health path, cần duyệt riêng.

Compose project `wedo-staging`; không fixed container_name; không external/shared
volumes; không publish DB/Redis. Backend mặc định **127.0.0.1:18280**, chỉ là cổng
đề xuất chưa reserved. Internal `data` network dành PG/Redis; backend thêm `egress`
để gọi approved S3. Ba named volumes tự namespace theo project:

- `postgres_data`: PG17 `/var/lib/postgresql/data`.
- `redis_data`: AOF Redis, maxmemory 64 MiB/noeviction; volume/AOF vẫn cần giám sát.
- `legacy_media`: `/opt/wedo/.local-media`, chỉ avatar legacy còn dùng local disk.
  Dockerfile tạo thư mục UID10001 để empty volume nhận ownership. Không mount QA
  media. Read-only root không được làm API avatar cũ thất bại; persistence/ownership
  của volume này phải được kiểm tra khi CI image chạy lần đầu.

Không có MinIO/AIStor container. External S3 giảm storage/server/backup local;
không giả định có license AIStor hay tự thay license. Redis chỉ nằm internal network,
không có password trong proposal; không coi network isolation thay TLS/auth cho một
môi trường khác nơi nhiều tenant có quyền Docker/root. Root/Docker admin vẫn đọc được
container secrets; cần owner chấp thuận threat model của shared host.

## Secret provisioning — chưa thực hiện

Không dùng QA env/DB/accounts/keys. Sáu file riêng ngoài Git được mount read-only:

```
WEDO_DB_PASSWORD
WEDO_JWT_SECRET_BASE64
WEDO_AUTH_TOKEN_PEPPER_BASE64
WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64
WEDO_MEDIA_ACCESS_KEY
WEDO_MEDIA_SECRET_KEY
```

Ba auth keys phải độc lập, random tối thiểu 32 byte rồi Base64. DB password random
riêng; S3 access/secret key do provider provision, không tự bịa dùng thật. Không in
keys ra terminal/log/chat. Template không chứa giá trị; configtree bắt buộc tồn tại,
không fallback secret. Compose file-backed secrets không mã hóa host files.

**Sau approval**, owner tạo thư mục external staging mới, không overwrite QA;
thiết lập file ownership cho UID/GID10001 đọc được (ví dụ root:10001, directory0750,
file0440, kiểm tra container PG cũng đọc được PASSWORD_FILE khi entrypoint chạy).
Không dựa vào Compose `uid/gid/mode` để chmod bind-backed secret files. Chưa tạo
hay đổi quyền bất kỳ secret thật nào trong D1. Staging env ngoài Git chỉ trỏ đường
dẫn; `.gitignore` giữ env/secret directory khỏi commit. Tuyệt đối không đưa real
env vào build context. CI dùng synthetic ephemeral secrets, không copy QA secrets.

## External S3 prerequisites

Owner chọn provider/budget/data region và tạo bucket **private, riêng staging**.
Backend hỗ trợ endpoint, public signing endpoint, region, path-style; static key
least-privilege trên đúng bucket/prefix. Provision tối thiểu PUT/GET/HEAD và DELETE
chỉ trong lifecycle app cần; bucket không public, không cấp quyền admin/CreateBucket.
`bootstrap-bucket=false` nên provider/bucket phải có trước full media acceptance.
Nếu provider enforce policy HEAD/ListBucket, cấp tối thiểu theo SDK operation thực tế.

Public endpoint phải HTTPS, truy cập được từ Android/iOS và backend nơi verify HEAD;
presigned PUT/GET có host/path/query là một phần chữ ký, không đổi tùy tiện bằng
redirect/reverse-proxy rewrite. Region/path-style phải đúng provider; cấu hình CORS
cho browser origins thật nếu dùng web (không wildcard credentials), Range/206 và
Content-Type cho video. S3 URL không được tiết lộ public object: backend giữ nguyên
membership/privacy/media authorization trước khi cấp signed URL, TTL hiện có giữ nguyên.

Test pending: authorized upload -> confirmation/HEAD -> GET ảnh/video seek, unauthorized
access, revoked membership/block/removal, expired URL, restart persistence, không
redirect tới IP Mac/MinIO cũ. Legacy avatar volume cũng phải backup riêng.

## Firebase và data bootstrap

`WEDO_PUSH_ENABLED=false` được Compose đặt cố định; disabled gateway trả trạng thái
`EXTERNAL_CONFIG_BLOCKED`, không giả gửi thành công, không đọc ADC. Không mount/copy
Firebase Admin QA. REST auth/groups/chat/polls/tasks/community/finance và shared WS
vẫn có thể chạy; remote notification delivery khi app background/killed cần FCM.
Notification Center lưu DB không đồng nghĩa push đã phát tới thiết bị.

Muốn enable push: review override riêng mount credential staging read-only + enable
flag, đúng Firebase project/client apps. iOS vẫn cần paid-team/APNs/FCM/capability và
physical receipt/tap gate. **R9 IN PROGRESS**, không claim iOS push COMPLETE.

Flyway init DB rỗng, Hibernate validate; không baseline DB tùy tiện, không clean/reset.
Không tự chạy QA seeder. Chưa có demo account persistent được tạo. Cần owner duyệt
quy trình synthetic demo account/verification riêng trước staged user acceptance;
không dump/copy QA DB hoặc dùng test fixture làm tài khoản thật.

## Validation và cách chạy

Đã chạy trên Mac, không dùng existing QA DB/container:

```sh
python3 scripts/validate-staging.py
cd backend
# Java21; -javaagent chỉ để Mockito hoạt động trong sandbox Mac, không đổi pom.
JAVA_HOME=$(/usr/libexec/java_home -v 21) MAVEN_OPTS=-Xmx512m ./mvnw -o -B -ntp \
  -DargLine="-javaagent:$HOME/.m2/repository/org/mockito/mockito-core/5.23.0/mockito-core-5.23.0.jar" \
  -Dtest=StagingProfileTest,OptionalPushConfigurationTest test
```

Kết quả: **9 tests, 0 failures, 0 errors, 0 skipped**. Lần đầu harness thiếu Spring
Duration conversion và Mockito self-attach bị sandbox chặn; đã sửa initializer test
và chạy lại với agent, không sửa business code để né failure. Java probe compile
`javac --release 21`, isolated random-loopback HTTP 200/503/302/unreachable: **4/4 PASS**.
Python AST syntax và workflow YAML parse PASS. CI smoke guard đã được thử trên Mac:
từ chối trước khi gọi Docker như thiết kế. `git diff --check` PASS tại closeout.

Compose validator chỉ `config --format json` với synthetic env + `/dev/null`, kiểm
service names/platform/limits/networks/ports/secrets/migration inventory. Không đọc
secret files, gọi Docker daemon, hoặc start services. Context guard chỉ kiểm tra
allow-list structure; image build mới chứng minh Docker COPY/context thực tế.

Sau **CI activation approval**, proposal chạy isolated Linux runner:

```sh
cd backend
bash mvnw -B -ntp -Dtest=StagingProfileTest,OptionalPushConfigurationTest,StagingBootstrapIntegrationTest test
cd ..
docker buildx build --platform linux/amd64 --load \
  --build-arg VCS_REF="$GITHUB_SHA" -t "wedo-d1-ci:$GITHUB_SHA" backend
python3 scripts/staging-container-smoke.py "wedo-d1-ci:$GITHUB_SHA"
```

Integration test chuẩn bị: fresh Testcontainers PG/Redis, 21 migrations, no QA seed,
health200, /me401, synthetic active-user login + authenticated /me/groups, denied
unauthorized WS and authorized WS101. Không gọi S3 thật. CI smoke guard bắt buộc
GitHub-hosted Actions + local Unix Docker + >=10GiB free + exact commit-tagged image;
project UUID mới. D2 bổ sung REST/login/WS trên chính image, recreate backend và PG,
kiểm synthetic account/legacy volume còn và readiness phục hồi; không S3 thật.
D2 cleanup `down --volumes` chỉ project CI UUID mới, không prune/existing projects.
Chi tiết guard, sanitized diagnostics và coverage ở report D2. Toàn bộ CI chưa chạy.

## Resource budget (ước tính, chưa benchmark staging image)

| Hạng mục | Cấu hình/ước tính |
| --- | --- |
| Backend | Limit1.5GiB/1CPU, heap128–768MiB; đo RSS/native/connection load sau CI |
| PostgreSQL17 | Limit1GiB/0.5CPU, shm128MiB; data/WAL synthetic staging budget1–2GiB ban đầu |
| Redis7 | Limit256MiB/0.25CPU; data max64MiB, AOF/rewrites cần thêm disk |
| Tổng container caps | 2.75GiB RAM /1.75CPU, không phải guaranteed consumption/reservation |
| Images + rollback | Ước1.5–2.5GiB uncompressed cho app + PG/Redis + 1 rollback, phải đo CI |
| Logs | Max khoảng90MiB/3services qua json-file, chưa gồm host journal/Nginx |
| Legacy avatar | Budget0.1–0.5GiB, giám sát, không có quota tự động |
| Backup | Dự trù1–2GiB local tạm; bản chính off-host encrypted, không chứa trong image |
| Tổng free trước launch | Khuyến nghị >=10–12GiB thực sau pull/backups, giữ >=8GiB sau rollout |

JAR QA hiện có khoảng145MiB chỉ là tham khảo, không phải image D1 đã build. Historical
server16GB free/5.5GiB available là số cũ, không capacity approval. Dự trù mới+rollback
có thể ăn5–7GiB; cần fresh check khi deploy, dừng nếu vượt headroom. Không tính cache
"reclaimable" là free. Không cần xóa Breast Cancer để chuẩn bị D1; không được dọn cache
hay retire project nào nếu chưa có approval riêng. Shared workloads có thể tăng.

## GHCR, rollback và approval tiếp theo

Workflow chỉ là `infra/staging/ghcr-workflow.proposal.yml`; **không tự chạy**. Owner
cần review/approve source+workflow activation, đặt required reviewers cho environment
`staging-image-publication` trước khi đưa vào `.github/workflows`. Manual validate
không publish theo mặc định; D2 tách validation readonly khỏi publish job cần approval
environment + manual publish=true trên dev. Publish dùng ephemeral `GITHUB_TOKEN`
packages:write, Actions pin SHA. Artifact từ validation cùng run được kiểm checksum,
image ID và revision trước tag/push; **không rebuild image sau validation**.
Không tạo PAT/GitHub secret. CI chưa cấp attestation/SBOM; đó là hardening follow-up,
không coi proposal này là một pipeline supply-chain hoàn chỉnh.
Publish image theo **commit SHA chứa D1 sau approval commit**, ghi digest output +
OCI revision; deploy bằng `ghcr.io/huygiang1/wedo-backend@sha256:...`, không latest.
GHCR visibility/pull quyền là owner decision. Private package cần read-only credential
provision riêng ngoài repo, không in token; public image chỉ nếu owner duyệt.

VPS chỉ pull prebuilt amd64 image, không build Maven/Docker. Giữ previous digest,
config version và DB/media backups. Flyway đổi schema tương lai không rollback bằng
đổi image một cách mù quáng; cần compatibility review và restore rehearsal riêng.
Backup trước upgrade: dedicated `pg_dump` + encrypted off-host, bucket versioning/
retention, legacy avatar snapshot, secrets backup riêng quyền hạn chế. Redis AOF
không thay DB backup. Không backup/copy existing projects trong D1.

Trước khi được sửa VPS, cần đủ các bước/approval:

1. User review D1, approve commit/push/CI activation và publication riêng; chạy CI
   build + full isolated checks ở trên, sửa confirmed artifact failures nếu có.
2. Owner chốt external S3, real staging keys/secret ownership, image visibility,
   retention/cost/backup policies và synthetic account bootstrap.
3. Mua/chốt domain ngoài D1; quyết định subdomain API, media endpoint; không coi
   `wedoapp.click` đã sở hữu. Rebuild mobile staging riêng nếu API origin thay.
4. Reauthorize exact SSH host/key + independently verified fingerprint; fresh
   read-only capacity/ports18280/Nginx/Certbot survey, không assume previous facts.
5. Owner approve exact new directory, isolated volumes/networks/resources, loopback
   port18280 reservation, image digest, backup/rollback và sau đó Nginx/HTTPS/WS
   upgrade headers/timeouts/trusted proxy policy. `forward-headers-strategy=none`
   hiện chưa tin proxy headers; review reverse-proxy behavior trước public access.
6. Explicit deploy approval mới được tạo staging files/containers/migrations trên
   DB riêng; không restart Docker, không dừng existing apps, không prune/shared DB.

Tài liệu tham khảo chính thức (D1):
[Spring configtree](https://docs.spring.io/spring-boot/reference/features/external-config.html),
[Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/),
[Compose service/secret mount constraints](https://docs.docker.com/reference/compose-file/services/),
[GitHub publishing images](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images),
[GHCR authentication/visibility](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
