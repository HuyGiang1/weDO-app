# weDO — Agent Current Handoff (`docs/AGENT_CURRENT_HANDOFF.md`)

> **Live Handoff Document** — Update this file whenever milestone status, corrective passes, verification counts, or next actions change.

## Current M16 Final Closeout (2026-09-30)

- Branch `feat/m16-media-search` remains based on `05b4da2431c772c31abe315458674a99b9ce68e6`; no stage, commit, push, or migration change. The live worktree is the source of unfinished M16 changes. Preserve the protected stash, local-only files, and the semantic-empty `FundDtos.java` status marker.
- Closeout corrected pending stranger direct requests to TEXT-only at both CHAT_IMAGE presign and message creation. Accepted/group conversations retain image-only, caption plus image, and four-image behavior. The pending Chat composer hides image attachment while leaving text send available. API contract documentation now states the rule.
- Focused backend `ChatServiceIntegrationTest,UploadControllerIntegrationTest`: 16 run, 0 failures, 0 errors, 0 skipped. Full backend: 618 run, 1 failure, 0 errors, 1 skipped; the sole failure is the known unrelated `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` baseline. Testcontainers PostgreSQL started successfully.
- Focused Flutter Chat screen: 25 passed. `flutter analyze`: no issues. Full Flutter: 690 passed. Fresh debug APK built with `WEDO_API_BASE_URL=http://127.0.0.1:8080` at `mobile/build/app/outputs/flutter-apk/app-debug.apk` and installed on Samsung `R58M36JQYVY`.
- Samsung narrow sanity: a pending QA Outsider direct request offered text send and no image attachment; text send succeeded. Accepted QA group chat offered image attachment and rendered existing image messages. Current app logcat sample contained zero fatal/Flutter/overflow markers. Temporary backend was stopped; port 8080 has no listener, and ADB reverse remains limited to 8080 and 9000.
- A1 storage/avatar, A2 Chat/Finance media, and Phase B Search audits found no new M16 closeout blocker beyond the accepted Fund test baseline. No V13 or M16 migration, no secret file staged, and the Chat repository shared media-uploader fallback remains wired for all route constructors.
- Security follow-up outside M16: under DEBUG WebSocket transport logging, a local runtime disconnect log included a token-bearing WebSocket URI. Do not reproduce log values. Avoid DEBUG transport logging or query-string tokens in shared/production logs; assess redaction in a separate security hardening task. This did not originate in the M16 media/search diff.
- Next action: review the exact M16 include/exclude list, then seek explicit commit approval. Do not stage or commit during closeout; separate approval is required for push.

## Historical M16 Phase B Global Search Implementation (2026-09-30)

- **Branch/base**: `feat/m16-media-search`, based on `05b4da2431c772c31abe315458674a99b9ce68e6`. M16-A1/A2 work remains in place. No migration, commit, or push was made for Search.
- **Approved contract**: exactly PEOPLE, GROUPS, ACTIVITIES, CONVERSATIONS; query length 2..100; accent-sensitive PostgreSQL ILIKE substring matching with literal `%`/`_`; All mode up to five per category and independent `hasMore`; typed mode page/size with 0/20 defaults and size 1..50; safe typed response projections and existing domain authorization before pagination. Conversations represent the newest visible matching text message and navigate to the exact conversation without message anchoring.
- **Backend implementation**: typed Search DTOs, controller validation, bounded SQL projections, and PostgreSQL integration coverage are in `backend/src/main/java/com/wedo/backend/search/` and `backend/src/test/java/com/wedo/backend/search/SearchControllerIntegrationTest.java`. Focused Search backend tests pass: 6 run, 0 failures, 0 errors, 0 skipped. Full backend: 618 run, 1 known unrelated baseline failure, 0 errors, 1 skipped. The only failure is `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` (expected true, was false); not changed by M16-B.
- **Flutter implementation**: typed models/API/controller, Search screen and route, Groups search entry point, identity-based authorized avatar resolution, exact destination navigation, 300 ms debounce, typed pagination, duplicate suppression, and stale-response handling. Search-focused tests pass (4); `flutter analyze` is clean; full Flutter suite passes: 688 tests.
- **Build/device**: fresh debug APK built at `mobile/build/app/outputs/flutter-apk/app-debug.apk` and installed on Samsung `R58M36JQYVY`. All five categories fit the phone viewport. On-device checks returned QA people, joined QA group, six matching M15 activities (All-mode `Xem tất cả` then typed results), and matching group conversation; people/profile, Group Info, Activity Detail, and exact conversation navigation opened. Backend PostgreSQL integration tests cover hidden discovery, both-direction blocks, outsider visibility, archive/history, literal wildcards, accents, and page offsets. Two-account privacy assertions were automated, not manually switched on Samsung.
- **Audit/runtime**: no V13, external search engine, `unaccent`, or trigram dependency; `git diff --check` clean. The temporary foreground backend was stopped after Samsung acceptance. Current device logcat has no Flutter fatal/error markers; ADB reverse is restricted to ports 8080 and 9000. No staging, commit, or push. Keep the protected stash and local-only files untouched.

## Historical M16 Phase B Search Contract Review (Superseded, 2026-09-30)

The review gaps were resolved by `DEC-M16-04` and the implemented Search contract summarized above.

## Historical M16 Phase A2 Status (Superseded by Phase B, 2026-09-30)

- **M15 status/base**: M15 is closed and pushed to `dev`. M16 branch `feat/m16-media-search` is based on `05b4da2431c772c31abe315458674a99b9ce68e6`.
- **A1 implementation**: Added provider-neutral S3 storage, local private MinIO compose services, authenticated 10-minute `AVATAR`/`GROUP_AVATAR` presigning, direct Flutter PUT, owner/group-scoped key and metadata validation, authorized 5-minute signed reads, profile/group avatar upload UI wiring, and best-effort after-commit old-object deletion. No migration was added. Onboarding and initial group creation reject supplied avatar keys; attach avatars after the resource is active/created.
- **A2 contract/implementation**: `DEC-M16-03` and the API blueprint now specify exactly `CHAT_IMAGE`, `EXPENSE_RECEIPT`, `FUND_CONTRIBUTION_PROOF`, `FUND_EXPENSE_RECEIPT`, and `FUND_REIMBURSEMENT_RECEIPT`; JPEG/PNG/WebP, 10 MiB per file, four Chat images, and one Finance key per current nullable column. Context is exact conversation ID for Chat and group ID for Finance. Server-generated namespaced keys, object metadata/size validation, current domain authorization, post-upload finalization checks, private authorized reads, durable Chat attachment metadata/order, image-only empty content, notification fallback, and after-commit best-effort cleanup are implemented. No migration/V13 was added; Global Search remains unimplemented.
- **Backend verification**: Prior A2 focused suites: 62 run, 1 known baseline failure, 0 errors, 0 skipped. This acceptance added `UploadControllerIntegrationTest.fundExpenseReceiptPresignIsReadOnlyAndRequiresManagerPermission`: focused class 4 run, 0 failures/errors/skips. Full backend after the production fix: 612 run, 1 failure, 0 errors, 1 skipped. The sole failure remains the known baseline `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` (expected true, was false); Docker/Testcontainers started PostgreSQL and Flyway applied through V12. `FundDtos.java` has no content diff; preserve its existing modified status marker.
- **Flutter verification**: Previously verified focused Chat/media/Expense/Fund tests: 46 passed; full suite: 684 passed, 0 failed; `flutter analyze`: no issues found. No Flutter source changed during final acceptance. The existing fresh debug APK remains at `mobile/build/app/outputs/flutter-apk/app-debug.apk` and was used on Samsung.
- **Bootstrap closeout**: AIStor uses `quay.io/minio/aistor/minio:RELEASE.2026-09-19T17-05-25Z` with the external license mounted read-only at `/minio.license`; the runner sets only a process-scoped license path and never reads the license. Compose config validates. Backend `S3BucketBootstrapper` successfully bootstrapped the private bucket; it performs HEAD/create, accepts a create race only after successful re-HEAD, never changes existing bucket policy/objects, and fails startup generically when enabled storage is inaccessible. `media.s3.bootstrap-bucket` remains true in local, false globally/production and in tests. ADB reverse is limited to 8080 and 9000; console 9001 remains host-loopback only.
- **Samsung A1 acceptance (2026-09-30)**: External license path exists (contents not inspected); Samsung `R58M36JQYVY` authorized; Docker Engine 29.7.2 accessible. AIStor readiness returned HTTP 200 and backend actuator returned UP with Flyway current through V12. Owner presign + direct signed PUT + Profile UI upload, persistence, replacement, old-object cleanup, and authenticated private read passed. With AIStor stopped, Profile UI showed `Unable to upload your photo. Your current photo is unchanged.`; app stayed alive and persisted avatar remained readable after storage recovery. Group avatar UI upload/replacement and reopen persistence passed; member presign/finalization were denied (403), wrong group context was rejected (400), signed private reads succeeded, anonymous reads returned 403. Final sampled device logcat: 0 fatal exceptions, 0 Flutter errors; ADB reverse list contains only 8080 and 9000.
- **Repository state**: No staged files; no commit or push. Preserve the status-only `FundDtos.java` marker, `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, untracked `mobile/android/app/google-services.json`, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`.
- **A2 Samsung Chat send fix (2026-09-30)**: Reproduction showed Send enabled with the selected preview, then the generic connection snackbar and zero presign calls. Group/notification routes create ChatRepository instances with ChatApi but no MediaUploadService; `uploadChatImage` therefore threw `StateError` before HTTP. ChatRepository now uses the app-registered shared uploader as its default, and the composer enables Send only for nonblank text or queued images while not sending and within the four-image cap. Widget coverage exercises empty/text/image/caption states, upload failure retention, returned-key forwarding, four accepted/five rejected, and rapid-tap deduplication. Focused Chat/media: 35 passed; `flutter analyze`: clean; full Flutter: 683 passed; fresh APK built and installed.
- **A2 two-account Chat acceptance (2026-09-30)**: Samsung recipient `owner@wedo.local` and authenticated API/WebSocket sender `member1@wedo.local` exercised production CHAT_IMAGE presign, direct signed PUT, and REST message creation. While the exact group conversation was active, one durable image-only message produced exactly one `MESSAGE_CREATED`, one rendered image item, and one attachment; REST history after reopen retained it. While away/backgrounded, another image message produced one visible FCM system notification with the existing Vietnamese Chat title and image fallback body, no key/URL, and tapping opened the exact conversation with the image rendered. With the exact conversation active again, one realtime image rendered and no redundant Android system push appeared. Sampled Samsung logcat showed zero Flutter errors and zero fatal Android exceptions. ADB reverse remains limited to TCP 8080 and 9000.
- **A2 Finance Samsung acceptance (2026-09-30)**: All four wired flows passed and persisted/reopened with private image previews: Expense receipt and replacement; Fund contribution proof (left PENDING); Fund manager expense receipt; member reimbursement receipt (left PENDING). Existing Fund contribution/expense/reimbursement records have no post-submit receipt-replacement UI, so replacement is not applicable for those flows. Authorized API media access returned 200 for Expense and all three Fund categories; outsider reads were denied (404), and outsider presigns for Expense and Fund expense were denied (404). Cross-group Finance receipt reuse and Chat image-as-Expense-receipt mutations were rejected (400), with the target second-group expense unchanged. A controlled Expense replacement using a valid presigned key but no PUT was rejected (400); the previous receipt reference remained unchanged. The previously attempted Fund expense upload failure was traced to `authorizeMediaPresign` calling a manager helper that issued stale-manager cleanup DELETE inside a read-only transaction. The read-only authorization now checks mutable membership and `canManageFund` without cleanup; the new PostgreSQL endpoint regression proves owner success and member denial. This is the only backend code change during final acceptance.
- **A2 closeout**: All required two-account Chat/FCM and implemented Finance media acceptance gates passed. No Search implementation or migration was added. Ready for M16 Search review; do not begin Search until separately authorized.
- **Final runtime state**: The freshly started backend from this checkout passed actuator health and used Flyway V12, then was stopped cleanly after acceptance; port 8080 has no listener. `wedo-minio`, `wedo-postgres`, and `wedo-redis` remain running. Samsung `R58M36JQYVY` remains authorized with only `tcp:8080 -> tcp:8080` and `tcp:9000 -> tcp:9000` reverse mappings.
- **A2 realtime refresh runtime correction (2026-09-30)**: Fresh Samsung logcat traced repeated `setState() callback argument returned a Future` errors to `ChatHomeScreen._refresh`, where an expression-bodied state callback returned the conversations Future. Changed it to a synchronous block and added a realtime refresh widget regression. Focused Chat Home test passes; `flutter analyze` is clean; full Flutter suite: 684 passed. Fresh debug APK rebuilt and installed at `mobile/build/app/outputs/flutter-apk/app-debug.apk`. On `R58M36JQYVY`, opening Chat Home exercised realtime refresh with no Flutter errors; one new image-only send through the final APK rendered in the conversation. These observations do not close the outstanding multi-account/FCM/Finance acceptance items above. No backend code or migration changed; no commit or push.

## Historical M15 Phase C Snapshot (2026-09-29)

- **Branch/commit**: `feat/m15-calendar-reminder` at M15 commit `09fd2614007bb117d13d99fe3b6c23efbe74d727`; no push, merge, rebase, or amend performed.
- **Implemented**: Phase A/B Calendar/reminder configuration and Phase C bounded due-reminder scheduler. It claims in batches of 100 at a 45-second cadence, locks Activity before reminder with `SKIP LOCKED`, revalidates eligibility, and atomically persists/deduplicates the ACTIVITY inbox item with `sent_at`; M14 push policy is dispatched after commit. Reuses V9; no migration change or V13.
- **Backend verification**: Phase C focused suites: 35 run, 0 failures, 0 errors, 0 skipped. The last full backend result remains 589 run, 1 failure, 0 errors, 1 skipped; the sole failure is the unrelated known Fund JSON decimal assertion at `FundServiceIntegrationTest.java:594`. Backend production code was not changed in this continuation, so the full suite was not rerun.
- **Flutter verification**: the isolated Calendar test now passes after correcting its timezone/date-boundary fixture while retaining the real API response display and activity-ID tap assertions. Focused Calendar (5), Notification (21), and route (56) tests: 82 passed. `flutter analyze`: no issues. Full `flutter test --reporter compact`: `+672: All tests passed!` Fresh debug APK built and installed at `mobile/build/app/outputs/flutter-apk/app-debug.apk` using API base `http://127.0.0.1:8080`.
- **Runtime**: Docker Desktop 4.86 / Engine 29.7.2; PostgreSQL healthy and Testcontainers started PostgreSQL. Current backend PID 21680 (Java; started 2026-09-29 22:32:10 local), actuator health `UP`; Samsung `R58M36JQYVY` authorized. Host, device, and PostgreSQL UTC clocks agreed within about one second. Firebase Admin credential path was set and existed; its contents and device tokens were never read or printed.
- **Samsung Phase C acceptance**: (1) UI-configured due reminder created one ACTIVITY inbox item, sent after commit, produced a visible Firebase system notification, tapped into the exact Activity detail, marked the notification read, and had no duplicate inbox/push after two more scheduler ticks. (2) With ACTIVITY preference off and global push on, a second reminder persisted and finalized `sent_at`, was `SUPPRESSED_CATEGORY_DISABLED`, and produced no matching system notification; ACTIVITY preference was restored. (3) While the group was muted and both user preferences enabled, a third reminder persisted once with `SUPPRESSED_GROUP_MUTED`; no reminder push appeared and the group was unmuted afterward. (4) Reschedule: the 23:15 local original due instant passed without inbox row or push after the Activity was moved later; offset stayed 5 minutes and the new 23:25 due instant produced one inbox row (`GATEWAY_ACCEPTED`) and one visible Samsung notification, still one after two further ticks. `GATEWAY_ACCEPTED` is provider handoff, with the physical notification separately proving device appearance.
- **Other acceptance/audits**: disable-before-due physical case was not run; automated disable/scheduler race coverage remains. Final bounded Samsung logcat: 0 `FATAL EXCEPTION`, 0 `AndroidRuntime`, 0 `FirebaseMessaging`, 0 `FirebaseApp` matches in last 3000 lines. No migration/V13; no generated artifact staged. `google-services.json` remains untracked; external Admin credential remains outside Git. Preserve the status-only `FundDtos.java` marker, both local-only docs, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`.
- **M15 Calendar filter pre-commit correction (2026-09-30)**: fixed `CalendarScreen` so each omitted filter argument preserves its current selection while an explicit null clears only that filter; added Clear filters for intentional reset-all. Calendar widget coverage verifies changing each filter preserves the others, combined query parameters, individual clear, reset-all, month navigation, Month/Agenda rendering, and activity opening. Focused Calendar tests: 5 passed; `flutter analyze`: no issues; full Flutter suite: 672 passed. Fresh debug APK rebuilt at `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Root cause was the screen callback assigning all three nullable callback parameters on every change; repository serialization was already correct.
- **M15 filter physical recheck**: NOT RE-RUN — device/runtime unavailable; focused and full automated regression PASS. This is nonblocking for the approved commit retry because the fix is isolated to Flutter filter state, no backend/reminder delivery code changed, and prior Samsung Calendar/Reminder/FCM acceptance passed.
- **Next**: M15 implementation is committed locally; wait for separate push authorization before publishing the branch.

## 1. Historical M15 Git & Branch State

- **Active Branch**: `feat/m15-calendar-reminder`
- **Base Commit (`dev`)**: `5e288f0098543d486ee1c2010a8f8f7b765d8ff1` (M14 merged and pushed; M14 closed)
- **Active Milestone**: **M15 — Calendar + Reminder (implementation and acceptance complete; committed locally, not pushed)**. Scope includes Activity-derived Calendar, personal reminders, due delivery through M14 Notification/FCM policy, and live Samsung acceptance. The post-fix Calendar filter device recheck was not rerun because the device/runtime was unavailable; this is nonblocking under the approved automated acceptance. M14 feature commit: `d4fc8571959d92e17b139be936669f64c459b6d8`.
- **Preserved Stash**: `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync` — **DO NOT** pop, apply, or drop.
- **Local-Only Untracked Files (Never Stage/Commit)**:
  - `docs/LEARNING_HANDBOOK_M0_M2.md`
  - `docs/M8_STITCH_FIDELITY_INVENTORY.md`
  - `.stitch/**`

---

## 2. Historical M10 Implementation (`feat/m10-chat-realtime`)

### Database Schema (`V4__chat.sql` — No New Migration Required)
- M10 reuses existing `V4__chat.sql` tables (`conversations`, `messages`, `conversation_read_states`, `user_presence_snapshots`).
- `ChatService.recordLastSeenSnapshot(userId, now)` upserts `user_presence_snapshots(user_id, last_seen_at)` when a user's last active WebSocket session disconnects.
- No existing Flyway migrations (`V0`..`V12`) were modified and no new migration (`V13+`) was required.

### Backend (`backend/src/main/java/com/wedo/backend/chat/realtime/...` & `ChatService.java`)
- **WebSocket Endpoints & Security (`ChatWebSocketConfig`, `ChatWebSocketHandshakeInterceptor`, `SecurityConfig`)**:
  - Registers `/ws` and `/api/v1/ws`.
  - Handshake interceptor validates JWT access token (`Authorization: Bearer <token>` header or `?access_token=<token>` query param) and verifies `UserStatus.ACTIVE`, rejecting unauthenticated/invalid handshakes with HTTP 401.
- **Transactional Event Bridge (`ChatRealtimeTransactionalBridge`)**:
  - `ChatService` publishes `DomainMutationEvent` (`send`, `edit`, `unsend`, `react`, `pin`, `unpin`) and `DomainReadEvent` (`markRead`).
  - `ChatRealtimeTransactionalBridge` listens with `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` so WebSocket/Redis frames are dispatched strictly after durable PostgreSQL transaction commit.
- **Redis Pub/Sub, Typing TTL & Multi-Session Presence (`ChatRealtimeCoordinator`, `ChatWebSocketHandler`)**:
  - Publishes and subscribes to Redis channel `wedo:chat:realtime` (`RedisEnvelope` deduplicated by `eventId`).
  - Ephemeral typing TTL keys `typing:{conversationId}:{userId}` (`5s` TTL) with `TYPING_START` / `TYPING_STOP` client frames and `TYPING_UPDATED` server broadcasts.
  - Multi-session presence set `presence:user:{userId}:sessions` (`120s` TTL): user stays online across multiple concurrent sockets until the last session closes, broadcasting `PRESENCE_UPDATED` to shared conversation peers and persisting `user_presence_snapshots.last_seen_at`.
  - Graceful local fallback when Redis is unreachable so REST Chat and single-node WebSocket delivery never fail.
- **Durable mutation boundary**: WebSocket accepts subscription, typing, heartbeat, and read-state commands only. Message send/edit/unsend/reaction mutations use M9 REST endpoints; unsupported WebSocket mutation commands return `VALIDATION_FAILED` without changing PostgreSQL state.

### Mobile (`mobile/lib/features/chat/...` & `main.dart`)
- **Files Implemented/Updated**:
  - `mobile/lib/features/chat/data/chat_realtime_event.dart` (`ChatRealtimeEvent`, `ChatRealtimeEventType`, `ChatRealtimeConnectionState`)
  - `mobile/lib/features/chat/data/chat_realtime_client.dart` (`ChatRealtimeClient`, `WebSocketChatRealtimeClient`, `NoopChatRealtimeClient`)
  - `mobile/lib/features/chat/data/chat_api.dart`, `chat_repository.dart`
  - `mobile/lib/features/chat/presentation/chat_formatters.dart`, `chat_home_screen.dart`, `chat_screen.dart`
  - `mobile/lib/main.dart`
- **Capabilities & Preserved M9 Pass 6 UX**:
  - Automatic WebSocket connection, `SUBSCRIBE`/`UNSUBSCRIBE` lifecycle, exponential-backoff reconnect, and silent reconnect history reconciliation.
  - `ChatRepository.defaultRealtimeClient` wired in `main.dart` so all navigation routes (`MyGroupsScreen`, `GroupInfoScreen`, `ChatHomeScreen`) share the live `WebSocketChatRealtimeClient` instance, and `SUBSCRIBED` initial `onlineUserIds` snapshot excludes `viewerUserId` so `"Đang hoạt động"` reflects other active participants.
  - Deduplicated live updates for `MESSAGE_CREATED`, `MESSAGE_EDITED`, `MESSAGE_UNSENT`, `MESSAGE_REACTION_UPDATED`, `READ_STATE_UPDATED` (moving reader mini-avatars in real time), `TYPING_UPDATED` (`"<Name> đang nhập..."` with 6s timeout), and `PRESENCE_UPDATED` (`"Đang hoạt động"` header badge and Chat Home green dot).
  - Preserves all M9 Pass 6 UX rules (no per-bubble default timestamp, `>= 30m` & date-boundary centered time separators breaking author runs, single-tap 2s exact timestamp reveal, long-press quick reactions & actions sheet).

---

## 3. Historical M10 Test, Static Analysis & Two-Account Samsung Realtime Acceptance

- **Backend Focused Chat + Realtime Suite** (`.\mvnw.cmd -Dtest="ChatRealtimeIntegrationTest,ChatControllerTest,ChatServiceIntegrationTest" test`):
  - **16 tests run, 0 failures, 0 errors, 0 skipped**
- **Backend Full Suite** (`.\mvnw.cmd test`):
  - **529 tests run, 0 failures, 0 errors, 1 skipped**
- **Mobile Static Analysis** (`flutter analyze`):
  - **Clean (`No issues found!`)**
- **Mobile Full Test Suite** (`flutter test --reporter compact`):
  - **626 passed, 0 failures**
- **Two-Account Samsung Physical Device Realtime Acceptance (`R58M36JQYVY`)**:
  - **PASSED END-TO-END WITHOUT MANUAL REFRESH**:
    - **Samsung client (`R58M36JQYVY`)**: `member1@wedo.local` (`QA Member 1`) viewing `weDO QA Team` (`groupId: 3ba858f7-858f-40db-a5d1-444fd6f88c36`, `conversationId: f2af179e-4627-4fa7-8972-5665c153bc36`).
    - **Local realtime harness client**: `member2@wedo.local` (`QA Member 2`) and `outsider@wedo.local` over `/ws` + M9 REST mutation endpoints.
    - Verified live `MESSAGE_CREATED` (both directions + duplicate suppression), live `TYPING_START` (`"QA Member 2 đang nhập..."`), live `TYPING_STOP`, typing TTL auto-expiry, live `MESSAGE_REACTION_UPDATED` (`❤️ 1` -> `👍 1` + `"Biểu cảm"` reaction details bottom sheet), live `READ_STATE_UPDATED` (`QM` reader mini-avatar movement), live `MESSAGE_EDITED` (`"Chào trực tiếp M10 (đã chỉnh sửa)"`), live `MESSAGE_UNSENT` (`"Tin nhắn đã được thu hồi"`), multi-session `PRESENCE_UPDATED` (`"● Đang hoạt động"` remains online with 2 sessions -> 1 session, goes offline on 0 sessions), reconnect/resubscribe with gap message delivery, and `outsider@wedo.local` security negative checks (`ERROR:ACCESS_DENIED` / `ERROR:GROUP_NOT_FOUND`).

---

## 4. Current M11 Handoff

- M11 implements Expense create/list/detail/edit/cancel and derived group/pair balances using existing V7 finance tables. No migration was added; M12 settlement actions and M13 fund remain deferred. Receipt upload is not implemented.
- Backend service integration covers deterministic equal/custom splits, audit history, settlement reservations, archived read-only permission projections, member/outsider authorization, multi-account visibility, inverse pair balances, maximum monetary JSON precision, and concurrent edit/cancel consistency.
- Flutter provides a group-specific Expense list, create/edit/detail/cancel and balance views. Amount handling uses integer minor units and decimal strings in both directions. Edit retains custom shares and the activity reference; edit and cancel controls independently consume server flags. Dates render in local time, audit states are Vietnamese, and reference IDs are not displayed.
- Samsung `R58M36JQYVY` acceptance completed using the local QA group: created 50.00, edited to 60.00 with two 30.00 shares, observed the caller's owed balance increase to 30.00, then cancelled and observed it return to 0.00.
- A cancel/reload `setState` Future-return crash was found and fixed, covered by a widget test and a successful fresh 5.00 create/cancel device check. Final corrected APK was rebuilt, installed and launched on Samsung; local time, translated cancellation history and zero balance were rechecked visually. No Flutter runtime exception appeared in the final app process logs.
- The original backend on port 8080 was pre-M11 and was not stopped or changed by this M11 continuation. Current M11 source ran on temporary port 8081 for device checks. The temporary M11 backend and debug sessions are now stopped. Final APK uses `http://127.0.0.1:8080`; the temporary device `tcp:8080 -> host tcp:8081` mapping was restored to `tcp:8080 -> tcp:8080`. Local cancelled QA expense rows remain as audit history.
- Preserve local-only docs and `.stitch/**`; preserve `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. Do not stage, commit, or push without separate authorization.

### Latest Verification (2026-09-28)

| Gate | Authoritative result |
| --- | --- |
| Backend compile `mvnw.cmd -DskipTests compile` | `BUILD SUCCESS` |
| Focused backend `ChatRealtimeIntegrationTest,ExpenseServiceIntegrationTest` | 18 run, 0 failures, 0 errors, 0 skipped (`BUILD SUCCESS`) |
| Full backend `mvnw.cmd test` | 542 run, 0 failures, 0 errors, 1 skipped (`BUILD SUCCESS`) |
| Focused Flutter Expense tests | 15 passed, 0 failed |
| `flutter analyze` | No issues found |
| Complete `flutter test --reporter compact` | 641 passed, 0 failed; command exited successfully |
| Debug APK with standard 8080 define | Successful; `mobile/build/app/outputs/flutter-apk/app-debug.apk`, 201414780 bytes |
| Samsung | Create/edit/cancel/balance reversal passed; final local-time/history fixes verified on installed APK |
| Migration audit | V0 bootstrap and V1-V12 retained unchanged; no new migration |
| Debug/temp audit | No temporary paths, QA credentials, debug prints, TODO/FIXME in new M11 production files |

### Realtime Package Recovery & Blocker Resolution

- The stale/conflicting working-tree modification in `backend/src/main/java/com/wedo/backend/chat/realtime/ChatRealtimeCoordinator.java` (from an earlier pre-review M10 replay that added WebSocket `SEND_MESSAGE`/`EDIT_MESSAGE`/`UNSEND_MESSAGE`/`SET_REACTION` handlers) was restored to committed M10 `HEAD` (`3c0b151aaaa2d5838ceb354778df43488e164c76`).
- All 6 production files under `backend/src/main/java/com/wedo/backend/chat/realtime/` and `backend/src/test/java/com/wedo/backend/chat/ChatRealtimeIntegrationTest.java` now match `HEAD` with zero working-tree diffs and zero empty/truncated files.
- `ChatRealtimeIntegrationTest.durableMessageMutationsAreRejectedOverWebSocket`, the focused `ChatRealtimeIntegrationTest,ExpenseServiceIntegrationTest` suite (`18/18`), and the full backend suite (`542` run, `0` failures, `0` errors, `1` skipped) all pass. No blocker remains for M11 closeout.

### Exact M11 Include Candidates (Not Staged)

Backend production:
- `backend/src/main/java/com/wedo/backend/common/error/ErrorCode.java`
- `backend/src/main/java/com/wedo/backend/expense/controller/ExpenseController.java`
- `backend/src/main/java/com/wedo/backend/expense/dto/ExpenseDtos.java`
- `backend/src/main/java/com/wedo/backend/expense/service/ExpenseService.java`

Backend tests:
- `backend/src/test/java/com/wedo/backend/expense/ExpenseServiceIntegrationTest.java`

Flutter production:
- `mobile/lib/app/routes.dart`
- `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
- `mobile/lib/features/expense/application/expense_controllers.dart`
- `mobile/lib/features/expense/data/expense_api.dart`
- `mobile/lib/features/expense/data/expense_failure.dart`
- `mobile/lib/features/expense/data/expense_models.dart`
- `mobile/lib/features/expense/data/expense_repository.dart`
- `mobile/lib/features/expense/presentation/expense_screens.dart`

Flutter tests:
- `mobile/test/app/routes_test.dart`
- `mobile/test/features/expense/data/expense_models_test.dart`
- `mobile/test/features/expense/presentation/expense_detail_screen_test.dart`

Canonical docs/handoff:
- `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md`
- `docs/ERD_DATABASE_DESIGN_v1.0.md`
- `docs/architecture/CLASS_DIAGRAM.puml`
- `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`
- `docs/LOCAL_DEVELOPMENT.md`
- `docs/AGENT_CURRENT_HANDOFF.md`
- `docs/AGENT_DECISION_LOG.md`

## 5. Current M12 Handoff (`feat/m12-settlement`)

### Implementation Summary
- **Database Schema (`V7__finance.sql` — No New Migration)**:
  - Uses existing `settlements` and `settlement_status_history` tables (`V7__finance.sql`). No authoritative `debts` table and no M13 Group Fund tables are modified.
- **Backend (`ExpenseController`, `ExpenseService`, `ExpenseDtos`, `ErrorCode`, `SettlementServiceIntegrationTest`)**:
  - Endpoints:
    - `POST /api/v1/groups/{groupId}/settlements`
    - `GET /api/v1/groups/{groupId}/settlements`
    - `GET /api/v1/settlements/{settlementId}`
    - `POST /api/v1/settlements/{settlementId}/confirm`
    - `POST /api/v1/settlements/{settlementId}/reject`
    - `POST /api/v1/settlements/{settlementId}/cancel`
  - Enforces `SET-01`..`SET-05`: direction derivation (`I_PAID` vs `I_RECEIVED`), active debt validation (`NO_OUTSTANDING_DEBT`, `SETTLEMENT_AMOUNT_EXCEEDS_DEBT`), pending debt reservation (`ledger.pending`), counterparty-only confirmation/rejection (`SETTLEMENT_CONFIRMATION_NOT_ALLOWED`), creator-only cancellation while `PENDING`, `SETTLEMENT_ALREADY_RESOLVED` protection under `FOR UPDATE` locking, archived group read-only projection, and `settlement_status_history` logging.
- **Mobile (`expense_models.dart`, `expense_failure.dart`, `expense_api.dart`, `expense_repository.dart`, `expense_controllers.dart`, `expense_screens.dart`, `routes.dart`, `group_info_screen.dart`)**:
  - `ExpenseBalanceScreen` (`Số dư nhóm` / `AppRoutes.groupSettlements = '/groups/settlements'`) displays member balances with `Thanh toán` (`YOU_OWE` -> `I_PAID`) and `Đã nhận tiền` (`OWES_YOU` -> `I_RECEIVED`) actions, prefilled settlement dialog supporting partial or full repayment, and `Lịch sử thanh toán` with server-projected `Xác nhận` / `Từ chối` / `Hủy yêu cầu` actions.
  - `SettlementDetailScreen` (`Chi tiết thanh toán`) displays full settlement attributes, localized status badges, action buttons, and `Lịch sử trạng thái` (`statusHistory`) in local time.
  - `GroupInfoScreen` adds `Thanh toán công nợ` navigation directly to `AppRoutes.groupSettlements`.

### Latest Verification (2026-09-28)

| Gate | Authoritative result |
| --- | --- |
| Focused backend `ExpenseServiceIntegrationTest,SettlementServiceIntegrationTest` | 17 run, 0 failures, 0 errors, 0 skipped (`BUILD SUCCESS`) |
| Full backend `mvnw.cmd test` | 546 run, 0 failures, 0 errors, 1 skipped (`BUILD SUCCESS`) |
| `flutter analyze` | No issues found |
| Complete `flutter test --reporter compact` | 642 passed, 0 failed |
| Debug APK (`WEDO_API_BASE_URL=http://127.0.0.1:8080`) | Built & installed (`mobile/build/app/outputs/flutter-apk/app-debug.apk`) |
| Samsung `R58M36JQYVY` Physical-Device E2E & Multi-Account QA | Verified `owner@wedo.local`, `member1@wedo.local`, `outsider@wedo.local`: initial 150,000.00 debt -> 60,000.00 `PENDING` (balance remains 150,000.00) -> 100,000.00 overpayment rejected (`SETTLEMENT_AMOUNT_EXCEEDS_DEBT`) -> outsider rejected (`404 GROUP_NOT_FOUND`) -> 60,000.00 confirmed (`COMPLETED`, remaining debt 90,000.00) -> 90,000.00 `I_RECEIVED` confirmed (`COMPLETED`, remaining debt 0.00) -> Samsung UI live confirmation of 20,000.00 (`50.000 ₫` -> `30.000 ₫`) & `SettlementDetailScreen` status history verified |
| Migration audit | V0..V12 unchanged; no new migration |

### Exact M12 Include Candidates (Not Staged)
- Backend production:
  - `backend/src/main/java/com/wedo/backend/common/error/ErrorCode.java`
  - `backend/src/main/java/com/wedo/backend/expense/controller/ExpenseController.java`
  - `backend/src/main/java/com/wedo/backend/expense/dto/ExpenseDtos.java`
  - `backend/src/main/java/com/wedo/backend/expense/service/ExpenseService.java`
- Backend tests:
  - `backend/src/test/java/com/wedo/backend/expense/SettlementServiceIntegrationTest.java`
- Flutter production:
  - `mobile/lib/app/routes.dart`
  - `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
  - `mobile/lib/features/expense/application/expense_controllers.dart`
  - `mobile/lib/features/expense/data/expense_api.dart`
  - `mobile/lib/features/expense/data/expense_failure.dart`
  - `mobile/lib/features/expense/data/expense_models.dart`
  - `mobile/lib/features/expense/data/expense_repository.dart`
  - `mobile/lib/features/expense/presentation/expense_screens.dart`
- Flutter tests:
  - `mobile/test/app/routes_test.dart`
  - `mobile/test/features/expense/data/expense_models_test.dart`
  - `mobile/test/features/expense/presentation/expense_detail_screen_test.dart`
- Canonical docs/handoff:
  - `docs/AGENT_PROJECT_CONTEXT.md`
  - `docs/AGENT_CURRENT_HANDOFF.md`
  - `docs/AGENT_DECISION_LOG.md`
  - `docs/architecture/CLASS_DIAGRAM.puml`

## 6. Current M13 Handoff (`feat/m13-group-fund`)

### Implementation Summary
- **Database Schema (`V8__fund.sql` — No New Migration)**:
  - Reuses all 9 existing `V8__fund.sql` tables (`group_funds`, `fund_managers`, `fund_collections`, `fund_collection_obligations`, `fund_contributions`, `fund_expenses`, `fund_reimbursements`, `fund_transactions`, `fund_transaction_reversals`). No Flyway migration (`V0`..`V12`) was edited and no `V13+` migration was added.
  - Strictly separated from M11/M12 pairwise `expenses` / `settlements` (`V7__finance.sql`).
- **Backend (`com.wedo.backend.fund.*`, `ErrorCode`, `FundServiceIntegrationTest`)**:
  - Dedicated domain boundary (`FundController`, `FundService`, `FundDtos`) implementing `FUND-01`..`FUND-17` and all 18 M13 `ErrorCode` constants.
  - Enforces single fund per group (`VND`), `OWNER` implicit fund governance + up to 2 assigned active `ADMIN` `Fund Manager` rows (`fund_managers`), automatic stale `Fund Manager` cleanup on `GroupMembershipEndedEvent` and admin demotion, derived obligation statuses (`UNPAID`, `PARTIAL`, `PAID`, `OVERDUE`), derived `ledgerBalance = sum(IN) - sum(OUT)` and `availableBalance = ledgerBalance - pendingReimbursements`, `FOR UPDATE` row-level locking across all balance/contribution/reimbursement/reversal/close mutations, immutable compensating `REVERSAL` entries (`fund_transaction_reversals`), and fund close preconditions (`ledgerBalance == 0`, `0` open collections, `0` pending contributions, `0` pending reimbursements).
  - M13 hardening serializes collection close/cancel and contribution transitions on the parent fund before child rows to avoid lock-order inversion; rejects amounts with meaningful precision beyond the schema's 2 decimal places rather than silently rounding.
- **Mobile (`mobile/lib/features/fund/*`, `routes.dart`, `group_info_screen.dart`)**:
  - Dedicated Flutter feature boundary (`fund_failure.dart`, `fund_models.dart`, `fund_api.dart`, `fund_repository.dart`, `fund_controllers.dart`, `fund_screens.dart`) registered at `AppRoutes.groupFund = '/groups/fund'` (`FundRouteArgs`) and wired from `GroupInfoScreen` (`'Quỹ nhóm'`).
  - Renders 4 localized Vietnamese tabs (`Tổng quan`, `Đợt thu`, `Chi quỹ & Hoàn tiền`, `Sổ giao dịch`) driven strictly by server-projected permission flags (`canCreateFund`, `canManageFund`, `canManageManagers`, `canContribute`, `canRequestReimbursement`, `canCloseFund`, `canReverse`, `readOnly`).

### Latest Verification (2026-09-28)

| Gate | Authoritative result |
| --- | --- |
| Focused backend `FundServiceIntegrationTest,ExpenseServiceIntegrationTest,SettlementServiceIntegrationTest` | 29 run, 0 failures, 0 errors, 0 skipped (`BUILD SUCCESS`; Testcontainers PostgreSQL started) |
| Full backend `mvnw.cmd test` | 558 run, 0 failures, 0 errors, 1 skipped (`BUILD SUCCESS`) |
| `flutter analyze` | No issues found |
| Focused Flutter `fund_screen_test.dart` + `routes_test.dart` | 59 passed, 0 failed |
| Complete `flutter test --reporter compact` | 645 passed, 0 failed |
| Debug APK (`WEDO_API_BASE_URL=http://127.0.0.1:8080`) | Built & installed (`mobile/build/app/outputs/flutter-apk/app-debug.apk`) |
| Samsung `R58M36JQYVY` Physical-Device E2E & Multi-Account QA | Real Flutter UI verified owner-created collection, member contribution submission, delegated Admin confirmation, direct expense, member reimbursement request, Admin approval, transaction reversal, and insufficient-available-balance rejection. Ledger returned to 80,000 VND after reversal; insufficient-funds UI error shown; `0` `FATAL EXCEPTION` in device logcat. The fund and delegated manager were already present in seed data; no REST calls were used for the claimed flows. |
| Migration audit | V0..V12 unchanged; no new migration |

### Exact M13 Include Candidates (Not Staged)
- Backend production:
  - `backend/src/main/java/com/wedo/backend/common/error/ErrorCode.java`
  - `backend/src/main/java/com/wedo/backend/fund/controller/FundController.java`
  - `backend/src/main/java/com/wedo/backend/fund/dto/FundDtos.java`
  - `backend/src/main/java/com/wedo/backend/fund/service/FundService.java`
- Backend tests:
  - `backend/src/test/java/com/wedo/backend/fund/FundServiceIntegrationTest.java`
- Flutter production:
  - `mobile/lib/app/routes.dart`
  - `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
  - `mobile/lib/features/expense/data/expense_api.dart`
  - `mobile/lib/features/fund/application/fund_controllers.dart`
  - `mobile/lib/features/fund/data/fund_api.dart`
  - `mobile/lib/features/fund/data/fund_failure.dart`
  - `mobile/lib/features/fund/data/fund_models.dart`
  - `mobile/lib/features/fund/data/fund_repository.dart`
  - `mobile/lib/features/fund/presentation/fund_screens.dart`
- Flutter tests:
  - `mobile/test/app/routes_test.dart`
  - `mobile/test/features/fund/fund_screen_test.dart`
- Canonical docs/handoff:
  - `docs/AGENT_PROJECT_CONTEXT.md`
  - `docs/AGENT_CURRENT_HANDOFF.md`
  - `docs/AGENT_DECISION_LOG.md`
  - `docs/architecture/CLASS_DIAGRAM.puml`

---

## 7. Current M14 Handoff (`feat/m14-notification-fcm`)

### Implementation Summary
- **Database Schema (`V1__identity_and_auth.sql`, `V9__notifications.sql`, `V10__cross_module_indexes.sql` — No New Migration)**:
  - Reuses existing `user_devices` (`V1`), `notifications`, `user_notification_settings`, `group_notification_settings` (`V9`), and `uq_user_devices_active_push_token` (`V10`). Zero Flyway migrations (`V0`..`V12`) were modified and no `V13+` migration was added.
- **Backend (`com.wedo.backend.notification.*`, `ChatRealtimeCoordinator`, domain event emitters)**:
  - Implemented `NotificationController`, `NotificationService`, `NotificationDtos`, `NotificationDomainEvent`, `NotificationDomainEventListener`, `PushGateway`, and `FcmPushGateway` covering `NOTI-01`..`NOTI-06` and `/api/v1/me/devices` (`GET`, `POST`, `DELETE /{deviceId}`).
  - Notification persistence is `AFTER_COMMIT` and `REQUIRES_NEW`; per-recipient duplicate checks serialize with a PostgreSQL transaction advisory lock. Push dispatch happens after the persistence transaction. A post-commit database failure is isolated from business state but can lose that notification because there is no durable outbox.
  - In-app inbox persistence is independent of push policy. User global/category settings suppress push only; group mute suppresses noncritical push only. Only waitlist promotion, settlement confirmation, fund contribution confirmation, and fund reimbursement approval are marked critical; join-request approval is not a critical bypass.
  - `ChatRealtimeCoordinator.isUserSubscribedToConversation` checks an open local socket and active conversation subscription; unsubscribe/disconnect remove local state. Subscription state is not shared across backend instances, so open-chat suppression is best-effort in a multi-instance deployment.
  - `FcmPushGateway` sends via Firebase Admin `FirebaseMessaging` using ADC, maps invalid/transient/provider failures, and returns provider acceptance only after Firebase returns a message ID. Device token values are not logged. `NotificationService` retains `AFTER_COMMIT` + `REQUIRES_NEW` isolation and PostgreSQL advisory-lock duplicate prevention.
  - Flutter uses `firebase_core`/`firebase_messaging`, Google Services Gradle integration, Android notification permission, stable secure device IDs, initial/token-refresh registration, logout deactivation, and foreground/background/opened/cold-start handlers. The untracked local `mobile/android/app/google-services.json` must remain excluded.
- **Mobile (`mobile/lib/features/notification/*`, `routes.dart`, `my_groups_screen.dart`, `group_info_screen.dart`)**:
  - Dedicated Flutter module (`notification_failure.dart`, `notification_models.dart`, `notification_api.dart`, `notification_repository.dart`, `notification_controllers.dart`, `notification_screens.dart`) registered at `AppRoutes.notifications = '/notifications'` and `AppRoutes.notificationSettings = '/notifications/settings'`.
  - Wired `"Thông báo"` header action in `MyGroupsScreen` and `"Tắt thông báo nhóm"` bottom sheet (`1 giờ`, `8 giờ`, `1 ngày`, `Cho đến khi bật lại`) in `GroupInfoScreen`.

### Latest Verification (2026-09-29)

| Gate | Authoritative result |
| --- | --- |
| Focused backend notification/producer suites (`M8MultiAccountIntegrationTest`, `ExpenseServiceIntegrationTest`) | 18 run, 0 failures, 0 errors, 0 skipped |
| Full backend `mvnw.cmd test` | 573 run, 1 failure, 0 errors, 1 skipped; sole failure is `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` at line 594; exact test also fails at base commit `a34de335cefa283b218bf80f5e421ccff58b96b3` |
| `flutter analyze` | No issues found |
| Focused Flutter notification push/API/router tests | 21 passed, 0 failed |
| Complete `flutter test --reporter compact` | 666 passed, 0 failed |
| Debug APK (`WEDO_API_BASE_URL=http://127.0.0.1:8080`) | Fresh debug build succeeded at `mobile/build/app/outputs/flutter-apk/app-debug.apk`; installed on Samsung `R58M36JQYVY` |
| Samsung `R58M36JQYVY` E2E | Fresh Chat push+system tap opened the exact group conversation and marked read; active-conversation realtime message appeared without a redundant card, then away-message push returned. Activity push+tap opened its matching detail. Poll and Task push+taps opened their parent Activity detail and marked rows read. Finance Expense push+tapped to Expense detail. Fund collection push+tapped to Group Fund. Read/unread count updated. Global-off and Poll-off were toggled in Flutter UI; inbox persisted and server dispatch decisions were `SUPPRESSED_USER_PUSH_DISABLED` / `SUPPRESSED_CATEGORY_DISABLED`. Group mute was selected in Flutter UI; a fresh Poll persisted with `SUPPRESSED_GROUP_MUTED` and no matching Android card. While muted, critical Fund contribution-confirmed was `GATEWAY_ACCEPTED` and appeared on the Samsung. Preferences and group mute were restored. Open-chat foreground behavior verified. Cold-start tap not verified. |
| Provider evidence | Real Firebase sends persisted `GATEWAY_ACCEPTED`; stale active fake-prefix QA device rows were deactivated, and no active fake-prefix rows remain |
| Device logcat | Final bounded logcat scan: 0 `FATAL EXCEPTION`; 14 AndroidRuntime lines, 0 FirebaseMessaging lines, 0 FirebaseApp lines in the last 3000 lines. No credential or token contents printed. Stay-awake was disabled and DND restored to Priority (`zen_mode=1`). |
| Migration/security audits | V0..V12 unchanged; no V13. Secret-pattern scan had no matches in code/source; external Firebase Admin JSON was never opened. Google Services JSON remains untracked/unstaged. One active real device registration; no fake-prefix active token. |

### M14 Environment Recheck (2026-09-29)
- `GOOGLE_APPLICATION_CREDENTIALS` resolved to the requested external path and `Test-Path` was true; the credential file was never opened, copied, logged, or staged.
- Docker Desktop 4.86.0 / Engine 29.7.2 and Testcontainers PostgreSQL work with elevated access; ordinary sandbox access to the Docker named pipe is denied.
- Device token values and Firebase Admin credential contents were never written to logs or reports. Two stale fake-prefix local QA device records were removed; the real Samsung token is active.

### M14 Closeout and M15 Transition (Historical Notes)
- Full backend suite has one failing Fund JSON decimal-string assertion (`FundServiceIntegrationTest.java:594`); the exact test also fails at clean base `a34de335cefa283b218bf80f5e421ccff58b96b3`, so it is pre-existing. Do not fold an unrelated Fund behavior change into M14 without review.
- Notification coverage audit added Activity confirmed schedule/location change notices to GOING/MAYBE participants, Poll create/close notices, and Task assignment/status-change notices. Focused integration tests prove exact recipients/categories/targets; Flutter route tests cover supported target types. Existing policy producers remain for Group invitation/join approval, Chat message, Activity creation/waitlist promotion, Expense/Settlement, and Fund. Social/Discussion do not have canonical notification producers.
- Live warm/background acceptance now covers Chat, Activity, Poll, Task, Finance, and Fund notification routes/taps; mark-read behavior and unread count; global/category suppression; Flutter UI group mute; critical Fund bypass while muted; and open-chat suppression versus away-chat push. Cold-start/terminated tap was not verified; no product defect remains from the current required scenarios.
- `FundDtos.java` has no normalized content diff; `git ls-files --eol` reports mixed working-tree line endings, leaving a status-only modified marker. No content was restored or staged.
- Verification retained: backend focused 18 passed; full backend 573 run, 1 confirmed clean-base Fund serialization failure, 0 errors, 1 skipped; Flutter focused 32 passed; analyze clean; full Flutter 667 passed; fresh debug APK built and installed. The only known suite failure is baseline and is not an M14 blocker.
- M14 is closed. Feature commit `d4fc8571959d92e17b139be936669f64c459b6d8` was merged to and pushed on `dev` as `5e288f0098543d486ee1c2010a8f8f7b765d8ff1`.
- M14 acceptance baseline includes inbox/read/unread, Firebase Admin sends, Samsung token lifecycle, Chat/Activity/Poll/Task/Finance/Fund producers, push taps/deep links, global/category suppression, group mute, critical bypass, open-chat suppression, and warm/background Samsung E2E. Cold-start push tap remains unverified. The one full-backend Fund JSON decimal assertion is confirmed on clean base and remains nonblocking.
- The M15 intake notes and plan below are superseded by the current M15 Phase C snapshot at the top of this file. The reminder delivery contract is recorded in `DEC-M15-01` and scheduler/idempotency semantics in `DEC-M15-03`; the live acceptance record is `M15-VER-01` in the decision log.
- Preserve/exclude `mobile/android/app/google-services.json`, both local-only docs, `.stitch/`, `.dev-runtime/`, `.dev-logs/`, and the protected stash.
