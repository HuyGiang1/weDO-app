# weDO Agent Project Context (STATIC)

> **Document Role — STATIC**: This file records long-lived repository architecture, technology stack, domain rules, milestone roadmap, and engineering conventions. Do **not** store temporary task notes, active worktree diffs, or volatile test counts here (those belong in `docs/AGENT_CURRENT_HANDOFF.md`). Stable architectural/product rulings belong in `docs/AGENT_DECISION_LOG.md`.

---

## 1. Product Purpose

**weDO** is a collaborative group coordination, event planning, communication, and shared finance application. It enables users to:
- Form and manage **Groups** (`ACTIVE`, `ARCHIVED`, `DELETED`, up to 100 active members) with invitations, join links/codes/QR, join requests, and bans.
- Plan **Activities** (scheduled or unscheduled) with lifecycle transitions (`PLANNING -> CONFIRMED -> IN_PROGRESS -> COMPLETED` or `CANCELLED`), capacity management, and race-safe FIFO **Waitlists** / **RSVPs**.
- Collaborate inside Activities via **Polls**, **Tasks**, and **Discussions** (comments + 1-level replies).
- Communicate via **Group Chat** (one canonical chat per group) and **Direct Messages (DM)** with stranger **Message Requests**, reactions, replies, pins, read receipts, and search.
- Track shared **Expenses**, derived **Debts**, two-sided **Settlements**, and ledger-backed **Group Funds** (collections, contributions, fund expenses, reimbursements, and 1-to-1 reversals).
- View cross-group **Calendars**, **Reminders**, **Notifications**, and the **Home** aggregation dashboard.

---

## 2. Monorepo Structure

| Path | Responsibility |
| --- | --- |
| `backend/` | Spring Boot 4.1.1 (Java 21, Maven wrapper `mvnw.cmd`) REST API, security, domain services, Flyway migrations (`src/main/resources/db/migration`), and JUnit/Testcontainers suites. |
| `mobile/` | Flutter consumer application (`lib/main.dart`, `lib/app/app.dart`, `lib/app/routes.dart`, and feature modules under `lib/features/<feature>/{data,domain,presentation}`). |
| `docs/` | Canonical product/API/DB specifications, milestone plans, `architecture/CLASS_DIAGRAM.puml`, `LOCAL_DEVELOPMENT.md`, and the `AGENT_*.md` handoff system. |
| `infra/` | Local infrastructure (`docker-compose.yml` running `wedo-postgres` on port 5432 and `wedo-redis` on port 6379). |
| `scripts/` | Local Windows runner scripts (`dev-run.cmd`, `dev-run.ps1`, `dev-stop.cmd`, `dev-stop.ps1`, `agent-handoff.ps1`). |
| `.agents/` | Agent delivery workflow skill (`.agents/skills/wedo-milestone-delivery/SKILL.md`). |

---

## 3. Backend & Mobile Technology Stack

- **Backend**:
  - Java 21, Spring Boot 4.1.1, Spring Security, Spring Data JPA + `JdbcTemplate`, Bean Validation, Actuator, OpenAPI.
  - **Database**: PostgreSQL 17 (`UUID` PKs, `CITEXT` for username/email, `TIMESTAMPTZ` for timestamps, `NUMERIC(19,2)` for monetary amounts). Schema managed by Flyway (`V0`..`V12`+); validated by Hibernate.
  - **Cache / Ephemeral Store**: Redis (used for ephemeral realtime state in M10; PostgreSQL remains persistent business truth).
  - **Authentication**: Stateless access JWT (15-minute TTL) paired with database-persisted rotating `refresh_sessions` (14-day sliding TTL, 30-day absolute family deadline via `V11`).
- **Mobile (Flutter)**:
  - Feature-sliced architecture (`data` APIs/DTOs/repositories, `domain` models/controllers, `presentation` screens/widgets).
  - `DioClient` with `AuthInterceptor` (Bearer attachment + generation-aware single-flight refresh on `401 AUTH_TOKEN_EXPIRED` via isolated `DioClient.raw` transport) and `AuthSessionInvalidator`.
  - Single route registry in `mobile/lib/app/routes.dart` (`AppRoutes`) where every route declares `AppRouteAccess.public` or `AppRouteAccess.authenticated`, enforced by `AuthRouteGuard`.

---

## 4. Major Domain Model & Role Model

### Domain Subsystems (Reference: `docs/ERD_DATABASE_DESIGN_v1.0.md` & `docs/architecture/CLASS_DIAGRAM.puml`)
1. **Identity & Auth**: `users`, `user_credentials`, `user_privacy_settings`, `auth_tokens`, `refresh_sessions`, `user_devices`.
2. **Social**: `friend_requests`, `friendships`, `user_blocks`, `user_presence_snapshots`.
3. **Group**: `groups`, `group_settings`, `group_memberships`, `group_invitations`, `group_invite_links`, `group_join_requests`, `group_bans`, `group_activity_logs`.
4. **Chat**: `conversations`, `direct_conversations`, `group_conversations`, `message_requests`, `conversation_sequences`, `messages`, `message_attachments`, `message_edit_history`, `message_hidden_users`, `message_reactions`, `conversation_read_states`, `message_pins`.
5. **Activity**: `activities`, `activity_participants`, `activity_rsvp_history`, `activity_waitlist_sequences`, `activity_status_history`, `activity_change_logs`.
6. **Poll / Task / Discussion**: `polls`, `poll_options`, `poll_votes`, `poll_vote_choices`, `tasks`, `task_assignees`, `task_status_history`, `activity_comments`.
7. **Finance & Group Fund**: `expenses`, `expense_shares`, `expense_change_logs`, `settlements`, `settlement_status_history`, `group_funds`, `fund_managers`, `fund_collections`, `fund_collection_obligations`, `fund_contributions`, `fund_expenses`, `fund_reimbursements`, `fund_transactions`, `fund_transaction_reversals` (no authoritative `debts` table; debt and fund balance are derived).
8. **Calendar & Notification**: `user_activity_reminders` (calendar is derived from Activities), `notifications`, `user_notification_settings`, `group_notification_settings`.

### Role Model (Reference: `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` §1, §5, §20)
- **Global Actors**: `Guest` (unauthenticated), `User` (authenticated onboarded user).
- **Group Roles** (`group_memberships.role` for `ACTIVE` memberships):
  - `OWNER`: Highest authority. Manages Admin/Member roles, transfers ownership (demoting previous Owner to `ADMIN`), archives/restores/deletes the group, kicks/bans Admins or Members, manages group settings and Group Fund. Cannot leave while other active members remain without transferring ownership first.
  - `ADMIN`: Manages Members, moderates group resources (activities, polls, tasks, discussion comments, pinned messages), approves join requests, manages invitations/links. Cannot manage or kick/ban the `OWNER`.
  - `MEMBER`: Standard participant. Capabilities for editing group profile, creating activities, or pinning messages depend on `group_settings` and resource-specific ownership/assignment rules.
  - `Fund Manager`: `OWNER` or an `ADMIN` explicitly granted fund management rights in `fund_managers`.

---

## 5. Milestone Roadmap (M0–M19)

Reference: `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` §2.

| Milestone | Scope | Status |
| --- | --- | --- |
| `M0` | Repository + Bootstrap (Spring Boot, Flutter, Docker, Health/OpenAPI) | Completed |
| `M1` | Database Foundation (`V1`–`V10`) + Common Infrastructure | Completed |
| `M2` | Authentication + Security (`V11` session family hardening, JWT, Refresh/Route Guard) | Completed |
| `M3` | User Profile + Privacy + Personal QR | Completed |
| `M4` | Social / Friends / Friend Requests / Block | Completed |
| `M5` | Group Core + Membership + Permission + Ownership Transfer | Completed |
| `M6` | Group Invitations / Join Links / Join Requests / Ban / Archive / Delete | Completed |
| `M7` | Activity + RSVP + FIFO Waitlist (`V12` unscheduled activities) | Completed |
| `M8` | Poll + Task + Activity Discussion | Completed |
| `M9` | Chat REST (Conversations, Group/DM, Message Requests, Reactions, Read State, Pins, Search) | Completed (`feat/m9-chat-rest`) |
| `M10` | Realtime WebSocket (`/ws`) + Redis (Live delivery, Typing, Presence) | Implemented; pre-commit review on `feat/m10-chat-realtime` |
| `M11` | Expense + Balance (Equal/Custom split, derived debt) | Planned |
| `M12` | Settlement (Two-sided confirmation workflow) | Planned |
| `M13` | Group Fund (Collections, Contributions, Fund Expenses, Reimbursements, Ledger) | Planned |
| `M14` | Notification + FCM | Planned |
| `M15` | Calendar + Reminder | Planned |
| `M16` | Media + Search | Planned |
| `M17` | Home Aggregation + Product Completion | Planned |
| `M18` | Hardening | Planned |
| `M19` | Deployment + Demo | Planned |

---

## 6. Canonical Source-of-Truth Hierarchy

When resolving ambiguity or conflicts, agents must follow this strict precedence order:

1. **Live Repository & Database Schema Authority**:
   - Flyway migrations (`backend/src/main/resources/db/migration/V*.sql`) first, current JPA entities/repositories/services second, and `docs/ERD_DATABASE_DESIGN_v1.0.md` + `docs/architecture/CLASS_DIAGRAM.puml` third.
   - Current git worktree (`git status`, `git diff`, untracked milestone files) is authoritative for unfinished work in the active milestone.
2. **Canonical Product & API Specifications**:
   - `docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md` (business rules, state machines, role rules)
   - `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` (endpoints, DTO shapes, permission rules, error codes)
   - `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` (milestone boundaries, acceptance notes)
   - `docs/LOCAL_DEVELOPMENT.md` (local runner, QA accounts, smoke procedures)
3. **Agent Handoff & Decision Docs**:
   - `AGENTS.md`, `docs/AGENT_PROJECT_CONTEXT.md`, `docs/AGENT_DECISION_LOG.md`, `docs/AGENT_CURRENT_HANDOFF.md`.

---

## 7. Engineering Rules & Conventions

### API & Permission Principles
- **Server-Authoritative Enforcement**: All authorization, role checks, group/activity lifecycle locks (`ARCHIVED`, `COMPLETED`, `CANCELLED`), and time-window validations (`<= 15m` edit/unsend) are enforced on the backend.
- **Projected Permission Flags**: Backend DTOs project explicit boolean permission flags (e.g. `canEdit`, `canDelete`, `canChangeStatus`, `canClaim`, `canManageAssignees`, `canVote`, `canComment`, `canReply`, `readOnly`). Flutter renders controls strictly from server-projected flags and must never re-implement `OWNER`/`ADMIN` role checks locally.
- **Anti-IDOR**: Cross-group, cross-conversation, banned, removed, or blocked access attempts are rejected server-side.

### Database Migration Rules
- Never edit existing committed Flyway migrations (`V0`..`V12`).
- Only introduce a new ordered migration (`V13+`) when the current milestone schema genuinely requires a DDL change (e.g., `V4` already covers M9 Chat; `V6` already covers M8 Poll/Task/Discussion).
- Update `docs/ERD_DATABASE_DESIGN_v1.0.md` and `docs/architecture/CLASS_DIAGRAM.puml` in the same milestone whenever schema/entities change.

### Flutter, Stitch, Vietnamese UI & Date-Time Rules
- **Stitch Visual Fidelity**: Use local Stitch exports (`.stitch/` and `docs/M8_STITCH_FIDELITY_INVENTORY.md`) as the visual reference for layout, card surfaces, bottom sheets, and typography while keeping backend contracts and permission rules authoritative. Never modify `.stitch/` files unless asked.
- **Vietnamese UI Rule**: All consumer-facing copy must use natural Vietnamese with complete diacritics (e.g. `"Trò chuyện"`, `"Cần làm"`, `"Đang thực hiện"`, `"Hoàn thành"`, `"Thu hồi tin nhắn"`, `"Xóa tin nhắn"`, `"Biểu cảm"`). Never expose raw enum constants, UUIDs, or internal storage keys in the UI.
- **Deadline / Date-Time Rule**: Every user-facing deadline, `dueAt`, or expiry input must collect and validate a complete local date **and** time. Same-day future times are valid. API payloads serialize explicit UTC offsets (`TIMESTAMPTZ` / ISO-8601).
- **Global vs Contextual Navigation**: Global bottom navigation (`Home | Groups | Chat | Calendar | Profile`) must keep tab roots independent. Tapping global `Chat` always opens Chat Home (`/chat`) without inheriting any `groupId` or `conversationId`; group-specific `"Trò chuyện"` actions open `/groups/chat` for that specific group.

### M9 / M10 Boundary
- **M9 (Chat REST)**: Complete chat lifecycle over REST (conversation listing & idempotent active group chat materialization, DMs, 3-text message requests, 72h decline cooldown, sequence history pagination, text send, reply, 15m edit/unsend, delete-for-me, 6-emoji quick reactions + REST reaction details sheet, `lastReadSequence` read state, pins `<= 20`, and search). `V4` `message_attachments` is reserved schema support; attachment upload/rendering belongs to dedicated media scope.
- **M10 (Realtime WebSocket + Redis)**: Authenticated `/ws`, live message/reaction/read broadcast, ephemeral Redis typing indicators, Redis presence, reconnect, and deduplication. Do not introduce WebSocket, Redis pub/sub, or polling hacks into M9.

---

## 8. Testing, Samsung Physical-Device Runner & QA Accounts

### Verification Ladder
1. **Focused checks** during iteration:
   - Backend: `cd backend && .\mvnw.cmd -Dtest=<TestClass> test`
   - Mobile: `cd mobile && flutter test <test_file_path>`
2. **Full closeout checks**:
   - Backend: `cd backend && .\mvnw.cmd test`
   - Mobile static analysis: `cd mobile && flutter analyze`
   - Mobile full unit/widget suite: `cd mobile && flutter test --reporter compact`
   - Mobile debug APK build (required when mobile production code changes):
     `cd mobile && flutter build apk --debug --dart-define=WEDO_API_BASE_URL=http://127.0.0.1:8080`
   - Repository hygiene: `git diff --check`, `git status --short`, `git diff --stat`, `git stash list`.

### Samsung Physical-Device E2E & Local Runner
- Configured physical device: Samsung `SM_G975U1` (`DeviceId = R58M36JQYVY`).
- Start full local stack + ADB reverse (`tcp:8080 -> tcp:8080`) + launch app: `.\scripts\dev-run.cmd`
- Stop backend process: `.\scripts\dev-stop.cmd`
- Stop backend + Docker infrastructure: `.\scripts\dev-stop.cmd -StopInfra`
- Do not change the machine's PowerShell execution policy permanently (`dev-run.cmd` runs PowerShell with `-NoProfile -ExecutionPolicy Bypass` per invocation).

### Local QA Accounts (Reference: `docs/LOCAL_DEVELOPMENT.md`)
When started via `.\scripts\dev-run.cmd` (`local` profile with `WEDO_LOCAL_TEST_DATA_ENABLED=true`), the backend idempotently seeds the `weDO QA Team` group and 5 local QA accounts (`owner@wedo.local`, `admin@wedo.local`, `member1@wedo.local`, `member2@wedo.local`, and `outsider@wedo.local`). See `docs/LOCAL_DEVELOPMENT.md` for credentials and multi-account test harness usage.

---

## 9. Git Workflow, Local-Only Exclusions & Commit/Push Rules

- **Branching**: Each milestone uses a dedicated feature branch off `dev` (e.g., `feat/m9-chat-rest`). Never implement milestone work directly on `dev` or `main`.
- **No Destructive Git Operations**: Never run `reset`, `clean`, `restore`, `stash drop/pop`, or `commit --amend` without explicit user authorization.
- **Local-Only Exclusions**:
  - `docs/LEARNING_HANDBOOK_M0_M2.md` (user-local learning handbook — never modify, stage, or delete)
  - `docs/M8_STITCH_FIDELITY_INVENTORY.md` (user-local Stitch fidelity inventory — never modify, stage, or delete)
  - `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync` (protected stash — never pop or drop)
  - `.dev-runtime/`, `.dev-logs/`, `.stitch/`
- **Explicit Two-Step Authorization**:
  1. **Commit requires explicit user approval.**
  2. **Push requires separate explicit user approval** (never treat commit approval as push approval).
