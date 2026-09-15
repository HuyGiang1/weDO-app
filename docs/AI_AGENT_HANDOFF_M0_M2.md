# weDO AI Agent Handoff Document (M0 – M2)

**Document Version:** 1.0  
**Project:** weDO (`weDO-app`)  
**Status:** Milestone 0 (Bootstrap), Milestone 1 (Database Foundation), Milestone 2 (Authentication & Security) are **COMPLETE**.  
**Current Milestone:** Milestone 3 (User Profile + Privacy) is **NOT STARTED**.  
**Audience:** AI Agent / Technical Assistant / Senior Technical Reviewer for future context recovery.

---

## 1. Project Purpose & Scope

`weDO` is a mobile application for group activity coordination, communication, social networking, and group financial management (shared expenses, debts, settlements, and group funds).
The system prioritizes:
- **Backend as single source of truth** for identity, authentication, permissions, financial debts, activity capacities, and waitlists.
- **Strict architectural layer boundaries** separating presentation, domain logic, data persistence, and transport.
- **Deep engineering excellence** emphasizing concurrency control, state-machine integrity, cryptographic hygiene, race condition prevention, and fail-closed security.
- **Production-grade patterns**: Stateless JWT access tokens + server-persisted, revocable, rotating refresh tokens with absolute family lifetimes and generation-aware client interceptors.

---

## 2. Technology Stack

| Layer / Component | Technology & Version | Responsibility / Details |
|---|---|---|
| **Backend Framework** | Spring Boot `4.1.1` (Java 21 LTS) | Modular monolith architecture, Spring WebMVC, Spring Security 6.x |
| **Persistence / ORM** | Spring Data JPA / Hibernate, PostgreSQL 17 | Relational persistence, row-level pessimistic locking (`PESSIMISTIC_WRITE`) |
| **Database Migrations** | Flyway (`flyway-database-postgresql`) | Schema evolution (`V0` through `V11` executable scripts) |
| **Cache & Realtime State** | Redis 7 (`spring-boot-starter-data-redis`) | Rate limiting, ephemeral presence/typing/WebSocket (M10+) |
| **JWT / Cryptography** | `io.jsonwebtoken:jjwt` `0.13.0`, BCrypt, HMAC-SHA256 | Access JWT generation/verification, password hashing, token pepper hashing |
| **API Documentation** | SpringDoc OpenAPI `3.0.0` (Swagger UI) | OpenAPI specification and contract visibility |
| **Mobile Framework** | Flutter `>=3.13.1` / Dart | Feature-first architecture, Navigator 1.0 fail-closed routing |
| **Mobile Networking** | Dio `5.9.1` | HTTP transport with custom generation-aware `AuthInterceptor` |
| **Mobile Secure Storage** | `flutter_secure_storage` `10.0.0` | OS Keychain (iOS) / Keystore (Android) abstraction |
| **Infrastructure / Containers**| Docker Compose (`infra/docker-compose.yml`) | Local services: PostgreSQL 17 (`wedo-postgres`), Redis 7 (`wedo-redis`) |
| **Testing Frameworks** | JUnit 5, AssertJ, Mockito, Testcontainers (PostgreSQL), Flutter Test | Unit, SpringBootTest integration, widget, and live client-backend E2E suites |

---

## 3. Repository Structure & Monorepo Boundaries

```text
weDO-app/
├── .github/workflows/          # CI/CD automation pipelines
├── backend/                    # Spring Boot application (Maven)
│   ├── src/main/java/com/wedo/backend/
│   │   ├── BackendApplication.java
│   │   ├── common/             # Global error handling, filters, health, base DTOs, time config
│   │   ├── security/           # Spring Security filter chain, JWT service, security error writer
│   │   ├── auth/               # Authentication domain (controllers, services, entities, DTOs, security)
│   │   ├── user/               # User entity, credential, privacy settings, user service & controller
│   │   ├── notification/       # Notification settings entity & repository (initialized in M2.4)
│   │   └── [activity, calendar, chat, discussion, finance, fund, group, media, poll, social, task]/ # Skeletons (.gitkeep)
│   ├── src/main/resources/
│   │   ├── db/migration/       # Flyway migrations (V0__bootstrap.sql to V11__session_family_hardening.sql)
│   │   ├── application.yml     # Base Spring configuration
│   │   ├── application-local.yml # Local development profile configuration
│   │   └── application-test.yml  # Test profile configuration
│   └── pom.xml
├── mobile/                     # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart           # Production entrypoint & manual dependency composition
│   │   ├── app/                # App widget, theme, single-source AppRoutes registry, AuthRouteGuard
│   │   ├── core/
│   │   │   ├── auth/           # SessionRevisionTransition, SessionInvalidationOutcome models
│   │   │   ├── network/        # AccessTokenHolder, ApiConfig, ApiException, AuthInterceptor, DioClient
│   │   │   ├── storage/        # SecureStorageService, SecureKeyValueStore abstraction
│   │   │   └── ui/widgets/     # Reusable design system widgets (AppTextField, PrimaryButton, etc.)
│   │   └── features/
│   │       ├── auth/           # Complete Auth feature slice (presentation, application, data, models)
│   │       └── [activity, calendar, chat, discussion, finance, fund, group, media, notification, poll, social, task, user]/ # Skeletons (.gitkeep)
│   ├── test/                   # Comprehensive offline unit, repository, controller, and widget tests
│   └── test_e2e/               # Live client-backend integration test harness (live_auth_e2e_test.dart)
├── docs/                       # Architecture blueprints, PRD, BA specs, ERD, and runbooks
├── infra/                      # Docker Compose local dependencies (PostgreSQL 17, Redis 7)
└── README.md                   # Project overview and developer onboarding instructions
```

---

## 4. Milestone 0 Summary (Bootstrap & Baseline)

- **Objective**: Establish monorepo structure, build tools, containerized local dependencies, and verifiable health connectivity.
- **Implemented**:
  - Root repo baseline, Git ignores, and directory organization (`backend/`, `mobile/`, `docs/`, `infra/`).
  - Spring Boot 4.1.1 bootstrap with Java 21, Spring Actuator `/actuator/health`, and OpenAPI documentation.
  - Custom health endpoint `GET /api/v1/health` returning `{"status":"UP"}`.
  - Docker Compose configuration (`infra/docker-compose.yml`) for PostgreSQL 17 (port 5432) and Redis 7 (port 6379) with healthchecks.
  - Flutter application skeleton with core theme tokens, `DioClient`, and `HealthService`.
  - Backend integration test verifying health endpoint.
  - Flutter unit test verifying health endpoint deserialization.
- **Status**: COMPLETE.

---

## 5. Milestone 1 Summary (Database Foundation & Infrastructure)

- **Objective**: Define executable relational database schema across all planned product domains, establish common backend error handling, Request ID tracing, and pagination abstractions.
- **Implemented**:
  - Flyway executable migrations:
    - `V0__bootstrap.sql`: Baseline marker.
    - `V1__identity_and_auth.sql`: Tables `users`, `user_credentials`, `user_privacy_settings`, `auth_tokens`, `refresh_sessions`, `user_devices`.
    - `V2__social.sql`: Tables `friend_requests`, `friendships`, `user_blocks`.
    - `V3__groups.sql`: Tables `groups`, `group_settings`, `group_memberships`, `group_invitations`, `group_join_requests`, `group_activity_logs`, `group_bans`.
    - `V4__chat.sql`: Tables `conversations`, `conversation_members`, `messages`, `message_attachments`, `message_reactions`, `message_receipts`.
    - `V5__activities.sql`: Tables `activities`, `activity_rsvps`, `activity_waitlist`.
    - `V6__poll_task_discussion.sql`: Tables `polls`, `poll_options`, `poll_votes`, `tasks`, `task_assignments`, `discussions`, `discussion_comments`.
    - `V7__finance.sql`: Tables `expenses`, `expense_splits`, `debts`, `settlements`.
    - `V8__fund.sql`: Tables `group_funds`, `fund_collections`, `fund_collection_targets`, `fund_contributions`, `fund_expenses`, `fund_reimbursements`, `fund_ledger_entries`.
    - `V9__notifications.sql`: Tables `user_notification_settings`, `notifications`, `reminders`.
    - `V10__cross_module_indexes.sql`: Cross-module foreign keys, composite performance indexes, and partial unique constraints.
  - Common Backend Infrastructure:
    - `BusinessException` and comprehensive `ErrorCode` enum.
    - `GlobalExceptionHandler` mapping exceptions to standard `ApiErrorResponse` (`timestamp`, `status`, `code`, `message`, `path`, `requestId`, `errors`).
    - `RequestIdFilter` ensuring MDC logging context and `X-Request-ID` HTTP header propagation.
    - `PagedResponse<T>` pagination model.
    - `TimeConfig` exposing a injectable `Clock` bean (`Clock.systemUTC()`).
  - Test suite with Testcontainers verifying database migration execution and Hibernate schema validation (`ddl-auto: validate`).
- **Status**: COMPLETE.

---

## 6. Milestone 2 Summary (Authentication & Security M2.1 – M2.16)

M2 delivered a fully hardened, defense-in-depth authentication slice across backend and mobile:

- **M2.1 Auth JPA Mapping Foundation**: JPA entities mapped to V1 schema (`UserEntity`, `UserCredentialEntity`, `UserPrivacySettingsEntity`, `AuthTokenEntity`, `RefreshSessionEntity`).
- **M2.2 Security Foundation + BCrypt**: Spring Security `SecurityFilterChain`, `BCryptPasswordEncoder` (10 rounds), `AuthenticatedUserPrincipal`.
- **M2.3 JWT Foundation**: `JwtService` implementing HMAC-SHA256 signing for access tokens (15m TTL, minimal claims: `sub`, `iat`, `exp`).
- **M2.4 User Registration**: `POST /api/v1/auth/register`. Normalizes email, validates password (8..72 chars, <=72 UTF-8 bytes for BCrypt), creates `UserEntity` (`PENDING_VERIFICATION`), `UserCredentialEntity`, default privacy settings, default notification settings, generates 6-digit verification code hashed with HMAC-SHA256 pepper into `auth_tokens`, publishes `EmailVerificationRequestedEvent`.
- **M2.5 Verify Email & Resend**: `POST /api/v1/auth/verify-email`. Validates 6-digit code, max 5 attempts with attempt persistence, transitions user to `ACTIVE`, issues short-lived `profileCompletionToken` (15m TTL). `POST /api/v1/auth/resend-verification` with 60s cooldown.
- **M2.6 Username Availability & Complete Profile**: `GET /api/v1/auth/usernames/{username}/availability` (case-insensitive, returns 200 with `available: boolean`). `POST /api/v1/auth/complete-profile` consumes `profileCompletionToken` (client never submits `userId`), validates username (`^[a-zA-Z0-9_]{3,30}$`), normalizes to lowercase, updates profile, returns `nextStep: LOGIN`.
- **M2.7 Login & Initial Refresh Session**: `POST /api/v1/auth/login`. Timing-mitigated credential verification (dummy password check for non-existent users), account lockout policy (5 failed attempts -> 15-minute lock), status disclosure ordering (checks status only after password verification). Two branches:
  1. *Profile Incomplete Recovery*: Returns `profileCompletionToken` + `nextStep: COMPLETE_PROFILE`.
  2. *Authenticated Session*: Returns `accessToken` (15m), opaque random `refreshToken` (43 chars URL-safe Base64), and creates row in `refresh_sessions`.
- **M2.8 Refresh Token Rotation**: `POST /api/v1/auth/refresh`. Verifies unexpired, unrevoked refresh token hash under row-level pessimistic lock, rotates parent session (`revokedAt = now`, `replacedBySessionId = childId`), issues new access token and new opaque refresh token. Enforces account status control point (revokes session on non-ACTIVE status). Replay of already-rotated token returns `401 REFRESH_TOKEN_INVALID` without broad compromise revocation.
- **M2.9 Logout**: `POST /api/v1/auth/logout`. Narrow current-session revocation (`revokedAt = now`, `replacedBySessionId = null`). Idempotent for non-rotated revoked sessions. Concurrency serialized via row lock.
- **M2.10 Password Recovery**: `POST /api/v1/auth/forgot-password` (neutral HTTP 200 response). `POST /api/v1/auth/reset-password` (one-time 6-digit OTP, 15m TTL, max 5 attempts, unified `PASSWORD_RESET_CODE_INVALID` HTTP 400 error, clears lockout, mandatory bulk revocation of all active refresh sessions for the user). Established global per-user lock hierarchy: `UserCredential -> RefreshSession`.
- **M2.11 Bearer Authentication & Current User**: `JwtAuthenticationFilter` (zero-DB-hit stateless filter). Protected endpoint `GET /api/v1/me` returning `MyProfileResponse`. Enforces database status (`ACTIVE` -> 200, `SUSPENDED`/`DEACTIVATED`/`PENDING_VERIFICATION` -> 403). Consolidated `SecurityErrorResponseWriter` emitting standard application error envelope.
- **M2.12 Session Family Hardening**: Migration `V11__session_family_hardening.sql` adding `absolute_expires_at TIMESTAMPTZ`. Login establishes 30-day fixed family deadline. Refresh rotation inherits family deadline; repeated refreshes cannot slide past family cap. Child expiration clamped to `min(now + 14d, familyDeadline)`. Optional `X-Device-Name` and server-observed remote IP capture.
- **M2.13 Flutter Auth Screens**: Responsive, accessible auth screens with strict design system adherence: `WelcomeScreen`, `RegisterScreen`, `VerifyEmailScreen`, `CreateUsernameScreen`, `CompleteProfileScreen`, `LoginScreen`, `ForgotPasswordScreen`, `ResetPasswordScreen`, `OtpCodeField`.
- **M2.14 Flutter Network & Secure Storage Foundation**: `DioClient`, `SecureStorageService` backed by `SecureKeyValueStore`, in-memory `AccessTokenHolder`, `AuthApi`, `AuthRepository` with FIFO credential mutation queue.
- **M2.15 Refresh Lifecycle, Interceptor & Route Guard**:
  - M2.15.1 *Startup Session Restoration*: Lazy bootstrap without network calls; restores tokens to RAM if both present; evicts corrupt partial pairs.
  - M2.15.2 *Isolated Refresh Transport*: Dedicated raw `Dio` instance without interceptors for `POST /api/v1/auth/refresh`.
  - M2.15.3 *Generation-Aware AuthInterceptor*: Automatic refresh strictly on `401 AUTH_TOKEN_EXPIRED`; generation-scoped single-flight refresh; atomic stale-401 retry authorized by `SessionRevisionTransition`; TOCTOU pre-dispatch generation check; max 1 retry per request.
  - M2.15.4 *Generation-Aware Session Invalidation*: `AuthSessionInvalidator` handles definitive refresh failures and `401 AUTH_TOKEN_INVALID`; generation-bounded invalidation (`SessionInvalidationSuperseded` vs `SessionInvalidationApplied`).
  - M2.15.5 *Fail-Closed Route Guard*: Single `AppRoutes` registry requiring `AppRouteAccess`; pure `AuthRouteGuard.evaluate(access, authStatus)`; denied routes return null.
- **M2.16 Auth E2E & DoD**: Live client-backend integration test harness (`mobile/test_e2e/live_auth_e2e_test.dart`) executing the full canonical flow against live Spring Boot and PostgreSQL via test OTP resolver (`OtpResolverTest`).
- **Status**: COMPLETE.

---

## 7. Backend Architecture

### Request Pipeline & Security Filter Chain
```text
HTTP Request
  │
  ├── RequestIdFilter               (Generates UUID, sets MDC 'requestId', adds X-Request-ID response header)
  │
  ├── SecurityFilterChain
  │     ├── CorsFilter / CsrfFilter (CSRF disabled for stateless REST)
  │     ├── JwtAuthenticationFilter (OncePerRequestFilter, Zero-DB-hit Bearer access-JWT parser)
  │     │     ├─ Missing/Non-Bearer -> passes through to chain
  │     │     ├─ Valid Bearer       -> populates SecurityContext with AuthenticatedUserPrincipal(userId)
  │     │     ├─ Expired Bearer     -> writes 401 AUTH_TOKEN_EXPIRED via SecurityErrorResponseWriter
  │     │     └─ Invalid Bearer     -> writes 401 AUTH_TOKEN_INVALID via SecurityErrorResponseWriter
  │     ├── RestAuthenticationEntryPoint (Writes 401 UNAUTHORIZED on unauthenticated protected access)
  │     ├── RestAccessDeniedHandler      (Writes 403 ACCESS_DENIED on unauthorized access)
  │     └── AuthorizationFilter     (Permits public endpoints, requires authentication for protected)
  │
  ├── Resource Controller           (@RestController, validates incoming DTOs via @Valid)
  │     ↓
  ├── Service Layer                 (@Service, @Transactional boundary, business validation, locking)
  │     ↓
  ├── Repository Layer              (Spring Data JPA, row-level locking, entity persistence)
  │     ↓
  └── PostgreSQL Database           (Persistent relational truth)
```

### Core Backend Classes & Responsibilities

| Class Path | Role | Who Calls It | What It Calls |
|---|---|---|---|
| `security.SecurityConfig` | Spring Security configuration bean | Spring Boot Container | Instantiates `JwtAuthenticationFilter`, configures public/protected routes, registers entry points |
| `security.jwt.JwtService` | Access JWT generation & parsing | `AuthService`, `JwtAuthenticationFilter` | JJWT library, cryptographic keys |
| `security.jwt.JwtAuthenticationFilter` | Stateless Bearer token filter | Servlet Container | `JwtService`, `SecurityErrorResponseWriter` |
| `security.SecurityErrorResponseWriter` | Standard error JSON renderer | `JwtAuthenticationFilter`, `RestAuthenticationEntryPoint`, `RestAccessDeniedHandler` | `ObjectMapper`, `ApiErrorResponse` |
| `auth.controller.AuthController` | Public REST API endpoints | Mobile / HTTP Clients | `AuthService` |
| `auth.service.AuthService` | Central Auth business & transaction logic | `AuthController` | `UserRepository`, `UserCredentialRepository`, `AuthTokenRepository`, `RefreshSessionRepository`, `JwtService`, `RefreshTokenService`, `PasswordEncoder` |
| `auth.security.RefreshTokenService` | Refresh token hashing, issuance, TTL calculation | `AuthService` | `RefreshSessionEntity`, SHA-256 MessageDigest, SecureRandom |
| `auth.security.AuthTokenHasher` | Peppered HMAC-SHA256 OTP hashing | `AuthService`, `OtpResolverTest` | Java Mac (HmacSHA256) |
| `auth.security.ProfileCompletionTokenService`| Onboarding JWT generation & verification | `AuthService` | JJWT library |
| `user.controller.UserController` | Protected User API endpoints (`/api/v1/me`) | Mobile / HTTP Clients | `UserService` |
| `user.service.UserService` | User profile & database status enforcement | `UserController` | `UserRepository` |
| `common.error.GlobalExceptionHandler` | `@RestControllerAdvice` exception handler | Spring MVC | Maps `BusinessException`, validation errors, system errors to `ApiErrorResponse` |

---

## 8. Mobile Architecture (Flutter)

### Layer Boundaries & Separation of Concerns
```text
Presentation Layer (UI Screens & Widgets)
  │  (Consumes form controllers, renders ViewModels, emits user events)
  │  STRICT RULE: Screens NEVER own Dio, raw tokens, SecureStorage, or refresh logic!
  ▼
Flow Coordination Layer (AuthFlowCoordinator)
  │  (Coordinates navigation, manages transient RAM-only onboarding tokens)
  ▼
Application Layer (AuthSessionController, AuthSessionInvalidator)
  │  (Owns AuthSessionStatus ValueNotifier, orchestrates generation-aware invalidation)
  ▼
Data / Domain Repository Layer (AuthRepository)
  │  (Serializes credential mutations in FIFO queue, maps DTOs, coordinates storage & API)
  ▼
Network Layer (DioClient, AuthInterceptor, AccessTokenHolder, AuthApi)
  │  (Attaches Bearer tokens, executes generation-scoped single-flight refresh, TOCTOU guard)
  ▼
Infrastructure / Storage Layer (SecureStorageService, SecureKeyValueStore)
  │  (Durable token persistence: iOS Keychain / Android Keystore)
```

### Core Mobile Classes & Responsibilities

| Class | Responsibility | State Owned | Dependencies |
|---|---|---|---|
| `WeDoApp` | Root MaterialApp widget | None | `AuthSessionController`, `AuthFlowCoordinator` |
| `AppRoutes` | Single route registry & generator | Static route table | `AuthRouteGuard`, Screen builders |
| `AuthRouteGuard` | Pure policy evaluator for route access | Stateless | Evaluates `AppRouteAccess` against `AuthSessionStatus` |
| `AuthSessionController` | Global session status notifier | `AuthSessionStatus` | `SecureStorageService`, `AccessTokenHolder`, `AuthRepository` |
| `AuthSessionInvalidator` | Definitive failure evaluation & invalidation | Stateless | `AuthRepository`, `AuthSessionController` |
| `AuthFlowCoordinator` | Onboarding UI flow & transient state | RAM-only `_profileCompletionToken`, `_registeredUserId` | `AuthRepository`, `AuthSessionController`, Navigator |
| `AuthRepository` | Auth operations & serialized credential mutation | FIFO mutation queue | `AuthApi`, `SecureStorageService`, `AccessTokenHolder` |
| `AuthApi` | REST request execution & DTO serialization | Stateless | `Dio` (normal), `Dio` (raw isolated refresh) |
| `AuthInterceptor` | Bearer attachment, auto-refresh, stale-401 retry, TOCTOU guard | `_activeRefreshFuture`, `_lastSuccessfulRefreshTransition` | `AccessTokenHolder`, refresh callback, `Dio` |
| `AccessTokenHolder` | In-memory active access token & revision counter | `_accessToken`, `_revision` | None |
| `SecureStorageService` | Durable storage read/write/clear | Stored token keys | `SecureKeyValueStore` (`FlutterSecureStorage`) |

---

## 9. Database Model & Schema Architecture

### Schema Migrations (`backend/src/main/resources/db/migration/`)
- `V0__bootstrap.sql` -> Bootstrap placeholder.
- `V1__identity_and_auth.sql` -> Core identity & security tables.
- `V2` through `V10` -> Domain tables for upcoming milestones (Social, Groups, Chat, Activities, Polls/Tasks/Discussions, Finance, Fund, Notifications, Constraints).
- `V11__session_family_hardening.sql` -> Adds nullable `absolute_expires_at TIMESTAMPTZ` to `refresh_sessions`.

### Milestone 0–2 Active Database Tables

```text
                               ┌──────────────────────────┐
                               │          users           │
                               ├──────────────────────────┤
                               │ id (UUID, PK)            │
                               │ email (CITEXT, UQ)       │
                               │ username (CITEXT, UQ)    │
                               │ display_name             │
                               │ status (CHECK)           │
                               │ email_verified_at        │
                               └─────────────┬────────────┘
                                             │
             ┌───────────────────────────────┼───────────────────────────────┐
             │ 1:1                           │ 1:1                           │ 1:1
             ▼                               ▼                               ▼
┌──────────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────┐
│     user_credentials     │   │  user_privacy_settings   │   │user_notification_settings│
├──────────────────────────┤   ├──────────────────────────┤   ├──────────────────────────┤
│ user_id (UUID, PK, FK)   │   │ user_id (UUID, PK, FK)   │   │ user_id (UUID, PK, FK)   │
│ password_hash            │   │ discover_by_username     │   │ push_enabled             │
│ failed_attempts          │   │ discover_by_qr           │   │ social_enabled           │
│ locked_until             │   │ dm_policy                │   │ group_enabled            │
│ password_changed_at      │   │ friend_request_policy    │   │ chat_enabled             │
└──────────────────────────┘   └──────────────────────────┘   └──────────────────────────┘
             │                               │
             │ 1:N                           │ 1:N
             ▼                               ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│       auth_tokens        │   │     refresh_sessions     │
├──────────────────────────┤   ├──────────────────────────┤
│ id (UUID, PK)            │   │ id (UUID, PK)            │
│ user_id (UUID, FK)       │   │ user_id (UUID, FK)       │
│ token_type (CHECK)       │   │ token_hash (UQ)          │
│ token_hash               │   │ expires_at               │
│ attempts                 │   │ absolute_expires_at (V11)│
│ expires_at               │   │ revoked_at               │
│ consumed_at              │   │ replaced_by_session_id(FK│
└──────────────────────────┘   │ device_name / ip_address │
                               └──────────────────────────┘
```

#### Table Details
1. **`users`**:
   - `id`: UUID Primary Key.
   - `email`: `CITEXT NOT NULL UNIQUE` (case-insensitive email uniqueness).
   - `username`: `CITEXT UNIQUE` (case-insensitive handle uniqueness, nullable until profile completion).
   - `status`: `VARCHAR(30)` (`PENDING_VERIFICATION`, `ACTIVE`, `SUSPENDED`, `DEACTIVATED`).
2. **`user_credentials`**:
   - `user_id`: UUID PK references `users(id) ON DELETE CASCADE`.
   - `password_hash`: BCrypt hash string.
   - `failed_attempts`: Integer consecutive wrong password count.
   - `locked_until`: Expiration timestamp of temporary login lockout.
3. **`auth_tokens`**:
   - `id`: UUID PK.
   - `user_id`: UUID FK references `users(id)`.
   - `token_type`: `EMAIL_VERIFICATION` or `PASSWORD_RESET`.
   - `token_hash`: HMAC-SHA256 hex digest of raw 6-digit OTP (peppered).
   - `attempts`: Failed attempt counter (max 5).
   - `consumed_at`: Terminal invalidation timestamp.
4. **`refresh_sessions`**:
   - `id`: UUID PK.
   - `user_id`: UUID FK references `users(id)`.
   - `token_hash`: SHA-256 lowercase hex digest of raw opaque refresh token (`UNIQUE`).
   - `expires_at`: Sliding expiration timestamp ($T_{\text{now}} + 14d$).
   - `absolute_expires_at`: Fixed family deadline ($T_{\text{login}} + 30d$, added in V11).
   - `revoked_at`: Revocation timestamp.
   - `replaced_by_session_id`: Self-referencing FK pointing to successor session on rotation.
   - `device_name`: Client device string ($\le 100$ chars).
   - `ip_address`: Server-observed remote IP ($\le 45$ chars).

---

## 10. Authentication Domain Lifecycle

### Canonical Sequence
```text
1. Register
   POST /api/v1/auth/register
   -> User created (PENDING_VERIFICATION) + UserCredential + OTP generated & pepper-hashed
   -> Emits EmailVerificationRequestedEvent

2. Verify Email
   POST /api/v1/auth/verify-email
   -> Verifies 6-digit OTP -> User status ACTIVE -> Issues profileCompletionToken (15m TTL)

3. Complete Profile
   POST /api/v1/auth/complete-profile
   -> Validates profileCompletionToken -> Sets username & displayName -> Returns nextStep: LOGIN

4. Login
   POST /api/v1/auth/login
   -> Password verified -> Issues Access JWT (15m) + Opaque Refresh Token (14d sliding, 30d family cap)
   -> Persists S1 in refresh_sessions -> Local storage & AccessTokenHolder populated

5. Authenticated Request
   GET /api/v1/me
   -> AuthInterceptor attaches Authorization: Bearer <accessToken>
   -> JwtAuthenticationFilter parses JWT (Zero-DB) -> UserService checks DB status -> Returns 200

6. Access Token Expiry & Automatic Refresh
   GET /api/v1/me -> 401 AUTH_TOKEN_EXPIRED
   -> AuthInterceptor intercepts error -> Single-flight refreshSession()
   -> POST /api/v1/auth/refresh via isolated raw Dio
   -> Backend locks S1 -> Rotates S1 to S2 -> Client updates storage & AccessTokenHolder (rev N -> N+1)
   -> AuthInterceptor TOCTOU check passes -> Transparent retry of GET /api/v1/me succeeds (200)

7. Logout
   POST /api/v1/auth/logout
   -> Backend marks S2 revoked (revokedAt = now)
   -> Client clears storage and RAM bearer token
```

---

## 11. Concurrency, Locking & Security Invariants

### 1. Global Per-User Security Barrier
To prevent deadlocks across security operations mutating credentials and sessions, a strict lock hierarchy is enforced:
$$\text{UserCredential} \longrightarrow \text{RefreshSession}$$
- **Login**: Locks `UserCredential` by `userId`.
- **Forgot Password**: Locks `UserCredential` by `userId`.
- **Reset Password**: Locks `UserCredential` by `userId`, then bulk-revokes active `RefreshSession` records.
- **Refresh Token**: Scalar projection lookup resolves `userId`, acquires lock on `UserCredential`, then acquires `PESSIMISTIC_WRITE` lock on `RefreshSession`.

### 2. Refresh Token Rotation & Replay
- When $S_1$ is rotated to $S_2$, $S_1.\text{revokedAt} = \text{now}$ and $S_1.\text{replacedBySessionId} = S_2.\text{id}$.
- If an already-rotated $S_1$ is submitted: Backend returns HTTP 401 `REFRESH_TOKEN_INVALID` and does **not** revoke successor $S_2$ or the session family.
- Two concurrent refresh requests submitting the same raw token serialize on row lock: the first rotates $S_1 \rightarrow S_2$ (HTTP 200); the second wakes, sees $S_1$ revoked, and receives HTTP 401 `REFRESH_TOKEN_INVALID`. Exactly one successor $S_2$ is created.

### 3. Generation-Aware Client Concurrency (Mobile)
- **Session Revision**: `AccessTokenHolder.revision` increments atomically whenever the access token is set or cleared.
- **Generation-Scoped Single-Flight Refresh**: Concurrent expired requests sharing generation $N$ join a single `_activeRefreshFuture`. Requests from different generations fail closed.
- **Stale 401 Detection**: If Request $A$ was sent at revision $N$, and Request $B$ refreshed the session ($N \rightarrow N+1$), Request $A$'s subsequent 401 is proven stale via `SessionRevisionTransition(N -> N+1)` and retries directly under $N+1$ without triggering another refresh.
- **Pre-Dispatch TOCTOU Guard**: Immediately before retrying a request, `AuthInterceptor.onRequest` asserts:
  `accessTokenHolder.revision == targetRevision && accessTokenHolder.currentAccessToken != null`
  If Account B logged in or user logged out during the retry window, the retry is aborted immediately via `RetryAbortedException` without transmitting credentials.
- **FIFO Mutation Queue**: All client-side credential mutations (`login`, `refresh`, `clear`, `invalidate`) serialize through `AuthRepository._mutationQueue`. Network operations execute outside the queue to prevent blocking.
- **Generation-Bounded Invalidation**: `AuthSessionInvalidator` only marks the session unauthenticated if the current revision matches the invalidation target revision. Older failures never log out newer sessions.

---

## 12. Critical Project Files

### Backend
- `backend/src/main/java/com/wedo/backend/security/SecurityConfig.java`: Spring Security filter chain and route authorization rules.
- `backend/src/main/java/com/wedo/backend/security/jwt/JwtAuthenticationFilter.java`: Zero-DB Bearer access-JWT parser filter.
- `backend/src/main/java/com/wedo/backend/security/jwt/JwtService.java`: Access token creation and claims extraction.
- `backend/src/main/java/com/wedo/backend/auth/controller/AuthController.java`: Auth REST controller.
- `backend/src/main/java/com/wedo/backend/auth/service/AuthService.java`: Core auth business logic, state machines, locking, and token operations.
- `backend/src/main/java/com/wedo/backend/auth/security/RefreshTokenService.java`: Refresh token hashing, issuance, and family deadline enforcement.
- `backend/src/main/resources/db/migration/V1__identity_and_auth.sql`: Core auth schema.
- `backend/src/main/resources/db/migration/V11__session_family_hardening.sql`: Session family deadline schema.

### Mobile
- `mobile/lib/main.dart`: Production dependency graph composition and session bootstrap.
- `mobile/lib/app/routes.dart`: Single route registry and `AppRouteDefinition` bindings.
- `mobile/lib/app/auth_route_guard.dart`: Pure session-status route evaluator.
- `mobile/lib/core/network/auth_interceptor.dart`: Generation-aware Bearer attachment, refresh, and retry interceptor.
- `mobile/lib/core/network/access_token_holder.dart`: In-memory access token and revision counter.
- `mobile/lib/features/auth/application/auth_session_controller.dart`: Session status state manager and lazy restorer.
- `mobile/lib/features/auth/application/auth_session_invalidator.dart`: Generation-aware session invalidator.
- `mobile/lib/features/auth/data/auth_repository.dart`: Auth repository with FIFO mutation serialization.
- `mobile/lib/features/auth/data/auth_api.dart`: Network API client using dual Dio instances (normal + isolated raw).
- `mobile/lib/features/auth/presentation/auth_flow_coordinator.dart`: Navigation and ephemeral onboarding coordinator.

---

## 13. Configuration & Environment Model

### Environment Variables
- `WEDO_DB_URL`: PostgreSQL JDBC URL (default: `jdbc:postgresql://localhost:5432/wedo`).
- `WEDO_DB_USERNAME`: Database username (default: `wedo`).
- `WEDO_DB_PASSWORD`: Database password (default: `wedo_local`).
- `WEDO_REDIS_HOST`: Redis host (default: `localhost`).
- `WEDO_REDIS_PORT`: Redis port (default: `6379`).
- `WEDO_JWT_SECRET_BASE64`: 256-bit Base64 signing key for access JWTs.
- `WEDO_AUTH_TOKEN_PEPPER_BASE64`: 256-bit Base64 pepper key for OTP hashes.
- `WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64`: 256-bit Base64 signing key for onboarding tokens.
- `WEDO_JWT_ACCESS_TOKEN_TTL`: Access token lifespan (default: `15m`; set to `5s` for E2E).
- `WEDO_REFRESH_TOKEN_TTL`: Refresh token sliding lifespan (default: `14d`).
- `WEDO_REFRESH_TOKEN_MAX_FAMILY_LIFETIME`: Absolute family lifespan (default: `30d`).
- `WEDO_LOGIN_MAX_FAILED_ATTEMPTS`: Consecutive failed login attempts before lockout (default: `5`).
- `WEDO_LOGIN_LOCK_DURATION`: Account lockout duration (default: `15m`).
- `WEDO_API_BASE_URL`: Flutter client API base URL (default: `http://127.0.0.1:8080`).

---

## 14. Test Architecture & Verification Matrix

### Backend Test Inventory (`backend/src/test/`)
- **Unit Tests**:
  - `PasswordEncoderTest`: Validates BCrypt encoding, verification, and null safety.
  - `JwtServiceTest`: Validates claim extraction, signature verification, expiration detection.
  - `AuthTokenHasherTest`: Validates HMAC-SHA256 peppered hashing and constant-time matching.
  - `RefreshTokenServiceTest`: Validates token generation, hashing, issuance invariants, family clamping.
  - `VerificationCodeGeneratorTest`: Validates 6-digit format and randomness.
  - `RequestIdFilterTest`, `TimeConfigTest`, `PagedResponseTest`: Validates infrastructure utilities.
- **Controller WebMvc Tests**:
  - `AuthControllerTest`: MockMvc tests validating request validation, status codes, and DTO contracts.
  - `UserControllerTest`: MockMvc tests validating protected `/api/v1/me` and security errors.
- **Spring Security Integration Tests**:
  - `SecurityConfigTest`: Validates filter chain, public vs protected endpoints, Bearer validation.
  - `RestAccessDeniedHandlerTest`: Validates 403 error response rendering.
- **Data & Service Integration Tests**:
  - `AuthJpaMappingTest`: Testcontainers PostgreSQL test validating Flyway migrations and entity mappings.
  - `AuthServiceTest`: Comprehensive transactional integration tests validating registration, verification, profile completion, login, lockout, refresh rotation, logout, and password recovery.
- **E2E Tooling**:
  - `OtpResolverTest`: Test-scoped helper resolving 6-digit verification code from live DB for E2E harness.

### Mobile Test Inventory (`mobile/test/` & `mobile/test_e2e/`)
- **Core Network & Storage**:
  - `access_token_holder_test.dart`: Validates token setting, clearing, and monotonic revision increments.
  - `api_config_test.dart`: Validates URL resolution and normalization.
  - `auth_interceptor_test.dart`: Exhaustive unit tests for Bearer attachment, auto-refresh, single-flight deduplication, stale-401 retry, TOCTOU guard, and failure propagation.
  - `dio_client_test.dart`: Validates interceptor registration and base options.
  - `secure_storage_service_test.dart`: Validates read, write, clear with mock key-value store.
- **Application & Data**:
  - `auth_session_controller_test.dart`: Validates startup session restoration (full, empty, partial) and revision guards.
  - `auth_session_invalidator_test.dart`: Validates definitive failure allow-list and generation-aware invalidation.
  - `auth_api_test.dart`: Validates HTTP method, headers, payloads, and error mappings.
  - `auth_repository_test.dart`: Validates repository operations, mutation queue serialization, and storage adoption.
  - `auth_session_integration_test.dart`: Proves end-to-end integration across Controller, Invalidator, Repository, Interceptor, and Storage.
- **Presentation & Routing**:
  - `auth_route_guard_test.dart`: Validates full access evaluation matrix (`public` vs `authenticated` across statuses).
  - `routes_test.dart`: Validates fail-closed route generation and argument handling.
  - `auth_flow_coordinator_test.dart`: Validates UI flow transitions and RAM token lifecycle.
  - Screen widget tests: Validates render, validation, and interaction across all 8 auth screens.
- **Live E2E Harness (`mobile/test_e2e/live_auth_e2e_test.dart`)**:
  - Live client-backend integration running against real Spring Boot and real PostgreSQL. Proves: register -> OTP resolve -> verify email -> complete profile -> login -> initial /me -> real access expiry wait -> transparent auto-refresh -> retried /me -> logout -> server-side revocation verification.

---

## 15. Local Execution Commands

### Infrastructure Startup
```bash
# From workspace root
docker compose -f infra/docker-compose.yml up -d
```

### Backend Execution
```powershell
# Windows
cd backend
$env:WEDO_JWT_ACCESS_TOKEN_TTL = "15m"
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```
```bash
# Linux / macOS
cd backend
WEDO_JWT_ACCESS_TOKEN_TTL=15m ./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### Backend Regression Tests
```powershell
# Windows
cd backend
.\mvnw.cmd test
```

### Flutter Application Execution
```bash
cd mobile
flutter pub get
flutter run --dart-define=WEDO_API_BASE_URL=http://127.0.0.1:8080
```

### Flutter Test Suites
```bash
# Offline unit, widget, and repository tests
cd mobile
flutter test -r expanded

# Live Auth Client-Backend E2E (Requires running backend & PostgreSQL)
cd mobile
flutter test test_e2e/live_auth_e2e_test.dart --dart-define=WEDO_API_BASE_URL=http://127.0.0.1:8080
```

---

## 16. Current Architectural Limitations & Deferred Scope

The following items are **intentionally NOT implemented** as of Milestone 2 completion:
1. **Authenticated Home / App Shell**: No authenticated dashboard, tabs, or bottom navigation bar exists. The post-login UI displays `'Signed in successfully.'` on `LoginScreen`.
2. **Protected Feature Screens**: All currently registered screens in `AppRoutes` are classified as `AppRouteAccess.public`.
3. **User Profile & Settings UI**: Editing profile, changing password, privacy settings UI are deferred to Milestone 3.
4. **User-Facing Logout UI**: No UI button or screen currently triggers `AuthRepository.logout()`.
5. **Reactive Screen Eviction**: No observer-based route eviction currently pops an already-visible screen upon session invalidation.
6. **External Email Delivery**: OTP codes are generated and published via internal Spring events; no JavaMailSender, SendGrid, or AWS SES is configured.
7. **Stateless JWT Logout Residual Window**: The backend does not maintain an access-token blacklist or query the database on every protected request. In the double-fault edge case where remote logout succeeds, local secure storage deletion fails, and the app hard-restarts before access token expiration, the restored access token remains cryptographically valid until its natural 15-minute `exp`.
8. **Cryptographic Device Binding**: Device names and IPs are audit/display metadata only; no mTLS, DPoP, or hardware keystore proofs are implemented.

---

## 17. Current Git State & Checkpoint

- **Active Branch**: `feat/m2-auth-security`
- **Completed M2 Commit / HEAD**: `a96457c docs: close milestone 2 auth foundation`
- **Remote Branch Status**: Merged into `dev` via commit `807cafa Merge pull request #4 from HuyGiang1/feat/m2-auth-security`.
- **Working Tree**: Clean (zero untracked or modified production files).

---

## 18. Collaboration & Working Rules for Future Milestones

1. **Strict Milestone Boundaries**: Never implement features from future milestones ahead of schedule.
2. **Architecture & Design First**: For any architectural, security, database, or concurrency change: inspect -> analyze -> report -> wait for approval -> implement.
3. **No Unapproved Commits or Pushes**: Never commit or push without explicit user consent.
4. **No Synthetic Functionality**: Never invent mock production features merely to make a flow appear complete.
5. **Separation of Concerns**: Keep Presentation, Application, Domain/Data, and Network/Infrastructure strictly decoupled. Screens must never access Dio, raw tokens, or SecureStorage directly.
6. **Zero Secret Logging**: Passwords, OTPs, JWT secrets, peppers, and raw tokens must never be logged or printed.
7. **Comprehensive Verification**: Run both static analysis and automated test suites after every implementation slice.
8. **Mentorship Mindset**: Explain *what*, *why*, *alternatives*, *tradeoffs*, *concurrency implications*, and *interview relevance* when introducing new concepts.

---

## 19. Next Milestone: Milestone 3 (User Profile + Privacy)

**Status:** **NOT STARTED**.

Milestone 3 will implement:
- Backend: `UserService` profile updates, username change, privacy settings management, personal QR generation, public profile lookups, sensitive field filtering.
- Mobile: User profile view, edit profile screen, privacy settings screen, QR code display.
- Database: Enforce privacy settings policies across API lookups.
- Tests: Privacy boundary unit tests, collision handling tests, and integration tests.
