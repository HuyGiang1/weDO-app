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

---

### DEC-M13-01 — Group Fund Dedicated Domain Boundary, Derived Ledger vs Available Balance, and Immutable Reversal Ledger (`FUND-01`..`FUND-17`)
- **ID**: `DEC-M13-01`
- **Milestone**: `M13`
- **Decision**:
  1. **Reuse `V8__fund.sql` Without New Migration & Keep Dedicated Domain Boundary**:
     - M13 uses the 9 existing `V8__fund.sql` tables (`group_funds`, `fund_managers`, `fund_collections`, `fund_collection_obligations`, `fund_contributions`, `fund_expenses`, `fund_reimbursements`, `fund_transactions`, `fund_transaction_reversals`) with no new Flyway migration.
     - Implemented in a dedicated package `com.wedo.backend.fund.*` (`FundController`, `FundService`, `FundDtos`) and Flutter module `mobile/lib/features/fund/*` so M13 pooled treasury cashflow never pollutes M11/M12 pairwise `expenses` / `settlements`.
  2. **Governance & Automatic Stale Fund Manager Revocation (`FUND-02`)**:
     - Group `OWNER` always holds full implicit Fund Governance + Fund Manager authority.
     - `OWNER` may assign up to 2 active `ADMIN` members as `Fund Manager` rows in `fund_managers`.
     - If an assigned `Fund Manager` is demoted to `MEMBER` or exits the group (`GroupMembershipEndedEvent`), `FundService` automatically revokes/filters stale `fund_managers` rows so non-eligible users never retain fund management rights.
  3. **Derived Ledger Balance vs Available Balance & `FOR UPDATE` Concurrency (`FUND-10`..`FUND-14`)**:
     - `ledgerBalance = sum(fund_transactions.direction = 'IN') - sum(fund_transactions.direction = 'OUT')`.
     - `availableBalance = ledgerBalance - sum(fund_reimbursements.status = 'PENDING')`.
     - All fund balance, contribution confirmation, reimbursement request/approval, transaction reversal, and fund close operations lock the `group_funds` row (`SELECT ... FOR UPDATE`) to prevent concurrent double-confirmation, over-contribution (`FUND_CONTRIBUTION_EXCEEDS_OBLIGATION`), or overdraft (`FUND_INSUFFICIENT_BALANCE`).
  4. **Immutable Ledger & Compensating Reversals (`FUND-15`, `FUND-16`)**:
     - `fund_transactions` rows are never updated or deleted. Reversing a `CONTRIBUTION`, `FUND_EXPENSE`, or `REIMBURSEMENT` transaction creates an opposite-direction `REVERSAL` row and links `fund_transaction_reversals(original_transaction_id, reversal_transaction_id)` (`UNIQUE(original_transaction_id)` prevents double reversal). Reversing an `IN` contribution requires `availableBalance >= amount` so the fund never drops below zero or violates pending reimbursement reservations.
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §16 (`FUND-01`..`FUND-17`), `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §20, `docs/ERD_DATABASE_DESIGN_v1.0.md` §15 (`V8__fund.sql`).
- **Consequences**: Complete auditability, zero cross-contamination between pairwise expense splits and pooled group treasury, and race-free balance/obligation enforcement.

---

### ADR-018 — M14 Notification & FCM Runtime Architecture (`NOTI-01`..`NOTI-06`)
- **Date**: 2026-09-28
- **Status**: Accepted & Enforced (`M14`)
- **Decision**:
  1. **Schema Reuse (`V1`, `V9`, `V10`)**:
     - Reuses `user_devices` (`V1`), `notifications`, `user_notification_settings`, `group_notification_settings` (`V9`), and `uq_user_devices_active_push_token` (`V10`). Zero new Flyway migrations (`V13+`) required.
  2. **Always-Persist In-App Inbox vs Push Policy Evaluation**:
     - Every committed domain event (`NotificationDomainEvent` + `ChatRealtimeEvents.DomainMutationEvent`) is handled in `NotificationDomainEventListener` with `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` and persisted to `notifications` inside an isolated `Propagation.REQUIRES_NEW` transaction (`NotificationService`), deduplicated per recipient via `data->>'eventKey'`.
     - User settings (`pushEnabled` + category toggles) and group mute settings (`1h`, `8h`, `1d`, `until_unmuted` evaluated dynamically against server `clock.instant()`) control **push delivery only**; in-app inbox rows are always persisted with their computed `pushDecision`.
     - Critical business events (`critical = true`: waitlist promotion, settlement confirmation, fund contribution confirmation, fund reimbursement approval) bypass group mute when user-level push + category toggles are enabled.
  3. **Open-Conversation Suppression & Push Failure Isolation**:
     - Chat notifications check `ChatRealtimeCoordinator.isUserSubscribedToConversation(recipientId, conversationId)`: actively subscribed recipients receive `SUPPRESSED_OPEN_CONVERSATION` while unsubscribed recipients receive push with `collapseKey = "chat:" + conversationId`.
     - `PushGateway` (`FcmPushGateway`) runs strictly outside database transactions; provider exceptions record `PROVIDER_FAILED` and invalid token errors (`UNREGISTERED` / `INVALID_ARGUMENT`) automatically deactivate the stale `user_devices` row without rolling back business or inbox state.
  4. **Dynamic Deep-Link Actionability**:
     - `NotificationService` resolves `target.actionable` and Vietnamese `target.nonActionableReason` at read time against live group membership and resource status (`CANCELLED` activities/expenses/settlements, handled invitations, removed/banned members).
- **Reason / Source**: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §18 (`NOTI-01`..`NOTI-06`), `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` §20, `docs/ERD_DATABASE_DESIGN_v1.0.md` §16 (`V9__notifications.sql`).
- **Consequences**: Business transactions never fail due to push provider errors, duplicate notifications are prevented, and stale deep links fail safely with clear Vietnamese explanations.

---

### ADR-019 — Honest FCM Delivery State and Atomic Notification Deduplication
- **Date**: 2026-09-29
- **Status**: Accepted (`M14`)
- **Decision**:
  1. Until a real Firebase Admin provider and approved project credentials are available, production push returns `REAL_FCM_EXTERNAL_CONFIG_BLOCKED`; local/fabricated device tokens must never be reported as sent or delivered.
  2. `GATEWAY_ACCEPTED` means only that a configured gateway accepted a handoff; it is not proof of device delivery. Internal push-policy/provider diagnostics are not part of the public Notification response.
  3. Inbox deduplication serializes the event-key check and insert with a PostgreSQL transaction-scoped advisory lock, avoiding a new migration or distributed-lock service.
- **Reason / Source**: M14 FCM/provider audit, V9/V10 schema, concurrent listener delivery analysis, and absence of Firebase SDK/configuration in the current build.
- **Consequences**: M14 does not claim cloud delivery until a real provider is configured; concurrent retries cannot create duplicate inbox rows, while a post-commit database failure can still lose an event because no durable outbox exists.

---

### DEC-M15-01 — Personal Activity Reminder Delivery and Rescheduling Policy
- **ID**: `DEC-M15-01`
- **Milestone**: `M15`
- **Date**: 2026-09-29
- **Status**: Accepted
- **Decision**:
  1. When a personal Activity reminder becomes due and remains eligible, it creates a persistent Notification Center item. It may also generate FCM push using category `ACTIVITY`, priority `NORMAL`, and a target to that Activity's detail. Inbox persistence is independent of push suppression.
  2. Push eligibility follows M14 global `pushEnabled`, `ACTIVITY` category preference, group mute, and active-device policy. Reminder notifications are not critical and never bypass group mute. No realtime delivery is required.
  3. An Activity start-time change reschedules enabled, unsent reminders in the same business transaction. If the recomputed `remind_at <= now` while the Activity is still future and otherwise eligible, it is due for the next scheduler run. Cancelled, completed, and other terminal Activities are not eligible for due delivery.
  4. A reminder already sent is not automatically sent again solely because the Activity time changes. Phase A/B implements configuration and rescheduling only; scheduler claiming, idempotency, inbox creation, and FCM dispatch are Phase C.
- **Reason / Source**: Explicit M15 product decision in the Phase A/B implementation authorization; existing M14 notification policy and V9 `user_activity_reminders` schema.
- **Consequences**: Phase A/B must not dispatch due reminders. Phase C must keep persistent inbox creation separate from push eligibility, respect M14 preferences/mute, and prevent duplicate delivery after rescheduling.

---

### DEC-M15-02 — Calendar Range Uses Inclusive Activity Overlap
- **ID**: `DEC-M15-02`
- **Milestone**: `M15`
- **Date**: 2026-09-29
- **Status**: Accepted
- **Decision**: Calendar `from`/`to` filters use inclusive overlap semantics. A scheduled Activity is included when `start_at <= to` (when `to` is supplied) and `COALESCE(end_at, start_at) >= from` (when `from` is supplied). Activities without `end_at` are point events at `start_at`; unscheduled Activities are excluded from dated Calendar results.
- **Reason / Source**: The canonical Calendar contract defines instant range filters but does not state start-within-range versus overlap. Inclusive overlap is consistent with displaying a multi-day Activity on every intersected date and avoids hiding an event spanning the selected range boundary.
- **Consequences**: Backend query and tests use this rule; Month and Agenda group returned instants after conversion to the device timezone. `from > to` is rejected.

### DEC-M15-03 — Atomic Due Activity Reminder Delivery
- **ID**: `DEC-M15-03`
- **Milestone**: `M15`
- **Date**: 2026-09-29
- **Status**: Accepted
- **Decision**:
  1. Poll due reminders at a configurable 45-second default cadence in bounded batches of 100. Candidate reads use the V9 partial due index; each candidate is processed in its own PostgreSQL transaction.
  2. Serialize reminder delivery against Activity edits and reminder changes by locking the Activity row first with `FOR UPDATE SKIP LOCKED`, then locking/rechecking its due reminder row with `FOR UPDATE SKIP LOCKED`. Activity edits and reminder PUT use the same Activity-first order.
  3. Persist/dedupe the ordinary ACTIVITY inbox row and set `user_activity_reminders.sent_at` in that same transaction. `sent_at` means the durable inbox exists or was idempotently confirmed; it does not represent provider/device delivery.
  4. The internal key is `activity-reminder:<userId>:<activityId>:<normalized-remindAt-instant>`. Push uses the existing NotificationService policy and is handed off after commit. Global/category suppression, group mute, missing devices, and provider failures do not roll back inbox or sent state. Reminders are NORMAL and non-critical.
  5. Terminal, started, archived-group, removed-member, disabled, and already-sent reminders remain stored but are excluded from delivery; changing an Activity schedule does not rearm a sent reminder. A changed user-configured offset can explicitly rearm a new schedule instance.
- **Reason / Source**: M15 Phase C approval, existing V9 reminder index and fields, M14 inbox idempotency and push preference policy, and Activity-first pessimistic locking in the lifecycle service.
- **Consequences**: No V13 migration or second push subsystem is required. Inbox creation is authoritative; a process failure after commit but before push handoff may suppress a push without losing the Notification Center item.

### M15-VER-01 — Phase C Physical Samsung Acceptance Record (Non-decision)
- **Date**: 2026-09-29
- **Device**: Samsung `<QA_ANDROID_SERIAL>`; device notification shade was used to verify actual provider delivery. No credential or FCM token contents were inspected or recorded.
- **Due delivery and tap**: A UI-configured reminder created exactly one persistent ACTIVITY inbox row and one visible system push. Tapping the push resumed weDO into the matching Activity detail and marked the notification read; a repeat check after two scheduler intervals found no duplicate inbox or push.
- **Category suppression**: With global push enabled and ACTIVITY disabled in Flutter Notification Settings, a due reminder still finalized `sent_at` and persisted exactly one inbox row with `SUPPRESSED_CATEGORY_DISABLED`; no matching system notification appeared. ACTIVITY was restored afterward.
- **Group mute**: With global and ACTIVITY push enabled, muting the group through Flutter caused a due reminder to persist once with `SUPPRESSED_GROUP_MUTED`, with no matching push; the group was unmuted after the test.
- **Reschedule**: A UI edit changed an enabled 5-minute reminder from a 23:15 local due instant to 23:25 local without changing its offset. The old instant passed with no inbox row or system notification. The new instant produced one inbox row and a `GATEWAY_ACCEPTED` provider result; one Samsung system notification was visible and the inbox count stayed one after two further scheduler intervals.
- **Interpretation**: `sent_at` represented durable inbox persistence, not FCM/device delivery. Provider handoff (`GATEWAY_ACCEPTED`) and physical notification appearance were verified separately. No scheduler timestamps were manually edited.
- **Other checks**: Host/device/PostgreSQL clocks agreed within about one second. Bounded last-3000-line logcat counts were zero for `FATAL EXCEPTION`, `AndroidRuntime`, `FirebaseMessaging`, and `FirebaseApp`. Physical disable-before-due was not run; automated disable/scheduler race coverage passed.

### DEC-M16-01 — Private S3-Compatible Avatar Uploads and Replacement
- **ID**: `DEC-M16-01`
- **Milestone**: `M16-A1`
- **Date**: 2026-09-30
- **Status**: Accepted
- **Decision**:
  1. Use a provider-neutral S3-compatible `ObjectStorageService`; local development uses MinIO and production provider/endpoint is configuration-driven. The bucket is private. Profile and group avatars upload directly from Flutter using a backend-authorized presigned PUT expiring after 10 minutes.
  2. Preserve canonical category names `AVATAR` and `GROUP_AVATAR`. `AVATAR` has no context and is owned by the authenticated user. `GROUP_AVATAR` requires `contextId` equal to the exact group UUID and the current group-information modification permission. The backend alone generates scoped opaque keys (`avatar/<userId>/<uuid>` and `group-avatar/<groupId>/<uuid>`).
  3. A1 accepts only `image/jpeg`, `image/png`, and `image/webp`, maximum 5 MiB for each avatar category. Presigned PUT signs MIME type and declared-size metadata; finalization verifies namespace/context, stored MIME, actual size, and signed declared size before persisting the key. No upload-session table is added; abandoned direct-upload orphan cleanup is deferred.
  4. Entities persist durable storage keys only. Authenticated callers obtain a five-minute signed GET after validating the owning profile/group exists and is not inactive/deleted; the object bucket remains private. Future chat and finance media require their own access rules and are not enabled by this decision.
  5. Avatar replacement commits the new database reference first, then best-effort deletes the previous M16 object after commit. Cleanup failure does not roll back the committed update. Legacy filesystem avatar keys remain readable during compatibility transition.
  6. Uploads themselves do not generate notifications. Future chat-image messages reuse normal `MESSAGE_CREATED` behavior.
- **Reason / Source**: Resolved M16-A1 authorization; canonical MEDIA-01 in `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md`; existing V1/V3 avatar key columns; user-approved A1 constraints.
- **Consequences**: Business code has no MinIO-specific dependency, client-supplied arbitrary keys cannot be finalized as avatars, device upload URLs are separated from internal S3 access, and no new database migration is required for A1.

### DEC-M16-02 — Explicit Private Bucket Bootstrap
- **ID**: `DEC-M16-02`
- **Milestone**: `M16-A1`
- **Date**: 2026-09-30
- **Status**: Accepted
- **Decision**: Local development opts into idempotent bucket existence/create through the S3-compatible backend adapter. It performs HEAD first, creates only when missing, tolerates a concurrent create only after the follow-up HEAD succeeds, and never changes an existing bucket's policy or contents. The application-wide and production default is disabled; automated test contexts disable real bucket access and exercise bootstrap logic in focused unit tests.
- **Reason / Source**: M16-A1 local MinIO startup closeout; startup must not depend on a separate `minio/mc` image, and production must not unexpectedly provision infrastructure.
- **Consequences**: MinIO remains private, failed enabled bootstrap fails application startup without printing credentials, and local Samsung traffic uses the separately configured client-reachable presign endpoint through ADB reverse on port 9000 only.

### DEC-M16-03 -- A2 Chat and Finance Media Authorization
- **ID**: `DEC-M16-03`
- **Milestone**: `M16-A2`
- **Date**: `2026-09-30`
- **Status**: Accepted
- **Decision**:
  1. Add exactly `CHAT_IMAGE`, `EXPENSE_RECEIPT`, `FUND_CONTRIBUTION_PROOF`, `FUND_EXPENSE_RECEIPT`, and `FUND_REIMBURSEMENT_RECEIPT`; do not add Settlement media. A2 images accept JPEG/PNG/WebP up to 10 MiB; a Chat message supports at most four attachments.
  2. Chat upload context is the exact conversation UUID. Finance upload context is the exact group UUID because presigning may precede creation of the owning record. Server-generated keys encode category, context, uploader, and random object ID; finalization binds each key to a concrete record and rechecks its business permission.
  3. V4 `message_attachments` and the existing V7/V8 finance key columns are sufficient; no V13 is required. A message with attachments is type `IMAGE`; image-only content is stored as an empty string. Message and attachments are atomic and immutable after creation.
  4. Media mutation authorization, read visibility, and mutability inherit the owning Chat/Finance operation. Signed GET URLs are ephemeral. No standalone delete endpoint is added; object cleanup is best-effort after commit only when a durable reference is actually removed.
  5. Image messages reuse exactly one `MESSAGE_CREATED`, current Chat notification policy, open-conversation suppression, and conversation deep link. Image-only notification copy is `Đã gửi một ảnh` or `Đã gửi <n> ảnh`.
- **Reason / Source**: User-approved M16 Phase A2 specification; existing V4, V7, and V8 schema.
- **Consequences**: Search and Settlement media remain out of scope. Existing finance create/update operations remain the only media finalization paths; categories do not create new business mutations.

### DEC-M16-04 -- Global Search Contract
- **ID**: `DEC-M16-04`
- **Milestone**: `M16-B`
- **Date**: `2026-09-30`
- **Status**: Accepted
- **Decision**: Global Search has exactly `PEOPLE`, `GROUPS`, `ACTIVITIES`, and `CONVERSATIONS`. Queries are trimmed, length 2..100, case-insensitive PostgreSQL substring matches with accent-sensitive semantics and literal `%`/`_`. All mode returns up to five results per category with independent `hasMore`; typed mode uses page/size (0/20 defaults, size 1..50) and no totals. Typed projections contain no email, phone, storage key, signed URL, or internal permission. Each category inherits its existing domain visibility rules in the database query before pagination. A conversation hit is its newest visible matching textual message; hidden, UNSENT, outside-history, and empty image-only messages do not match. Opening a hit opens its conversation without message anchoring. No migration, text extension/index, or external search engine is added.
- **Reason / Source**: User-approved M16 Phase B implementation contract; current V1-V12 schema and established user/group/activity/chat authorization.
- **Consequences**: Search behavior is bounded and privacy-preserving under current domain rules. Ranking is deterministic (exact, prefix, substring; category-specific tie-breakers); Flutter debounces 300 ms, uses five-result All sections and typed size-20 pagination, and ignores stale responses.

### DEC-M17-01 -- Bounded Home Read Model for Pass 1
- **ID**: `DEC-M17-01`
- **Milestone**: `M17`
- **Date**: `2026-10-05`
- **Status**: Implemented for Pass 1; subject to review
- **Decision**: Use canonical `GET /api/v1/home` as one authenticated, bounded read model. Recent Groups reuse the existing active-membership group listing; Upcoming Activities require a future scheduled `PLANNING`/`CONFIRMED` Activity in an active group; Finance Summary derives from the existing Expense ledger rules with completed settlements; Actions Required initially includes unanswered future RSVP, open unvoted Poll, assigned incomplete Task due within seven days or overdue, and pending Settlement awaiting the caller. Limit sections to 5/5/4/8 rows respectively. Do not add a table or migration. Do not present ordinary notifications as required actions.
- **Reason / Source**: M17 Pass 1's four-section scope, HOME-01, current group/activity/finance permissions, and current V1-V12 schema. The roadmap also lists Recent Updates, but the explicit Pass 1 brief fixes only four sections.
- **Consequences**: Home has no mutation authority and does not create a second business workflow. Recent Updates and other potential action categories require a later M17 review.

### DEC-M17-02 -- Home Recent Updates from the Notification Inbox
- **ID**: `DEC-M17-02`
- **Milestone**: `M17`
- **Date**: `2026-10-05`
- **Status**: Implemented; subject to closeout review
- **Decision**: Populate Home Recent Updates from persisted, recipient-scoped Notification inbox records. Scan the newest 30, retain only records whose existing target resolver reports an actionable current-user destination, and show at most five in inbox order. Reuse the Notification DTO and target router for display/read/deep-link behavior; do not add a feed table or generate duplicate events.
- **Reason / Source**: M17 Pass 2 requires cross-domain, privacy-preserving updates; the existing inbox already contains type, title/body, timestamp, read state, recipient and target context independently of push preferences.
- **Consequences**: Revoked or otherwise inaccessible targets do not appear on Home. Home reflects events already emitted to the inbox; it does not promise a complete audit log or include older eligible records beyond the bounded scan window.

### DEC-M18-01 -- Fund Response Monetary Precision
- **ID**: `DEC-M18-01`
- **Milestone**: `M18 Pass 1`
- **Date**: `2026-10-11`
- **Status**: Implemented; pending full regression
- **Decision**: Serialize all Fund response monetary `BigDecimal` fields as decimal JSON strings, matching the established Expense/Balance response contract. Keep request binding and stored `NUMERIC(19,2)` values unchanged.
- **Reason / Source**: The existing Fund integration assertion for `ledgerBalance` expected a string while the DTO emitted a JSON number; the finance contract already requires decimal strings to preserve precision.
- **Consequences**: Fund clients receive exact decimal text. No schema change or new endpoint is introduced; the baseline Fund test and full suite must confirm compatibility before closeout.

### DEC-M18-02 -- Header-only WebSocket Authentication
- **ID**: `DEC-M18-02`
- **Milestone**: `M18 Pass 1 closeout`
- **Date**: `2026-10-11`
- **Status**: Implemented
- **Decision**: Authenticate supported Chat WebSocket clients with the bearer handshake header, never a URL query token. Remove the backend legacy query fallback rather than introduce an unused compatibility switch.
- **Reason / Source**: Current Flutter uses the Authorization header; repository audit found query-only authentication only in legacy tests/documentation, not another supported production client. URL credentials risk disclosure through diagnostics.
- **Consequences**: Query-only clients receive 401. Update the canonical API and handshake regression; historical M10 decisions remain historical. No endpoint, schema, or financial behavior change.

### DEC-M18-03 -- Bounded Post-commit Delivery and Honest Durability
- **ID**: `DEC-M18-03`
- **Milestone**: `M18 Pass 4`
- **Date**: `2026-10-11`
- **Decision**: Move general domain notification and Chat realtime after-commit callbacks to explicit application workers (2 threads, queue 256, named `wedo-delivery-`); use separate push workers with the same bounds (`wedo-push-`). Never use CallerRuns on rejection. Keep secondary inbox/policy and metadata transactions REQUIRES_NEW and advisory-lock duplicate prevention. Reminder inbox and sent_at remain atomic; only push is deferred. Log rejection/failure with safe IDs and exception class, not provider payloads.
- **Reason**: Synchronous secondary transactions held a completed business transaction's connection while requesting another, starving the normal pool under twenty Chat sends. Independent workers remove that connection dependency without increasing Hikari capacity.
- **Consequences**: General inbox creation is eventual/best-effort until its insert commits; persisted inbox survives push failure. Queue rejection or process crash may lose an attempt, as no durable outbox/retry exists. REST Chat history remains durable and powers bounded backwards-cursor reconnect recovery; FCM is best effort and unavailable mobile registration cannot block app startup. No schema or financial transaction change.

### DEC-PREDEMO-01 -- Activity Task Eligibility and Assignee-only Progress
- **Date**: 2026-10-19
- **Status**: User-approved product rule change; supersedes historical M8 assignment/status rules above.
- **Decision**: New Task assignments and claims require active group membership plus GOING RSVP in the Task's Activity. MAYBE and WAITLIST do not qualify. Only current Task assignees may change TODO/IN_PROGRESS/DONE; management roles do not bypass this rule. Task creator/Owner/Admin retain existing edit/assignment/delete rights.
- **Leave policy**: Preserve existing assignments and status history after Activity departure. Retained assignees may still update progress while group access remains valid. Metadata edits can retain them; after explicit removal, adding them again requires GOING. No automatic reassignment, deletion, or historical rewrite.
- **Consequences**: No migration or new endpoint. Backend enforces additions/claims and projects permissions; Flutter filters assignment candidates using current Activity RSVP plus active group members. Existing nonparticipant assignments are historical, not new eligible candidates.

### DEC-PREDEMO-02 -- Poll-in-Chat Safety Deferral
- **Date**: 2026-10-19
- **Status**: Deferred under the user's explicit pre-demo safety gate.
- **Decision**: Keep Poll history/detail/voting unchanged for this candidate. V4 messages permit only TEXT/IMAGE, with no durable poll reference/system-event abstraction; current message projections/client reducers do not support poll cards or poll vote state events. Do not encode hidden JSON as ordinary text or publish unrecoverable pseudo-messages.
- **Post-demo design**: Add an additive ordered migration for typed poll/system message payloads and stable event keys; atomically persist poll creation/vote transitions with conversation sequence events. Reuse current after-commit Chat transport, permission checks and REST history/catch-up; fetch Poll domain state after reconnect. Use per-vote revisions/idempotency keys, respect anonymous/result visibility policies, and keep all closed/open/multiple Polls in Activity history. Implement backend Poll/Chat DTO/persistence/service/realtime and Flutter model/reducer/card/history changes with duplicate/reconnect/privacy integration tests before device rollout. No such migration or protocol change is made now.

### DEC-R3-01 -- Canonical group Poll with optional Activity association
- **Date**: 2026-10-25
- **Status**: User-authorized R3 resumed implementation; supersedes the pre-demo deferral and speculative design details in DEC-PREDEMO-02, without altering its historical record.
- **Decision**: Group Chat Poll creation does not require an Activity. Canonical Poll owns `groupId`; nullable `activityId`, if present, must belong to that group. One Poll/ballot store and one durable `POLL` message reference; no hidden Activity. Group history includes all group Polls, Activity history retains linked Polls.
- **Transactions/transport**: Atomically create Poll/options and sequence-ordered Chat message. Reuse one client command UUID for uncertain creation retry. Subsequent votes use existing locked ballot replacement and after-commit Poll invalidations, not extra per-vote Chat messages, artificial aggregate versions or another socket. Anonymous hints omit voter actor identity. Existing shared authorization/Redis/refetch remains authoritative.
- **Deadline**: List reads project server-clock expiry without batch mutation. Single authorized detail reads materialize closure idempotently; writes enforce expiry independently. No periodic polling/scheduler is introduced.
- **Consequences**: Additive V13 ownership backfill/legacy trigger and typed message FK; isolated PostgreSQL validation precedes QA migration. Migration now applied successfully and must not be rewritten. API/ERD/class diagram describe the current model. R3 remains IN PROGRESS until its physical acceptance gate passes; no R4–R9 authorization is implied.

### DEC-R3-02 -- Durable public vote activity and anonymous timing privacy
- **Date**: 2026-10-25
- **Status**: User-requested R3 UX redesign; supersedes only DEC-R3-01's no-per-vote-Chat-message ruling for PUBLIC Chat-linked Polls.
- **Decision**: Each actual first/change PUBLIC vote atomically persists one typed timeline activity referencing the original canonical Poll; no-op/rejected/rollback operations create none. Optional UUID command receipts prevent duplicate and delayed replay; existing ballots stay authoritative. Use ordinary Chat sequence/unread/MESSAGE_CREATED after-commit delivery and existing targeted Poll hints, never another socket or full history read per vote.
- **Privacy**: Anonymous votes create no per-vote timeline activity, even generic, to avoid sender/timing correlation. Public result-hidden voter identities are also withheld until permitted. Participant count is unique ballots, not summed selections; names/avatar preview and per-option membership are backend-authorized public-result projections.
- **Consequences**: Forward-only V14 permits repeated activity references while retaining one original POLL card; receipts are request metadata, not another vote store. Existing canonical APIs remain compatible; original card/results update in place, activity is durable/clickable. Full paired UX acceptance remains required before R3 COMPLETE.

### DEC-R4-01 — Private group memories and shared album media
- **Date**: 2026-10-26
- **Status**: Implemented; R4 physical acceptance pending.
- **Decision**: Moments and Albums are group-owned private resources, optionally linked to an existing same-group Activity; no RSVP or implicit Activity requirement. Additive V15 stores post/media/reaction/comment/album/association facts. Album items reference existing media, never copy object bytes. Creator or current Owner/Admin manages content; all reads require current membership, writes mutable membership.
- **Media**: Reuse presigned private MinIO storage, stable media IDs, streaming PUT and native MP4 playback. JPEG/PNG/WebP10MiB, MP4 H.264/AAC50MiB defaults, max8/post, configurable byte limits. Authorize media ID before issuing a60-second GET; previously issued URLs have that bounded residual access window. No transcoder or content-byte codec probe.
- **Consequences**: Soft deletion retains objects/audit and protects shared references. Failed writes do not commit dangling media references; unfinished uploads may leave private orphan objects until an explicit retention policy. Reuse existing group-scoped AFTER_COMMIT/shared socket/Redis targeted invalidations, with no new transport/outbox/polling. R4 remains IN PROGRESS until required physical evidence; Community remains a separate future milestone.

### DEC-R5-01 — Canonical Community visibility and eligible realtime
- **Date**: 2026-10-27
- **Status**: Implemented; focused verification passed, physical acceptance pending.
- **Decision**: Community is independent of private group Moments, one GENERAL post store with PUBLIC/FRIENDS/FRIENDS_OF_FRIENDS/GROUP_ONLY. One eligibility predicate applies before feed pagination and to detail/media/interactions/profile/socket. Bidirectional blocks override; FOF uses confirmed active graph with unblocked active bridge; GROUP_ONLY requires current membership and no ban, never trusts supplied group ownership. For You is eligible PUBLIC freshness; Friends requires direct friendship. No location/ranking/recruitment implementation.
- **Media/moderation**: Existing signed upload, image limits and60-second private GET; own-uploader context prevents silently exposing private Moment keys publicly. Personal hide and durable structured reports, creator or group-only Owner/Admin moderation. A group moderator cannot republish another author's protected media PUBLIC. No global administrator role/user-report API invented; full review workflow belongs to R7.
- **Realtime**: Existing AFTER_COMMIT/shared socket/Redis only, own community feed scope and eligible post scope; actor-free hints, visible-resource reaction/comment refresh. Graph/block/group changes issue recipient-only policy hints and recheck post scopes; clients clear protected cache before refetch. Stable per-scope eventId derivation avoids cross-scope dedupe loss, without manufactured aggregate revisions.
- **Consequences**: Additive forward-only V16, no QA reset/object deletion or separate transport. R5 image-post slice does not claim Community video, R6 recruitment, R8 ranking or R7 review UI complete. Previously issued signed URLs retain their documented60-second residual window. R4 milestone closure remains an independent physical-evidence decision.

### DEC-R5-02 — Mixed eligible For You feed
- **Date**: 2026-10-27
- **Status**: User-requested correction implemented and focused-tested; supersedes only DEC-R5-01's PUBLIC-only For You selection.
- **Decision**: For You includes every Community post the viewer is eligible to read, including their own FRIENDS/FRIENDS_OF_FRIENDS/GROUP_ONLY posts. Visibility is enforced behind the feed by the shared authorization predicate, not by routing private posts into an exclusive tab. Friends remains an overlapping direct-author-friendship filter; My Posts remains an author list.
- **Source**: User physically observed FRIENDS publication visible to Samsung but absent from For You and could not find their own post on iPhone. They explicitly requested all eligible posts on For You. No visibility/block/group rule is relaxed.
- **Consequences**: Change one discovery filter; no schema/migration/transport change, no exposure of ineligible content. Additional backend regression covers mixed modes, own FRIENDS, FOF/group exclusion and block precedence. Separate scoped Community keyboard UX correction makes outside-body touch/drag/explicit hide dismiss iOS input without losing text or automatically publishing.


### DEC-R6-01 — Explicit manager recruitment with canonical bounded admission
- **Date**: 2026-10-27
- **Status**: Implemented, focused verified; R6 physical acceptance in progress.
- **Decision**: Extend canonical CommunityPost with LOOKING_FOR_MEMBERS and one-to-one metadata. Only current unbanned Owner/Admin of ACTIVE APPROVAL_REQUIRED group may recruit externally. Explicit publication is the opt-in where schema has no group public/privacy flag. Optional Activity must be same-group, not cancelled/completed. No ordinary-member recruitment or AUTO_JOIN fallback.
- **Privacy**: Public preview is a manager-published group-name/optional Activity-title+time snapshot, never full private DTO/members/Chat/Moments/Finance/invite code/phone/GPS. Canonical visibility and block predicates apply everywhere; blocks against active group managers and bans prevent admission. Manager-only review scope is separate from publicly readable post scope and revoked on role loss. Mixed eligible For You decision DEC-R5-02 remains unchanged.
- **Admission/count**: Canonical GroupJoinRequest PENDING creates no membership. Provenance table links existing request; only existing canonical approval creates membership. Target1..100 counts lifetime distinct approved applicants; leaving does not refund historical approvals. Current group100-capacity separately bounds admission. Group→metadata locks guard all provenance-linked approval routes. No RSVP auto-join, artificial versions or separate socket/polling.
- **Lifecycle**: Immutable target/group/Activity; caption/visibility use canonical edit. Current manager may close idempotently, no reopen. Deadline explicit, else plannedAt, else30days; writes/read/resync enforce projected CLOSED/EXPIRED/FILLED/OPEN, with no idle expiry scheduler. No R7 moderation/R8 ranking scope implied.
- **Consequences**: Additive V17 tested on isolated PostgreSQL before QA with backup; applied V13–V17 must not be rewritten. R6 remains IN PROGRESS until exact acceptance. Existing QA/media/signing/Firebase/finance unaffected; unperformed physical negatives remain honestly pending.


### DEC-R7-01 — Explicit Community moderator and reversible audited content actions
- **Date**: 2026-10-27
- **Status**: Implemented/focused verified; R7 paired physical acceptance pending.
- **Decision**: Extend canonical community_reports to POST/COMMENT/USER, preserve reporter FK privately, partial unique OPEN target/reporter dedupe and structured reasons including SCAM. No automatic takedown or account ban on report. Hide remains personal and reversible without overriding audience/block/removed state.
- **Roles**: Revocable operator-provisioned community_moderators grant is required for public/global/user-report moderation; no global privilege from group ownership. Current unbanned Owner/Admin of ACTIVE group may review only their GROUP_ONLY post/comment reports. User explicitly approved exactly QA Owner for local global-moderator acceptance, recorded after V18 tests/backup. No public grant API/default role seed.
- **Lifecycle**: Existing ACTIVE/REMOVED content with immutable REMOVE/RESTORE audit; OPEN report represents review, not automatic suppression. DISMISS/RESOLVE do not delete content; USER removal/restoration forbidden. Author deletion cannot be reversed. Canonical visibility, blocks and closed recruitment state still apply after restoration. No shared object hard deletion.
- **Transport/media**: Existing AFTER_COMMIT/shared socket/Redis; own moderator scope and per-report current access rechecked before delivery. Evidence media URLs are exact report-scoped authorized exceptions,60seconds; ordinary removed-content URLs cannot be newly issued, old signed URL residual bounded60seconds. No public reporter evidence. Reconnect clears permission-sensitive caches before authoritative read; no polling/mutation replay.
- **Consequences**: Additive V18 tested isolated before QA, applied successfully, immutable thereafter; grants/report/action FKs and queue/cursor indexes retained. Existing R5 mixed eligible For You rule and R6 governed admission unchanged. R7 remains IN PROGRESS pending exact physical evidence, R2 ongoing, R8/R9 not started.


### DEC-R7-02 — Avoid unrelated Community refresh for nonfriend blocks
- **Date**: 2026-10-27
- **Status**: Confirmed physical symptom, red PostgreSQL/socket reproduction and34 focused regression PASS; backend-only deployed, physical retest pending.
- **Decision**: Existing relationship events from a block that ends no active friendship and from unblock carry server `communityPolicyScope=RECIPIENT_ONLY`; Community/moderation invalidation goes only to each involved recipient. Personal hide/unhide policy is also recipient-only. Do not reload unrelated Owner's unchanged feed/post/queue.
- **Security**: Actual friendship UPDATE count>0 retains conservative broad graph checks because third-party FOF can be revoked. Existing/default graph events remain broad. Involved users still get authorized policy/refetch and revoked scopes; no new client-side authorization or transport. Unblock does not restore friendship.
- **Consequences**: Three bounded backend production changes only, no schema/mobile/signing/Firebase changes. Reproduced R7 defect authorizes this fix; no renewed foundation audit or R8 scope. Physical Owner queue/remove/reconnect acceptance remains open.


### DEC-R10-01 — Canonical Activity Journey and truthful camera check-in
- **Date**:2026-10-28
- **Status**: Implemented/focused verified; physical acceptance pending.
- **Decision**: Activity owns stops and the sole RSVP. Check-in associates one canonical Moment, not copied storage/social entities. CAMERA_CLIENT_DECLARED/client capture time never assert GPS/presence; server receipt authoritative. Parent completion freezes writes without fabricating child completion. Existing AFTER_COMMIT/shared scopes/Redis and targeted REST reused.
- **Consequences**: V19/V20 additive and applied after isolated tests/backup, immutable. Protected media authorization retained. No new transport/location tracking/financial ledger behavior.

### DEC-R10-02 — Configurable private proof and explicit idempotent Poll actions
- **Date**:2026-10-28
- **Status**: Implemented/focused verified; physical acceptance pending.
- **Decision**: Old Task modes/status unchanged. DIRECT_COMPLETE requires proof; REQUIRE_REVIEW requires different current authorized manager approval of unchanged current assignee proof before canonical DONE/history. Generic assignee status cannot bypass evidence. Evidence private, review history retained. Poll actions explicitly select option/target Activity and confirm, deduplicate command/natural source key, preserve source snapshots after deletion. Multi-option sources use explicit per-option actions, no bulk/automatic winner execution.
- **Consequences**: Current membership and Task snapshot guards prevent stale approval. No proof auto-sharing, no schema status rewrite; dedicated physical gates still required before R10 completion.


### DEC-R10-03 — Compact Activity navigation and canonical check-in media
- **Date**:2026-10-28
- **Status**: User-requested UX correction, focused verified; corrected-device retest pending.
- **Decision**: Activity detail exposes four consistent actions Journey/Check-in, Task, Moments, Poll; removes duplicate tools card and mounted Discussion section/subscription from production Activity route. Canonical Discussion records/module remain preserved. Check-in media must authorize as canonical Moment; Task evidence and Community retain distinct endpoints, no fallback between protected domains.
- **Reason**: User reports both-device Check-in failure and confusing duplicate controls. Actual screen plus wrong-route404/correct200 prove inherited Community media method was incorrect.
- **Consequences**: Flutter-only bounded fix, no schema/backend/signing/privacy relaxation.164 focused tests and clean analyzer; no physical PASS inferred before retest.


### DEC-R10-04 — Plan time is guidance; explicit execution state
- **Date**:2026-10-28
- **Status**: User-confirmed requirement, implemented UI and focused verification.
- **Decision**: Planned Stop timestamps do not gate authorized start/check-in/completion; users may arrive/work early. Actual state is explicit, never inferred from time. Existing open/terminal Activity/Stop and membership authorization still applies. Timeline/detail/overview must distinguish running/completed/planned, with clear action verbs.
- **Consequences**: No backend rule change required: regression proves existing early-execution behavior. Compact matching four actions retained. Pair image fix userPASS, new status/compact physical retest pending; R10 not complete.


### DEC-R10-05 — Preserve work meaning in converted Task title
- **Date**:2026-10-28
- **Status**: User-requested correction, focused verified; physical retest pending.
- **Decision**: TASK conversion defaults title to Poll question, with explicit editable taskTitle≤255; chosen option belongs in description and durable source linkage. This supersedes R10 option-text Task title default only. STOP titles remain option text. No language inference: user can revise “Mua hoa quả” to “Đi mua hoa quả”.
- **Navigation**: Centered success dialog View opens Activity Task list; existing source-history links retain detail behavior.
- **Consequences**: Additive API, no migration. Retry returns same target without name mutation; old Tasks preserved.13backend/28Flutter focusedPASS, analyzer clean; no R10 completion from automated evidence alone.


### DEC-UX-NAV-01 — Global fade pages and retained immediate main tabs
- **Date**:2026-10-28
- **Status**: User-authorized global UX implementation;266focusedPASS/analyzer clean, installed both; QA iPhone core physical fade/back/scrollPASS and Samsung navigation/back/scroll/media smokePASS.
- **Decision**: One shared PageTransitionsTheme for all Material pages/platforms:120ms forward/reverse opacity only, no page slide/zoom; accessibility/reduced-motion no visual animation. Main-tab roots0ms and lazy retained state/scroll in same Navigator. Keep typed/auth/deeplink contracts and session disposal, no extra GlobalKey or socket. Native camera/picker/modal animations and gallery content gestures stay appropriate.
- **Gestures**: Preserve public Cupertino edge detection with slide arguments pinned and fade driven by actual route animation; Android uses public predictive route hooks for progress/cancel/commit without native scale/slide decoration. Respect pop eligibility.
- **Consequences**: Cross-cutting requirement for R10 and R9, not R10 completion. Physical newer-Android predictive/reduced-motion and remaining exact-candidate adjacent matrix recorded separately. No backend/business/API/DB change in navigation task.


### DEC-R2-01 — Activate dependency-scoped personal read models
- **Date**:2026-10-29
- **Status**: User-authorized R2 final closure implementation,75focused backendPASS; physical acceptance in progress, R2 not yet COMPLETE.
- **Decision**: Existing AFTER_COMMIT ReadModelFanout enabled by default (explicit false optout retained), reusing shared Redis/socket and deterministic per-event/user/type IDs. Only current active group members receive private own-read-model hints without group/actor/business data. Home follows Group/Activity/Poll/Task/Expense/Settlement; Calendar Group/parent Activity; group-list Group only. Discussion/Fund/JourneyStop do not trigger unrelated Home/Calendar reads because those current read models do not depend on them.
- **Access**: Access-changing Group events derive HOME_ACCESS_CHANGED/CALENDAR_ACCESS_CHANGED so clients clear sensitive snapshots before an authoritative read, even during network loss; ordinary HOME_CHANGED keeps accepted content/scroll state. User-private membership events continue existing GROUP_ bindings. No new sockets, polling, persistent balances, schema or financial formulas.
- **Consequences**: Supersedes only the historical R1/R2-A defaultOFF deferral. Tests cover commit/rollback, membership recipient checks, duplicate IDs, irrelevant events and cache invalidation. Best-effort/no-outbox limitations remain. Do not infer physical or full R2 closure from tests alone.

## DEC-R8-01 — Privacy-first bounded Feed Ranking V1 (2026-10-29)

- For You only: existing R7 audience/block/hide/moderation predicate precedes candidate selection/scoring and every later page; requesting viewer's POST reports additionally excluded from discovery, not a global takedown or detail/media authorization change. Friends/Profile and separate OPEN recruitment discovery retain contracts.
- Integer weight total1000: freshness600, confirmed friend150, distinct non-author actor engagement150 (cap20), eligible future OPEN recruitment100; half-life86400s; no viewer interests stored, contribution0. No private Chat/Task/Finance/location inference.
- Preserve UUID nextBefore/items/hasMore response. Bounded chronological windows200 (max500), fixed traversal reference, deterministic score/time/UUID order, immutable per-window snapshots, current authorization recheck. Older windows remain reachable, no top200 permanent cutoff. No float cursor/score/feature disclosure.
- Local bounded ephemeral cache2048 cursor states/15min fixed TTL, version1 and viewer binding. Invalid/tampered/expired/evicted/restarted/different-instance cursor returns explicit400 COMMUNITY_FEED_CURSOR_INVALID; no silent rerank. Single-instance V1; sticky routing/shared snapshots require later reviewed deployment work. No new DB/Redis/background infrastructure or migration.
- Add authenticated read-only POST /community/posts/refresh for≤100 requested IDs, same feed eligibility and order; client batches20 to revalidate accepted cards without ranked-list reset. Existing policy invalidation clears cached tabs before refetch. No new transport or UI redesign. Exact implementation/test/physical limits in R8_FEED_RANKING_DELIVERY.md.


## DEC-R8-02 — Reconcile newly granted Community eligibility without reshuffling retained cards (2026-10-29)

- Physical R8 block/unblock exposed surviving-ID-only refresh: removal was safe but unblocked/unhidden authorized posts were not rediscovered. Keep R7 authority and immediate protected-cache clearing; do not weaken filters or restore stale DTOs.
- Existing Community policy-change path now additionally fetches bounded ranked discovery for the loaded depth, revalidates retained IDs, keeps their accepted relative order, appends newly eligible IDs and advances the canonical cursor for that discovery snapshot. Explicit policy change is the exception to retaining the cursor. Reaction/comment/reconnect retain targeted read-only refresh and do not rerank globally. Initial new-post hint remains an explicit update indicator.
- Widget regression reproduced RED then passes in304 affected Flutter checks/analyzer clean; physical fix retest must be recorded separately. No backend/schema/event transport or accepted visual design change.


## DEC-R8-03 — Missed discovery on reconnect uses an indicator, not list replacement (2026-10-29)

- Reconnect/resubscribe '*' from the existing binding means authoritative visible-ID revalidation, never an empty targeted set. One bounded first-page read detects eligible IDs missed while offline/background and sets the existing new-post indicator; accepted order/cursor are retained until explicit update.
- No polling, new socket, continuous healthy PONG fetch or reaction/comment global rerank. Expected failures and late responses retain existing ReliableRead/generation rules. Physical regression motivated this correction; latest305FlutterPASS/analyzer clean, physical final retest recorded separately.
