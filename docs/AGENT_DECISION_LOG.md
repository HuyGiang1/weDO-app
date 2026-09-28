# weDO Agent Decision Log (APPEND-ONLY / STABLE DECISIONS)

> **Document Role — APPEND-ONLY / STABLE DECISIONS**: This file records locked architectural, product, schema, and UX decisions established by canonical specifications or accepted milestone deliveries (especially M7–M9). Do **not** add speculative future decisions or temporary debugging notes here.

---

## Decision Registry

### DEC-ARCH-01 — Server-Authoritative Permissions & Lifecycle Projections
- **ID**: `DEC-ARCH-01`
- **Milestone**: `M2–M9` (Cross-cutting)
- **Decision**: Backend services are the sole enforcement and calculation point for authorization, role hierarchy (`OWNER`, `ADMIN`, `MEMBER`), group/activity lifecycle locks (`ARCHIVED`, `COMPLETED`, `CANCELLED`), and mutation time windows. Backend API responses project explicit boolean permission flags (such as `canEdit`, `canDelete`, `canChangeStatus`, `canClaim`, `canManageAssignees`, `canVote`, `canComment`, `canReply`, `readOnly`).
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §27, `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` §1, `.agents/skills/wedo-milestone-delivery/SKILL.md` §4 & §6.
- **Consequences**: Flutter UI must consume server-projected permission flags to show/hide/enable actions and must **never** duplicate `OWNER`/`ADMIN` role calculations or timestamp authorization logic locally.

---

### DEC-ARCH-02 — Stitch Visual Reference Without Business-Rule Drift
- **ID**: `DEC-ARCH-02`
- **Milestone**: `M3–M9` (Cross-cutting)
- **Decision**: Local Stitch design exports (`.stitch/` and `docs/M8_STITCH_FIDELITY_INVENTORY.md`) are the visual source of truth for Flutter screen layout, card surfaces, bottom sheets, spacing, and typography, while canonical backend API contracts, server-projected permission flags, and full-diacritic Vietnamese UI copy remain authoritative for runtime behavior.
- **Reason / Source**: `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `.agents/skills/wedo-milestone-delivery/SKILL.md` §6.
- **Consequences**: Agents align UI presentation to Stitch references where available, never modify `.stitch/` files unless explicitly instructed, and never weaken server authorization or lifecycle constraints to match static mockups.

---

### DEC-M7-01 — Activity Optional Scheduling Semantics (`V12`)
- **ID**: `DEC-M7-01`
- **Milestone**: `M7`
- **Decision**: Activities support both scheduled and unscheduled creation via Flyway migration `V12__unscheduled_activities.sql`, where `activities.start_at`, `activities.end_at`, and `activities.timezone` are nullable. An unscheduled activity has `start_at = NULL`, `end_at = NULL`, and `timezone = NULL`; a scheduled activity requires non-null `start_at` and `timezone`, with optional `end_at > start_at`.
- **Reason / Source**: `docs/ERD_DATABASE_DESIGN_v1.0.md` §6 (`M7 activity persistence and V12 schedule rule`), `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §11.
- **Consequences**: Unscheduled activities can be created in `PLANNING` without forcing dummy timestamps; activities without `end_at` transition to `COMPLETED` manually via `POST /api/v1/activities/{activityId}/complete`.

---

### DEC-M8-01 — Poll Consumer Single-Choice Scope & Deadline Evaluation
- **ID**: `DEC-M8-01`
- **Milestone**: `M8`
- **Decision**: The M8 Flutter consumer app creates and submits `SINGLE_CHOICE` Polls only (selecting exactly one option per vote), while the backend and `V6` schema retain `MULTIPLE_CHOICE` compatibility. Poll `deadlineAt` collects a full local date + time (same-day future times valid), serializes with an explicit UTC offset, and is evaluated against server time on every Poll read/mutation without requiring a background scheduler.
- **Reason / Source**: `docs/ERD_DATABASE_DESIGN_v1.0.md` §7, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §12 (`POLL-01` to `POLL-06`).
- **Consequences**: Passed deadlines immediately behave as `CLOSED` (`closed_at` persisted idempotently with `closed_by = null`); `ANONYMOUS` polls store voter user IDs internally for ballot uniqueness but never expose voter identities via API or UI.

---

### DEC-M8-02 — Task `dueAt` Overdue Semantics & Task Deletion Rules
- **ID**: `DEC-M8-02`
- **Milestone**: `M8`
- **Decision**:
  1. Task `dueAt` is an optional complete instant (`TIMESTAMPTZ`) collected as full local date + time in Flutter (same-day future times valid). Passing `dueAt` marks a Task as **overdue only** — it never auto-transitions `status` to `DONE` and never auto-deletes the Task.
  2. Task status (`TODO` -> `"Cần làm"`, `IN_PROGRESS` -> `"Đang thực hiện"`, `DONE` -> `"Hoàn thành"`) is shared across assignees and may be changed (`canChangeStatus`) by an assignee, Task creator, Activity creator, Group `OWNER`, or Group `ADMIN`.
  3. Task physical deletion (`DELETE /api/v1/tasks/{taskId}`, controlled by `canDelete`) is allowed **only** to the Task Creator, Group `OWNER`, or Group `ADMIN` (cascading cleanly to `task_assignees` and `task_status_history` under `V6`). Ordinary assignees do not gain delete permission.
- **Reason / Source**: `docs/ERD_DATABASE_DESIGN_v1.0.md` §8, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §13 (`TASK-01` to `TASK-06`).
- **Consequences**: Flutter renders the status selector only when `canChangeStatus == true` and the delete confirmation (`"Xóa công việc"`) only when `canDelete == true`, popping back to the Task List upon deletion.

---

### DEC-M8-03 — Activity Discussion Embedded in Activity Detail & Read-Only Lifecycle
- **ID**: `DEC-M8-03`
- **Milestone**: `M8`
- **Decision**: Activity Discussion (`activity_comments` with one reply level via `parent_comment_id`) is embedded directly inside `ActivityDetailRuntimeScreen` rather than a separate route. `GET /api/v1/activities/{activityId}/comments` projects discussion-level `permissions` (`canComment`, `canReply`, `readOnly`) independent of whether comment count is zero. `COMPLETED`, `CANCELLED`, and `ARCHIVED`-group activities preserve historical comments as readable (`readOnly = true`, `canComment = false`, `canReply = false`).
- **Reason / Source**: `docs/ERD_DATABASE_DESIGN_v1.0.md` §8, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §14.
- **Consequences**: Active members see a usable composer even when there are zero comments; completed/cancelled/archived discussions hide mutation controls while keeping existing comment threads visible.

---

### DEC-M9-01 — M9 REST vs M10 Realtime & Media Scope Boundary
- **ID**: `DEC-M9-01`
- **Milestone**: `M9` / `M10`
- **Decision**:
  1. M9 delivers complete Chat functionality over **REST** using existing `V4` tables (no new Flyway migration required).
  2. M9 send (`POST /api/v1/conversations/{conversationId}/messages`) is **text-only** (`type: TEXT` + optional `replyToMessageId`). `V4`'s `message_attachments` table is reserved schema support; attachment upload, storage ownership, and rendering are deferred to dedicated media scope (`M16`) and clients must not submit raw storage keys.
  3. Live event broadcast (`MESSAGE_CREATED`, `MESSAGE_EDITED`, `MESSAGE_UNSENT`, `REACTION_UPDATED`, `MESSAGE_READ`), WebSocket `/ws`, Redis fanout, typing indicators, and live presence belong strictly to **M10**.
- **Reason / Source**: `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` §12–13, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §9–10, `docs/ERD_DATABASE_DESIGN_v1.0.md` §5.
- **Consequences**: M9 must not introduce WebSocket endpoints, Redis pub/sub, or background polling loops. Conversation list, message pages, reactions, and `lastReadSequence` read receipts update deterministically on REST actions, manual refresh, and screen re-entry.

---

### DEC-M9-02 — 15-Minute Server-Authoritative Edit & Unsend Window
- **ID**: `DEC-M9-02`
- **Milestone**: `M9`
- **Decision**: Only the original message sender may edit (`PATCH /api/v1/messages/{messageId}`) or unsend (`POST /api/v1/messages/{messageId}/unsend`) an `ACTIVE` message, and **only within 15 minutes** of `created_at` as evaluated strictly by backend server time.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §9, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` `CHAT-07` & `CHAT-08`.
- **Consequences**: Client timestamps are never used for authorization; edits preserve `message_edit_history`; attempts after 15 minutes are rejected server-side.

---

### DEC-M9-03 — Unsend ("Thu hồi tin nhắn") vs Delete-For-Me ("Xóa tin nhắn")
- **ID**: `DEC-M9-03`
- **Milestone**: `M9`
- **Decision**:
  1. **Unsend (`POST /api/v1/messages/{messageId}/unsend` — `"Thu hồi tin nhắn"`)**: Withdraws the message for all conversation participants (sender only, `<= 15m`), sets status to `UNSENT`, clears exposed content to render `"Tin nhắn đã được thu hồi"`, and **atomically removes all active pins and reactions**. Withdrawn messages never project reactions and reject any future reaction mutations.
  2. **Delete-for-me (`DELETE /api/v1/messages/{messageId}/me` — `"Xóa tin nhắn"`)**: Inserts a visibility row in `message_hidden_users` at **any time** (no 15-minute limit), hiding the message strictly for the requesting user without altering other participants' view.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §9, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` `CHAT-08` & `CHAT-09`, `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` §12.
- **Consequences**: Replies pointing to an `UNSENT` message render the withdrawn placeholder; `GET /api/v1/messages/{messageId}/reactions` returns `[]` for `UNSENT` messages; Flutter keeps the two actions distinct in Vietnamese copy.

---

### DEC-M9-04 — Stranger Message Request 3-Text Limit
- **ID**: `DEC-M9-04`
- **Milestone**: `M9`
- **Decision**: When a non-friend initiates a Direct Message (permitted by the recipient's DM privacy policy: `EVERYONE` default, `MUTUAL_GROUPS`, or blocked by `FRIENDS_ONLY`), a `PENDING` `message_requests` record is created. Prior to receiver acceptance, the sender may send **at most 3 `TEXT` messages** and no attachments. Receiver acceptance (`POST /api/v1/message-requests/{id}/accept`) transitions the request to `ACCEPTED` and unlocks normal direct messaging without creating a `friendships` row.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §4, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` `CHAT-03` & `CHAT-04`.
- **Consequences**: A 4th message attempt before acceptance is rejected by `ChatService`; accepting a message request does not bypass the separate friend-request workflow.

---

### DEC-M9-05 — Message Request 72-Hour Decline Cooldown vs Block Cancellation
- **ID**: `DEC-M9-05`
- **Milestone**: `M9` / `M4`
- **Decision**:
  1. **Decline (`POST /api/v1/message-requests/{id}/decline`)**: Retains conversation/request history, transitions the request to `DECLINED`, and enforces a **72-hour cooldown** before the sender can initiate a new message request.
  2. **Block (`BlockService.blockUser`)**: Blocking a user transitions any `PENDING` message request between the pair to terminal state `CANCELLED` (`resolved_at = now`) **without** activating a 72-hour decline cooldown; subsequent unblocking does not revive the cancelled request.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §4, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` `CHAT-04`, `backend/src/main/java/com/wedo/backend/social/service/BlockService.java`.
- **Consequences**: `BlockService` executes an atomic update on `message_requests` alongside friendship/friend-request termination.

---

### DEC-M9-06 — Quick Reaction Set & Toggle/Replace Semantics
- **ID**: `DEC-M9-06`
- **Milestone**: `M9`
- **Decision**: M9 quick reactions (`PUT /api/v1/messages/{messageId}/reaction`) are constrained to the 6 canonical emojis: `👍`, `❤️`, `😂`, `😮`, `😢`, and `😡`. Each user may hold at most 1 reaction per message (`UNIQUE (message_id, user_id)`): submitting the same emoji toggles the reaction off; submitting a different emoji replaces the user's reaction.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §9, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` `CHAT-10`, `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` §12.
- **Consequences**: Both backend validation and Flutter reaction pickers restrict selection to the 6 emojis; `UNSENT` messages cannot be reacted to.

---

### DEC-M9-07 — Reaction Badge Edge Geometry & Authoritative Reaction-Detail Sheet
- **ID**: `DEC-M9-07`
- **Milestone**: `M9`
- **Decision**:
  1. **Compact Bubble Badge**: The reaction badge anchors directly to the message bubble's lower-right corner (for both own and other-user messages), displaying at most **2 distinct emojis plus the total reaction count** (e.g., `❤️ 5` or `❤️ 😂 6`, never repeating duplicate icons like `❤️ ❤️ ❤️`).
  2. **Reaction-Detail Sheet (`GET /api/v1/messages/{messageId}/reactions`)**: Tapping the compact badge fetches the authoritative reactor list over REST (`{ user: { id, displayName, avatarUrl }, emoji }`, where `avatarUrl` is an API-relative media URL, never a raw storage key) and opens a rounded bottom sheet titled `"Biểu cảm"` with `"Tất cả"` plus tabs for present emojis, rendering each reactor's `UserAvatar`, `displayName`, and emoji.
- **Reason / Source**: `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` `CHAT-10`, `mobile/lib/features/chat/presentation/message_reaction_details_sheet.dart`.
- **Consequences**: Cross-conversation outsiders and blocked direct users are denied access to `GET /api/v1/messages/{messageId}/reactions` (preventing IDOR); raw user UUIDs and storage keys are never displayed.

---

### DEC-M9-08 — Global Chat Tab vs Group-Specific Chat Navigation Invariant
- **ID**: `DEC-M9-08`
- **Milestone**: `M9`
- **Decision**:
  1. **Global Bottom Tab (`Chat`)**: Tapping the global bottom navigation `Chat` tab from **any** screen (including `MyGroupsScreen` and `GroupInfoScreen`) must always navigate to **Chat Home** (`AppRoutes.chatHome` / `/chat`) showing the user's conversation list (which idempotently materializes eligible active group conversations, including empty chats) with **no** `groupId` or `conversationId` forwarded.
  2. **Explicit Group Chat Entry (`"Trò chuyện"`)**: Tapping the group-specific `"Trò chuyện"` action inside `GroupInfoScreen` navigates to `AppRoutes.groupChat` (`/groups/chat`) with that exact `groupId`.
  3. **Chat Home Selection & Header Navigation**: Tapping a conversation row in `ChatHomeScreen` opens `AppRoutes.groupChat` (`/groups/chat`) and pressing Back returns to `ChatHomeScreen` (`/chat`). Tapping the group header inside `ChatScreen` opens that group's `GroupInfoScreen`.
- **Reason / Source**: `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` §12 (`M9 navigation invariant`), `mobile/lib/app/routes.dart`, `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`.
- **Consequences**: `GroupInfoScreen` separates `onChatHome` (bottom navigation tab index 2 -> `/chat`) from `onChat` (group action button -> `/groups/chat`), preventing any viewed group (e.g., `Tam Đảo`) from hijacking the global `Chat` tab.

---

### DEC-M9-09 — Chat Time Separators (`>= 30m` & Date Boundary) and Tap-to-Show Time vs Long-Press Actions
- **ID**: `DEC-M9-09`
- **Milestone**: `M9`
- **Decision**:
  1. **No Per-Bubble Always-Visible Timestamp**: Message bubbles do not render individual timestamps inside/under every row by default.
  2. **Centered Time Separators**: A centered secondary-text separator (`_ChatTimeSeparator`) is inserted before the first visible message, before any message where `current.createdAt - previous.createdAt >= 30 minutes` (`HH:mm` on same day), and across any calendar **date boundary** regardless of elapsed minutes (`dd/MM HH:mm` via `chatListTime`). Every time separator breaks visual author grouping so sender name and `UserAvatar` reappear for other-user runs.
  3. **Three-Way Gesture Separation**:
     - **Single tap on bubble** (`onTap`): Temporarily reveals that message's exact timestamp in a centered floating indicator (`chat-tap-timestamp`) for 2 seconds (updating on tapping another message, dismissing on scroll, and supporting withdrawn messages without exposing reactions/actions).
     - **Long press on bubble** (`onLongPress`): Opens the quick-reaction (`👍 ❤️ 😂 😮 😢 😡`) and permitted actions bottom sheet (`ACTIVE` messages only).
     - **Single tap on reaction badge**: Opens `MessageReactionDetailsSheet` (`"Biểu cảm"`).
- **Reason / Source**: M9 Corrective Pass 6 (`mobile/lib/features/chat/presentation/chat_screen.dart`, `mobile/lib/features/chat/presentation/chat_formatters.dart`).
- **Consequences**: Eliminates gesture conflict between viewing message time and opening the reaction/action sheet while keeping bubble heights compact and preserving bottom-right reaction badge alignment.

---

### DEC-M10-01 — Chat Realtime Architecture (`/ws`, `AFTER_COMMIT` Bridge, Redis Coordination, and Viewer-Tailored Fanout)
- **ID**: `DEC-M10-01`
- **Milestone**: `M10`
- **Decision**:
  1. **PostgreSQL + M9 REST Remains Authoritative**: Durable chat mutations (`send`, `edit`, `unsend`, `react`, `read-state`, `pin`) execute via existing REST endpoints and PostgreSQL transactions. `ChatService` publishes domain events (`DomainMutationEvent`, `DomainReadEvent`) handled exclusively by `ChatRealtimeTransactionalBridge` with `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` so rolled-back transactions never emit WebSocket or Redis frames.
  2. **Viewer-Tailored Realtime Payloads & Anti-IDOR**: `ChatWebSocketHandshakeInterceptor` validates JWT access tokens (`Authorization: Bearer` header or `?access_token=` query parameter) and active user status before upgrade on `/ws` and `/api/v1/ws`. `SUBSCRIBE`, `TYPING_START`, `TYPING_STOP`, and `MARK_READ` frames enforce conversation membership, group archive rules, and block/stranger request boundaries. Outgoing message frames compute `isMine` and `permissions` per recipient user via `ChatService.messageForViewer`.
  3. **Redis Fanout, Typing TTL, Multi-Session Presence & Graceful Fallback**: `ChatRealtimeCoordinator` coordinates cross-instance fanout on Redis pub/sub channel `wedo:chat:realtime` (deduplicated by `eventId`), stores ephemeral typing state in `typing:{conversationId}:{userId}` (`5s` TTL), and tracks multi-session presence in `presence:user:{userId}:sessions` (`120s` TTL), persisting `user_presence_snapshots.last_seen_at` only when a user's last active WebSocket session disconnects. If Redis is unreachable, `ChatRealtimeCoordinator` degrades gracefully to in-memory session delivery without breaking REST Chat.
  4. **Flutter Deduplication & Reconnect Reconciliation**: `WebSocketChatRealtimeClient` automatically reconnects with exponential backoff, re-subscribes active conversations, and triggers silent history reconciliation on reconnect while deduplicating incoming frames by `eventId`, `message.id`, and `sequence`.
- **Reason / Source**: `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §41, `docs/ERD_DATABASE_DESIGN_v1.0.md` §17, `backend/src/main/java/com/wedo/backend/chat/realtime/*`, `mobile/lib/features/chat/data/chat_realtime_client.dart`.
- **Consequences**: Seamless multi-device realtime chat delivery, live typing/presence/read-avatar updates, and zero regressions to M9 Pass 6 UX.

---

### DEC-M11-01 - Expense Facts, Derived Pair Balances, and M12 Boundary
- **ID**: `DEC-M11-01`
- **Milestone**: `M11`
- **Decision**:
  1. Reuse the V7 `expenses`, `expense_shares`, `expense_change_logs`, and existing settlement tables; do not add a debt table or migration.
  2. Store and calculate money as `NUMERIC(19,2)` / `BigDecimal`; Flutter represents amounts in integer minor units and sends decimal strings. EQUAL shares use deterministic cent allocation with remainder cents assigned to the payer first when included, otherwise canonical UUID order. CUSTOM_AMOUNT shares must sum exactly to the total.
  3. Derive current pairwise net balances from ACTIVE expenses/shares minus COMPLETED settlements, preserving pending settlements as reservations. Cancellation changes expense status and retains history. Active membership is required for mutations and participants; group owners/admins and creators receive server-projected correction permissions.
  4. Receipt upload/storage is deferred because no receipt upload/ownership contract exists in the current runtime. M12 settlement actions and M13 fund behavior are not pulled into M11.
- **Reason / Source**: M11 verified runtime, V1-V12 migrations (finance schema from V7), current API contract and M11 acceptance.
- **Consequences**: Expense history remains auditable, balances are recomputable, no arbitrary client debt or receipt storage key is trusted, and M11 requires no schema migration.

---

### DEC-M11-02 - Exact Monetary JSON and Read-Only Projections
- **ID**: `DEC-M11-02`
- **Milestone**: `M11`
- **Decision**: Expense and Balance response amounts are decimal JSON strings, preserving all `NUMERIC(19,2)` digits across client JSON decoding. Archived-group and cancelled-expense responses disable both `canEdit` and `canCancel`. Flutter renders each permission independently, displays instants in local time, and translates audit states without showing internal reference IDs.
- **Reason / Source**: M11 money precision, archive lifecycle, Vietnamese UI and server-authoritative permission requirements; focused boundary and widget tests.
- **Consequences**: No binary floating-point loss on the wire, no advertised mutation on archived groups, and readable consumer history.

---

### DEC-M12-01 — Peer-to-Peer Two-Sided Settlement & Pending Debt Reservation (`SET-01`..`SET-05`)
- **ID**: `DEC-M12-01`
- **Milestone**: `M12`
- **Decision**:
  1. **Reuse `V7__finance.sql` Schema Without New Migration**: M12 uses the existing `settlements` and `settlement_status_history` tables (`V7__finance.sql`). No authoritative `debts` table is created.
  2. **Direction & Counterparty Authority**:
     - `I_PAID`: `from_user_id = caller`, `to_user_id = otherUserId`. Only `to_user_id` (creditor) can `confirm` or `reject`.
     - `I_RECEIVED`: `from_user_id = otherUserId`, `to_user_id = caller`. Only `from_user_id` (debtor) can `confirm` or `reject`.
     - Only `created_by` can `cancel` while `status = PENDING`.
  3. **Pending Reservation & Derived Debt Reduction (`SET-02`, `SET-05`)**:
     - `PENDING`, `REJECTED`, and `CANCELLED` settlements do not reduce derived pairwise debt (`ACTIVE` expense shares minus `COMPLETED` settlements).
     - However, `PENDING` settlements reserve outstanding pairwise debt (`ledger.pending`) under a `SELECT id FROM groups WHERE id=? FOR UPDATE` row lock so concurrent settlement requests cannot over-settle remaining debt (`NO_OUTSTANDING_DEBT` when debt is zero/opposite; `SETTLEMENT_AMOUNT_EXCEEDS_DEBT` when exceeding `currentDebt - pendingReserved`).
     - Confirming a `PENDING` settlement (`SELECT ... FOR UPDATE` on both `groups` and `settlements`) re-validates `amount <= currentDebt`, transitions `status` to `COMPLETED`, sets `completed_at`, records `settlement_status_history`, and immediately reduces derived pairwise debt.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §15.2 (`SET-01`..`SET-05`), `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §19, `docs/ERD_DATABASE_DESIGN_v1.0.md` §14 (`V7__finance.sql`).
- **Consequences**: Prevents unilateral debt erasure, double confirmation, and concurrent over-settlement while preserving an immutable status history audit trail.
