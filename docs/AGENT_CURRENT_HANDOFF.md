# weDO — Agent Current Handoff (`docs/AGENT_CURRENT_HANDOFF.md`)

> **Live Handoff Document** — Update this file whenever milestone status, corrective passes, verification counts, or next actions change.

## 1. Current Git & Branch State

- **Active Branch**: `feat/m10-chat-realtime`
- **Base Commit (`dev`)**: `5c2187dcb9b73c19ac1f1368e37d6cb369bfdbb4` (`merge: integrate m9 REST chat`, which merged M9 commit `8d88e693cb909d19df317913678febfa571f3ad5`)
- **Active Milestone**: **M10 — Chat Realtime (`WebSocket + Redis`)** (Complete, verified, and deployed to Samsung `R58M36JQYVY`; uncommitted in pre-commit state pending manual review)
- **Preserved Stash**: `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync` — **DO NOT** pop, apply, or drop.
- **Local-Only Untracked Files (Never Stage/Commit)**:
  - `docs/LEARNING_HANDBOOK_M0_M2.md`
  - `docs/M8_STITCH_FIDELITY_INVENTORY.md`
  - `.stitch/**`

---

## 2. What Is Implemented in M10 (`feat/m10-chat-realtime` Worktree)

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

## 3. Latest Verified Test, Static Analysis & Two-Account Samsung Realtime Acceptance Status

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

## 4. Next Actions for Incoming Agent / User

1. **User Review of M10 Realtime Acceptance**:
   - M10 is in pre-commit state on `feat/m10-chat-realtime` with two-account Samsung realtime acceptance verified.
2. **After User Approval**:
   - Stage and commit M10 (`feat/m10-chat-realtime`), excluding `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `.stitch/**`, and `stash@{0}`.
