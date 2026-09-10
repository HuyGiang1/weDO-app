# M2.16 — Auth Live E2E Verification Runbook

## Overview

This runbook describes how to execute the **M2.16 Live Auth Client-Backend Integration E2E** suite and conduct the **Manual Mobile UI Smoke Verification** against a real local Spring Boot backend and real PostgreSQL database.

---

## Architecture & System Boundary

- **Client Boundary**: Live Flutter/Dart auth components (`AuthRepository`, `AuthInterceptor`, `AccessTokenHolder`, `DioClient`, `AuthApi`) running in Dart VM with an in-memory `SecureKeyValueStore`.
- **Network Boundary**: Real HTTP/JSON transport over `Dio` to Spring Boot.
- **Backend Boundary**: Real Spring Boot application running on port `8080`, Spring Security filter chain (`JwtAuthenticationFilter`), and Flyway migrations.
- **Database Boundary**: Real PostgreSQL database with persistent tables (`users`, `user_credentials`, `auth_tokens`, `refresh_sessions`).
- **OTP IPC Boundary**: Test-scoped Java helper (`OtpResolverTest`) executed via Maven Surefire, communicating via a temporary file deleted immediately upon reading.
- **Limitation Note**: Automated headless execution proves client logic, networking, token lifecycle, and backend database state. It does not exercise native iOS Keychain or Android Keystore OS-level cold restarts (which are covered by manual smoke verification).

---

## 1. Prerequisites & Environment Setup

### Required Tools
- **Java**: Version 21 LTS
- **Maven**: Bundled Maven wrapper (`./mvnw` or `mvnw.cmd`)
- **Flutter SDK**: >= 3.13.1
- **PostgreSQL**: Version 16 or 17 running on localhost port `5432`

### Environment Variables & Secrets Policy
> [!IMPORTANT]
> Never hardcode or commit actual secret values into repository files. Supply them via local environment variables or rely on the development defaults configured in `application-local.yml`.

Relevant variable names:
- `WEDO_DB_URL`: JDBC URL (default: `jdbc:postgresql://localhost:5432/wedo`)
- `WEDO_DB_USERNAME`: Database username (default: `wedo`)
- `WEDO_DB_PASSWORD`: Database password (default: `wedo_local`)
- `WEDO_JWT_SECRET_BASE64`: 256-bit Base64 signing secret for JWT access tokens
- `WEDO_AUTH_TOKEN_PEPPER_BASE64`: 256-bit Base64 pepper for auth tokens (OTP hashing)
- `WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64`: Base64 signing secret for profile completion tokens
- `WEDO_JWT_ACCESS_TOKEN_TTL`: Shortened access token TTL for deterministic E2E testing (set to `5s`)
- `WEDO_API_BASE_URL`: Base URL for Flutter client (default: `http://127.0.0.1:8080`)

---

## 2. PostgreSQL Startup & Verification

Ensure PostgreSQL is running and the database `wedo` exists:

### Windows (PowerShell)
```powershell
# Verify PostgreSQL service or Docker container
Test-NetConnection -ComputerName 127.0.0.1 -Port 5432
```

### macOS / Linux
```bash
nc -zv 127.0.0.1 5432
```

---

## 3. Starting the Backend for E2E Testing

The backend must be started with the `local` profile and a **5-second access-token TTL** so that token expiration occurs deterministically during the test without long idle waits.

### Windows (PowerShell)
```powershell
cd backend
$env:WEDO_JWT_ACCESS_TOKEN_TTL = "5s"
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

### macOS / Linux
```bash
cd backend
WEDO_JWT_ACCESS_TOKEN_TTL=5s ./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### Health Check Verification
Once started, verify the backend is healthy:
```powershell
# PowerShell
Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/health"

# curl
curl -i http://127.0.0.1:8080/api/v1/health
```
Expected output: `HTTP 200 OK` with `{"status":"UP"}`.

---

## 4. Running the Automated Live Auth E2E Suite

The live E2E test harness is located at `mobile/test_e2e/live_auth_e2e_test.dart` outside `mobile/test/` so that normal local test runs do not require a live backend.

### Execution Command
From the repository root or inside `mobile/`:

```powershell
# Windows (PowerShell)
cd mobile
flutter test test_e2e/live_auth_e2e_test.dart

# With explicit Base URL (if not default):
flutter test test_e2e/live_auth_e2e_test.dart --dart-define=WEDO_API_BASE_URL=http://127.0.0.1:8080
```

```bash
# macOS / Linux
cd mobile
flutter test test_e2e/live_auth_e2e_test.dart
```

---

## 5. Canonical E2E Flow & Evidence Capture

The automated test executes the following sequence without any mock transports:

```text
Phase 1: Register
  - Action: POST /api/v1/auth/register with unique email and password
  - Expected: HTTP 201 Created, nextStep: "VERIFY_EMAIL", valid userId returned.

Phase 2: Resolve Verification OTP
  - Action: Harness calls test-scoped OtpResolverTest via Maven Surefire IPC.
  - Expected: 6-digit candidate matches stored HMAC-SHA256 in auth_tokens table.
  - IPC: Written to temp file, read by harness, file deleted immediately. Never logged.

Phase 3: Verify Email
  - Action: POST /api/v1/auth/verify-email (userId, 6-digit OTP)
  - Expected: HTTP 200 OK, status: "ACTIVE", nextStep: "COMPLETE_PROFILE",
    profileCompletionToken returned.

Phase 4: Complete Profile
  - Action: POST /api/v1/auth/complete-profile (profileCompletionToken, username, displayName)
  - Expected: HTTP 200 OK, status: "ACTIVE", nextStep: "LOGIN".

Phase 5: Login
  - Action: POST /api/v1/auth/login (email, password)
  - Expected: HTTP 200 OK, AuthenticatedSession issued.
  - Local State: A1 in AccessTokenHolder (revision: 1), R1 in storage.

Phase 6: Initial Protected Request
  - Action: GET /api/v1/me via AuthInterceptor
  - Expected: HTTP 200 OK, CurrentUser matches registered user ID. Holder revision stays 1.

Phase 7: Real Expiry & Transparent Auto-Refresh
  - Action: Wait until server-issued accessTokenExpiresAt + 800ms safety margin.
  - Action: Call normal repository.getCurrentUser() (harness NEVER calls refresh directly).
  - Internal Mechanics:
    1. GET /api/v1/me receives 401 AUTH_TOKEN_EXPIRED.
    2. AuthInterceptor triggers refreshSession(expectedRevision: 1).
    3. Backend rotates session (revokes S1, creates S2 with R2).
    4. Client adopts A2 in AccessTokenHolder (revision: 2) and R2 in storage.
    5. AuthInterceptor retries original request with Bearer A2.
    6. Request resolves with 200 OK to the caller.
  - Assertions:
    - User ID matches registered user.
    - Revision incremented: 1 -> 2.
    - A2 != A1 and nonblank.
    - R2 != R1 and nonblank.

Phase 8: Logout
  - Action: Call repository.logout().
  - Expected: POST /api/v1/auth/logout with R2 returns HTTP 204 No Content.
  - Local State: AccessTokenHolder cleared (null), storage cleared (null).

Phase 9: Server Revocation Proof
  - Action: Direct isolated POST /api/v1/auth/refresh with captured R2.
  - Expected: HTTP 401 Unauthorized with code "REFRESH_TOKEN_INVALID".
  - Local State: Storage and holder remain unauthenticated.
```

---

## 6. Manual Mobile UI Smoke Verification Checklist

After the automated E2E harness succeeds, perform this manual sanity check on a simulator/device to verify UI behavior:

| Step | Screen | User Action | Expected Visible UI Result |
| :--- | :--- | :--- | :--- |
| 1 | Welcome Screen | Launch mobile app | Welcome screen displays brand title, "Create Account" button, and "I already have an account" button. |
| 2 | Register Screen | Tap "Create Account" | Navigates to `/register`. Form with email and password fields displays. |
| 3 | Register Action | Enter unique email and password, tap "Continue" | Loading spinner shows briefly. App navigates to `/verify-email`. |
| 4 | Verify Email | Enter 6-digit OTP from database helper, tap "Verify" | App navigates to `/create-username`. |
| 5 | Create Username | Enter unique username, tap "Check", then "Continue" | Availability displays as available; app navigates to `/complete-profile`. |
| 6 | Complete Profile | Enter display name, tap "Complete Profile" | Form submits; app redirects to `/login`. |
| 7 | Login Screen | Enter email and password, tap "Sign In" | Loading indicator displays on button; button resets; **SnackBar displays: `'Signed in successfully.'`**. User remains on Login Screen (correct: no authenticated app shell exists yet in M2). |

---

## 7. Troubleshooting & Failure Diagnostics

### 1. Connection Refused (`errno = 1225` or `ECONNREFUSED`)
- **Cause**: Spring Boot backend is not running on port `8080`.
- **Fix**: Run `.\mvnw spring-boot:run` in `backend/` and verify `http://127.0.0.1:8080/api/v1/health` returns 200.

### 2. OtpResolverTest Fails with "Active EMAIL_VERIFICATION token record must exist"
- **Cause**: The registration step did not insert a record into `auth_tokens`, or the test harness passed an incorrect `userId`.
- **Fix**: Check `backend` console logs to ensure Flyway migrations ran and database table `auth_tokens` exists.

### 3. Transparent Auto-Refresh Timeout / Fails with 401
- **Cause**: Backend access token TTL was not shortened (still at default 15m).
- **Fix**: Ensure `WEDO_JWT_ACCESS_TOKEN_TTL=5s` was passed when starting Spring Boot.

### 4. Port Conflict on 8080
- **Cause**: Another process is occupying port 8080.
- **Fix**: Terminate the conflicting process or set `server.port` / `SERVER_PORT` and configure `--dart-define=WEDO_API_BASE_URL=...` accordingly.

---

## 8. Test Data & Database Cleanup Strategy

- **Unique User Isolation**: Each E2E run generates unique random emails (`e2e_<timestamp>@example.com`) and usernames (`u_<radix36>`). Multiple runs never collide.
- **Local Dev Reset (Optional)**: If you wish to wipe test data from PostgreSQL:
  ```sql
  TRUNCATE TABLE auth_tokens, refresh_sessions, user_profiles, user_credentials, users CASCADE;
  ```
  *(Never run against staging or production databases).*
