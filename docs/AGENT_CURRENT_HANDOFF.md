# weDO — Agent Current Handoff (`docs/AGENT_CURRENT_HANDOFF.md`)

> **Live Handoff Document** — Update this file whenever milestone status, corrective passes, verification counts, or next actions change.

## 1. Current Git & Branch State

- **Active Branch**: `feat/m12-settlement`
- **Base Commit (`dev`)**: `4495fd46da131301365b890a6c63efda510ca1e7` (M11 merged & closed)
- **Active Milestone**: **M12 — Settlement / Repayment** (`SET-01`..`SET-05` implemented and verified end-to-end across backend, Flutter, and Samsung physical device `R58M36JQYVY`; ready for user review / commit authorization; no stage/commit/push performed)
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
