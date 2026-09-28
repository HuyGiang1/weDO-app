# weDO — Agent Current Handoff (`docs/AGENT_CURRENT_HANDOFF.md`)

> **Live Handoff Document** — Update this file whenever milestone status, corrective passes, verification counts, or next actions change.

## 1. Current Git & Branch State

- **Active Branch**: `feat/m9-chat-rest`
- **Base Commit (`HEAD`)**: `0d05097c573cb6d348e586bd6d03c8acfbb78ccd` (`feat(m8): implement poll, task, and activity discussion`)
- **Active Milestone**: **M9 — REST Chat Runtime** (Complete, verified, and passed Samsung user acceptance; uncommitted pending explicit user commit approval)
- **Preserved Stash**: `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync` — **DO NOT** pop, apply, or drop.
- **Local-Only Untracked Files (Never Stage/Commit)**:
  - `docs/LEARNING_HANDBOOK_M0_M2.md`
  - `docs/M8_STITCH_FIDELITY_INVENTORY.md`
  - `.stitch/**`

---

## 2. What Is Implemented in M9 (`feat/m9-chat-rest` Worktree)

### Database Schema (`V4__chat.sql` — No New Migration Required)
- M9 uses the existing `V4__chat.sql` tables (`conversations`, `direct_conversations`, `group_conversations`, `conversation_sequences`, `messages`, `message_requests`, `message_attachments`, `message_edit_history`, `message_hidden_users`, `message_reactions`, `conversation_read_states`, `message_pins`).
- No existing Flyway migrations (`V0`..`V12`) were modified and no new migration (`V13+`) was needed. `message_attachments` remains reserved schema support while media upload/rendering is deferred beyond M9.

### Backend (`backend/src/main/java/com/wedo/backend/chat/...` & `BlockService.java`)
- **REST Endpoints (`ChatController` at `/api/v1`)**:
  - `GET /api/v1/conversations` (lists viewable conversations; idempotently materializes canonical active group conversations, including empty chats, with group avatar projection and unread count)
  - `POST /api/v1/groups/{groupId}/conversation` (creates or opens canonical group conversation)
  - `POST /api/v1/direct-conversations` (opens canonical direct conversation or initiates/resolves stranger message-request state)
  - `GET /api/v1/message-requests`, `POST /api/v1/message-requests/{id}/accept`, `POST /api/v1/message-requests/{id}/decline` (stranger message requests with 3-text limit before accept and 72h cooldown after decline)
  - `GET /api/v1/conversations/{id}/messages` (sequence-paginated message history via `beforeSequence` & `limit`, including other participants' persisted `lastReadSequence` and public avatar projection)
  - `POST /api/v1/conversations/{id}/messages` (text-only message send + optional `replyToMessageId` + `clientMessageId`)
  - `PATCH /api/v1/messages/{id}` (sender-only edit within 15-minute server-time window; preserves `message_edit_history`)
  - `POST /api/v1/messages/{id}/unsend` (sender-only unsend within 15-minute server-time window; sets `UNSENT` and atomically clears active reactions and pins)
  - `DELETE /api/v1/messages/{id}/me` (delete-for-me at any time via `message_hidden_users`)
  - `PUT /api/v1/messages/{id}/reaction` (6 canonical quick reactions: `👍`, `❤️`, `😂`, `😮`, `😢`, `😡` with toggle/replace semantics)
  - `GET /api/v1/messages/{id}/reactions` (authoritative reaction-detail projection `{ user: { id, displayName, avatarUrl }, emoji }` with anti-IDOR conversation/history/block enforcement)
  - `PUT /api/v1/conversations/{id}/read-state` (monotonic `lastReadSequence` update)
  - `POST /api/v1/messages/{id}/pin`, `DELETE /api/v1/messages/{id}/pin`, `GET /api/v1/conversations/{id}/pins` (up to 20 active pins per conversation)
  - `GET /api/v1/conversations/{id}/messages/search` (scoped search respecting join-time, hidden-for-me, and `UNSENT` rules)
- **Block Integration (`BlockService.java`)**:
  - Blocking a user transitions any `PENDING` `message_requests` between the pair to `CANCELLED` without triggering the 72-hour decline cooldown.

### Mobile (`mobile/lib/features/chat/...` + Navigation/Group Integration)
- **Files Implemented/Updated**:
  - `mobile/lib/features/chat/data/chat_api.dart`, `chat_models.dart`, `chat_repository.dart`
  - `mobile/lib/features/chat/presentation/chat_formatters.dart`, `chat_home_screen.dart`, `chat_requests_screen.dart`, `chat_screen.dart`, `message_reaction_details_sheet.dart`
  - Integrated into `mobile/lib/app/routes.dart`, `mobile/lib/app/app.dart`, `mobile/lib/main.dart`, `group_info_screen.dart`, `my_groups_screen.dart`, `group_widgets.dart`, and `public_user_profile_screen.dart`.
- **Corrective Passes Completed (Passes 1–6)**:
  - **Pass 1–3**: Eligible/empty group conversation visibility, group avatar rendering, own-right vs other-left author run grouping, compact lower-right reaction badge (`chat-reaction-badge-<id>`), and REST-backed read indicators.
  - **Pass 4**: `MessageReactionDetailsSheet` (`"Biểu cảm"`) showing filterable reactor identities (`UserAvatar`, `displayName`, emoji) from `GET /api/v1/messages/{id}/reactions`.
  - **Pass 5**: Global bottom `Chat` tab always opens `ChatHomeScreen` (`/chat`) without forwarding `groupId`/`conversationId`; Group Info's explicit `"Trò chuyện"` button opens `/groups/chat` for that exact group; conversation header opens its own Group Info; Back from a conversation opened in Chat Home returns to Chat Home.
  - **Pass 6**: Removed always-visible per-bubble timestamps; added centered time separators (`>= 30 minutes` or calendar date boundary, breaking visual author runs); separated gestures into single-tap bubble (2-second centered exact timestamp reveal), long-press bubble (quick reactions/actions sheet for `ACTIVE` messages), and single-tap reaction badge (`MessageReactionDetailsSheet`).

---

## 3. Latest Verified Test, Static Analysis & Samsung Acceptance Status

- **Backend Full Suite** (`.\mvnw.cmd test`):
  - **524 tests run, 0 failures, 0 errors, 1 skipped**
- **Mobile Focused Chat Pass 6 Suite** (`flutter test test/features/chat --reporter compact`):
  - **21 passed, 0 failures**
- **Mobile Focused Chat / Routing / Group Suite** (`flutter test test/features/chat test/app/routes_test.dart test/features/groups/presentation/group_widgets_test.dart --reporter compact`):
  - **86 passed, 0 failures**
- **Mobile Static Analysis** (`flutter analyze`):
  - **Clean (`No issues found!`)**
- **Mobile Full Test Suite** (`flutter test --reporter compact`):
  - **623 passed, 0 failures**
- **Samsung Physical Device (`R58M36JQYVY`)**:
  - **PASS by user** (backend `UP`, `adb reverse tcp:8080` active, latest debug APK installed, device unlocked, app foregrounded).

---

## 4. Next Actions for Incoming Agent / User

1. **Ready for M9 Commit (Requires Explicit User Approval)**:
   - Stage only the 37 M9 + agent handoff files (`16` modified tracked files + `21` untracked M9/handoff files).
   - Explicitly exclude `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `.stitch/**`, and `stash@{0}`.
   - Recommended commit message: `feat(m9): complete REST chat runtime`.
2. **After M9 Commit / Push Approval**:
   - Proceed to **M10 — Realtime WebSocket (`/ws`) + Redis** on a new milestone branch when requested by the user.
