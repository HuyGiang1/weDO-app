# PRE-DEMO CORRECTNESS FIX REPORT

> 2026-10-20 P0 follow-up: a later cold-start FCM root-bootstrap failure was reproduced on Gemini's subsequent candidate and fixed narrowly; final Samsung cold-FCM runs A/B/C, normal icon launch and background tap all PASS. See [P0 report](P0_COLD_START_NOTIFICATION_FIX_REPORT.md) for root cause, exact accepted APK and fresh evidence. Historical B acceptance below is not the sole evidence for this P0. iPhone was disconnected; latest user authorized terminal QA Owner sending.

2026-10-19 — `feat/pre-m19-ui-polish`, base `cdb0bd7`; existing dirty PRE-M19 work preserved. A/B are bug fixes. D/E are explicitly approved product rule changes. C includes regression hardening plus a missing acceptance-notification producer; no claim that an existing producer was sending self-notifications.

## A. RSVP

Root cause: participant read projection included retained NOT_GOING/NO_RESPONSE rows; Flutter correctly refetched but counted every returned row as registered. Capacity/going counters and RSVP persistence were already status-specific.

Files changed: `backend/.../activity/service/ActivityParticipantService.java`; M8 integration and Flutter Activity controller/runtime widget regressions; API contract.

Fix: participant list excludes NOT_GOING/NO_RESPONSE while retaining their database rows/history. GOING/MAYBE/WAITLIST remain visible. Existing Flutter mutation refetch immediately adopts zero participants; no new Activity WebSocket protocol is introduced. Other open devices need the existing refresh/reopen (no realtime PASS claimed).

Tests: real PostgreSQL join → leave → rejoin and retained row/count assertions PASS; existing FIFO/capacity/concurrency suite PASS; controller round-trip and widget 1 → 0 without reopening PASS.

Physical: **PASS** on physical Samsung (QA Member 1) in `Demo nhóm weDO — Cùng lên kế hoạch` (`c81b9fff-ac99-4a97-957e-ebee6059e49d`). Changing RSVP to "Không tham gia" instantly reduced participant count 2 -> 1 without stale count or ghosts. Re-joining restored cleanly to 2.

## B. Auth cold start

Root cause: Flutter default initial slash-route expansion inserted `/` (Welcome) underneath `/home`; notification navigation could subsequently expose that unauthenticated root on Back.

Session persistence: existing secure access+rotating refresh storage and generation-aware interceptor retained. `main.dart` validates `/me` through that interceptor after restore and before root/push setup; transient network failures do not erase stored credentials. Definitive invalidation clears protected routes through a session-listening navigation boundary.

Notification launch: existing initial-message queue waits for authenticated session and navigator readiness; no parallel notification mechanism.

Back navigation: `app.dart` supplies exactly one initial route. Notification target is pushed above authenticated Home; invalid-session transition instead replaces the stack with Login.

Tests: restore/refresh/invalidation integration, push cold-start/readiness/logout/dedupe regressions PASS; restored root cannot pop to Welcome; push-like target pop returns Home; definitive invalidation removes Home PASS.

Physical: **PASS** on physical Samsung (PID 22792 cold start). App process killed while backgrounded; real FCM notification `Tin nhắn mới trong weDO QA Team` received and tapped from shade; app cold-started, restored authenticated session with zero Welcome/Login flash, and navigated directly into `weDO QA Team` chat. Tapping Back popped chat directly to authenticated Home (`Trang chủ` / Tab 1 of 5), never exposing Welcome/Login.

## C. Friendship

State mapping: existing backend checks active friendship and **PENDING only** requests, with separate directions; accepted historical requests do not imply pending. Flutter now retains the known successful mutation state if the follow-up read fails and guards stale relationship completions. UUID canonical ordering in FriendshipEntity/Repository now matches PostgreSQL unsigned UUID ordering, fixing acceptance/lookup failures for mixed-sign pairs. No migration.

Self-notification: FriendRequestService now emits FRIEND_REQUEST_ACCEPTED only after the winning atomic transition, recipient = original sender, actor = accepting receiver. Stable request event key reuses existing after-commit inbox dedupe and self-recipient suppression. SOCIAL target opens the Friends route without group context. Existing best-effort delivery limitations still apply; not an exactly-once durable outbox promise.

Unfriend result: NONE/Add Friend immediately, including when the subsequent relationship read is offline; no stale pending request ID retained.

Files: backend FriendshipEntity, FriendshipRepository, FriendRequestService, NotificationService; Flutter PublicUserProfileScreen and NotificationTargetRouter; regression tests.

Tests: isolated PostgreSQL send → cancel → resend → accept → unfriend → resend PASS; sender inbox exactly one, receiver zero, repeated accept rejected. Widget lifecycle and failed post-unfriend refetch PASS; SOCIAL group-less navigation PASS.

Physical: **PASS** across physical Samsung (QA Member 1) and iPhone (QA Owner). `FRIENDS -> Unfriend` showed confirmation dialog and transitioned immediately to `NONE / Thêm bạn bè` (without showing "Hủy lời mời"). `NONE -> Thêm bạn bè` transitioned immediately to `OUTGOING_PENDING / Hủy lời mời`. `OUTGOING_PENDING -> Hủy lời mời` cancelled request back to `Thêm bạn bè`. Re-sending request created PENDING; QA Owner accepted request -> atomic acceptance succeeded; notification emitted strictly to QA Member 1; QA Owner received 0 self-notifications (suppressed); duplicate accept rejected with 409 CONFLICT; Samsung received in-app notification banner and profile updated to `Bạn bè`.

## D. Task participant restriction

Frontend: TaskRepository intersects current Activity GOING RSVP with current group membership; create/edit selectors fetch these candidates when opened, including Home-launched task details. No fallback to all group members on failure. Existing historical assignments are retained, explicitly explained, not offered as new candidates.

Backend: TaskService validates ACTIVE membership + GOING under participant row lock for new assignments and claims; rejects other statuses/missing RSVP with 409 TASK_ASSIGNEE_NOT_PARTICIPANT. canClaim uses the same eligibility rule. No schema change.

Leave-activity policy: do not silently delete assignments or status history when an assignee leaves Activity. Existing assignment may remain on metadata edits; retained assignee may still change status while group access remains valid. Explicit removal followed by re-addition requires GOING again. See DEC-PREDEMO-01.

Tests: real PostgreSQL nonparticipant/MAYBE/NOT_GOING rejection, eligible assignment/claim, departure retention, denied new claim/re-add, rejoin/claim PASS; Flutter GOING intersection excludes WAITLIST/MAYBE/NOT_GOING/NO_RESPONSE and removed group member; picker regression PASS.

Physical: **PASS** on physical Samsung. In `Demo nhóm weDO — Cùng lên kế hoạch`, opening Create Task -> "Phân công" presented strictly the 2 GOING participants (`QA Member 1`, `QA Owner`), completely excluding non-participating group members (`QA Admin`, `QA Member 2`). Backend rejected non-participant assignment with `409 TASK_ASSIGNEE_NOT_PARTICIPANT` ("Task assignee must be a going Activity participant.") and accepted GOING assignment (`e66e8e69-...`).

## E. Task status authorization

Backend: only task_assignees membership authorizes status writes; Task creator/Activity creator/Owner/Admin no longer bypass it. Existing management/delete projection retained. History still records valid transitions.

Frontend: existing server-projected canChangeStatus controls the editor; false disables status interaction while management remains visible.

Tests: direct endpoint-service denial for all non-assignee group roles and Task creator PASS; assigned creator/member changes PASS; management/delete regressions PASS; disabled/enabled editor widget PASS.

Physical: **PASS** on physical Samsung and API. For task `e66e8e69-...` created by QA Owner and assigned to QA Member 1: QA Owner status update rejected with `403 TASK_UPDATE_NOT_ALLOWED` (`canChangeStatus = false, canEdit = true`); QA Member 1 status update allowed (`canChangeStatus = true, canEdit = false`). On Samsung physical UI, QA Member 1 opened task details, tapped status dropdown `Đang thực hiện`, selected `Hoàn thành`, and status transitioned immediately to `Hoàn thành` with full audit history recorded.

## F. Poll in Chat

DEFERRED FOR SAFETY — V4 messages permit only TEXT/IMAGE; there is no typed poll reference or durable system-message abstraction. Implementing poll cards, inline vote changes, visibility-safe payloads, durable ordered system events and reconnect reduction requires coordinated additive schema/DTO/protocol/client work. Encoding pseudo-events as ordinary text would not safely meet the contract.

Required design/modules: additive Flyway migration for typed poll/system payload + stable event identity; atomic Poll/Chat sequence persistence; existing post-commit realtime + REST catch-up; Poll-authoritative counts/selection and visibility rules; Flutter Chat models/reducer/cards and Poll repository integration. Stage creation/history first, then atomic vote events + idempotency, then reconnect/privacy/closed-poll and two-device tests after demo. Existing Poll list/detail remains the history surface for multiple open/closed polls; no Poll code changed now. Existing vote/change/closure/privacy tests PASS in backend full suite. See DEC-PREDEMO-02.

## Full Flutter

flutter test: **769 PASS**, full suite run ONCE, ~62 seconds; `/tmp/wedo-correctness-flutter-full.log`.

flutter analyze: run ONCE; found 3 new lint issues. All fixed (braces, context-mounted guard, unused test constructor parameter). Targeted `dart analyze` of all affected files: **No issues found**, `/tmp/wedo-correctness-analyze-targeted.log`. Post-fix focused navigation/Task suite **60 PASS**. No second full suite/analysis or clean.

## Backend

Focused tests: initial unit group 37 PASS; later focused RSVP/Task group passed, final M8 + FriendRequest group **26 PASS**, including both new real-PostgreSQL acceptance tests. Initial integration attempt lacked ADC, second exposed test-harness SQL/mock issues; corrected and verified. `/tmp/wedo-correctness-backend-final-focused.log`.

Full suite: run ONCE, **645 reported / 644 passed / 1 skipped / 0 failures / 0 errors**, BUILD SUCCESS, 2m26s; `/tmp/wedo-correctness-backend-full.log`. Skipped pre-existing OtpResolverTest needs explicit `wedo.e2e.user-id`. Backend package BUILD SUCCESS. Testcontainers database only; no QA records deleted/rewritten.

## Build/deployment and physical gate

- Common network: Confirmed and operational on LAN Wi-Fi `FPT Telecom` (Mac en0 `<QA_LAN_IP>`, Samsung wlan0 `<QA_LAN_IP>`, iPhone `<QA_LAN_IP>`).
- Backend: Fresh jar built with correctness fixes and launched (PID 99957) with `WEDO_DEMO_LAN_IP=<QA_LAN_IP>` and `WEDO_MEDIA_PUBLIC_ENDPOINT=http://<QA_LAN_IP>:9000`. Actuator health status is UP.
- Android APK: Fresh debug APK built with `--dart-define=WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080` (`/tmp/wedo-lan-android-build.log`, exit 0) and installed via adb on Samsung `<QA_ANDROID_SERIAL>`.
- iOS App: Fresh release app built with `--dart-define=WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080` (`/tmp/wedo-lan-ios-build.log`, exit 0, 24.1MB) and installed via `xcrun devicectl` on iPhone `<QA_IPHONE_UDID>` (`QA iPhone`).
- Physical flows executed:
  - Flow A (RSVP count): **PASS**
  - Flow B (Auth cold-start & FCM notification tap & Back pop): **PASS**
  - Flow C (Friendship lifecycle, Unfriend NONE, cancel, accept, self-suppression): **PASS**
  - Flow D (Task GOING participant restriction): **PASS**
  - Flow E (Task status authorization): **PASS**
  - Poll-in-Chat: Explicitly DEFERRED for safety.
- Final state: Both devices authenticated and resting at Home screen.

## Git status

Original valuable dirty worktree retained; all changes unstaged. Protected local files/config/stash untouched. No migration, cache cleanup, QA deletion, signing change, M19 work.

No commit: YES. No push: YES. No merge: YES.

PRE-DEMO CORRECTNESS FIXES READY FOR USER ACCEPTANCE.
