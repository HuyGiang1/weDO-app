# API CONTRACT & BACKEND IMPLEMENTATION BLUEPRINT v1.0

**Project:** Ứng dụng kết nối, giao tiếp, chia sẻ và quản lý hoạt động nhóm  
**Document type:** Backend API Contract + Spring Boot Implementation Blueprint  
**Version:** 1.0  
**Status:** BASELINE  
**Mobile:** Flutter + Dart  
**Backend:** Spring Boot  
**Database:** PostgreSQL  
**ORM:** Spring Data JPA / Hibernate  
**Migration:** Flyway  
**Realtime:** WebSocket + Redis  
**Media:** S3-compatible storage / Cloudinary  
**Push:** Firebase Cloud Messaging  
**API documentation:** OpenAPI / Swagger  
**API style:** REST + WebSocket  
**Authentication:** Email + Password + JWT Access Token + Refresh Token

---

## 1. Document Purpose

Tài liệu này là baseline kỹ thuật chính thức cho backend và API của ứng dụng. Nó được xây dựng dựa trên Product Requirement Overview, BA Consolidated Specification, Screen Map / UX Flow và ERD / Database Design đã chốt.

Tài liệu trả lời các câu hỏi: Flutter gọi endpoint nào; request/response DTO gồm gì; validation ở đâu; quyền nào áp dụng; Service/Repository nào chịu trách nhiệm; API nào cần `@Transactional`; API nào cần locking; khi nào dùng REST/WebSocket/Redis; error code nào client phải xử lý; domain event nào được phát; màn hình nào sử dụng API nào; và Spring Boot nên được triển khai theo blueprint nào.

Chuỗi tài liệu chuẩn:

```text
PRODUCT REQUIREMENT OVERVIEW
        ↓
BA CONSOLIDATED SPECIFICATION
        ↓
SCREEN MAP / UX FLOW
        ↓
ERD & DATABASE DESIGN
        ↓
API CONTRACT & BACKEND IMPLEMENTATION BLUEPRINT
        ↓
SYSTEM ARCHITECTURE
        ↓
DEVELOPMENT PLAN
        ↓
IMPLEMENTATION
```

---

## 2. System Context

```text
Flutter Mobile App
        │
        ├── HTTPS / REST ───────────────► Spring Boot ─► Spring Data JPA ─► PostgreSQL
        │
        ├── WebSocket ──────────────────► Spring Boot ─► Redis
        │
        ├── Media upload ───────────────► S3-compatible storage / Cloudinary
        │
        └── Push notification ◄───────── FCM ◄───────── Spring Boot
```

### Responsibilities

- **Flutter:** UI, navigation, client state, form state, display formatting, local cache, REST calls, WebSocket connection, optimistic UI where safe.
- **Spring Boot:** authentication, authorization, business validation, state transitions, transaction management, financial calculation, group permissions, aggregation, notification generation, realtime orchestration and data consistency.
- **PostgreSQL:** persistent source of truth.
- **Redis:** presence, typing, short-lived rate limits, WebSocket-related ephemeral state and selected caches.
- **Object storage:** avatars, chat images, receipts and payment proofs.
- **FCM:** push notifications.

---

## 3. API Conventions

### 3.1 Base URL and versioning

```text
/api/v1
```

Breaking changes require a new version such as `/api/v2`; existing contracts must not be silently broken.

### 3.2 Resource naming

Use nouns/resources:

```http
GET  /api/v1/groups
POST /api/v1/groups
GET  /api/v1/groups/{groupId}
```

Do not use `/getGroups`, `/createGroup`, `/deleteExpense`.

### 3.3 HTTP methods

- `GET`: read/query.
- `POST`: create a resource or execute an explicit business action.
- `PATCH`: partial update.
- `PUT`: idempotently replace/update one current state, e.g. RSVP or reaction.
- `DELETE`: remove/revoke/hide when that semantic is appropriate.

### 3.4 Explicit business actions

Protected state machines are changed by action endpoints instead of letting the client set arbitrary statuses.

```http
POST /api/v1/groups/{groupId}/archive
POST /api/v1/groups/{groupId}/restore
POST /api/v1/activities/{activityId}/confirm
POST /api/v1/activities/{activityId}/cancel
POST /api/v1/settlements/{settlementId}/confirm
POST /api/v1/settlements/{settlementId}/reject
```

### 3.5 HTTP status convention

- `200 OK`: successful query/update/action.
- `201 Created`: new resource created.
- `204 No Content`: successful action without response body.
- `400 Bad Request`: malformed request or input validation.
- `401 Unauthorized`: missing/invalid authentication.
- `403 Forbidden`: authenticated but not permitted.
- `404 Not Found`: resource does not exist or is not visible.
- `409 Conflict`: business-state conflict.
- `429 Too Many Requests`: rate limited.
- `500 Internal Server Error`: unexpected backend failure.

### 3.6 Standard error format

```json
{
  "timestamp": "2026-08-22T15:00:00Z",
  "status": 409,
  "code": "GROUP_MEMBER_LIMIT_REACHED",
  "message": "The group has reached its maximum capacity.",
  "path": "/api/v1/groups/123/join"
}
```

Validation error:

```json
{
  "timestamp": "2026-08-22T15:00:00Z",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "Request validation failed.",
  "errors": {
    "name": "must not be blank",
    "amount": "must be greater than zero"
  }
}
```

Spring Boot uses a central `@RestControllerAdvice`. Flutter branches primarily on `code`, not by parsing human-readable messages.

### 3.7 DTO rule

Never expose JPA Entity directly through the API.

```text
Entity ↔ Mapper ↔ Request/Response DTO
```

Reasons: security, API stability, hiding internal fields, avoiding lazy-loading serialization problems and separating persistence from contract.

### 3.8 Validation strategy

**Input validation** uses Bean Validation such as `@NotBlank`, `@Email`, `@Size`, `@Positive`, `@Valid`.

**Business validation** belongs in Service, for example group capacity 100, banned member, completed activity, expense split mismatch, settlement larger than debt, contribution larger than remaining obligation and insufficient fund balance.

### 3.9 Date/time

API uses ISO-8601. Activity also stores an IANA timezone such as `Asia/Ho_Chi_Minh`.

```json
{
  "startAt": "2026-09-01T19:00:00+07:00",
  "timezone": "Asia/Ho_Chi_Minh"
}
```

Java uses `Instant`/`OffsetDateTime`; PostgreSQL uses `TIMESTAMPTZ`.

### 3.10 Money

Java uses `BigDecimal`; PostgreSQL uses `NUMERIC(19,2)`. Never use `float`/`double` as the authoritative financial type. Formatting such as `600.000đ` is a Flutter responsibility.

### 3.11 Pagination

Normal lists use page-based pagination:

```http
GET /api/v1/groups/{groupId}/expenses?page=0&size=20
```

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalElements": 53,
  "totalPages": 3,
  "hasNext": true
}
```

Chat history uses cursor/sequence pagination:

```http
GET /api/v1/conversations/{conversationId}/messages?beforeSequence=1250&limit=30
```

### 3.12 Transaction policy

Use `@Transactional` when a single business command modifies multiple related records. Critical transaction boundaries include registration, group creation/join/ban/ownership transfer, message sequence allocation, RSVP + waitlist promotion, expense + shares, settlement confirmation, collection/contribution, fund expense and reimbursement approval.

### 3.13 Concurrency and locking

Use database locking for race-sensitive operations. Spring Data JPA may use `@Lock(LockModeType.PESSIMISTIC_WRITE)` where appropriate. Critical cases: final activity slot, FIFO waitlist promotion, message sequence allocation, contribution remaining amount, fund spending, reimbursement approval and settlement confirmation when debt must be revalidated.

### 3.14 Cross-resource integrity

Every ID supplied by Flutter must be validated in its business context. Examples: Expense from Group A cannot reference Activity from Group B; Task assignees must belong to the activity/group context; Collection obligations cannot target unrelated users.

### 3.15 Soft-delete/history principle

Do not casually hard-delete membership, message, activity, expense, settlement or fund history. Status and visibility rules preserve auditability.

---

## 4. Authentication & Security Model

### 4.1 Authentication & Stateless SecurityContext

The backend uses Email + Password authentication with Spring Security, JWT access tokens, server-revocable refresh tokens, and `PasswordEncoder`.

- **Stateless Session Policy:** `SessionCreationPolicy.STATELESS`. The `SecurityContext` exists in memory per request only. There is no `HttpSession` persistence across requests. Every protected request must supply credentials via `Authorization: Bearer <access-token>`.
- **Principal Integrity:** The current user identity is always derived from the authenticated `SecurityContext`; clients are never trusted to supply `currentUserId` for authorization.
- **Authenticated Principal Contract:** `AuthenticatedUserPrincipal` contains strictly the authenticated `userId: UUID`. The `SecurityContext` does NOT hold `UserEntity`, passwords, emails, usernames, account status, or raw JWT strings. Authentication is populated as `UsernamePasswordAuthenticationToken(principal, null, Collections.emptyList())` with null credentials and an empty authorities list (no synthetic roles or permissions).

### 4.2 Access JWT Architecture & Claim Contract

- **Lifespan:** Short-lived 15 minutes (`security.jwt.access-token-ttl: 15m`).
- **Cryptographic Claim Contract:**
  - `sub`: User ID formatted as a standard UUID string.
  - `iat`: Issued-at epoch seconds.
  - `exp`: Expiration epoch seconds.
  - No `username`, `email`, `status`, `roles`, `permissions`, or `jti` are included in the access JWT claims.
- **Token Purpose Separation:** Access JWTs and profile-completion tokens are signed using distinct configuration keys (`security.jwt.secret-base64` vs. `security.profile-completion.secret-base64`). Under current cryptographic configuration, a profile-completion token cannot pass access-JWT verification.

### 4.3 Bearer Authentication Flow & Filter Responsibilities

**Request Pipeline Flow:**
```text
HTTP Request
  → RequestIdFilter
  → JwtAuthenticationFilter
  → SecurityContextHolder
  → AuthorizationFilter
  → Resource Controller
```

- **JwtAuthenticationFilter Implementation:**
  - Extends `OncePerRequestFilter`.
  - Defined as a plain class (not a Spring `@Component`), instantiated directly inside `SecurityConfig` and attached via `http.addFilterBefore(..., UsernamePasswordAuthenticationFilter.class)`. This avoids accidental duplicate Servlet container filter registration.
- **Filter Responsibility & Zero-DB-Hit Access Layer:**
  - `JwtAuthenticationFilter` strictly answers: *"Is this Bearer access JWT cryptographically valid, and which userId does it represent?"*
  - It does NOT query `users`, `user_credentials`, `refresh_sessions`, or `auth_tokens`.
  - It does NOT check current account status, refresh tokens, revoke sessions, or load JPA entities.
  - Fresh database state and account status enforcement are intentionally deferred to resource services (such as `UserService` for `GET /api/v1/me`) that actually require entity data.

### 4.4 Authorization Header Policy & Public Endpoint Semantics

- **Authorization Header Evaluation:**
  - Absent or blank header: Filter is a no-op and delegates to the filter chain.
  - Non-Bearer header (e.g., `Basic ...`, `Digest ...`, `Custom ...`): Filter ignores the header and delegates to the filter chain.
  - Scheme matching: Case-insensitive comparison (`Bearer`, `bearer`, `BEARER`).
  - Blank/missing token with Bearer scheme: Emits HTTP 401 `AUTH_TOKEN_INVALID`.
- **Public Endpoint + Bearer Credential Semantics:**
  - `JwtAuthenticationFilter` executes for all incoming requests (including public endpoints).
  - Public endpoint + no `Authorization` header → normal public execution.
  - Public endpoint + non-Bearer `Authorization` → filter ignores it, normal public execution.
  - Public endpoint + invalid/malformed Bearer credential → HTTP 401 `AUTH_TOKEN_INVALID`.
  - Public endpoint + expired Bearer credential → HTTP 401 `AUTH_TOKEN_EXPIRED`.
  - *Rationale:* When a client explicitly supplies Bearer credentials, the backend validates them rather than silently ignoring invalid credentials.

### 4.5 Refresh Token

High-entropy opaque random session credential (not a JWT). Raw token is returned only to client; SHA-256 hash is persisted in the database (`refresh_sessions.token_hash`). Configured with a 14-day sliding TTL (`security.refresh-token.ttl: 14d`). Refresh rotation invalidates the old token/session S1 atomically (`revoked_at = now`, `replaced_by_session_id = S2.id`) and produces a new access token and a replacement refresh token/session S2.

### 4.6 Security Error Handling & Error Envelope Consolidation

Security errors are rendered consistently via `SecurityErrorResponseWriter`, shared by:
- `RestAuthenticationEntryPoint`: Invoked when an unauthenticated request attempts to access a protected resource. Emits HTTP 401 `UNAUTHORIZED` (`"Authentication is required."`).
- `RestAccessDeniedHandler`: Invoked when an authenticated request lacks required authorization. Emits HTTP 403 `ACCESS_DENIED` (`"Access is denied."`).
- `JwtAuthenticationFilter`: Invoked when Bearer credentials fail validation. Emits HTTP 401 `AUTH_TOKEN_EXPIRED` (`"Authentication token has expired."`) or HTTP 401 `AUTH_TOKEN_INVALID` (`"Invalid authentication token."`).

**Canonical Error Envelope:**
All security filters and entry points output the standard application error envelope:
```json
{
  "timestamp": "2026-09-07T03:15:30.123Z",
  "status": 401,
  "code": "AUTH_TOKEN_INVALID",
  "message": "Invalid authentication token.",
  "path": "/api/v1/me",
  "requestId": "4fa85f64-5717-4562-b3fc-2c963f66afa6"
}
```
The `requestId` is resolved from `RequestIdFilter` via MDC (or header fallback) and synchronized to the `X-Request-ID` response header. Internal JWT parser exceptions are never exposed to clients.

### 4.7 Status-Blind Access JWT Limitation & Password Reset Interaction

- **Status-Blind Limitation:** Because `JwtAuthenticationFilter` performs no per-request user database queries, a cryptographically valid access JWT belonging to an account whose status changes (e.g., suspended or deactivated) after token issuance may establish authentication until the token expires (up to 15 minutes). Protected endpoints that query database user state (such as `GET /api/v1/me`) enforce current database status.
- **Password Reset Interaction:** Password reset revokes all active refresh sessions in the database, but already-issued access JWTs remain cryptographically valid until expiration. There is no distributed access-token blacklist in the current architecture.

### 4.8 Authentication vs Authorization

Authentication answers **who the user is**. Authorization answers **whether that authenticated user may perform an action** based on current membership, role, ownership, privacy, block and domain state.

---


## 5. Authentication API

### AUTH-01 Register

**Endpoint:** `POST /api/v1/auth/register`  
**Authentication:** Public  
**Request DTO:** `RegisterRequest`

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

**Business flow:** normalize email; ensure unique email; validate password; create User; hash password; create UserCredential; create default privacy settings; create default notification settings; create email verification token; publish verification event.

**Transaction:** YES  
**Repositories:** UserRepository, UserCredentialRepository, UserPrivacySettingsRepository, UserNotificationSettingsRepository, AuthTokenRepository.  
**Response:** user ID, email, verification state and `nextStep=VERIFY_EMAIL`.  
**Errors:** `EMAIL_ALREADY_EXISTS`, `INVALID_EMAIL`, `INVALID_PASSWORD`.  
**Events:** `USER_REGISTERED`, `EMAIL_VERIFICATION_REQUESTED`.

### AUTH-02 Verify Email

- **Endpoint:** `POST /api/v1/auth/verify-email`
- **Authentication:** Public
- **Request DTO:** `VerifyEmailRequest`

```json
{
  "userId": "c0a80123-4567-89ab-cdef-0123456789ab",
  "code": "123456"
}
```

**Response DTO:** `VerifyEmailResponse` (HTTP 200 OK)

```json
{
  "userId": "c0a80123-4567-89ab-cdef-0123456789ab",
  "status": "ACTIVE",
  "emailVerifiedAt": "2026-09-05T10:15:30Z",
  "nextStep": "COMPLETE_PROFILE",
  "profileCompletionToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Business flow:** Validate active token, expiration and attempts; compare hashed code; consume token; update user status to `ACTIVE`; record `email_verified_at`; issue short-lived `profileCompletionToken`.

**Credential semantics:**
- `profileCompletionToken` is a short-lived **onboarding credential** (TTL: 15 minutes).
- Purpose is strictly restricted to `COMPLETE_PROFILE`.
- It is **not** an application access token and **not** a refresh token.
- It must **not** be used for authenticated/protected application APIs.

**Errors:** `400 VALIDATION_FAILED`, `400 VERIFICATION_CODE_INVALID`, `400 VERIFICATION_CODE_EXPIRED`, `400 VERIFICATION_ATTEMPTS_EXCEEDED`, `404 RESOURCE_NOT_FOUND`, `409 EMAIL_ALREADY_VERIFIED`.

### AUTH-03 Resend Verification

**Endpoint:** `POST /api/v1/auth/resend-verification`  
Uses Redis rate limiting to prevent abuse.

### AUTH-04 Complete Initial Profile

- **Endpoint:** `POST /api/v1/auth/complete-profile`
- **Authentication:** Public at Spring Security level (no `Authorization: Bearer` access token required). Authorization is performed using the `profileCompletionToken` onboarding credential. This is onboarding-only behavior.
- **Request DTO:** `CompleteProfileRequest`

```json
{
  "profileCompletionToken": "eyJhbGciOiJIUzI1NiJ9...",
  "username": "huygiang",
  "displayName": "Huy Giang",
  "bio": null,
  "avatarStorageKey": null
}
```

> **CRITICAL SECURITY REQUIREMENT:**
> The client does **not** submit and is never trusted to supply `userId`. Backend derives `userId` exclusively from the cryptographically validated `profileCompletionToken`. No `SecurityContext` authentication is established.

**Validation & Normalization Rules:**
- `profileCompletionToken`:
  - Required, non-blank.
- `username`:
  - Required.
  - 3..30 characters.
  - Allowed characters: letters A-Z / a-z, digits 0-9, underscore `_` (`^[a-zA-Z0-9_]{3,30}$`).
  - No whitespace allowed.
  - Canonical storage in lowercase (`trim().toLowerCase(Locale.ROOT)`).
  - Uniqueness enforced case-insensitively via DB unique index.
- `displayName`:
  - Required.
  - Max 100 characters (`@Size(min = 1, max = 100)`).
  - Unicode allowed.
  - Trimmed before persistence (`trim()`).
  - Non-unique.
- `bio`:
  - Optional.
  - Max 500 characters (`@Size(max = 500)`).
  - Trimmed before persistence; blank after trim becomes `null`.
- `avatarStorageKey`:
  - Optional.
  - Max 255 characters (`@Size(max = 255)`).
  - Preserved exactly as supplied (no normalization in M2.6).

**Business Flow:**
1. Validate incoming request fields via declarative Bean Validation.
2. Verify and parse `profileCompletionToken` (purpose = `COMPLETE_PROFILE`, unexpired, valid signature).
3. Extract `userId` from token subject; retrieve user entity from DB.
4. Verify user status is `ACTIVE` (return 403 `ACCESS_DENIED` if not).
5. Verify user has not already completed profile (`username == null`; return 409 `PROFILE_ALREADY_COMPLETED` if already populated).
6. Check case-insensitive username availability; return 409 `USERNAME_ALREADY_EXISTS` if taken.
7. Persist canonical profile fields (`username`, `displayName`, `bio`, `avatarStorageKey`) and handle potential concurrent unique constraint violation gracefully.
8. Return completed profile response.

**Response DTO:** `CompleteProfileResponse` (HTTP 200 OK)

```json
{
  "userId": "c0a80123-4567-89ab-cdef-0123456789ab",
  "username": "huygiang",
  "displayName": "Huy Giang",
  "status": "ACTIVE",
  "nextStep": "LOGIN"
}
```

*Note: Returns HTTP 200 OK with `nextStep=LOGIN`. No access token and no refresh token are issued.*

**Error Behavior:**
- `400 VALIDATION_FAILED`:
  - Missing/blank token.
  - Invalid username format (length not 3..30, invalid characters, whitespace).
  - Invalid DTO fields (`displayName` missing/blank or >100, `bio` >500, `avatarStorageKey` >255).
- `401 UNAUTHORIZED`:
  - Malformed profile completion token.
  - Invalid signature.
  - Expired token.
  - Wrong token purpose (not `COMPLETE_PROFILE`).
  - Invalid token subject (not a valid UUID).
- `403 ACCESS_DENIED`:
  - User status is not `ACTIVE`.
- `404 RESOURCE_NOT_FOUND`:
  - Verified token subject does not map to any existing user.
- `409 PROFILE_ALREADY_COMPLETED`:
  - Username already populated on the user entity.
- `409 USERNAME_ALREADY_EXISTS`:
  - Username already taken or DB uniqueness race on insert/update.

**Deferred Onboarding Recovery Requirement for Login:**
> ProfileCompletionToken TTL: 15 minutes.
>
> If it expires before profile completion, the account remains: `status = ACTIVE`, `username == null`.
>
> Recovery is implemented in M2.7 Login (AUTH-06):
> Login detects `ACTIVE + username == null` and issues a fresh `ProfileCompletionToken` with `nextStep = COMPLETE_PROFILE` without issuing application access or refresh tokens.

### AUTH-05 Username Availability

- **Endpoint:** `GET /api/v1/auth/usernames/{username}/availability`
- **Authentication:** Public
- **Response DTO:** `UsernameAvailabilityResponse` (HTTP 200 OK)

**Validation Rules:**
- Path variable `{username}` follows the same MVP validation rules as profile completion: 3..30 characters, `^[a-zA-Z0-9_]{3,30}$`.
- Invalid path username returns `400 VALIDATION_FAILED`.
- Taken username still returns `200 OK` with `available: false` (do **not** return 409).

**Case-Insensitivity & Canonical Handling:**
- Username comparison is strictly case-insensitive.
- Example: If username `huygiang` exists in the database, availability queries for `HuyGiang`, `HUYGIANG`, and `huygiang` all refer to the same logical username and return `available: false`.
- Response always returns the canonical lowercase username.

**Response Examples (HTTP 200 OK):**

Available username:
```json
{
  "username": "huygiang",
  "available": true
}
```

Taken username:
```json
{
  "username": "huygiang",
  "available": false
}
```

### AUTH-06 Login

- **Endpoint:** `POST /api/v1/auth/login`
- **Authentication:** Public endpoint at Spring Security level. (Note: `GET /api/v1/auth/login` remains protected/unauthorized. No `Authorization: Bearer` access token required for login.)
- **Request DTO:** `LoginRequest`
- **Response DTO:** `LoginResponse` (HTTP 200 OK)

**Request Schema:**

```json
{
  "email": "user@example.com",
  "password": "..."
}
```

*(No client metadata fields such as `deviceId`, `deviceName`, `pushToken`, `rememberMe`, or `ipAddress` are accepted in M2.7.)*

**Request Validation Rules:**
- `email`:
  - Required (`@NotBlank`).
  - Valid email syntax (`@Email`).
  - Normalized internally by trimming leading/trailing whitespace and converting to lowercase.
- `password`:
  - Required (`@NotBlank`).
  - Max 72 UTF-8 bytes: technical safety constraint for BCrypt hashing (not a password-strength rule).
  - Note: No minimum length (e.g. min 8), uppercase/lowercase, or special-character requirements are enforced at login.

**Authentication & Anti-Enumeration Semantics:**
- Unknown email or incorrect password:
  - Returns `401 AUTH_INVALID_CREDENTIALS` with default message `"Invalid email or password."`.
  - Specific internal reasons (`EMAIL_NOT_FOUND`, `USER_NOT_FOUND`, `CREDENTIAL_NOT_FOUND`) are never exposed to callers.
  - The implementation performs a dummy password verification for unknown accounts to reduce timing differences between unknown-email and wrong-password paths.

**Account Status Disclosure Order:**
- Account status checks are only evaluated **after** password verification succeeds:
  - If password is correct and status is `PENDING_VERIFICATION` → `403 EMAIL_NOT_VERIFIED` (`"Email address has not been verified."`).
  - If password is correct and status is `SUSPENDED` → `403 ACCOUNT_SUSPENDED` (`"Account has been suspended."`).
  - If password is correct and status is `DEACTIVATED` → `403 ACCOUNT_DEACTIVATED` (`"Account has been deactivated."`).
  - If password is wrong for an account in any of these states → returns `401 AUTH_INVALID_CREDENTIALS` (`"Invalid email or password."`).
- This strict sequence prevents leaking account existence or status to callers who do not know the password.

**Account Lockout Policy:**
- Default configuration (configurable via environment/application properties):
  - Max failed attempts: `5` (`security.login.max-failed-attempts`)
  - Lock duration: `15 minutes` (`security.login.lock-duration`)
- Semantics:
  - 1st through 4th consecutive wrong password:
    - Returns `401 AUTH_INVALID_CREDENTIALS`.
    - `failed_attempts` counter increments by 1.
  - 5th consecutive wrong password:
    - Returns `401 AUTH_INVALID_CREDENTIALS`.
    - `failed_attempts` reaches 5; `locked_until` is set to `now + 15 minutes`.
  - Wrong password submitted while account is actively locked:
    - Returns `401 AUTH_INVALID_CREDENTIALS`.
    - `failed_attempts` counter does not increment further; lock duration is not extended.
  - Correct password submitted while account is actively locked:
    - Returns `423 ACCOUNT_LOCKED` with message `"Account is temporarily locked."`.
  - Lock expiration: At exact `now == locked_until`, the lock is expired. On the next successful login, `failed_attempts` and `locked_until` are reset.
  - `ACCOUNT_LOCKED` is never exposed on a wrong-password request.

**Response Branches (One Stable DTO Shape):**

`LoginResponse` provides a single, stable JSON schema across all login branches. Fields not applicable to a specific branch are returned as `null`.

1. **Profile-Incomplete Recovery Branch (`ACTIVE` status, `username == null`):**
   - Occurs when credentials are valid, email is verified (`ACTIVE`), but the user has not completed initial profile setup (fulfills the deferred M2.6 recovery requirement).
   - Issues a fresh short-lived `profileCompletionToken` (purpose: `COMPLETE_PROFILE`, TTL: 15 minutes).
   - No application access token is issued; no refresh token is issued; zero `refresh_sessions` rows are created.
   - HTTP 200 OK:
     ```json
     {
       "userId": "11111111-1111-1111-1111-111111111111",
       "status": "ACTIVE",
       "nextStep": "COMPLETE_PROFILE",
       "profileCompletionToken": "eyJhbGciOi...",
       "accessToken": null,
       "refreshToken": null,
       "tokenType": null,
       "accessTokenExpiresAt": null,
       "user": null
     }
     ```

2. **Fully-Onboarded Normal Branch (`ACTIVE` status, `username != null`):**
   - Occurs when credentials are valid, email is verified (`ACTIVE`), and profile is complete.
   - Issues an application access token, an initial refresh token, and creates a persistent refresh session.
   - HTTP 200 OK:
     ```json
     {
       "userId": "11111111-1111-1111-1111-111111111111",
       "status": "ACTIVE",
       "nextStep": "AUTHENTICATED",
       "profileCompletionToken": null,
       "accessToken": "eyJhbGciOi...",
       "refreshToken": "7k8y...",
       "tokenType": "Bearer",
       "accessTokenExpiresAt": "2026-09-05T10:15:00Z",
       "user": {
         "id": "11111111-1111-1111-1111-111111111111",
         "email": "user@example.com",
         "username": "huygiang",
         "displayName": "Huy Giang",
         "avatarStorageKey": null
       }
     }
     ```

**User Summary Structure (`UserSummaryDto`):**
```json
{
  "id": "UUID",
  "email": "string",
  "username": "string",
  "displayName": "string",
  "avatarStorageKey": "string|null"
}
```
*(Sensitive or internal fields such as `passwordHash`, `failedAttempts`, `lockedUntil`, privacy settings, or internal refresh session identifiers are strictly excluded.)*

**Token Architecture & Terminology:**
- `profileCompletionToken`: Short-lived onboarding JWT (purpose: `COMPLETE_PROFILE`, TTL: 15 minutes) used strictly for `POST /api/v1/auth/complete-profile`. Not an application session.
- `accessToken`: Application authentication JWT (`tokenType: "Bearer"`, TTL: 15 minutes). Minimal claims: `sub` (user UUID), `iat`, `exp`. No custom claims (roles, email, username) inside the JWT. Response expiration field: `accessTokenExpiresAt`.
- `refreshToken`: High-entropy opaque session credential (256-bit secure random, Base64 URL-safe without padding, 43 characters). **Not a JWT**.
  - Client transmission: Raw token returned only to client in response body.
  - Server persistence: Raw token is **never stored**. Its SHA-256 lowercase hex digest is stored in `refresh_sessions.token_hash`.
  - Default TTL: 14 days (`security.refresh-token.ttl`).

**Refresh Session State (M2.7):**
- On fully onboarded login, a single record is inserted into `refresh_sessions`:
  - `user_id`: Authenticated user ID.
  - `token_hash`: SHA-256 hash of the issued refresh token.
  - `expires_at`: `now + 14 days`.
  - `revoked_at`: `null`.
  - `replaced_by_session_id`: `null`.
  - `device_name`: `null` (device metadata omitted in M2.7).
  - `ip_address`: `null` (IP tracking omitted in M2.7).

**Milestone Boundary: M2.7 vs. M2.8 vs. M2.9 vs. M2.10 vs. M2.11:**
- **M2.7 (Implemented in commit `e74f08e`):**
  - Initial login credential verification with timing-mitigated anti-enumeration.
  - Status disclosure ordering and account lockout semantics.
  - Profile-incomplete recovery branch issuing fresh `profileCompletionToken`.
  - Fully-onboarded branch issuing application `accessToken` + initial opaque `refreshToken`.
  - Initial `refresh_sessions` row persistence.
- **M2.8 (Implemented in commit `480b6e2`):**
  - Public endpoint `POST /api/v1/auth/refresh` at Spring Security level.
  - Refresh token rotation (issuing new access token and new opaque refresh token S2).
  - Atomically revoking previous session S1 (`revokedAt = now`) and linking `replacedBySessionId = S2.id`.
  - Concurrency-safe same-token handling via row-level `PESSIMISTIC_WRITE` lock.
  - Reuse of previously rotated token is rejected with `401 REFRESH_TOKEN_INVALID` without broad session revocation.
  - Enforcing account status control point (revoking current session on non-ACTIVE status).
- **M2.9 (Implemented in commit `7eaadeb`):**
  - Public endpoint `POST /api/v1/auth/logout` at Spring Security level.
  - Narrow matched-session revocation (`revokedAt = now`, `replacedBySessionId = null`).
  - Idempotent handling of existing non-rotated revoked sessions (returns HTTP 204 without mutating `revokedAt`).
  - Refresh/logout concurrency safety via row-level lock serialization (`findByTokenHashWithLock`).
- **M2.10 (Implemented in commit `6fe6194`):**
  - Public endpoint `POST /api/v1/auth/forgot-password` at Spring Security level with neutral HTTP 200 response.
  - Public endpoint `POST /api/v1/auth/reset-password` at Spring Security level with HTTP 204 success and unified `PASSWORD_RESET_CODE_INVALID` HTTP 400 error.
  - One-time 6-digit `PASSWORD_RESET` OTP lifecycle with HMAC-SHA256 hash storage, 15m TTL, max 5 attempts with attempt persistence, and authoritative newest token selection.
  - Successful password mutation clearing prior temporary login lockout (`failedAttempts = 0`, `lockedUntil = null`).
  - Mandatory revocation of all active refresh sessions for the user (`revokedAt = now WHERE revokedAt IS NULL`).
  - Per-user security barrier (`UserCredential` -> `RefreshSession`) serializing credential-mutating flows and hardening refresh lock ordering.
- **M2.11 (Implemented in commit `c6655b9`):**
  - Access JWT consumption and Bearer authentication filter (`JwtAuthenticationFilter`).
  - Stateless `SecurityContext` population with immutable `AuthenticatedUserPrincipal(userId)`.
  - Protected endpoint `GET /api/v1/me` via `UserController` (`@AuthenticationPrincipal AuthenticatedUserPrincipal`).
  - Current-user database lookup in `UserService` (`userRepository.findById(userId)`).
  - Current account-status enforcement at `/me` (`ACTIVE` → 200, `SUSPENDED` → 403 `ACCOUNT_SUSPENDED`, `DEACTIVATED` → 403 `ACCOUNT_DEACTIVATED`, `PENDING_VERIFICATION` → 403 `EMAIL_NOT_VERIFIED`).
  - Missing DB user on valid cryptographic token translates to HTTP 401 `AUTH_TOKEN_INVALID` (not 404).
  - Security error writer consolidation (`SecurityErrorResponseWriter`) across entry point, access denied handler, and JWT filter.
  - Dedicated access-token error codes: `AUTH_TOKEN_INVALID` and `AUTH_TOKEN_EXPIRED`.
- **Still NOT implemented in M2.11:**
  - Real email delivery provider / JavaMailSender / SendGrid / SES.
  - Access-token blacklist, Redis revocation store, or immediate access JWT revocation.
  - Authenticated change-password endpoint (`POST /api/v1/auth/change-password`).
  - Session management UI / device binding / absolute family lifetime (M2.12).
  - Roles / permissions / RBAC (`PermissionService`).
  - Global account-status DB validation in `JwtAuthenticationFilter`.
  - `tokenVersion` or token revocation lists.
  - Flutter auth integration.
  - Media / avatar CDN URL resolution.

**Security & Configuration Notes:**
- Route `POST /api/v1/auth/login` is public in Spring Security, meaning no pre-existing Bearer token is needed. Public route does not mean unauthenticated success; authentication occurs inside Login business logic through email/password credential verification.
- `JwtAuthenticationFilter` is introduced in M2.11 as a zero-DB-hit filter executing before `UsernamePasswordAuthenticationFilter`.
- Default configuration settings:
  - `security.jwt.access-token-ttl: 15m`
  - `security.profile-completion-token.ttl: 15m`
  - `security.refresh-token.ttl: 14d`
  - `security.login.max-failed-attempts: 5`
  - `security.login.lock-duration: 15m`

### AUTH-07 Refresh Token

- **Endpoint:** `POST /api/v1/auth/refresh`
- **Authentication:** Public endpoint at Spring Security level. Credential authentication is performed using `refreshToken` in request body. No `Authorization: Bearer` access token required. (Note: `GET /api/v1/auth/refresh` remains protected/unauthorized with HTTP 401. No `/auth/**` wildcard.)
- **Request DTO:** `RefreshTokenRequest`
- **Response DTO:** `RefreshTokenResponse` (HTTP 200 OK)

**Request Schema:**

```json
{
  "refreshToken": "..."
}
```

*(No client metadata fields such as `deviceId`, `deviceName`, `pushToken`, or IP metadata are accepted in M2.8.)*

**Request Validation Rules:**
- `refreshToken`:
  - Required (`@NotBlank(message = "Refresh token must not be blank")`).
  - Opaque random credential.
  - Note: No strict 43-character regex validation is applied (avoids freezing token representation; invalid tokens naturally fail lookup).
  - No JWT parsing.

**Success Response Schema (HTTP 200 OK):**

```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "9m2x...",
  "tokenType": "Bearer",
  "accessTokenExpiresAt": "2026-09-05T10:30:00Z",
  "refreshTokenExpiresAt": "2026-09-19T10:15:00Z"
}
```

*(Response contains only token credentials and timestamps. No `UserSummaryDto` and no device/session metadata are included.)*

**Happy-Path Rotation Semantics:**
- Incoming raw refresh token is hashed using SHA-256 (`RefreshTokenService.hashToken`).
- Matched `refresh_sessions` row is locked exclusively using `PESSIMISTIC_WRITE` (`findByTokenHashWithLock`).
- Verifies session validity (not revoked, not expired) and account status (`ACTIVE`).
- Issues a new application access token (JWT 15m) and extracts expiration timestamp via `JwtService`.
- Issues a new refresh token and creates replacement session S2 via `RefreshTokenService.issue` (Sliding 14 days).
- Updates previous session S1: `S1.revokedAt = now`, `S1.replacedBySessionId = S2.id`.
- Atomically commits transaction (`@Transactional`).
- The previous refresh token becomes invalid immediately upon successful rotation.

**Session Validity & Expiration Rules:**
- A refresh session is usable only when:
  1. The session record exists in `refresh_sessions`.
  2. `revokedAt == null` (unrevoked).
  3. `now < expiresAt` (strictly before expiry; exact `now == expiresAt` is expired/invalid).
  4. The associated user exists and is valid for refresh.
- Expired session:
  - Returns `401 REFRESH_TOKEN_INVALID`.
  - No replacement session is created.
  - The expired row's `revokedAt` is not mutated merely because of expiry (historical state preserved).

**Unified Credential Error Contract:**
- `REFRESH_TOKEN_INVALID` (HTTP 401, `"Invalid refresh token."`):
  - Single, unified external error code for all refresh credential failures: unknown/random token, expired token, revoked token, and previously rotated token.
  - No separate external error codes (such as `REFRESH_TOKEN_EXPIRED`, `REFRESH_TOKEN_REUSED`, or `REFRESH_SESSION_REVOKED`) are exposed in M2.8.

**Account Status Control Point:**
- Refresh serves as an authoritative control point for account state.
- If the refresh session itself is structurally valid and unexpired, but the user account status is non-ACTIVE:
  - `PENDING_VERIFICATION` → `403 EMAIL_NOT_VERIFIED` (`"Email address has not been verified."`).
  - `SUSPENDED` → `403 ACCOUNT_SUSPENDED` (`"Account has been suspended."`).
  - `DEACTIVATED` → `403 ACCOUNT_DEACTIVATED` (`"Account has been deactivated."`).
- In all non-ACTIVE cases:
  - The current session is immediately revoked: `session.setRevokedAt(now)`.
  - `replacedBySessionId` remains `null` (no replacement session created).
  - This revocation **persists in DB** despite the HTTP 403 business error response (managed via `noRollbackFor = RefreshSessionStatusException.class`).
  - Only `ACTIVE` users may proceed to rotation.

**Reuse & Compromise Semantics:**
- If an already-rotated token (`revokedAt != null` and `replacedBySessionId != null`) is submitted:
  - Returns `401 REFRESH_TOKEN_INVALID`.
  - The replacement session remains active.
  - M2.8 intentionally does not perform broad compromise revocation (such as revoking descendant chains or all user sessions), because legitimate duplicate/concurrent retries cannot be distinguished reliably from malicious reuse with the current schema.

**Concurrent Same-Token Handling:**
- Two concurrent refresh requests using the exact same refresh token (e.g., client race condition or network retry):
  - The first request acquires `PESSIMISTIC_WRITE` lock on the old session, rotates S1 to S2, and succeeds (HTTP 200).
  - The second request waits for lock release, then observes S1 as already revoked, and fails with `401 REFRESH_TOKEN_INVALID`.
  - Exactly one replacement session S2 is created and remains active.
  - Enforced by row-level locking without user-wide revocation.

**Raw Token Storage Limitation:**
- The server stores only the SHA-256 hash of refresh tokens (`refresh_sessions.token_hash`), never raw tokens.
- After S1 rotates to S2, the server cannot reconstruct raw S2 for a duplicate S1 request.
- True idempotent replay of refresh requests is not supported with this security model; raw refresh tokens are never persisted to solve retry behavior.

**Hardened Lock Ordering & Concurrency (M2.10 Update):**
- In M2.10, `refreshToken` was hardened to participate in the global per-user security barrier (`UserCredential` $\rightarrow$ `RefreshSession`).
- **Lock Ordering Algorithm:**
  1. Hash raw incoming refresh token.
  2. Preliminary non-authoritative lookup via scalar projection (`findUserIdByTokenHash(tokenHash)`) to resolve `userId` without caching a stale `RefreshSessionEntity` in Hibernate L1 cache.
  3. Acquire exclusive lock on `UserCredential` (`userCredentialRepository.findByUserIdWithLock(userId)`).
  4. Authoritative re-read and lock on `RefreshSession` (`refreshSessionRepository.findByTokenHashWithLock(tokenHash)`).
  5. Verify session `userId` matches locked credential `userId`.
  6. Revalidate locked session state (`revokedAt == null`, `now < expiresAt`, user account status).
  7. Perform rotation $S_1 \rightarrow S_2$.
- **Same-User Concurrency Semantic Change:**
  - Multiple concurrent refresh requests belonging to the **same user** are serialized through the `UserCredential` row lock.
  - Two different valid refresh sessions for the same user serialize, but both succeed sequentially if otherwise valid.
  - Refresh operations for different users do not contend on the same per-user `UserCredential` lock and may proceed independently, subject to normal database/runtime resource contention.

**Sliding Session Lifetime:**
- Refresh token TTL: 14 days sliding (`security.refresh-token.ttl: 14d`).
- Each successful rotation creates a new session with `expiresAt = rotation_time + 14 days`.
- Continued active use extends the session. No absolute family lifetime is enforced in M2.8 (deferred to M2.12 session hardening).

**Token Architecture & Terminology:**
- `accessToken`: Application JWT authentication credential (`tokenType: "Bearer"`, TTL: 15 minutes, minimal claims: `sub`, `iat`, `exp`).
- `refreshToken`: High-entropy opaque session credential (256-bit secure random, Base64 URL-safe without padding, 43 characters, sliding 14 days). **Not a JWT**. Raw token returned only to client; SHA-256 stored server-side.
- `profileCompletionToken`: Short-lived onboarding JWT (purpose: `COMPLETE_PROFILE`, TTL: 15 minutes).

**Refresh Session State (M2.8):**
- On successful rotation:
  - Previous session S1: `revoked_at = now`, `replaced_by_session_id = S2.id`.
  - New session S2: `revoked_at = null`, `replaced_by_session_id = null`, `expires_at = now + 14 days`.
- Session rows are permanently preserved for audit and reuse detection (no hard delete).

**Security & Configuration Notes:**
- Route `POST /api/v1/auth/refresh` is public only at the filter-chain level; the refresh token in the body serves as the authentication credential.
- No `JwtAuthenticationFilter` is required for the refresh endpoint.
- Relevant configuration settings:
  - `security.jwt.access-token-ttl: 15m`
  - `security.refresh-token.ttl: 14d`

### AUTH-08 Logout

- **Endpoint:** `POST /api/v1/auth/logout`
- **Authentication:** Public endpoint at Spring Security filter-chain level. Credential authentication is performed using `refreshToken` in request body. No `Authorization: Bearer` access token required. (Note: `GET /api/v1/auth/logout` remains protected/unauthorized with HTTP 401. No `/auth/**` wildcard.)
- **Request DTO:** `LogoutRequest`
- **Response:** HTTP `204 No Content` (Empty body, no `LogoutResponse` DTO).

**Request Schema:**

```json
{
  "refreshToken": "..."
}
```

*(No metadata fields such as `deviceId`, `deviceName`, `pushToken`, or IP metadata are accepted in M2.9.)*

**Request Validation Rules:**
- `refreshToken`:
  - Required (`@NotBlank(message = "Refresh token must not be blank")`).
  - Opaque random credential.
  - No strict 43-character regex validation, no JWT parsing.
  - `null`, empty `""`, or whitespace-only token fails validation → HTTP 400 `VALIDATION_FAILED`.

**Logout Scope & Active Session Revocation:**
- Narrow current-session revocation: revokes only the matched refresh session.
- Does NOT revoke all sessions for the user, does NOT revoke all devices, does NOT traverse replacement descendants, does NOT revoke token family, does NOT blacklist access JWTs.
- For an existing active/current session (`revokedAt == null && now < expiresAt`):
  - Sets `revokedAt = now`.
  - `replacedBySessionId` remains `null`.
  - Atomically commits transaction (`@Transactional`).
  - Returns HTTP `204 No Content`.
  - No replacement session is created, and no new token is issued.

**Idempotent Non-Rotated Revoked Session Semantics:**
- If an existing session in the database has:
  - `revokedAt != null` AND `replacedBySessionId == null`
- Logout returns HTTP `204 No Content` without mutating the database.
- The original `revokedAt` timestamp is strictly preserved (never overwritten).
- *Semantic Distinction:* An existing refresh session that is already revoked without a replacement is treated as an idempotent logout success. The database schema does not store revocation reasons, so this state may originate from a prior logout, account-status revocation, or future administrative revocation.

**Rotated Token Semantics:**
- If an old token that has already been rotated (`revokedAt != null && replacedBySessionId != null`) is submitted:
  - Returns HTTP 401 `REFRESH_TOKEN_INVALID`.
  - Does NOT return 204.
  - Does NOT revoke the replacement session ($S_2$).
  - Does NOT traverse descendant chains or revoke user sessions.
  - Reason: Old rotated credentials no longer represent the current concrete refresh session.

**Unknown & Expired Token Semantics:**
- **Unknown/Random Token:**
  - Token hash absent from `refresh_sessions` → HTTP 401 `REFRESH_TOKEN_INVALID` (`"Invalid refresh token."`). Does not silently return 204 for unknown credentials.
- **Expired Active Session:**
  - If `revokedAt == null` and `now >= expiresAt` (exact boundary `now == expiresAt` is expired/invalid) → HTTP 401 `REFRESH_TOKEN_INVALID`.
  - No `revokedAt` mutation occurs merely because the session is expired.

**Service Check Order:**
1. Hash incoming raw token via `RefreshTokenService.hashToken(rawToken)`.
2. Lock matched row via `refreshSessionRepository.findByTokenHashWithLock(tokenHash)`.
3. If absent → throw `REFRESH_TOKEN_INVALID` (401).
4. If `revokedAt != null`:
   - If `replacedBySessionId != null` → throw `REFRESH_TOKEN_INVALID` (401).
   - If `replacedBySessionId == null` → return normally (idempotent 204).
5. If `now >= expiresAt` (`!now.isBefore(session.getExpiresAt())`) → throw `REFRESH_TOKEN_INVALID` (401).
6. Otherwise (active current session) → `session.setRevokedAt(now)`, save, return normally (204).
*(Note: Checking revoked-without-replacement before expiry ensures an already-revoked session remains idempotent even after its original expiration timestamp).*

**Account Status Independence:**
- Logout does NOT require `ACTIVE` user account status.
- The implementation does not load the `User` entity to authorize logout.
- A valid refresh session belonging to an unverified (`PENDING_VERIFICATION`), suspended (`SUSPENDED`), or deactivated (`DEACTIVATED`) account can be revoked successfully.
- Reason: Logout is credential revocation, not access-granting. Does not emit `EMAIL_NOT_VERIFIED`, `ACCOUNT_SUSPENDED`, or `ACCOUNT_DEACTIVATED`.

**Locking & Concurrency:**
- Logout reuses the exact same row-level lock as refresh: `findByTokenHashWithLock`. Operations on the same refresh session row are serialized without user-global locking.
- **Refresh vs. Logout Race:**
  - *Outcome A (Logout wins lock):* $S_1$ revoked with `replacedBy = null` → Logout returns 204. Refresh wakes, observes $S_1$ revoked → fails with 401 `REFRESH_TOKEN_INVALID`. No replacement session $S_2$ is created.
  - *Outcome B (Refresh wins lock):* Refresh rotates $S_1 \rightarrow S_2$ → Refresh returns 200. Logout wakes with raw $S_1$, observes $S_1$ revoked with `replacedBy = S2.id` → fails with 401 `REFRESH_TOKEN_INVALID`. Replacement session $S_2$ remains active.
- **Double Logout Concurrency:**
  - Two concurrent logout requests for the same active session serialize on the row lock: the first revokes the session, the second observes the already-revoked state and succeeds idempotently without overwriting `revokedAt`.

**Access Token Limitation Post-Logout:**
- Logout revokes the refresh session in the database only.
- Any already-issued stateless JWT access token remains cryptographically valid until its existing expiration timestamp (up to the remaining portion of its 15-minute TTL).
- No access-token blacklist or Redis revocation store exists in M2.9. Logout does NOT instantly invalidate an already-issued access token.
- **Client Responsibility:** Upon receiving HTTP 204, the client must clear `accessToken`, `refreshToken`, and local authenticated state from client-side storage.

**Session State Terminology Summary:**
- **Active / Current:** `revokedAt == null`.
- **Revoked without replacement:** `revokedAt != null` AND `replacedBySessionId == null`.
- **Rotated:** `revokedAt != null` AND `replacedBySessionId != null`.

**Security & Configuration Notes:**
- Route `POST /api/v1/auth/logout` is public only at the filter-chain level; the refresh token in the body serves as the credential. Public route does not mean unconditional success.
- No `JwtAuthenticationFilter` is required for logout.

### AUTH-09 Forgot Password

- **Endpoint:** `POST /api/v1/auth/forgot-password`
- **Authentication:** Public endpoint at Spring Security filter-chain level. No `Authorization: Bearer` access token required. (Note: `GET /api/v1/auth/forgot-password` remains protected/unauthorized with HTTP 401. No `/auth/**` wildcard.)
- **Request DTO:** `ForgotPasswordRequest`
- **Response DTO:** `ForgotPasswordResponse` (HTTP 200 OK)

**Request Schema:**

```json
{
  "email": "user@example.com"
}
```

*(Contains only `email`. No `userId` or client metadata accepted.)*

**Request Validation Rules:**
- `email`:
  - Required (`@NotBlank(message = "Email must not be blank")`).
  - Standard format (`@Email(message = "Email must be a valid email address")`).
  - Validation failure → HTTP 400 `VALIDATION_FAILED`.

**Email Normalization:**
- Canonicalized consistently across all auth flows: `trim().toLowerCase(Locale.ROOT)`.

**Success Response Schema (HTTP 200 OK):**

```json
{
  "message": "If an account with this email exists, password reset instructions have been sent."
}
```

*(Contains strictly `message`. No `userId`, account status, or OTP information is returned.)*

**Response Neutrality & Anti-Enumeration Semantics:**
- The endpoint returns the exact same HTTP 200 status and response body for:
  - Known `ACTIVE` accounts
  - Unknown / non-existent emails
  - `PENDING_VERIFICATION` accounts
  - `SUSPENDED` accounts
  - `DEACTIVATED` accounts
- *Disclosure Semantics:* The endpoint uses the same outward HTTP status and response body for known, unknown, and ineligible accounts to reduce direct account enumeration through response semantics. (Note: The implementation does not claim absolute timing indistinguishability against statistical side-channel analysis).
- For unknown or ineligible accounts, no database token or fake user entity is created.

**Token Issuance & Lifecycle (`PASSWORD_RESET`):**
- Generated only for existing accounts in `ACTIVE` status:
  1. Resolves user by canonical email.
  2. Acquires exclusive row lock on `UserCredential` (`findByUserIdWithLock(userId)`).
  3. Queries current unconsumed `PASSWORD_RESET` tokens.
  4. Terminally invalidates all prior unconsumed tokens (`consumedAt = now`).
  5. Generates a fresh 6-digit numeric OTP via `VerificationCodeGenerator`.
  6. Hashes raw code with HMAC-SHA256 pepper via `AuthTokenHasher.hash(userId, PASSWORD_RESET, rawCode)`.
  7. Persists new `AuthTokenEntity`:
     - `tokenType = PASSWORD_RESET`
     - `tokenHash = hash` (raw code is **never** persisted or logged)
     - `attempts = 0`
     - `consumedAt = null`
     - `expiresAt = now + 15m` (TTL: 15 minutes)
  8. Publishes `PasswordResetRequestedEvent(userId, normalizedEmail, rawCode)`.
  9. Returns generic HTTP 200 `ForgotPasswordResponse`.

**Domain Event & Email Delivery Integration Seam:**
- The backend publishes `PasswordResetRequestedEvent` containing `(userId, email, rawCode)` for downstream delivery integration.
- M2.10 does not yet include a production mail listener/provider (no `JavaMailSender`, SendGrid, or AWS SES).
- There is currently no `@TransactionalEventListener(phase = AFTER_COMMIT)` listener registered in production. The event serves as the application handoff boundary seam (consistent with M2.5 email verification).
- The raw OTP exists transiently only in the in-memory event payload and is never logged.

**Concurrency & Lock Invariant:**
- Forgot password requests serialize on the `UserCredential` row lock.
- If two forgot password requests for the same `ACTIVE` user execute concurrently:
  - The first acquires lock, invalidates prior tokens, creates $T_1$, and commits.
  - The second waits for lock release, sees $T_1$, invalidates $T_1$, creates $T_2$, and commits.
- Final invariant: Exactly one unconsumed `PASSWORD_RESET` token exists per user. No database unique constraint is required.

---

### AUTH-10 Reset Password

- **Endpoint:** `POST /api/v1/auth/reset-password`
- **Authentication:** Public endpoint at Spring Security filter-chain level. No `Authorization: Bearer` access token required. (Note: `GET /api/v1/auth/reset-password` remains protected/unauthorized with HTTP 401. No `/auth/**` wildcard.)
- **Request DTO:** `ResetPasswordRequest`
- **Response:** HTTP `204 No Content` (Empty body, no response DTO).

**Request Schema:**

```json
{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "MyNewPassword123!"
}
```

**Request Validation Rules:**
- `email`: Required (`@NotBlank`), valid email format (`@Email`).
- `code`: Required (`@NotBlank`), exactly 6 numeric digits (`@Pattern(regexp = "^\\d{6}$")`).
- `newPassword`:
  - Reuses exact registration password rules:
  - Required (`@NotBlank`).
  - Length: 8 to 72 characters (`@Size(min = 8, max = 72)`).
  - UTF-8 byte length safety: $\le 72$ bytes for BCrypt compatibility.
- Any request failing syntactic validation returns HTTP 400 `VALIDATION_FAILED`.

**Unified Outward Error Contract:**
- For all reset authorization, account status, token validity, and verification failures, the endpoint returns a single unified outward error:
  - **HTTP 400 Bad Request**
  - **Error Code:** `PASSWORD_RESET_CODE_INVALID`
  - **Message:** `"Invalid password reset code."`
- Unified outward policy applies to:
  - Unknown / non-existent email
  - Account status not `ACTIVE` (`PENDING_VERIFICATION`, `SUSPENDED`, `DEACTIVATED`)
  - Missing `UserCredential` row
  - No active unconsumed reset token in database
  - Expired reset token (`now >= expiresAt`)
  - Attempt counter exhausted (`attempts >= 5`)
  - Incorrect OTP code submitted
- *Oracle Leakage Prevention:* The unified outward error reduces account and reset-state oracle leakage through normal HTTP status/body/error semantics. It does not claim complete timing indistinguishability.
- No `PASSWORD_RESET_CODE_EXPIRED`, `PASSWORD_RESET_ATTEMPTS_EXCEEDED`, `ACCOUNT_SUSPENDED`, or `EMAIL_NOT_VERIFIED` errors are exposed on this endpoint.

**Internal Verification Check Order & Token Semantics:**
1. Canonicalize email (`trim().toLowerCase(Locale.ROOT)`).
2. Look up user by email $\rightarrow$ if absent $\rightarrow$ throw `PASSWORD_RESET_CODE_INVALID` (400).
3. Verify user status is `ACTIVE` $\rightarrow$ if non-ACTIVE $\rightarrow$ throw `PASSWORD_RESET_CODE_INVALID` (400).
4. Acquire exclusive lock on `UserCredential` (`findByUserIdWithLock(userId)`) $\rightarrow$ if absent $\rightarrow$ throw `PASSWORD_RESET_CODE_INVALID` (400).
5. Query unconsumed `PASSWORD_RESET` tokens newest first (`consumedAt IS NULL ORDER BY createdAt DESC, id DESC`) $\rightarrow$ if empty $\rightarrow$ throw `PASSWORD_RESET_CODE_INVALID` (400).
6. **Authoritative Token Selection:** The newest unconsumed token is authoritative. Any older unconsumed tokens in the database are terminally invalidated (`consumedAt = now`).
7. **Check A — Expiration Boundary:**
   - Evaluated using `clock.instant()`.
   - `now < expiresAt`: Usable.
   - `now >= expiresAt` (exact boundary `now == expiresAt` and beyond): Expired $\rightarrow$ throw `PASSWORD_RESET_CODE_INVALID` (400).
   - For an expired token: No attempt increment, no password mutation, no refresh session revocation.
8. **Check B — Max Attempts:**
   - If `token.attempts >= 5` $\rightarrow$ throw `PASSWORD_RESET_CODE_INVALID` (400) without incrementing attempts further.
9. **Check C — OTP Verification & Attempt Persistence:**
   - Hashes supplied code via `AuthTokenHasher.hash(userId, PASSWORD_RESET, rawCode)` and compares with `tokenHash`.
   - **Wrong OTP:**
     - `token.attempts` is incremented by 1 and persisted to the database.
     - On the 5th wrong attempt: `attempts` becomes 5, is persisted to DB, and returns `PASSWORD_RESET_CODE_INVALID` (400). Subsequent attempts see `attempts >= 5` and are rejected without further increments.
     - Throws dedicated `PasswordResetAttemptException` configured with `noRollbackFor = PasswordResetAttemptException.class` so the increment commits even though HTTP 400 is returned.
10. **Correct OTP:**
    - `authoritativeToken.consumedAt = now` (one-time use enforced; cannot be reused).
    - Proceed to password mutation and session revocation.

**consumedAt Terminology & Lifecycle:**
- In the `auth_tokens` schema, `consumedAt != null` indicates that the token is **terminal and no longer usable**.
- A non-null `consumedAt` does not necessarily mean the password was reset; it may mean the token was superseded by a subsequent forgot-password request or invalidated during cleanup. The schema does not track explicit revocation reasons.

**Password Mutation Semantics:**
- Upon valid code verification:
  - `credential.passwordHash = passwordEncoder.encode(newPassword)`
  - `credential.failedAttempts = 0` (clears prior failed login attempts)
  - `credential.lockedUntil = null` (clears prior temporary login lockout)
  - `credential.passwordChangedAt = now`
  - `credential.updatedAt = now`
- Successful password recovery allows a previously locked-out user to log in immediately with their new password.

**Revocation of All Active Refresh Sessions:**
- As a security requirement, successful password reset revokes **all active refresh sessions** belonging to that user:
  - SQL: `UPDATE refresh_sessions SET revoked_at = :now WHERE user_id = :userId AND revoked_at IS NULL`
  - Only updates rows where `revokedAt IS NULL`.
  - Does **not** overwrite `replacedBySessionId`, preserving historical S1 $\rightarrow$ S2 rotation linkages.
  - Revokes sessions across all client devices/browsers.
- No automatic login is performed; no new refresh token or access token is issued. Response is HTTP 204 No Content.

**Access Token Limitation Post-Reset:**
- Password reset revokes all refresh sessions in the database immediately.
- However, already-issued stateless JWT access tokens remain cryptographically valid until their existing expiration timestamp (up to the remaining portion of their 15-minute TTL).
- No access-token blacklist, Redis revocation store, or token-version mechanism exists in M2.10. Password reset does not instantly terminate active HTTP requests with unexpired access JWTs.

---

### Cross-Milestone Security Architecture: Shared Per-User Barrier

**Global Lock Ordering:**
To serialize security-sensitive per-user credential and session mutations without deadlocks, a strict global lock hierarchy is established:
$$\text{UserCredential} \longrightarrow \text{RefreshSession}$$

All sensitive operations follow this hierarchy:
- **Login (`POST /api/v1/auth/login`):** Locks `UserCredential` by `userId`.
- **Forgot Password (`POST /api/v1/auth/forgot-password`):** Locks `UserCredential` by `userId`.
- **Reset Password (`POST /api/v1/auth/reset-password`):** Locks `UserCredential` by `userId`, then bulk-revokes active `RefreshSession` rows.
- **Refresh Token (`POST /api/v1/auth/refresh`):** Preliminary lookup resolves `userId`, locks `UserCredential` by `userId`, then locks `RefreshSession` row.

**Reset vs. Refresh Race Guarantees:**
When a password reset and a refresh token rotation execute concurrently for the same user:
- **Case A (Reset acquires `UserCredential` lock first):**
  - Reset verifies OTP, mutates password, revokes all active refresh sessions, and commits.
  - Refresh was blocked waiting on `UserCredential` lock. Refresh unblocks, locks its session row, observes `revokedAt != null`, and fails with `401 REFRESH_TOKEN_INVALID`. No replacement session S2 is created.
- **Case B (Refresh acquires `UserCredential` lock first):**
  - Refresh verifies session, rotates S1 to S2, and commits.
  - Reset was blocked waiting on `UserCredential` lock. Reset unblocks, mutates password, and executes bulk revocation (`WHERE userId = :id AND revokedAt IS NULL`), which catches and revokes the newly created active S2 session.
- **Security Invariant:** In all interleavings, after the `resetPassword` transaction completes commit, **zero active refresh sessions remain** for that user.

**Login vs. Reset Serialization:**
- If login wins the lock, it completes credential verification and may issue a new session. Reset then executes, changes the password, and revokes the newly issued session.
- If reset wins the lock, it changes the password. Login unblocks, reads the updated credential hash, and rejects the old password.

**Forgot vs. Reset Serialization:**
- Forgot and reset requests for the same user serialize on `UserCredential`. Issuing a new token and consuming an existing token cannot corrupt token lifecycle state.

---

## 6. Profile & User API

### USER-01 Get My Profile

- **Endpoint:** `GET /api/v1/me`
- **Authentication:** Protected (Requires `Authorization: Bearer <accessToken>`)
- **Controller:** `UserController` (`@AuthenticationPrincipal AuthenticatedUserPrincipal principal`)
- **Service:** `UserService.getCurrentUser(principal.userId())`
- **Success Response:** HTTP 200 OK
- **Response DTO:** `MyProfileResponse`

**Response Schema:**

```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "username": "johndoe",
  "email": "user@example.com",
  "phone": "+1234567890",
  "displayName": "John Doe",
  "avatarStorageKey": "avatars/user-123.jpg",
  "bio": "Hello world",
  "status": "ACTIVE",
  "emailVerified": true
}
```

**Field Specifications (Exactly 9 Fields):**
- `id` (UUID): User unique identifier.
- `username` (string | null): Unique user handle, or null if not yet set.
- `email` (string): Normalized primary email address.
- `phone` (string | null): Contact phone number, or null.
- `displayName` (string | null): Public display name, or null.
- `avatarStorageKey` (string | null): Storage identifier/key for user avatar, or null.
  - *Implementation Decision:* Current backend stores validated storage keys and does not yet contain a media/CDN URL resolver. The API returns `avatarStorageKey` directly rather than an invented CDN URL. If media architecture later resolves presigned/public URLs, contract may evolve.
- `bio` (string | null): Profile biography text, or null.
- `status` (string enum): Current account status (`ACTIVE`). Only accounts in `ACTIVE` status can view profile.
- `emailVerified` (boolean): Verification state, computed as `emailVerifiedAt != null`. The underlying `emailVerifiedAt` timestamp is not exposed in the `/me` response.

**Field Exclusions & Privacy:**
- `createdAt` is explicitly omitted from `MyProfileResponse` in M2.11.
- Sensitive credential internals (`passwordHash`, `failedAttempts`, `lockedUntil`, credentials, refresh sessions) are strictly omitted.

**Database Lookup & Account Status Enforcement:**
- **Zero Filter DB Hit:** `JwtAuthenticationFilter` performs zero database queries. Only resource flows needing user data perform database reads.
- **Resource Lookup:** `UserService` queries `UserRepository.findById(userId)`.
- **User Record Not Found:** If a cryptographically valid token contains a user UUID that does not exist in the database (e.g., deleted account), the endpoint returns HTTP 401 `AUTH_TOKEN_INVALID` (`"Invalid authentication token."`), NOT 404.
- **Account Status Policy:**
  - `ACTIVE`: HTTP 200 OK with `MyProfileResponse`.
  - `SUSPENDED`: HTTP 403 Forbidden with `ACCOUNT_SUSPENDED` (`"Account has been suspended."`).
  - `DEACTIVATED`: HTTP 403 Forbidden with `ACCOUNT_DEACTIVATED` (`"Account has been deactivated."`).
  - `PENDING_VERIFICATION`: HTTP 403 Forbidden with `EMAIL_NOT_VERIFIED` (`"Email address has not been verified."`).
  - *Note:* This check is performed inside `UserService` after database retrieval; it is not performed globally in `JwtAuthenticationFilter`.

**Error Responses:**
- `401 UNAUTHORIZED`: Emitted by entry point when `Authorization` header is missing or empty on this protected endpoint.
- `401 AUTH_TOKEN_EXPIRED`: Emitted when the supplied Bearer access JWT has expired.
- `401 AUTH_TOKEN_INVALID`: Emitted when Bearer access JWT is malformed, invalid signature, non-UUID subject, opaque refresh token, profile-completion token, or user is not found in database.
- `403 ACCOUNT_SUSPENDED`: Authenticated account is suspended in database.
- `403 ACCOUNT_DEACTIVATED`: Authenticated account is deactivated in database.
- `403 EMAIL_NOT_VERIFIED`: Authenticated account is pending verification in database.

### USER-02 Update Profile

`PATCH /api/v1/me/profile`

Editable: display name, bio, avatar reference and other safe profile fields. Email, username and account status are not changed through this endpoint.

### USER-03 Change Username

`PATCH /api/v1/me/username`  
Normalize, validate format and enforce uniqueness.

### USER-04 Get Privacy Settings

`GET /api/v1/me/privacy`

Returns current privacy settings with defaults applied upon registration:
- `discoverByUsername`: boolean (default `true`)
- `discoverByQr`: boolean (default `true`)
- `discoverByEmail`: boolean (default `false`)
- `discoverByPhone`: boolean (default `false`)
- `dmPolicy`: enum `EVERYONE` (default), `MUTUAL_GROUPS`, `FRIENDS_ONLY`
- `friendRequestPolicy`: enum `EVERYONE` (default), `MUTUAL_GROUPS`, `NONE`
- `showOnlineStatus`: boolean (default `true`)
- `showLastSeen`: boolean (default `true`)

Semantics of `dmPolicy`:
- `EVERYONE`: Friends DM directly; non-friends must use Message Request (max 3 text messages).
- `MUTUAL_GROUPS`: Only non-friends sharing a group can send Message Request.
- `FRIENDS_ONLY`: Non-friends cannot send Message Request.

Semantics of `friendRequestPolicy`:
- `EVERYONE`: Any valid user can send friend requests.
- `MUTUAL_GROUPS`: Only users sharing a mutual group can send friend requests.
- `NONE`: Friend requests are blocked.

### USER-05 Update Privacy Settings

`PATCH /api/v1/me/privacy`

Supports partial updates to any of the privacy fields listed above.

### USER-06 Change Password

`POST /api/v1/me/change-password`  
Verify current password, hash new password and optionally revoke other sessions.

### USER-07 Personal QR

`GET /api/v1/me/qr`  
Returns a stable application/user deep-link value; Flutter may generate the QR bitmap locally. No QR-image table is required.

### USER-08 Public Profile

`GET /api/v1/users/{userId}`  
Returns privacy-filtered public fields, relationship status, mutual group count, messaging/friend-request capability and presence fields if allowed.

### USER-09 Search Users

`GET /api/v1/users/search?q={query}&page=0&size=20`  
Search respects `discover_by_*` privacy settings.

---

## 7. Friend / Social / Block API

### SOCIAL-01 Send Friend Request

`POST /api/v1/users/{userId}/friend-requests`

Validate: not self, target exists, no block in either direction, target privacy allows request, not already friends, no pending request and declined cooldown has expired. Create PENDING request and publish notification event.

Errors: `CANNOT_FRIEND_SELF`, `USER_BLOCKED`, `ALREADY_FRIENDS`, `FRIEND_REQUEST_ALREADY_PENDING`, `FRIEND_REQUEST_COOLDOWN_ACTIVE`, `FRIEND_REQUEST_NOT_ALLOWED`.

### SOCIAL-02 Received Friend Requests

`GET /api/v1/me/friend-requests?direction=received`

### SOCIAL-03 Sent Friend Requests

`GET /api/v1/me/friend-requests?direction=sent`

### SOCIAL-04 Accept Friend Request

`POST /api/v1/friend-requests/{requestId}/accept`  
Transaction: request PENDING -> ACCEPTED and create ACTIVE friendship using canonical pair IDs.

### SOCIAL-05 Decline Friend Request

`POST /api/v1/friend-requests/{requestId}/decline`  
PENDING -> DECLINED; sender receives a 24-hour resend cooldown.

### SOCIAL-06 Cancel Friend Request

`POST /api/v1/friend-requests/{requestId}/cancel`  
Sender only. PENDING -> CANCELLED. No cooldown.

### SOCIAL-07 Friends List

`GET /api/v1/me/friends?page=0&size=30`

### SOCIAL-08 Unfriend

`DELETE /api/v1/friends/{userId}`  
Friendship becomes ENDED; DM history remains; immediate re-request is allowed.

### SOCIAL-09 Block User

`POST /api/v1/users/{userId}/block`

Transaction: create directional block, end friendship, cancel pending friend request, cancel pending message request, prevent future direct social interaction, but preserve shared-group membership/business history and required financial/activity visibility.

### SOCIAL-10 Unblock User

`DELETE /api/v1/users/{userId}/block`  
Does not restore friendship and creates no cooldown.

### SOCIAL-11 Blocked Users

`GET /api/v1/me/blocked-users`

---

## 8. Group API

### GROUP-01 Create Group

`POST /api/v1/groups`

```json
{
  "name": "Đà Nẵng 2026",
  "description": "Chuyến đi hè",
  "avatarStorageKey": null
}
```

**Authorization:** any ACTIVE authenticated user.  
**Transaction:** YES.

Business flow:
1. Validate current user ACTIVE.
2. Create Group ACTIVE with owner_user_id=current user.
3. Create default GroupSettings.
4. Create ACTIVE GroupMembership role OWNER.
5. Create one GROUP Conversation.
6. Create conversation sequence state.
7. Write GROUP_CREATED activity log.
8. Commit all operations.

### GROUP-02 My Groups

`GET /api/v1/groups`  
Filters: ACTIVE / ARCHIVED.

### GROUP-03 Recent Groups

`GET /api/v1/groups/recent`  
Used by Home and Groups screens.

### GROUP-04 Group Detail

`GET /api/v1/groups/{groupId}`

### GROUP-05 Group Overview

`GET /api/v1/groups/{groupId}/overview`

Aggregates group identity, current user's role/permissions, upcoming activities, required actions, poll/task previews, finance/fund summary and recent updates.

### GROUP-06 Update Group

`PATCH /api/v1/groups/{groupId}`

Owner/Admin can edit description. Name/avatar are Owner/Admin by default and may be editable by Members only when corresponding group settings allow.

### GROUP-07 Group Settings

`GET /api/v1/groups/{groupId}/settings`  
`PATCH /api/v1/groups/{groupId}/settings`

Settings include member name/avatar editing, member Activity creation, member message pinning, join policy and chat history policy.

### GROUP-08 Members

`GET /api/v1/groups/{groupId}/members`  
`GET /api/v1/groups/{groupId}/members/{userId}`

### GROUP-09 Promote Admin

`POST /api/v1/groups/{groupId}/members/{userId}/promote-admin`  
Owner only.

### GROUP-10 Demote Admin

`POST /api/v1/groups/{groupId}/members/{userId}/demote-admin`  
Owner only.

### GROUP-11 Kick Member

`POST /api/v1/groups/{groupId}/members/{userId}/kick`

Owner can kick Admin or Member. Admin can kick Member only. Kicked user may rejoin later. Membership history is retained.

### GROUP-12 Ban Member

`POST /api/v1/groups/{groupId}/members/{userId}/ban`

Same role restrictions as Kick. Creates active ban and prevents join/request until unbanned.

### GROUP-13 Leave Group

`POST /api/v1/groups/{groupId}/leave`

Member/Admin can leave. Admin loses role. Owner cannot leave while another active member exists and must transfer ownership first.

### GROUP-14 Transfer Ownership

`POST /api/v1/groups/{groupId}/transfer-ownership`

```json
{
  "newOwnerUserId": "..."
}
```

Transaction: lock group, ensure target is active member/admin, new owner -> OWNER, old owner -> ADMIN, update owner_user_id and write activity log.

### GROUP-15 Direct Invitation

`POST /api/v1/groups/{groupId}/invitations`

Direct invite acceptance bypasses join approval policy. Banned users cannot be invited successfully.

### GROUP-16 My Group Invitations

`GET /api/v1/me/group-invitations`

### GROUP-17 Accept/Decline/Cancel Invitation

`POST /api/v1/group-invitations/{id}/accept`
`POST /api/v1/group-invitations/{id}/decline`
`POST /api/v1/group-invitations/{id}/cancel`

- Acceptance transaction checks group ACTIVE, invite valid, user not banned, no ACTIVE membership and active member count below 100.
- Authorized Owner/Admin can cancel a PENDING direct invitation. Once cancelled, the invitee cannot accept it.
- `ACCEPTED`, `DECLINED`, `CANCELLED` are terminal states. Direct invitations do not expire.

### GROUP-18 Create Invite Link/Code/QR

`POST /api/v1/groups/{groupId}/invite-links`

Supports expiration and usage limit. QR is generated from invite code/deep link; no QR-image table is needed.

### GROUP-19 Invite Links

`GET /api/v1/groups/{groupId}/invite-links`  
`POST /api/v1/group-invite-links/{id}/revoke`

### GROUP-20 Resolve/Join by Invite Code

`GET /api/v1/group-invites/{inviteCode}`  
`POST /api/v1/group-invites/{inviteCode}/join`

`AUTO_JOIN` creates active membership if valid; `APPROVAL_REQUIRED` creates a pending join request. Invite-link usage count increments only when active membership is actually created.

### GROUP-21 Join Requests

`GET /api/v1/groups/{groupId}/join-requests`
`POST /api/v1/group-join-requests/{requestId}/approve`
`POST /api/v1/group-join-requests/{requestId}/reject`
`POST /api/v1/group-join-requests/{requestId}/cancel`

- Approval is transactional and rechecks group capacity, ban and membership state.
- Requester can cancel their own PENDING join request. `CANCELLED` is a terminal state and does not create membership.
- After cancellation, user may submit a new join request later if still eligible (not banned and no existing active membership).

### GROUP-22 Bans

`GET /api/v1/groups/{groupId}/bans`  
`DELETE /api/v1/groups/{groupId}/bans/{userId}`

Unban does not automatically rejoin the user.

### GROUP-23 Archive/Restore/Delete

`POST /api/v1/groups/{groupId}/archive`  
`POST /api/v1/groups/{groupId}/restore`  
`DELETE /api/v1/groups/{groupId}`

Archive preserves history/memberships but makes the group read-only. Restore is Owner only. Delete is soft/business delete and requires strong confirmation at UI level.

### GROUP-24 Activity Log

`GET /api/v1/groups/{groupId}/activity-log?page=0&size=30`

---

## 9. Chat & Direct Message API

### CHAT-01 Open/Create Direct Conversation

`POST /api/v1/direct-conversations`

```json
{
  "userId": "..."
}
```

Backend reuses the canonical pair conversation and determines access status `OPEN`, `REQUEST_PENDING` or `REQUEST_DECLINED` based on friendship, privacy, block and existing Message Request state.

### CHAT-02 Conversation List

`GET /api/v1/conversations`

Returns conversation identity, type, last message preview/time, unread count and appropriate presence indicator.

### CHAT-03 Message Requests

`GET /api/v1/message-requests`

### CHAT-04 Accept/Decline Message Request

`POST /api/v1/message-requests/{id}/accept`
`POST /api/v1/message-requests/{id}/decline`

Rules: before acceptance sender may send max 3 TEXT messages and no images/files; decline keeps conversation/request history and starts 72-hour cooldown; Accept opens direct conversation but does not create friendship; Block terminates any pending message request with status CANCELLED without activating a 72-hour decline cooldown, and unblocking does not revive it.

### CHAT-05 Message History

`GET /api/v1/conversations/{conversationId}/messages?beforeSequence={seq}&limit=30`

Must enforce group history policy, join time, delete-for-me rows, UNSENT representation, block/direct access and active/historical membership rules.

### CHAT-06 Send Message

Primary realtime command is WebSocket `SEND_MESSAGE`.

```json
{
  "clientMessageId": "client-generated-id",
  "conversationId": "...",
  "type": "TEXT",
  "content": "Tối nay sân cũ nhé",
  "replyToMessageId": null,
  "attachments": []
}
```

Transaction: authorize conversation; validate Message Request restrictions; validate <=10 images; allocate monotonic conversation sequence; persist message; update conversation last_message; commit; publish/broadcast `MESSAGE_CREATED`. `clientMessageId` supports retry/idempotency.

### CHAT-07 Edit Message

`PATCH /api/v1/messages/{messageId}`  
Sender only, ACTIVE message, <=15 minutes. Preserve edit history and return/broadcast Edited state.

### CHAT-08 Unsend Message

`POST /api/v1/messages/{messageId}/unsend`  
Sender only, <=15 minutes. Message becomes UNSENT, normal content is no longer exposed, and any active pin is removed automatically.

### CHAT-09 Delete For Me

`DELETE /api/v1/messages/{messageId}/me`  
Creates message_hidden_users visibility row; does not affect other users.

### CHAT-10 Reaction

`PUT /api/v1/messages/{messageId}/reaction`

```json
{
  "emoji": "👍"
}
```

No reaction -> create. Different emoji -> replace. Same emoji -> toggle off. Maximum one emoji/user/message is enforced by database key + service behavior.

### CHAT-11 Read State

`PUT /api/v1/conversations/{conversationId}/read-state`

```json
{
  "lastReadSequence": 1234
}
```

Read state stores last-read sequence instead of one seen row per message.

### CHAT-12 Pin Message

`POST /api/v1/messages/{messageId}/pin`  
`DELETE /api/v1/messages/{messageId}/pin`  
`GET /api/v1/conversations/{conversationId}/pins`

Owner/Admin or Member if group setting permits. Max 20 active pins/group conversation.

### CHAT-13 Search Messages

`GET /api/v1/conversations/{conversationId}/messages/search?q=&senderId=&from=&to=`

Search respects all history visibility, hidden and UNSENT rules.

---

## 10. WebSocket Contract

Suggested endpoint:

```text
/ws
```

Connection must be authenticated.

### Client -> Server commands

```text
SEND_MESSAGE
EDIT_MESSAGE
UNSEND_MESSAGE
SET_REACTION
MARK_READ
TYPING_START
TYPING_STOP
```

### Server -> Client events

```text
MESSAGE_CREATED
MESSAGE_EDITED
MESSAGE_UNSENT
REACTION_UPDATED
MESSAGE_READ
MESSAGE_PINNED
MESSAGE_UNPINNED
USER_TYPING
USER_STOPPED_TYPING
PRESENCE_CHANGED
```

### Typing

Ephemeral; Redis key such as `typing:{conversationId}:{userId}` with short TTL (about 5 seconds). Not persisted as business data.

### Presence

Live presence resides in Redis; persistent last-seen snapshot may be written to `user_presence_snapshots`. Presence exposure always respects privacy settings.

---

## 11. Activity API

### ACT-01 Create Activity

`POST /api/v1/groups/{groupId}/activities`

```json
{
  "title": "Đánh cầu lông",
  "description": null,
  "startAt": "2026-09-01T19:00:00+07:00",
  "endAt": "2026-09-01T21:00:00+07:00",
  "timezone": "Asia/Ho_Chi_Minh",
  "location": {
    "type": "PHYSICAL",
    "name": "Sân ABC",
    "address": "...",
    "latitude": null,
    "longitude": null
  },
  "maxParticipants": 8
}
```

Authorization: Owner/Admin; Member when group setting permits. Create state `PLANNING`. Snapshot eligible users to preserve `NO_RESPONSE` semantics. Initialize waitlist sequence. Past start times should generally be rejected except administrative/correction flow.

### ACT-02 Activity List

`GET /api/v1/groups/{groupId}/activities`  
Filters: status, RSVP, creator, from/to.

### ACT-03 Activity Detail

`GET /api/v1/activities/{activityId}`  
Returns core info, current user's RSVP, counts/capacity, waitlist, poll/task/expense/discussion previews and permission flags.

### ACT-04 Update Activity

`PATCH /api/v1/activities/{activityId}`

Creator may edit own Activity; Owner/Admin may edit any Activity. Allowed fields depend on state. CONFIRMED time/location changes are logged and notify Going/Maybe participants. Capacity decrease is rejected if below current GOING count. Capacity increase auto-promotes waitlisted users FIFO under parent activity lock. IN_PROGRESS allows limited practical edits. CANCELLED core fields are locked. COMPLETED allows only limited correction/logging.

### ACT-05 Confirm Activity

`POST /api/v1/activities/{activityId}/confirm`  
`PLANNING -> CONFIRMED`.

### ACT-06 Cancel Activity

`POST /api/v1/activities/{activityId}/cancel`

```json
{
  "reason": "Thời tiết xấu"
}
```

### ACT-07 Complete Activity

`POST /api/v1/activities/{activityId}/complete`  
Useful for activities without end time. Activities with end time can automatically transition based on scheduler/domain logic.

### ACT-08 RSVP

`PUT /api/v1/activities/{activityId}/rsvp`

```json
{
  "status": "GOING"
}
```

User can request GOING/MAYBE/NOT_GOING. WAITLIST is assigned by backend, not chosen directly.

Transaction + locking flow:
1. Lock capacity-sensitive activity/participant state.
2. Ensure Activity is not COMPLETED/CANCELLED.
3. Ensure user eligible.
4. If GOING requested and capacity available -> GOING.
5. If full -> WAITLIST and assign monotonic FIFO position.
6. When GOING slot is freed, promote first WAITLIST automatically.
7. Write RSVP history.
8. Publish `RSVP_CHANGED` / `WAITLIST_PROMOTED` events.

Late GOING is allowed while IN_PROGRESS. Completed/cancelled RSVP is locked.

### ACT-09 Participants

`GET /api/v1/activities/{activityId}/participants`  
Groups response by GOING, MAYBE, NOT_GOING, NO_RESPONSE, WAITLIST.

---

## 12. Poll API

### POLL-01 Create Poll

`POST /api/v1/activities/{activityId}/polls`

```json
{
  "question": "Đi Hội An ngày nào?",
  "type": "SINGLE_CHOICE",
  "options": ["Thứ 6", "Thứ 7", "Chủ nhật"],
  "allowMemberAddOption": true,
  "maxSelections": null,
  "voteVisibility": "PUBLIC",
  "resultVisibility": "IMMEDIATE",
  "deadlineAt": "2026-09-01T12:00:00+07:00"
}
```

Vote visibility cannot be changed after the first vote.

### POLL-02 List/Detail

`GET /api/v1/activities/{activityId}/polls`  
`GET /api/v1/polls/{pollId}`

### POLL-03 Vote

`PUT /api/v1/polls/{pollId}/vote`

```json
{
  "optionIds": ["..."]
}
```

Poll must be OPEN and before deadline. Single choice requires exactly one option. Multiple choice enforces maxSelections when configured. Existing vote may be changed while poll remains open.

### POLL-04 Add Option

`POST /api/v1/polls/{pollId}/options`  
Allowed only when creator enabled member-added options.

### POLL-05 Edit/Delete/Disable Option

Before any vote, option creator may edit/delete their option where allowed. Once voted, materially changing/deleting is forbidden. Poll Creator/Owner/Admin may disable an option while retaining existing votes.

`POST /api/v1/poll-options/{optionId}/disable`

### POLL-06 Close Poll

`POST /api/v1/polls/{pollId}/close`
Creator/authorized moderator may close early (`closed_at` set to now, `closed_by` set to actor). Poll also closes automatically upon reaching deadline (`closed_at` set to close time, `closed_by` is null). In both cases, persisted status transitions to CLOSED and no further votes or option changes are permitted.

### POLL-07 Public Voters

`GET /api/v1/polls/{pollId}/voters`  
Only for PUBLIC polls. Anonymous polls still store user IDs internally for integrity but API never exposes voter identity.

---

## 13. Task API

### TASK-01 Create Task

`POST /api/v1/activities/{activityId}/tasks`

```json
{
  "title": "Thuê xe",
  "description": null,
  "assigneeUserIds": ["...", "..."],
  "dueAt": "2026-09-01T12:00:00+07:00"
}
```

Task may have 1+ assignees or remain unassigned. Multiple assignees share ONE task status.

### TASK-02 List/Detail

`GET /api/v1/activities/{activityId}/tasks`  
`GET /api/v1/tasks/{taskId}`  
Filters: status, assignedToMe.

### TASK-03 Update Task

`PATCH /api/v1/tasks/{taskId}`  
Core task edits are controlled by Activity Creator/Owner/Admin.

### TASK-04 Change Status

`PUT /api/v1/tasks/{taskId}/status`

```json
{
  "status": "IN_PROGRESS"
}
```

Any assignee, Owner/Admin or Activity Creator can change shared status. Every transition is logged with actor, old status, new status and timestamp.

### TASK-05 Claim Unassigned Task

`POST /api/v1/tasks/{taskId}/claim`

No subtasks in MVP. Completing Activity does not automatically complete tasks.

---

## 14. Activity Discussion API

`GET    /api/v1/activities/{activityId}/comments`  
`POST   /api/v1/activities/{activityId}/comments`  
`POST   /api/v1/comments/{commentId}/replies`  
`PATCH  /api/v1/comments/{commentId}`  
`DELETE /api/v1/comments/{commentId}`

Rules:
- One reply level only.
- User can edit/delete own comments.
- Owner/Admin can moderate; moderation is logged.
- COMPLETED activities may retain active discussion.
- CANCELLED activities may lock new comments based on domain setting/rule.

---

## 15. Calendar & Reminder API

### CAL-01 Global Calendar

`GET /api/v1/calendar/activities?from=&to=&rsvp=&groupId=&status=`

Aggregates Activities across user's groups. Views may include PLANNING as tentative and CANCELLED as cancelled. Filters support All, Going, Maybe, No Response, Waitlist and Group.

There is no Calendar business table; calendar is a read model over Activity + Participant + Reminder.

### CAL-02 Reminder

`GET /api/v1/activities/{activityId}/reminder`  
`PUT /api/v1/activities/{activityId}/reminder`

```json
{
  "enabled": true,
  "offsetMinutes": 60
}
```

Single reminder configuration per user per activity. UI may offer preset offsets (e.g. 1 day = 1440 min, 1 hour = 60 min) or custom offset. Disabling sets `enabled = false`. Activity time changes reschedule affected reminders.

---

## 16. Expense API

### FIN-01 Create Expense - Equal Split

`POST /api/v1/groups/{groupId}/expenses`

```json
{
  "title": "Tiền sân",
  "amount": 600000,
  "payerUserId": "...",
  "splitMethod": "EQUAL",
  "participantUserIds": ["...", "...", "..."],
  "activityId": null,
  "occurredAt": "2026-09-01T12:00:00+07:00",
  "note": null,
  "receiptStorageKey": null
}
```

One payer only. Payer may be a participant. Backend calculates all ExpenseShare values; Flutter is not authoritative. EQUAL split requires totalAmount >= participantCount * 0.01 so every share > 0; uses deterministic remainder-unit distribution: base = floor(amount / N, 2); remainder units (0.01) distributed one-by-one to paid_by (if participant), then remaining participants ordered by canonical UUID.

### FIN-02 Create Expense - Custom Amount

Same endpoint with `splitMethod=CUSTOM_AMOUNT` and explicit shares.

```json
{
  "title": "Ăn tối",
  "amount": 1000000,
  "payerUserId": "...",
  "splitMethod": "CUSTOM_AMOUNT",
  "shares": [
    {"userId": "...", "amount": 300000},
    {"userId": "...", "amount": 700000}
  ]
}
```

Service requires `sum(shares) == expense.amount`. No self-debt is generated for payer's own share.

### FIN-03 Expense From Activity

`activityId` is optional and must reference an Activity in the same Group. UI may suggest GOING members, but later RSVP changes never mutate existing Expense participation/shares.

### FIN-04 Expense List

`GET /api/v1/groups/{groupId}/expenses?activityId=&involvingMe=&createdByMe=&from=&to=`

### FIN-05 Expense Detail

`GET /api/v1/expenses/{expenseId}`  
Includes payer, shares, activity reference, receipt, creator and change-history summary.

### FIN-06 Update Expense

`PATCH /api/v1/expenses/{expenseId}`

Creator may edit own Expense; Owner/Admin can perform corrections. Amount/payer/participants/split changes require audit log and debt recalculation from facts. Must preserve BOTH COMPLETED accounting protection (cannot cause already completed settlements to exceed underlying obligation / over-settle) AND PENDING reservation protection (rejected if resultingDebt < pendingReserved). Violation rejected with `EXPENSE_UPDATE_NOT_ALLOWED`.

### FIN-07 Cancel Expense

`POST /api/v1/expenses/{expenseId}/cancel`  
No hard-delete financial history. Must preserve BOTH COMPLETED accounting protection (cancellation cannot leave completed settlements over-settled) AND PENDING reservation protection (rejected if resultingDebt < pendingReserved). Violation rejected with `EXPENSE_UPDATE_NOT_ALLOWED`.

---

## 17. Balance / Debt API

There is no authoritative `debts` table.

Current pairwise debt is derived from:

```text
Expense payer + ExpenseShare facts
minus COMPLETED Settlements
then pairwise netting
```

### BAL-01 My Group Balances

`GET /api/v1/groups/{groupId}/balances/me`

```json
{
  "totalOwedByMe": 300000,
  "totalOwedToMe": 550000,
  "balances": [
    {
      "user": {
        "id": "...",
        "displayName": "Nam",
        "avatarUrl": "..."
      },
      "direction": "OWES_YOU",
      "amount": 200000
    }
  ]
}
```

### BAL-02 Balance With User

`GET /api/v1/groups/{groupId}/balances/{userId}`  
Includes net amount, source Expense breakdown, completed Settlements and pending settlement action context.

Frontend is never allowed to set arbitrary debt.

---

## 18. Settlement API

### SET-01 Create Settlement

`POST /api/v1/groups/{groupId}/settlements`

```json
{
  "otherUserId": "...",
  "amount": 100000,
  "declarationType": "I_PAID"
}
```

Backend derives debtor/creditor from current pairwise balance and declaration semantics. Initiator integrity: created_by matches from_user_id for I_PAID and to_user_id for I_RECEIVED. Validate amount > 0 and <= current outstanding debt. Initial state: PENDING.

### SET-02 Confirm

`POST /api/v1/settlements/{id}/confirm`

Two-sided confirmation:
- debtor says I_PAID -> creditor confirms;
- creditor says I_RECEIVED -> debtor confirms.

Only COMPLETED affects debt.

### SET-03 Reject

`POST /api/v1/settlements/{id}/reject`

### SET-04 Cancel

`POST /api/v1/settlements/{id}/cancel`  
Creator may cancel while still PENDING.

### SET-05 List

`GET /api/v1/groups/{groupId}/settlements?status=&involvingMe=&otherUserId=`

Settlement confirmation is transaction-sensitive and should revalidate current financial state where required.

---

## 19. Group Fund API

Zero or one Fund per Group in MVP.

### FUND-01 Create Fund

`POST /api/v1/groups/{groupId}/fund`  
Owner only.

### FUND-02 Get Fund

`GET /api/v1/groups/{groupId}/fund`

### FUND-03 Fund Overview

`GET /api/v1/funds/{fundId}/overview`

Returns computed balance, active collection preview, pending contribution-verification count, pending reimbursements, recent transactions and current-user permissions.

Fund balance is NEVER directly edited or trusted from a stored balance field. It is derived from the ledger:

```text
Confirmed Contributions
- Fund Expenses
- Completed Reimbursements
± Reversals
```

### FUND-04 Managers

`GET    /api/v1/funds/{fundId}/managers`  
`POST   /api/v1/funds/{fundId}/managers/{userId}`  
`DELETE /api/v1/funds/{fundId}/managers/{userId}`

Owner always manages. Owner may grant Fund Manager to eligible Admin.

### FUND-05 Create Collection

`POST /api/v1/funds/{fundId}/collections`

```json
{
  "title": "Quỹ tháng 9",
  "description": null,
  "deadlineAt": "2026-09-10T23:59:59+07:00",
  "obligations": [
    {"userId": "...", "requiredAmount": 500000},
    {"userId": "...", "requiredAmount": 300000}
  ]
}
```

Transaction creates collection + member obligations. Required amount may differ per member.

### FUND-06 Collection List/Detail

`GET /api/v1/funds/{fundId}/collections`  
`GET /api/v1/collections/{collectionId}`

Collection statuses: OPEN, CLOSED, CANCELLED.
- When Collection transitions to CANCELLED, all associated PENDING contributions transition to CANCELLED (not REJECTED, no ledger entry).
- When Collection transitions to CLOSED, existing PENDING contributions may still be confirmed or rejected, but no new contributions are accepted.

Derived obligation state: UNPAID, PARTIAL, PAID, OVERDUE. Those states are computed from required, confirmed/pending contributions and deadline rather than being an authoritative manually-editable status.

### FUND-07 Submit Contribution

`POST /api/v1/collections/{collectionId}/contributions`

```json
{
  "amount": 200000,
  "paymentTime": "2026-09-03T12:00:00+07:00",
  "proofStorageKey": "...",
  "note": "Đã chuyển khoản"
}
```

Initial state PENDING. Late contribution after deadline remains allowed.

Concurrency-sensitive validation:

```text
maximum new contribution
= required amount
- confirmed contributions
- existing pending contributions
```

No overpayment is accepted.

### FUND-08 My Contributions / Verification Queue

`GET /api/v1/collections/{collectionId}/my-contributions`  
`GET /api/v1/funds/{fundId}/contributions?status=PENDING`

### FUND-09 Confirm Contribution

`POST /api/v1/contributions/{contributionId}/confirm`

Owner/Fund Manager. Transaction: lock contribution/context, ensure PENDING, confirm, create ledger IN transaction, publish event. Only CONFIRMED increases balance.

### FUND-10 Reject/Cancel Contribution

`POST /api/v1/contributions/{id}/reject`  
`POST /api/v1/contributions/{id}/cancel`

Manager rejects PENDING; member may cancel own PENDING contribution.

### FUND-11 Create Fund Expense

`POST /api/v1/funds/{fundId}/expenses`

```json
{
  "title": "Tiền xe",
  "amount": 1000000,
  "expenseDate": "2026-09-01",
  "receiptStorageKey": null,
  "note": null
}
```

Owner/Fund Manager. Transaction + lock computes current ledger balance, requires amount <= available balance, creates FundExpense and OUT ledger transaction. No negative fund balance.

### FUND-12 Fund Expense List/Detail

`GET /api/v1/funds/{fundId}/expenses`  
`GET /api/v1/fund-expenses/{expenseId}`

### FUND-13 Request Reimbursement

`POST /api/v1/funds/{fundId}/reimbursements`

```json
{
  "amount": 500000,
  "reason": "Ứng tiền mua đồ ăn",
  "receiptStorageKey": "..."
}
```

Any eligible member may submit; initial state PENDING.
Creation reservation: At create-time, locks fund context and requires `pendingReserved + requestedAmount <= ledgerBalance`. If insufficient, returns `FUND_INSUFFICIENT_BALANCE`.

### FUND-14 Approve/Reject Reimbursement

`POST /api/v1/reimbursements/{id}/approve`  
`POST /api/v1/reimbursements/{id}/reject`

Approval transaction locks fund context, excludes current reimbursement from other pending sum (`currentAmount <= ledgerBalance - otherPending`), marks COMPLETED (`resolved_at = now()`, `resolved_by = actor`), and creates OUT ledger transaction. If balance is insufficient, request remains PENDING and API returns `FUND_INSUFFICIENT_BALANCE`.
Rejection/cancellation marks status REJECTED/CANCELLED (`resolved_at = now()`), releasing reserved amount immediately with no ledger entry.

### FUND-15 Ledger Transactions

`GET /api/v1/funds/{fundId}/transactions`  
`GET /api/v1/fund-transactions/{transactionId}`

Types: CONTRIBUTION, FUND_EXPENSE, REIMBURSEMENT, REVERSAL.

### FUND-16 Reverse/Correct Transaction

`POST /api/v1/fund-transactions/{id}/reverse`

```json
{
  "reason": "Sai số tiền"
}
```

Creates compensating/reversal ledger entry (1-to-1 full reversal, opposite direction, same amount). Never delete historical financial transactions. Reversal cannot reverse a REVERSAL transaction. If reversing a positive transaction results in negative available balance, operation is rejected.

### FUND-17 Close Fund

`POST /api/v1/funds/{fundId}/close`  
Owner only. Preconditions: ledger balance == 0, no PENDING reimbursements, no PENDING contributions, no OPEN collections. Sets status to CLOSED, records `closed_at = now()` and `closed_by = actor`. History remains viewable; new fund operations are disabled. Group may create a new ACTIVE fund later.

---

## 20. Notification API

### NOTI-01 Notification Center

`GET /api/v1/notifications?page=0&size=30`

Notification contains category, priority (`HIGH`, `NORMAL`, `LOW`), actor, target/deep link, timestamp and read state.

### NOTI-02 Unread Count

`GET /api/v1/notifications/unread-count`

### NOTI-03 Mark Read

`POST /api/v1/notifications/{notificationId}/read`

### NOTI-04 Mark All Read

`POST /api/v1/notifications/read-all`

### NOTI-05 Notification Settings

`GET   /api/v1/me/notification-settings`  
`PATCH /api/v1/me/notification-settings`

Response / Request payload:
```json
{
  "pushEnabled": true,
  "socialEnabled": true,
  "groupEnabled": true,
  "chatEnabled": true,
  "activityEnabled": true,
  "pollEnabled": true,
  "taskEnabled": true,
  "financeEnabled": true,
  "fundEnabled": true
}
```

Categories: Social, Group, Chat/DM, Activity, Poll, Task, Finance, Fund.
User registration automatically creates default notification settings with all fields set to `true`.
Notifications inbox records are always persisted in-app; these settings control PUSH delivery only.

### NOTI-06 Group Notification Settings

`GET /api/v1/groups/{groupId}/notification-settings`  
`PUT /api/v1/groups/{groupId}/notification-settings`

Mute choices: 1h, 8h, 1 day, until unmuted. Chat mute must not suppress critical business events.

### Push behavior

If user is currently viewing a conversation, use realtime delivery without push. Otherwise group-chat pushes should aggregate by conversation. High-value business events such as waitlist promotion, settlement confirmation and contribution verification remain explicit.

Stale deep-link target actions must become non-actionable rather than causing invalid state mutation.

---

## 21. Search, Upload & Home Read Models

### SEARCH-01 Global Search

`GET /api/v1/search?q={query}&type={optional}`

MVP categories: PEOPLE, joined GROUPS, ACTIVITIES, CONVERSATIONS.

### MEDIA-01 Request Upload Target

`POST /api/v1/uploads/presign`

```json
{
  "category": "CHAT_IMAGE",
  "fileName": "photo.jpg",
  "contentType": "image/jpeg",
  "fileSize": 1234567
}
```

Backend validates auth, category, content type and size. Response returns upload target and `storageKey`. Business endpoints store only validated references/metadata, not Base64 blobs.

Categories: AVATAR, GROUP_AVATAR, CHAT_IMAGE, EXPENSE_RECEIPT, CONTRIBUTION_PROOF, FUND_EXPENSE_RECEIPT, REIMBURSEMENT_RECEIPT.

### HOME-01 Home Dashboard

`GET /api/v1/home`

Aggregated read model may return Recent Groups, Upcoming Activities, Finance Summary, Actions Required and Recent Updates. This is not a database entity.

### HOME-02 Actions Required

`GET /api/v1/me/actions-required`

Potential action types: RSVP_REQUIRED, POLL_VOTE_REQUIRED, TASK_DUE, SETTLEMENT_CONFIRMATION, FUND_CONTRIBUTION, CONTRIBUTION_VERIFICATION, REIMBURSEMENT_APPROVAL.

---

## 22. Group Security Matrix

| Action | Owner | Admin | Member |
|---|---:|---:|---:|
| View group | Yes | Yes | Yes |
| Chat | Yes | Yes | Yes |
| Edit description | Yes | Yes | No |
| Edit name/avatar | Yes | Yes | Config |
| Create Activity | Yes | Yes | Config |
| Pin message | Yes | Yes | Config |
| Approve join | Yes | Yes | No |
| Promote/Demote Admin | Yes | No | No |
| Kick Member | Yes | Yes | No |
| Kick Admin | Yes | No | No |
| Ban Member | Yes | Yes | No |
| Ban Admin | Yes | No | No |
| Transfer ownership | Yes | No | No |
| Archive/Restore | Yes | No | No |
| Delete group | Yes | No | No |

---

## 23. Activity Security Matrix

| Action | Owner/Admin | Activity Creator | Other Member |
|---|---:|---:|---:|
| View | Yes | Yes | Yes |
| Create | Yes | According to group setting | According to group setting |
| Edit core details | Yes | Yes | No |
| Confirm/Cancel | Yes | Yes | No |
| RSVP self | Yes | Yes | Yes |
| Change another user's RSVP | No | No | No |
| Moderate comment | Yes | Own comments | Own comments |

---

## 24. Finance & Fund Security Matrix

### Expense / Settlement

| Action | Owner/Admin | Member |
|---|---:|---:|
| View permitted group finance | Yes | Yes |
| Create Expense | Yes | Yes |
| Edit own Expense | Yes | Yes |
| Correct another Expense | Yes | No |
| Settle own debt | Yes | Yes |
| Confirm settlement involving self | Yes | Yes |
| Arbitrarily set debt | No | No |

### Group Fund

| Action | Owner | Fund Manager | Member |
|---|---:|---:|---:|
| View Fund | Yes | Yes | Yes |
| Create Fund | Yes | No | No |
| Create Collection | Yes | Yes | No |
| Verify Contribution | Yes | Yes | No |
| Add Fund Expense | Yes | Yes | No |
| Request Reimbursement | Yes | Yes | Yes |
| Approve Reimbursement | Yes | Yes | No |
| Assign Fund Manager | Yes | No | No |
| Close Fund | Yes | No | No |

---

## 25. Core Error Code Catalogue

### Authentication & Security

```text
UNAUTHORIZED
ACCESS_DENIED
AUTH_INVALID_CREDENTIALS
AUTH_TOKEN_EXPIRED
AUTH_TOKEN_INVALID
REFRESH_TOKEN_INVALID
EMAIL_NOT_VERIFIED
EMAIL_ALREADY_EXISTS
USERNAME_ALREADY_EXISTS
ACCOUNT_SUSPENDED
ACCOUNT_DEACTIVATED
ACCOUNT_LOCKED
PASSWORD_RESET_CODE_INVALID
```

*Authentication & Security Error Status & Disclosure Semantics:*
- `UNAUTHORIZED` (HTTP 401, `"Authentication is required."`): Emitted by `RestAuthenticationEntryPoint` when an unauthenticated request attempts to access a protected endpoint (missing, blank, or non-Bearer authorization header).
- `ACCESS_DENIED` (HTTP 403, `"Access is denied."`): Emitted by `RestAccessDeniedHandler` when an authenticated principal lacks required authority or permission.
- `AUTH_TOKEN_EXPIRED` (HTTP 401, `"Authentication token has expired."`): Emitted when a Bearer access JWT has expired (`exp < now`).
- `AUTH_TOKEN_INVALID` (HTTP 401, `"Invalid authentication token."`): Emitted when a Bearer token is malformed, has an invalid cryptographic signature, contains a non-UUID subject, has a blank token string following the Bearer scheme, represents a profile-completion token or opaque refresh token, or when the authenticated user ID no longer exists in the database during protected resource lookup (`GET /api/v1/me`). Parser exception details are never leaked.
- `AUTH_INVALID_CREDENTIALS` (HTTP 401, `"Invalid email or password."`): Emitted on unknown email or wrong password during login. Also emitted when wrong password is submitted for unverified, suspended, deactivated, or locked accounts.
- `REFRESH_TOKEN_INVALID` (HTTP 401, `"Invalid refresh token."`): Single external error emitted on unknown/random refresh token, expired token, revoked token, or previously rotated token during refresh rotation and logout.
- `EMAIL_NOT_VERIFIED` (HTTP 403, `"Email address has not been verified."`): Emitted after password verification succeeds on `PENDING_VERIFICATION` accounts, when attempting refresh with a valid credential for an unverified account (current session is revoked), or when accessing `GET /api/v1/me` with an unverified account.
- `ACCOUNT_SUSPENDED` (HTTP 403, `"Account has been suspended."`): Emitted after password verification succeeds on `SUSPENDED` accounts, when attempting refresh with a valid credential for a suspended account (current session is revoked), or when accessing `GET /api/v1/me` with a suspended account.
- `ACCOUNT_DEACTIVATED` (HTTP 403, `"Account has been deactivated."`): Emitted after password verification succeeds on `DEACTIVATED` accounts, when attempting refresh with a valid credential for a deactivated account (current session is revoked), or when accessing `GET /api/v1/me` with a deactivated account.
- `ACCOUNT_LOCKED` (HTTP 423, `"Account is temporarily locked."`): Emitted **only** when the password is verified as correct while the account is actively locked (`now < locked_until`). Never exposed on wrong-password requests.
- `PASSWORD_RESET_CODE_INVALID` (HTTP 400, `"Invalid password reset code."`): Single unified external error emitted on unknown email, non-ACTIVE account, missing/consumed/expired reset token, exhausted attempts ($\ge 5$), or wrong OTP code during password reset. Emitted as a single error to reduce reset-flow and account-state oracle leakage through normal response semantics (without claiming timing indistinguishability).

### Social

```text
CANNOT_FRIEND_SELF
ALREADY_FRIENDS
FRIEND_REQUEST_ALREADY_PENDING
FRIEND_REQUEST_COOLDOWN_ACTIVE
FRIEND_REQUEST_NOT_ALLOWED
USER_BLOCKED
MESSAGE_REQUEST_LIMIT_REACHED
MESSAGE_REQUEST_COOLDOWN_ACTIVE
DM_NOT_ALLOWED
```

### Group

```text
GROUP_NOT_FOUND
GROUP_ARCHIVED
GROUP_DELETED
NOT_GROUP_MEMBER
GROUP_MEMBER_LIMIT_REACHED
USER_BANNED_FROM_GROUP
GROUP_INVITATION_NOT_FOUND
GROUP_INVITATION_EXPIRED
JOIN_REQUEST_ALREADY_PENDING
INSUFFICIENT_GROUP_PERMISSION
TRANSFER_OWNERSHIP_REQUIRED
INVALID_OWNERSHIP_TARGET
```

### Chat

```text
CONVERSATION_NOT_FOUND
CONVERSATION_ACCESS_DENIED
MESSAGE_NOT_FOUND
MESSAGE_EDIT_WINDOW_EXPIRED
MESSAGE_UNSEND_WINDOW_EXPIRED
MESSAGE_ALREADY_UNSENT
PIN_LIMIT_REACHED
INVALID_MESSAGE_ATTACHMENT
```

### Activity

```text
ACTIVITY_NOT_FOUND
ACTIVITY_CLOSED
ACTIVITY_ALREADY_STARTED
ACTIVITY_ALREADY_COMPLETED
INVALID_ACTIVITY_TIME
ACTIVITY_CAPACITY_INVALID
RSVP_LOCKED
```

### Poll / Task

```text
POLL_NOT_FOUND
POLL_CLOSED
POLL_DEADLINE_PASSED
INVALID_POLL_SELECTION
MAX_POLL_SELECTIONS_EXCEEDED
POLL_OPTION_DISABLED
POLL_OPTION_CHANGE_NOT_ALLOWED
POLL_VOTERS_PRIVATE
TASK_NOT_FOUND
TASK_UPDATE_NOT_ALLOWED
TASK_ALREADY_ASSIGNED
TASK_NOT_CLAIMABLE
```

### Finance

```text
EXPENSE_NOT_FOUND
INVALID_EXPENSE_AMOUNT
EXPENSE_SPLIT_TOTAL_MISMATCH
EXPENSE_PARTICIPANT_INVALID
EXPENSE_UPDATE_NOT_ALLOWED
NO_OUTSTANDING_DEBT
SETTLEMENT_NOT_FOUND
SETTLEMENT_AMOUNT_EXCEEDS_DEBT
SETTLEMENT_ALREADY_RESOLVED
SETTLEMENT_CONFIRMATION_NOT_ALLOWED
```

### Fund

```text
FUND_NOT_FOUND
FUND_ALREADY_EXISTS
FUND_CLOSED
NOT_FUND_MANAGER
COLLECTION_NOT_FOUND
CONTRIBUTION_EXCEEDS_REMAINING_AMOUNT
CONTRIBUTION_NOT_PENDING
FUND_INSUFFICIENT_BALANCE
REIMBURSEMENT_NOT_FOUND
REIMBURSEMENT_ALREADY_RESOLVED
```

---

## 26. Domain Event Catalogue

```text
USER_REGISTERED
EMAIL_VERIFICATION_REQUESTED
PASSWORD_RESET_REQUESTED
FRIEND_REQUEST_SENT
FRIEND_REQUEST_ACCEPTED
USER_BLOCKED
GROUP_CREATED
GROUP_MEMBER_JOINED
GROUP_MEMBER_LEFT
GROUP_MEMBER_KICKED
GROUP_MEMBER_BANNED
GROUP_OWNERSHIP_TRANSFERRED
GROUP_ARCHIVED
MESSAGE_CREATED
MESSAGE_EDITED
MESSAGE_UNSENT
MESSAGE_REACTION_CHANGED
ACTIVITY_CREATED
ACTIVITY_CONFIRMED
ACTIVITY_TIME_CHANGED
ACTIVITY_LOCATION_CHANGED
ACTIVITY_CANCELLED
ACTIVITY_STARTED
ACTIVITY_COMPLETED
RSVP_CHANGED
WAITLIST_PROMOTED
POLL_CREATED
POLL_CLOSED
TASK_ASSIGNED
TASK_STATUS_CHANGED
EXPENSE_CREATED
EXPENSE_UPDATED
EXPENSE_CANCELLED
SETTLEMENT_CREATED
SETTLEMENT_COMPLETED
SETTLEMENT_REJECTED
FUND_CREATED
COLLECTION_CREATED
CONTRIBUTION_SUBMITTED
CONTRIBUTION_CONFIRMED
CONTRIBUTION_REJECTED
FUND_EXPENSE_CREATED
REIMBURSEMENT_REQUESTED
REIMBURSEMENT_COMPLETED
```

Domain events may use Spring `ApplicationEventPublisher` inside the modular monolith. They do not imply microservices.

---

## 27. DTO Catalogue

### Security Principals

```text
AuthenticatedUserPrincipal (record: UUID userId)
```

### Auth

```text
RegisterRequest / RegisterResponse
VerifyEmailRequest / VerifyEmailResponse
ResendVerificationRequest / ResendVerificationResponse
CompleteProfileRequest / CompleteProfileResponse
UsernameAvailabilityResponse
LoginRequest / LoginResponse
UserSummaryDto
RefreshTokenRequest / RefreshTokenResponse
LogoutRequest
ForgotPasswordRequest / ForgotPasswordResponse
ResetPasswordRequest
ChangePasswordRequest
```

### User / Social

```text
UserSummaryResponse
UserPublicProfileResponse
MyProfileResponse
UpdateProfileRequest
UpdateUsernameRequest
UpdatePrivacySettingsRequest
FriendRequestResponse
FriendResponse
BlockedUserResponse
```

*Profile DTO Differentiation:*
- `UserSummaryDto`: Embedded in authentication responses (`LoginResponse`), containing summary fields (`id`, `username`, `email`, `displayName`, `avatarUrl`).
- `MyProfileResponse`: Dedicated private profile response for `GET /api/v1/me`. Contains exactly 9 fields: `id`, `username`, `email`, `phone`, `displayName`, `avatarStorageKey`, `bio`, `status`, `emailVerified`. Does NOT expose `createdAt`, `emailVerifiedAt`, or credential/session internals.

### Group

```text
CreateGroupRequest
UpdateGroupRequest
GroupSummaryResponse
GroupDetailResponse
GroupOverviewResponse
GroupSettingsResponse
UpdateGroupSettingsRequest
GroupMemberResponse
CreateInvitationRequest
GroupInvitationResponse
CreateInviteLinkRequest
InviteLinkResponse
JoinRequestResponse
TransferOwnershipRequest
GroupActivityLogResponse
```

### Chat

```text
ConversationSummaryResponse
ConversationDetailResponse
MessageResponse
MessageAttachmentResponse
SendMessageCommand
EditMessageRequest
SetReactionRequest
UpdateReadStateRequest
MessageRequestResponse
PinnedMessageResponse
MessageSearchResultResponse
```

### Activity / Poll / Task / Discussion

```text
CreateActivityRequest
UpdateActivityRequest
ActivitySummaryResponse
ActivityDetailResponse
ChangeRsvpRequest
ActivityParticipantResponse
CreatePollRequest
PollResponse
VotePollRequest
CreatePollOptionRequest
CreateTaskRequest
UpdateTaskRequest
UpdateTaskStatusRequest
TaskResponse
CreateCommentRequest
UpdateCommentRequest
CommentResponse
ActivityReminderRequest
```

### Finance

```text
CreateExpenseRequest
CustomExpenseShareRequest
UpdateExpenseRequest
ExpenseSummaryResponse
ExpenseDetailResponse
BalanceSummaryResponse
BalanceWithUserResponse
BalanceDetailResponse
CreateSettlementRequest
SettlementResponse
```

### Fund

```text
CreateFundRequest
FundOverviewResponse
CreateCollectionRequest
CollectionObligationRequest
CollectionDetailResponse
SubmitContributionRequest
ContributionResponse
CreateFundExpenseRequest
FundExpenseResponse
CreateReimbursementRequest
ReimbursementResponse
FundTransactionResponse
ReverseTransactionRequest
```

---

## 28. Spring Boot Implementation Blueprint

Recommended feature-first package direction before Phase 6 finalizes exact architecture:

```text
com.app
├── auth
├── user
├── social
├── group
├── chat
├── activity
├── poll
├── task
├── discussion
├── calendar
├── finance
├── fund
├── notification
├── media
├── security
└── common
```

A feature may contain:

```text
controller/
service/
repository/
entity/
dto/
mapper/
event/
exception/
```

### Controller responsibility

- Accept HTTP request.
- Bind Request DTO.
- Execute `@Valid` input validation.
- Extract path/query parameters.
- Obtain authenticated principal/current user.
- Call Service.
- Return response/status.

Controller must remain thin and must not contain long business workflows.

### Service responsibility

- Business validation.
- Authorization coordination.
- State transitions.
- Cross-repository workflow.
- Transaction boundaries.
- Locking strategy where required.
- Domain event publication.

### Repository responsibility

- Find/save/exists/count.
- Persistence queries.
- Fetch with locking.
- Database-specific retrieval concerns.

Business workflow does not belong in Repository.

### Mapper responsibility

- Request DTO -> domain/entity input.
- Entity/projection -> Response DTO.

Manual mapping is acceptable initially. MapStruct may be introduced later.

---

## 29. Important Spring Boot Concept Map

```text
@RestController
→ REST endpoint controller

@RequestMapping
→ controller base path

@GetMapping / @PostMapping / @PatchMapping / @PutMapping / @DeleteMapping
→ HTTP route methods

@RequestBody
→ JSON body -> Java DTO

@PathVariable
→ value from URL path

@RequestParam
→ query/filter parameter

@Valid
→ Bean Validation on DTO

@Entity
→ Java persistence mapping

JpaRepository
→ persistence abstraction

@Service
→ business layer

@Transactional
→ atomic all-or-nothing business operation

@RestControllerAdvice
→ centralized API exception handling

Spring Security
→ authentication + request security pipeline

PasswordEncoder
→ safe password hashing

JWT
→ authenticated current-user identity

Pessimistic Lock
→ protect race-sensitive database state

WebSocket
→ realtime bidirectional communication

Redis
→ ephemeral realtime/cache/rate-limit state

ApplicationEventPublisher
→ decouple business action from secondary effects

Flyway
→ versioned PostgreSQL schema migration

OpenAPI / Swagger
→ executable API documentation
```

---

## 30. Screen -> API Mapping

### Home

```text
GET /api/v1/home
GET /api/v1/notifications/unread-count
```

### Groups list

```text
GET /api/v1/groups
GET /api/v1/groups/recent
GET /api/v1/me/group-invitations
```

### Group Overview

```text
GET /api/v1/groups/{id}/overview
```

### Members

```text
GET /api/v1/groups/{id}/members
```

### Global Chat

```text
GET /api/v1/conversations
GET /api/v1/message-requests
```

### Conversation

```text
GET /api/v1/conversations/{id}/messages
GET /api/v1/conversations/{id}/pins
WebSocket message/read/reaction/typing/presence events
```

### Activity List / Detail

```text
GET /api/v1/groups/{id}/activities
GET /api/v1/activities/{id}
PUT /api/v1/activities/{id}/rsvp
GET /api/v1/activities/{id}/polls
GET /api/v1/activities/{id}/tasks
GET /api/v1/activities/{id}/comments
```

### Calendar

```text
GET /api/v1/calendar/activities
```

### Finance Dashboard

```text
GET /api/v1/groups/{id}/balances/me
GET /api/v1/groups/{id}/expenses
GET /api/v1/groups/{id}/fund
```

### Create Expense

```text
POST /api/v1/groups/{id}/expenses
```

### Fund Dashboard

```text
GET /api/v1/funds/{id}/overview
```

### Notification Center

```text
GET /api/v1/notifications
POST /api/v1/notifications/{id}/read
```

### Profile

```text
GET /api/v1/me
```

---

## 31. Idempotency & Retry Safety

Mobile networks can retry requests. Duplicate creation must be considered for message send and financial commands.

Candidates:

```text
SEND_MESSAGE
Create Settlement
Submit Contribution
Create Fund Expense
Approve Reimbursement
```

Possible mechanisms to finalize in Architecture/Implementation:
- `clientMessageId` / `clientRequestId`.
- `Idempotency-Key` header.
- unique business constraints.
- transaction + duplicate-key handling.

Backend remains authoritative even if Flutter retries.

---

## 32. Source-of-Truth Rules

Flutter must never be authoritative for:

```text
debt
fund balance
waitlist promotion
member permissions
poll validity
settlement validity
contribution remaining amount
```

Authoritative facts:

```text
Expense + ExpenseShare
→ debt inputs

COMPLETED Settlement
→ debt reduction

Fund transaction ledger
→ fund balance

ActivityParticipant
→ RSVP / capacity state

GroupMembership + GroupBan
→ group access

Privacy + Friendship + Block + MessageRequest
→ DM access
```

Flutter may calculate previews for UX, but Spring Boot revalidates everything before commit.

---

## 33. Non-Persistent Realtime State

The following should not be modeled as ordinary long-lived PostgreSQL business state:

```text
typing indicator
current WebSocket connection
online heartbeat
short-lived rate-limit counters
short-lived presence cache
```

Redis/in-memory infrastructure is the primary owner of these states. Persistent last-seen may be snapshotted to PostgreSQL.

---

## 34. Implementation Order

Recommended dependency order:

```text
1. Common error model + exception infrastructure
2. PostgreSQL/Flyway baseline
3. User Entity + Authentication
4. JWT + Spring Security
5. Profile + Privacy
6. Friend + Block
7. Group + Membership + Invitation + Permission
8. Activity Core + RSVP + Waitlist
9. Poll + Task + Discussion
10. Chat REST history
11. WebSocket Chat + Redis Presence/Typing
12. Expense + ExpenseShare + Balance calculation
13. Settlement
14. Group Fund + Collection + Contribution + Ledger + Reimbursement
15. Notifications + FCM
16. Calendar + Reminder
17. Search + Media upload
18. Home aggregation
19. Full integration/e2e hardening
```

This is a dependency order, not a day-by-day study schedule.

---

## 35. Testing Expectations

Every critical Service should have:

```text
happy-path test
input-validation test
permission test
business-state transition test
transaction rollback test
edge-case test
```

Concurrency-sensitive tests are especially required for:

```text
Activity final slot
FIFO waitlist promotion
Message sequence allocation
Contribution remaining amount with concurrent pending submissions
Fund concurrent spending
Reimbursement approval
Settlement duplicate/double confirmation
```

API integration tests should cover authentication and HTTP contract. OpenAPI examples should reflect the same DTOs and error codes.

---

## 36. OpenAPI / Swagger

Use Springdoc OpenAPI to expose an executable development reference, typically at `/swagger-ui.html` or the equivalent configured Springdoc path.

Endpoints should document:
- summary/description;
- request schema;
- response schema;
- security requirement;
- status codes;
- representative business errors.

The written Blueprint remains the business/implementation baseline. OpenAPI becomes the machine-readable/runtime API reference.

---

## 37. Out of MVP API

No MVP API contract is defined for:

```text
voice messages
voice/video calls
Discord-style channels
live location
Moments
Shared Album
AI planner/summary/generation
bank API integration
automatic payment reconciliation
multiple funds per group
custom group roles
subtasks
end-to-end encryption
```

They require future specification/versioning.

---

## 38. Baseline Business Decisions Preserved

This API contract explicitly preserves the locked BA decisions:

```text
Email + Password MVP
Owner / Admin / Member
max 100 ACTIVE members/group
one Group Chat/group
FULL_HISTORY or FROM_JOIN_TIME
message edit <=15 minutes
message unsend <=15 minutes
max 10 images/message
max 20 pinned messages/group
max one emoji/user/message
Message Request max 3 text messages before accept
no image/file before Message Request accept
friend decline cooldown 24h
message-request decline cooldown 72h
block removes friendship/direct social interaction but not shared business history
Activity state machine PLANNING -> CONFIRMED -> IN_PROGRESS -> COMPLETED, plus CANCELLED
FIFO waitlist
Single/Multiple Poll
PUBLIC/ANONYMOUS vote exposure rule
one shared Task status for multiple assignees
one reply level in Activity discussion
one payer/Expense
EQUAL or CUSTOM_AMOUNT split
pairwise net debt, no arbitrary Debt table mutation
two-sided Settlement confirmation
zero or one Fund/group
collection-based contributions
manual contribution verification
no overpayment against remaining obligation
no negative Fund balance
ledger-derived Fund balance
no hard-delete financial transaction history
in-app + push notifications
conversation-aggregated group-chat push
```

---

## 39. Phase 5 Acceptance Definition

Phase 5 is complete when:

```text
Every MVP business module has an API surface.
Authentication strategy is fixed.
Authorization model is fixed.
Common DTO/error conventions are fixed.
REST vs WebSocket responsibilities are fixed.
Redis responsibilities are identified.
Financial source-of-truth rules are fixed.
Transaction-sensitive APIs are identified.
Concurrency-sensitive APIs are identified.
Core domain events are identified.
Screen-to-API mapping exists.
Spring Boot implementation responsibilities are understandable.
An implementation Agent can build APIs without inventing new business rules.
```

---

## 40. Final Baseline Status

**API CONTRACT & BACKEND IMPLEMENTATION BLUEPRINT v1.0**  
**Status: BASELINE ESTABLISHED**

No endpoint, permission rule, protected state transition, financial calculation rule or persistence assumption should be changed during implementation without checking impact on:

```text
PRODUCT REQUIREMENT OVERVIEW
BA CONSOLIDATED SPECIFICATION
SCREEN MAP / UX
ERD & DATABASE DESIGN
API CONTRACT
FLUTTER CLIENT
TESTS
```

The next design phase is **SYSTEM ARCHITECTURE**, where the project will finalize Spring Boot module/layer architecture, Flutter architecture, WebSocket/Redis topology, object storage/FCM integration, deployment boundaries and detailed package/code structure.
