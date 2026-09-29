# weDO — Agent Current Handoff (`docs/AGENT_CURRENT_HANDOFF.md`)

> **Live Handoff Document** — Update this file whenever milestone status, corrective passes, verification counts, or next actions change.

## 1. Current Git & Branch State

- **Active Branch**: `feat/m14-notification-fcm`
- **Base Commit (`dev`)**: `a34de335cefa283b218bf80f5e421ccff58b96b3` (M13 merged & closed)
- **Active Milestone**: **M14 — Notification + FCM** (`NOTI-01`..`NOTI-06` implemented; live Samsung warm/background acceptance for Chat, Activity, Poll, Task, Finance, Fund, global/category suppression, UI group mute, and critical bypass verified. Cold-start tap remains unverified. The full backend suite retains one Fund JSON assertion reproduced at clean base. Local commit is explicitly approved; no push is authorized.)
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

### Current M14 Blockers
- Full backend suite has one failing Fund JSON decimal-string assertion (`FundServiceIntegrationTest.java:594`); the exact test also fails at clean base `a34de335cefa283b218bf80f5e421ccff58b96b3`, so it is pre-existing. Do not fold an unrelated Fund behavior change into M14 without review.
- Notification coverage audit added Activity confirmed schedule/location change notices to GOING/MAYBE participants, Poll create/close notices, and Task assignment/status-change notices. Focused integration tests prove exact recipients/categories/targets; Flutter route tests cover supported target types. Existing policy producers remain for Group invitation/join approval, Chat message, Activity creation/waitlist promotion, Expense/Settlement, and Fund. Social/Discussion do not have canonical notification producers.
- Live warm/background acceptance now covers Chat, Activity, Poll, Task, Finance, and Fund notification routes/taps; mark-read behavior and unread count; global/category suppression; Flutter UI group mute; critical Fund bypass while muted; and open-chat suppression versus away-chat push. Cold-start/terminated tap was not verified; no product defect remains from the current required scenarios.
- `FundDtos.java` has no normalized content diff; `git ls-files --eol` reports mixed working-tree line endings, leaving a status-only modified marker. No content was restored or staged.
- Verification retained: backend focused 18 passed; full backend 573 run, 1 confirmed clean-base Fund serialization failure, 0 errors, 1 skipped; Flutter focused 32 passed; analyze clean; full Flutter 667 passed; fresh debug APK built and installed. The only known suite failure is baseline and is not an M14 blocker.
- M14 local commit is explicitly approved with the exact message in the commit request; verify the resulting commit in `git log`. No push is authorized. Preserve/exclude `mobile/android/app/google-services.json`, both local-only docs, `.stitch/`, `.dev-runtime/`, `.dev-logs/`, and the protected stash.
