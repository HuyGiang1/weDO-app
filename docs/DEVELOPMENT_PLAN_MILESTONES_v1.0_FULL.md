# DEVELOPMENT PLAN & MILESTONES v1.0

**Phase 7 — Practical Coding Roadmap**

Tài liệu chuyển PR + BA + ERD + API Contract + Architecture thành lộ trình code thực tế cho weDO.

## 1. Development Principles
1. Code theo business capability/vertical slice, không code màn hình ngẫu nhiên.
2. Backend là source of truth cho auth, permission, debt, fund balance, waitlist.
3. Flutter render state; không tự quyết định business state.
4. Flyway quản lý schema; Hibernate validate.
5. Entity != DTO.
6. Service là transaction/business boundary.
7. Realtime không thay persistent truth.
8. Mỗi milestone phải có tests và Definition of Done.

## 2. Master Roadmap

```text
M0  Repository + Bootstrap
M1  Database Foundation + Common Infrastructure
M2  Authentication + Security
M3  User Profile + Privacy
M4  Social / Friends / Block
M5  Group Core + Membership + Permission
M6  Invitation / Join Request / Ban / Archive
M7  Activity + RSVP + Waitlist
M8  Poll + Task + Discussion
M9  Chat REST
M10 WebSocket + Redis
M11 Expense + Balance
M12 Settlement
M13 Group Fund
M14 Notification + FCM
M15 Calendar + Reminder
M16 Media + Search
M17 Home Aggregation + Product Completion
M18 Hardening
M19 Deployment + Demo
```

## 3. M0 — Repository & Bootstrap

Deliverables:
- `backend/`
- `mobile/`
- `docs/`
- `infra/`
- `.github/workflows/`
- root README
- root `.gitignore`
- Spring Boot Java 21/Maven
- Flutter
- Docker Compose
- health endpoint
- Actuator
- OpenAPI
- Flutter → backend health test

DoD:
- PostgreSQL healthy.
- Redis healthy.
- Backend starts.
- Flutter starts.
- Backend health UP.
- Flutter can call backend health endpoint.
- Docs committed.
- Teammate can clone and run.

## 4. M1 — Database Foundation & Common Infrastructure

Create executable Flyway:
```text
V1 identity/auth
V2 social
V3 groups
V4 chat
V5 activities
V6 poll/task/discussion
V7 finance
V8 fund
V9 notification/reminder
V10 indexes/constraints
```

Add:
- refresh_sessions
- user_devices

Common backend:
- BusinessException
- ErrorCode
- GlobalExceptionHandler
- validation response
- pagination
- correlation ID
- time abstraction

Tests:
- clean DB migration
- unique constraints
- FK/check/partial unique indexes
- Hibernate validate

## 5. M2 — Auth + Security

Features:
- register
- verify email
- resend
- username availability
- complete profile
- login
- refresh
- logout
- forgot/reset password

Learn:
- Spring Security filter chain
- JWT
- BCrypt
- Authentication vs Authorization
- refresh token rotation

Flutter:
- auth screens
- secure storage
- Dio interceptor
- refresh interceptor
- route guard

DoD: register → verify → login → refresh → logout E2E.

## 6. M3 — User Profile + Privacy

Backend:
- UserService
- UserPrivacyService
- DTO/mappers

API:
- `/me`
- update profile
- username
- privacy
- password
- QR
- public profile

Tests:
- privacy
- collision
- sensitive-field filtering

## 7. M4 — Social

Features:
- search
- friend request
- accept/decline/cancel
- friends
- unfriend
- block/unblock

Critical rules:
- decline cooldown 24h
- cancel immediate resend
- unfriend immediate re-request
- block removes direct interaction, not shared business history

Tests: full state-transition matrix.

## 8. M5 — Group Core

Tables:
- groups
- group_settings
- group_memberships
- group_activity_logs

Backend:
- GroupService
- GroupMembershipService
- GroupPermissionService
- GroupOwnershipService

Critical:
- max 100 active members
- Owner cannot leave with others
- transfer owner transaction
- old Owner becomes Admin
- membership history retained
- one active membership/user/group

Flutter:
- Groups
- Group Overview
- Settings
- Members
- role actions

## 9. M6 — Group Join/Invite/Ban

Features:
- direct invite
- link/code/QR
- expiry/usage/revoke
- AUTO_JOIN
- APPROVAL_REQUIRED
- join request approval
- ban/unban
- archive/restore/delete

Tests:
- expired/revoked link
- banned join denied
- archived group read-only

## 10. M7 — Activity + RSVP + Waitlist

Features:
- create/update/detail/list
- confirm/cancel/complete
- RSVP
- capacity
- FIFO waitlist
- status/change history

Concurrency:
- multiple users racing for final slot

DoD: waitlist promotion is FIFO and race-safe.

## 11. M8 — Poll + Task + Discussion

Poll:
- single/multiple
- anonymity
- deadline
- close early
- vote change
- member-added option

Task:
- assignees
- claim
- TODO/IN_PROGRESS/DONE

Discussion:
- comments
- one-level reply
- moderation

Tests:
- anonymous voter hidden
- max selection
- task permission
- reply depth

## 12. M9 — Chat REST

Features:
- conversations
- group chat
- DM
- message request
- history
- send
- edit
- unsend
- delete for me
- reaction
- read
- pin
- search

Rules:
- non-friend max 3 text before accept
- 72h cooldown after decline
- edit/unsend 15m
- pin max 20
- cursor/sequence pagination

DoD: complete chat works by REST before realtime.

## 13. M10 — Realtime WebSocket + Redis

Features:
- authenticated socket
- message delivery
- typing
- presence
- read/reaction updates
- reconnect
- dedup

Redis:
- presence
- typing TTL
- session mapping

Rule: persist first, broadcast after commit.

DoD: two devices chat realtime reliably.

## 14. M11 — Expense + Derived Debt

Features:
- equal/custom expense
- payer
- participants
- optional Activity
- edit/cancel
- receipt
- balance endpoint
- pairwise netting

Use:
- Java BigDecimal
- PostgreSQL NUMERIC(19,2)

No debts table.

DoD: debt can be recomputed from facts.

## 15. M12 — Settlement

Features:
- partial/full
- two-sided confirmation
- history

States:
- PENDING
- COMPLETED
- REJECTED
- CANCELLED

Only COMPLETED affects debt.

Tests:
- over-settlement
- concurrent changes
- invalid confirmer

## 16. M13 — Group Fund

Features:
- create/close fund
- managers
- collections
- obligations
- contribution submit/confirm/reject
- fund expense
- reimbursement
- ledger
- reversal

Critical:
- no negative balance
- pending + confirmed prevent overpayment
- ledger is source of truth
- concurrent spending locked

DoD: rebuild ledger = correct balance.

## 17. M14 — Notification + FCM

Features:
- notification center
- unread
- category preferences
- group mute
- device tokens
- FCM

Architecture:
Business Event → after commit → notification → push decision.

## 18. M15 — Calendar + Reminder

Features:
- Month
- Agenda
- filters
- personal reminder
- timezone

Calendar derives from Activity.
Reminder reschedules on activity time changes.

## 19. M16 — Media + Search

Media:
- signed upload
- avatar
- chat image
- receipt/proof

Search:
- users respecting privacy
- joined groups
- activities
- conversations

## 20. M17 — Home & Product Completion

Home endpoint:
- Recent Groups
- Upcoming Activities
- Finance Summary
- Actions Required
- Recent Updates

Mobile:
```text
Home | Groups | Chat | Calendar | Profile
```

Group:
```text
Overview | Chat | Activities | Finance | Members
```

## 21. M18 — Hardening

Security:
- IDOR
- authorization matrix
- token expiry/reuse
- sensitive logging
- object ownership

Concurrency:
- final slot
- waitlist
- message sequence
- contribution limit
- fund balance
- settlement

Performance:
- indexes/query plans
- chat history
- notification
- calendar
- finance

Reliability:
- WebSocket reconnect/dedup
- push failure not rollback business transaction

## 22. M19 — Deployment & Demo

Backend:
- Dockerfile
- prod profile
- env validation
- health/readiness
- HTTPS/WSS

CI minimum:
```text
mvn test
flutter analyze
flutter test
```

Demo:
1. register/login
2. friend
3. group
4. activity/RSVP/waitlist
5. realtime chat
6. expense/debt
7. settlement
8. fund
9. notifications
10. calendar/home

## 23. Backend Learning Map

| Milestone | Concepts |
|---|---|
| M0 | Maven, profiles, Docker, Actuator |
| M1 | PostgreSQL, Flyway, constraints |
| M2 | Security, JWT, BCrypt |
| M3 | DTO/Mapper/Validation |
| M4 | State transition |
| M5 | JPA relationships, authorization |
| M7 | State machine, locking |
| M9 | cursor pagination |
| M10 | WebSocket, Redis |
| M11 | BigDecimal, derived state |
| M13 | ledger, concurrency |
| M14 | domain events, FCM |
| M18 | testing/security/performance |
| M19 | Docker/CI/deployment |

## 24. Working Cycle per Milestone

```text
1. Read specs
2. Explain business rules
3. Design classes/files
4. Review migration/schema
5. Implement entity/repository
6. Implement service
7. Implement controller/API
8. Write tests
9. Run tests
10. Explain code
11. Implement Flutter integration
12. E2E test
13. Review against BA/API
14. Commit
```

## 25. Codex Prompt Template

```text
Read all docs in /docs:
- Product Requirement
- BA Specification
- ERD
- API Contract
- Architecture
- Development Plan

Current milestone: [MILESTONE]

Before coding:
- summarize relevant business rules
- list DB/API/classes
- verify dependencies
- surface ambiguities

Then guide implementation step-by-step.
Do not silently change business rules/schema.
Do not expose JPA Entity as API DTO.
Keep transaction boundaries in service.
Write tests.
Explain what I am learning.
At the end, review against BA + API and Definition of Done.
```

## 26. Branch Strategy

For a small team, use `main` plus feature branches.

Examples:
```text
feat/auth-security
feat/group-core
feat/activity
feat/chat-rest
feat/chat-realtime
feat/finance-expense
feat/group-fund
```

## 27. Commit Convention

```text
feat:
fix:
test:
refactor:
docs:
chore:
```

## 28. Definition of Done

A milestone is done when:
- BA rules reviewed.
- ERD mapping correct.
- API contract correct.
- permission tested.
- validation tested.
- error codes correct.
- transaction correct.
- no Entity leak.
- OpenAPI updated.
- tests pass.
- Flutter flow works.
- loading/error/empty states handled.
- architecture rules respected.

## 29. Special Control Areas

Not normal CRUD:
- Group permissions/ownership/history
- Activity lifecycle/capacity/waitlist
- Chat visibility/message request/sequence
- Debt derived state
- Settlement two-sided confirmation
- Fund ledger/reversal/locking
- Notification after-commit behavior

## 30. Phase 8 Starting Sequence

```text
1 Create/clone repo
2 Monorepo folders
3 Spring Boot
4 Flutter
5 PostgreSQL + Redis
6 Profiles/config
7 Error foundation
8 Flyway schema
9 Actuator + OpenAPI
10 Flutter→backend health
11 Commit M0
12 Begin M1/M2 according to plan
```

## 31. Dependency Graph

```text
M0 → M1 → M2 → M3 → M4 → M5 → M6
                         ↓
                        M7 → M8
                         ↓
                        M9 → M10
                         ↓
                       M11 → M12 → M13
                                   ↓
                                  M14 → M15 → M16 → M17 → M18 → M19
```

## 32. Phase 7 Exit Criteria
- Milestones defined.
- Dependencies defined.
- Backend/mobile/DB mapping defined.
- Learning goals defined.
- Tests/DoD defined.
- Transaction/concurrency risks identified.
- Agent workflow defined.
- Phase 8 starting point explicit.

**DEVELOPMENT PLAN & MILESTONES v1.0 — BASELINE ESTABLISHED**
