# SYSTEM ARCHITECTURE BLUEPRINT v1.0

**Phase 6 — Architecture Baseline**

Tài liệu kiến trúc tổng thể của weDO, bám theo Product Requirement, BA Consolidated Specification, ERD/Database Design và API Contract v1.0.

## 1. Architecture Goals
- Dễ học và triển khai với Spring Boot + Flutter.
- Đủ rõ để Agent/Codex có thể code theo.
- Không over-engineering bằng microservices trong MVP.
- Hỗ trợ realtime chat, typing, presence, read receipt.
- Đảm bảo transaction/concurrency cho Activity, Expense, Settlement và Group Fund.
- Giữ API Contract là biên giới chính thức giữa mobile và backend.
- Có khả năng mở rộng sau MVP.

## 2. Architecture Decision Summary

| Decision | Choice |
|---|---|
| Repository | Monorepo |
| Backend | Spring Boot Modular Monolith |
| Mobile | Flutter Feature-first |
| Integration | REST + WebSocket |
| Primary DB | PostgreSQL |
| Realtime state | Redis |
| Schema | Flyway |
| File storage | S3-compatible / Cloudinary |
| Push | Firebase Cloud Messaging |

## 3. Why Modular Monolith

Dự án có nhiều domain như Auth, Social, Group, Chat, Activity, Finance, Fund và Notification nhưng chưa cần deploy độc lập từng service. Modular Monolith giữ module boundary rõ nhưng vẫn cho transaction nội bộ đơn giản.

Không dùng Microservices ở MVP vì sẽ phát sinh Gateway, service discovery, distributed transaction, tracing, broker, nhiều deployment và service authentication mà chưa mang lại giá trị tương xứng.

## 4. Monorepo

```text
weDO-app/
├── backend/
├── mobile/
├── docs/
├── infra/
├── .github/workflows/
├── .env.example
├── .gitignore
└── README.md
```

Backend và mobile build/deploy độc lập nhưng cùng repo để đồng bộ docs và API Contract.

## 5. Runtime Architecture

```text
Flutter
  │
  ├── REST/HTTPS ───────────────► Spring Boot
  │                              ├─ Security
  │                              ├─ Controllers
  │                              ├─ Services
  │                              ├─ Domain Events
  │                              └─ WebSocket
  │                                     │
  ├── WebSocket ────────────────────────┤
  │                                     ├── PostgreSQL
  │                                     └── Redis
  │
  ├── Direct media upload ─────────────► Object Storage
  │
  └── Push ◄──────────────────────────── FCM
```

## 6. Spring Boot Architecture

Package-by-feature:

```text
backend/src/main/java/com/wedo/backend/
├── BackendApplication.java
├── common/
├── security/
├── auth/
├── user/
├── social/
├── group/
├── chat/
├── activity/
├── poll/
├── task/
├── discussion/
├── calendar/
├── finance/
├── fund/
├── notification/
└── media/
```

Một feature điển hình:

```text
group/
├── controller/
├── service/
├── repository/
├── entity/
├── dto/
│   ├── request/
│   └── response/
├── mapper/
├── event/
└── exception/
```

Quy tắc:
- Controller mỏng.
- Service chứa business rule và transaction.
- Repository chỉ lo persistence/query.
- Entity không trả trực tiếp qua API.
- Cross-module access qua public service/facade hoặc event.
- `common` không biến thành dumping ground.

## 7. Backend Dependency Rule

```text
Controller
  ↓
Service
  ↓
Repository
  ↓
PostgreSQL
```

`@Transactional` đặt ở service/use-case boundary.

## 8. Core Modules

| Module | Responsibility |
|---|---|
| auth | register, login, verification, reset, refresh |
| user | profile, privacy |
| social | friend, block, search |
| group | group, membership, roles, invitations, bans |
| activity | lifecycle, RSVP, capacity, waitlist |
| poll | polling |
| task | lightweight task |
| discussion | activity discussion |
| chat | DM/group chat/messages/read/reactions |
| finance | expense, debt derivation, settlement |
| fund | fund, collection, contribution, ledger |
| calendar | global aggregation/reminders |
| notification | in-app + FCM |
| media | signed upload/storage key |
| search/home | aggregation/search |

## 9. Flutter Architecture

Feature-first, pragmatic Clean Architecture.

```text
mobile/lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── bootstrap/
├── core/
│   ├── network/
│   ├── auth/
│   ├── websocket/
│   ├── storage/
│   ├── error/
│   ├── config/
│   └── ui/
└── features/
    ├── auth/
    ├── social/
    ├── group/
    ├── chat/
    ├── activity/
    ├── calendar/
    ├── finance/
    ├── fund/
    └── notification/
```

Recommended direction:
- Riverpod
- Dio
- go_router
- flutter_secure_storage
- JSON serialization

## 10. REST Integration

```text
Flutter UI
 → State
 → Feature Repository
 → API Client
 → REST
 → Spring Controller
 → Service
 → Repository
 → PostgreSQL
```

API Contract v1.0 là biên giới chính thức.

## 11. Security Architecture
- Spring Security.
- Access JWT stateless.
- Refresh session server-side.
- Refresh-token rotation/revocation.
- BCrypt/PasswordEncoder.
- Current user lấy từ SecurityContext.
- Group role lấy từ DB membership, không tin request.
- Business authorization nằm ở Service/PermissionService.
- Flutter lưu token trong secure storage.

## 12. Security Persistence

`refresh_sessions`:
- id
- user_id
- token_hash
- expires_at
- revoked_at
- replaced_by_session_id
- device metadata optional
- created_at

`user_devices`:
- user_id
- platform
- FCM token
- device id
- active
- last_seen_at

## 13. Group Permission Architecture

```text
GroupPermissionService
├── requireActiveMember(...)
├── requireAdminOrOwner(...)
├── requireOwner(...)
├── canCreateActivity(...)
├── canPinMessage(...)
└── canManageTargetMember(...)
```

## 14. WebSocket Architecture

REST dùng cho CRUD/history/search/settings.
WebSocket dùng cho realtime delivery.

Core events:
- MESSAGE_CREATED
- MESSAGE_EDITED
- MESSAGE_UNSENT
- REACTION_UPDATED
- MESSAGE_READ
- MESSAGE_PINNED
- USER_TYPING
- PRESENCE_CHANGED

Flow:

```text
Flutter SEND
 → WebSocket auth/authorize
 → ChatService @Transactional
 → persist PostgreSQL
 → after commit
 → broadcast event
```

Không broadcast trước DB commit.

## 15. Redis Architecture

Redis dùng cho:
- presence
- typing TTL
- rate limit
- temporary socket/session state
- cache khi thật sự cần

```text
typing:{conversationId}:{userId} TTL=5s
presence:user:{userId}
rate-limit:verification:{userId}
```

Persistent truth không nằm Redis.

## 16. PostgreSQL & Flyway

PostgreSQL là source of truth.

```text
V1__identity_and_auth.sql
V2__social.sql
V3__groups.sql
V4__chat.sql
V5__activities.sql
V6__poll_task_discussion.sql
V7__finance.sql
V8__group_fund.sql
V9__notifications_reminders.sql
V10__cross_module_indexes.sql
```

Hibernate:

```yaml
ddl-auto: validate
```

Migration đã chạy không sửa; dùng version mới.

## 17. Transactions

Transaction-critical:
- register
- create group
- ownership transfer
- join/ban
- send message + sequence
- RSVP + waitlist
- create/edit expense
- confirm settlement
- confirm contribution
- fund expense
- reimbursement approval

Một bước fail → rollback business operation.

## 18. Concurrency & Locking

Lock-sensitive:
- slot cuối của Activity
- FIFO waitlist promotion
- conversation sequence
- pending contribution limit
- fund balance spending
- settlement confirmation

## 19. Activity Architecture

Lifecycle:

```text
PLANNING → CONFIRMED → IN_PROGRESS → COMPLETED
```

or CANCELLED.

WAITLIST do backend quyết định.
FIFO promotion phải transaction-safe.

## 20. Finance Architecture
- Expense = fact.
- ExpenseShare = obligation.
- Không có authoritative `debts` table.
- Debt = expense facts - completed settlements + pairwise netting.
- Money dùng `BigDecimal` / `NUMERIC(19,2)`.
- Finance history không hard-delete.

## 21. Settlement Architecture
- Full/partial.
- Two-sided confirmation.
- Only COMPLETED affects debt.
- Revalidate current debt at confirmation time.

## 22. Fund Architecture
- Max one fund/group MVP.
- Balance derived from ledger.
- No direct edit balance.
- Contribution only increases balance when CONFIRMED.
- Fund Expense/Reimbursement cannot make balance negative.
- Corrections via reversal.

## 23. Domain Events

Synchronous invariant remains inside transaction.

```text
Business Service
 → commit
 → Domain Event
 → Notification Listener
 → in-app notification / FCM
```

Examples:
- WAITLIST_PROMOTED
- SETTLEMENT_COMPLETED
- CONTRIBUTION_CONFIRMED
- ACTIVITY_TIME_CHANGED

## 24. Object Storage

Flutter requests signed upload target.
Flutter uploads directly.
Backend validates storage key before associating it with business entity.

Do not:
- store binary in PostgreSQL
- send Base64 media in business JSON

## 25. Notification Architecture

Business event → NotificationService → persist notification → evaluate mute/preferences → FCM if needed.

Rules:
- Open conversation → realtime, no normal chat push.
- Chat push may aggregate.
- Critical Finance/Fund/Activity events are not suppressed by chat mute.

## 26. Error Handling

Use `@RestControllerAdvice`.

```json
{
  "status": 409,
  "code": "GROUP_MEMBER_LIMIT_REACHED",
  "message": "..."
}
```

Flutter branches by `code`, not message text.

## 27. Configuration

```text
application.yml
application-local.yml
application-test.yml
application-prod.yml
```

No real secrets committed.
Use environment variables and `.env.example`.

## 28. Local Development

During development:
- Spring Boot runs natively
- Flutter runs natively
- PostgreSQL runs Docker
- Redis runs Docker

## 29. Testing

Backend:
- unit
- repository
- integration
- security
- concurrency

Flutter:
- unit
- state
- widget
- integration for critical flow

## 30. Observability
- Actuator health/readiness.
- Request correlation ID.
- No sensitive token/password logs.
- Structured error code logging.

## 31. OpenAPI

Springdoc OpenAPI/Swagger provides executable API reference.
Written API Contract remains business baseline.

## 32. Deployment

```text
Flutter
 → HTTPS/WSS
 → Spring Boot container
 → PostgreSQL
 → Redis
 → Object Storage
 → FCM
```

No domain microservice split in MVP.

## 33. Agent/Codex Rules
1. Read PR + BA + ERD + API + Architecture + Development Plan.
2. Do not silently change business rules.
3. Do not expose JPA Entity through API.
4. Do not bypass Service/PermissionService.
5. Preserve transaction boundaries.
6. Do not add mutable authoritative debt/fund balance tables.
7. Write tests for important rules.
8. Surface ambiguity before deciding.

## 34. Architecture Decision Summary

| Decision | Choice |
|---|---|
| Repo | Monorepo |
| Backend | Modular Monolith |
| Packaging | Feature-first |
| DB | PostgreSQL |
| Schema | Flyway |
| Realtime | WebSocket + Redis |
| Mobile | Flutter Feature-first |
| Media | Object Storage |
| Push | FCM |

## 35. Phase 6 Exit Criteria
- Architecture boundaries defined.
- Security direction defined.
- Database/realtime responsibilities defined.
- Transaction/concurrency strategy defined.
- Finance/fund source-of-truth rules defined.
- Local/deployment/testing baseline defined.
- Agent working rules defined.

**SYSTEM ARCHITECTURE BLUEPRINT v1.0 — BASELINE ESTABLISHED**
