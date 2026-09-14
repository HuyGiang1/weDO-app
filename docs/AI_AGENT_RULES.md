# PERMANENT WORKING RULES — weDO PROJECT
## Mandatory Operational Rules & Architectural Invariants for AI Agents

> **File:** `docs/AI_AGENT_RULES.md`<br/>
> **Status:** PERMANENT & MANDATORY<br/>
> **Target Audience:** All AI Coding Assistants / Pair Programmers operating in this repository.<br/>
> **Repository Context:** `weDO` (Backend: Spring Boot 4.1.1 Java 21; Mobile: Flutter Dart 3; Infra: PostgreSQL 17, Redis 7).

---

## 1. ONBOARDING & CONTEXT HIERARCHY

At the beginning of any new session or task, the AI agent must follow this strict context loading sequence:

1. **`docs/AI_AGENT_RULES.md`** (This file — Core behavioral & architectural rules).
2. **`docs/AI_AGENT_HANDOFF_M0_M2.md`** (or latest milestone handoff document).
3. **`docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`** (Master roadmap & milestone progress).
4. **Current milestone documentation** (e.g., Runbooks, RFCs).
5. **Relevant API / Architecture documentation** (`docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md`, `docs/SYSTEM_ARCHITECTURE_BLUEPRINT_v1.0_FULL.md`).
6. **Actual source code** (`backend/src/main/**`, `mobile/lib/**`).
7. **Automated tests** (`backend/src/test/**`, `mobile/test/**`).
8. **Git history & logs** (When tracing origin or rationale of changes).

### Session Bootstrap Protocol
Before taking any action or answering architectural questions:
* Inspect current branch (`git branch --show-current`).
* Inspect current HEAD commit (`git log -1 --oneline`).
* Check working tree status (`git status --short`).
* Identify the current active milestone and the exact requested slice.
* Do **not** rely exclusively on stale conversation memory. **Repository state is authoritative.**

---

## 2. CORE OPERATIONAL WORKFLOW

### Low-Risk / Routine Implementation Flow
```text
INSPECT → UNDERSTAND → IMPLEMENT → RUN TESTS → REPORT → WAIT FOR COMMIT APPROVAL
```

### High-Risk / Architecture & Security Flow
Applies to any work touching:
* Architecture & Cross-layer refactors
* Authentication & Authorization
* Security & Token infrastructure (JWT, Refresh Tokens, Passwords, Salt/Pepper)
* Database schema & Flyway migrations
* Concurrency, Threading, Mutexes & Database Row Locking
* Transaction boundaries (`@Transactional`)
* Session lifecycle & State restoration
* Routing guards & Access policies
* Destructive operations

```text
INSPECT
  ↓
ANALYZE ONLY (Zero code/file modifications)
  ↓
REPORT (Findings, Options, Tradeoffs, Recommendation)
  ↓
WAIT FOR MENTOR / OWNER APPROVAL
  ↓
IMPLEMENT (Approved scope only)
  ↓
RUN COMPREHENSIVE TESTS (Focused tests + Full regression)
  ↓
REPORT (Verification evidence, Git status & diff checks)
  ↓
WAIT FOR COMMIT APPROVAL
```

> ⚠️ **CRITICAL:** Do NOT jump directly from request to implementation for architecture or security tasks!

---

## 3. MILESTONE & SCOPE BOUNDARIES

* The project is strictly milestone-driven.
* **Milestone State Resolution:**
  * **Snapshot at Creation (M2 closure):** M0 COMPLETE, M1 COMPLETE, M2 COMPLETE, M3 NOT STARTED.
  * **Current Milestone:** Must **always** be dynamically resolved from the latest `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md` and the latest handoff document. Future agents must **never** assume the snapshot at creation remains the current state.
* Complete **only** the explicitly requested slice. Then **STOP**.
* Never implement "the obvious next feature" unprompted.
* **STOP means STOP:** Do not commit, do not push, do not start the next slice, do not refactor adjacent modules, do not "helpfully" finish unapproved work.

---

## 4. GIT GOVERNANCE & DISCIPLINE

### A. No Commit Without Approval
* Never run `git commit` unless the project owner explicitly approves.
* Pre-commit report checklist:
  1. Exact files changed.
  2. Concrete reason why each file changed.
  3. Focused and regression test results.
  4. Analysis/build status (`flutter analyze`, compiler outputs).
  5. `git diff --check` (clean formatting, no whitespace errors).
  6. `git diff --stat`.
  7. `git status --short`.
  8. Architectural and security impact statement.

### B. No Push Without Explicit Approval
* Never run `git push` unless the owner explicitly issues a push command.
* "Looks good" or approving a commit does **NOT** constitute push approval.

### C. Git Safety & Branch Protection
* Never merge branches automatically.
* Never rebase shared history automatically.
* Never force-push (`git push -f`).
* Never delete branches automatically.
* Always check `git status --short` before and after work.
* Inspect untracked files explicitly (`git diff` does **not** show untracked files; stage intended files and review with `git diff --cached`).
* Never commit IDE artifacts, temporary files, logs, OTP tokens, or scratch credentials.

### D. Focused Commits
* One commit = One coherent technical change.
* Commit messages must be written in **English**, following Conventional Commits (e.g., `feat: ...`, `test: ...`, `docs: ...`, `chore: ...`, `fix: ...`).
* Never bundle unrelated refactors with feature work.

---

## 5. LANGUAGE & EDUCATIONAL POLICY

* **Language Rules:**
  * Production code, identifiers, classes, methods, variables: **English**.
  * Code comments: **English**.
  * Commit messages: **English**.
  * Technical explanations and reports to the project owner: **Vietnamese** is preferred when practical.
  * Never introduce Vietnamese identifiers into production code.
* **Educational Purpose:**
  * This project is primary training for a Backend Intern / Junior Engineer.
  * Code should be readable and explicit rather than overly compressed or excessively clever.
  * When explaining concepts, use the 7-step pedagogical structure:
    1. Simple mental model.
    2. Actual weDO implementation.
    3. Exact files and classes.
    4. Why this design exists.
    5. Common naive bugs avoided.
    6. Interview takeaway.
    7. Reusable engineering lesson.
  * Highlight key milestones with: `KEY CONCEPT FOR MENTOR EXPLANATION`.

---

## 6. SOURCE OF TRUTH HIERARCHY

1. **Active Source Code + Active Automated Tests** = Highest truth of current runtime behavior.
2. **API Contract (`docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md`)** = Source of truth for client-backend integration.
3. **Master Roadmap (`docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`)**.
4. **Architecture Documentation (`docs/SYSTEM_ARCHITECTURE_BLUEPRINT_v1.0_FULL.md`)**.
5. **Business Analysis / Product Specs (`docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md`)** = Intended future behavior (distinguish clearly from implemented reality).

> ⚠️ **REPORTING INTEGRITY:** Clearly distinguish:
> * `CONFIRMED FROM SOURCE`
> * `CONFIRMED BY TEST`
> * `OBSERVED DURING LIVE EXECUTION`
> * `ASSUMPTION`
> * `RECOMMENDATION`
> * `DEFERRED`
> * `UNKNOWN`
> Never phrase an assumption as a verified fact!

---

## 7. API CONTRACT & INTEGRATION GOVERNANCE

* The API contract governs frontend-backend collaboration.
* Before altering any API-related code, verify:
  * HTTP Method
  * URL Path
  * Request Body DTO
  * Response Body DTO
  * HTTP Status
  * Domain Error Code (`ErrorCode` enum)
  * Authentication requirement (Public vs Bearer)
* Keep Backend Controller, DTOs, Service, and Flutter `AuthApi`/Models in lockstep. Never alter one side silently.

---

## 8. BACKEND (SPRING BOOT) ARCHITECTURAL RULES

### A. Layered Separation of Concerns
* **Controller:** Thin HTTP boundary. Parses requests, triggers `@Valid`, formats response DTOs and HTTP status codes. **Zero business logic, zero SQL queries.**
* **Service:** Business capability boundary, transaction orchestration (`@Transactional`), domain decisions.
* **Repository:** Spring Data JPA interface. Persistence access, derived queries, database row-locking (`@Lock(LockModeType.PESSIMISTIC_WRITE)`).
* **Entity:** Represents persistent database tables and foreign-key relationships. **Never return JPA entities directly to API clients.**
* **DTO:** API contract boundary representation (Java Records). Defines validation rules and protects internal schema.

### B. Dependency Injection & Beans
* Always use **Constructor Injection**.
* Declare injected dependencies as `private final`.
* Never manually instantiate Spring-managed services with `new SomeService()`.
* Avoid field injection (`@Autowired` on member variables).

### C. Transactions (`@Transactional`)
* Use `@Transactional` deliberately on service methods that mutate state.
* Clearly identify rollback rules. Use `noRollbackFor` when failure counts must commit (e.g., `@Transactional(noRollbackFor = LoginAttemptException.class)`).
* Keep transactions short. Do **not** execute slow network calls (e.g., external email APIs) inside a database transaction.

### D. Concurrency & Row Locking
* Never assume single-threaded execution.
* Protect concurrent session operations (e.g., token rotation, login attempts) using database-level locking:
  `SELECT ... FOR UPDATE` via `@Lock(LockModeType.PESSIMISTIC_WRITE)`.
* Prevent deadlocks by enforcing strict **linear acquisition order** (e.g., lock `UserCredential` first, then lock `RefreshSession`).

### E. Configuration & Environments
* Never hardcode secrets, database passwords, or environment IPs.
* Utilize `application.yml`, `application-local.yml`, `application-test.yml`, and environment variables (`${WEDO_...}`).

---

## 9. DATABASE & FLYWAY MIGRATION RULES

* **All schema changes must be driven by Flyway migrations** (`backend/src/main/resources/db/migration/`).
* Never alter schema manually on production or shared databases.
* Never edit an already-applied migration script. Add a new versioned script (`V12__...sql`).
* Maintain `spring.jpa.hibernate.ddl-auto: validate`.
* Every schema change must consider:
  * Primary Keys (follow the approved schema/ERD and existing conventions; UUID is the dominant/current identity strategy where source/schema defines it)
  * Foreign Key cascades
  * Unique constraints (case-insensitive `citext` for emails/usernames)
  * Partial indexes (e.g., `WHERE revoked_at IS NULL`)
  * Check constraints
  * Nullability

---

## 10. MOBILE (FLUTTER) ARCHITECTURAL RULES

### A. Layered Separation of Concerns
* **Screen (Presentation):** Renders UI, listens to user input, displays loading indicators and SnackBars. **Must NEVER touch Dio, read raw tokens, or parse JWTs.**
* **AuthFlowCoordinator (Presentation):** Orchestrates multi-step auth UI flows, user feedback, and navigation decisions.
* **AuthSessionController (Application):** Owns global auth session status (`ValueNotifier<AuthSessionStatus>`).
* **AuthSessionInvalidator (Application):** Decides whether a failure requires local session destruction using explicit allow-lists.
* **AuthRepository (Data):** Serializes credential mutations via FIFO queue, coordinates `AuthApi` and `SecureStorageService`.
* **AuthApi (Data):** Maps raw HTTP requests and responses via Dio.
* **AccessTokenHolder (Core/Network):** Holds current in-memory access token on RAM and tracks session `revision`.
* **SecureStorageService (Core/Storage):** Interacts with hardware Keychain / Keystore via `SecureKeyValueStore` abstraction.
* **AuthInterceptor (Core/Network):** Handles Bearer injection, single-flight refresh, stale-401 recovery, and TOCTOU dispatch checks.

### B. State Management
* weDO intentionally uses lightweight, native state management (`ValueNotifier`, constructor injection, clean abstractions).
* Do **NOT** add Bloc, Riverpod, Provider, GetX, or Redux without explicit architectural justification and owner approval.

### C. Routing & Navigation
* Built on Navigator 1.0 (`onGenerateRoute` with `AppRoutes`).
* Every route must define an explicit `AppRouteAccess` (`public` vs `authenticated`).
* Security policy evaluates via `AuthRouteGuard`. Unknown routes must fail closed.

---

## 11. CURRENT SOURCE/TEST-BACKED SECURITY INVARIANTS

When modifying or testing authentication code, preserve these 12 current source/test-backed security invariants unless an explicitly approved architecture/security redesign changes them:

1. **Account Isolation:** An old request from revision $N$ must never hijack, refresh, or clear a newer revision $N+1$ session.
2. **Rotation Integrity:** An old refresh operation must not overwrite credentials from a newer login.
3. **No Zombie Sessions:** An old refresh token must not resurrect a logged-out session.
4. **Generation Single-Flight:** Requests from different session generations must not join the same refresh Future.
5. **Exact Invalidation:** Invalidation requests apply only if the current session matches the target generation (`SessionInvalidationApplied` vs `SessionInvalidationSuperseded`).
6. **Strict Refresh Trigger:** Automatic refresh is triggered **ONLY** on HTTP 401 with error code `AUTH_TOKEN_EXPIRED`.
7. **Invalid Tokens Fail Closed:** `AUTH_TOKEN_INVALID`, `AUTH_INVALID_CREDENTIALS`, and generic `UNAUTHORIZED` must **NEVER** trigger automatic refresh.
8. **TOCTOU Protection:** Retry authorization must verify that the session generation and token remain valid immediately before physical network dispatch.
9. **Stale-401 Defense:** A late 401 arriving after a successful transition from $N \to N+1$ must retry immediately using the proven transition without firing a redundant refresh.
10. **Adoption Order:** When rotating tokens, validate response $\to$ write durable storage $\to$ update `AccessTokenHolder` RAM $\to$ release waiting requests.
11. **Queue Resilience:** The credential mutation FIFO queue must recover after errors; a failed mutation Future must never poison subsequent operations.
12. **Zero Secret Leakage:** Raw passwords, OTPs, reset codes, JWT secrets, peppers, and tokens must **NEVER** be logged, printed, or exposed in commit history.

---

## 12. TESTING & QUALITY STANDARDS

* **Testing Pyramid:**
  * Unit Tests (Fast, offline, in-memory).
  * Integration Tests (Current integration tests use real PostgreSQL via Testcontainers. Do not replace them with H2 for database-behavior-sensitive tests without architecture approval).
  * Widget & Coordinator Tests (Flutter headless tests).
  * Live Client-Backend Integration E2E (Real Flutter Dio $\to$ Real Spring Boot $\to$ Real PostgreSQL).
* **Test Isolation:**
  * The default test suites (`./mvnw test`, `flutter test`) must be completely offline-capable and must not require running servers.
  * Live E2E tests live in dedicated directories (`mobile/test_e2e/`).
* **Test-Only Boundaries:**
  * Test utilities (e.g., `OtpResolverTest`) must remain strictly in `src/test` or `test_e2e` and must **never** leak into production runtimes.
  * Never add backdoor production endpoints (e.g., `/debug/login`, `/bypass-auth`).
* **Secretless Assertions:**
  * Tests may assert `A2 != A1` or `R2 != R1`, but must never print the raw strings of `A1`, `A2`, `R1`, or `R2`.

---

## 13. CURRENT DEFERRED SCOPE (DO NOT IMPLEMENT CASUALLY)

The following features belong to future milestones and are **intentionally not yet implemented**:
* Authenticated Home / Dashboard / Application Shell (Milestone 17 — Home & Product Completion / Global Navigation completion).
* User Profile / Settings UI (Milestone 3 — User Profile + Privacy).
* User-facing Logout UI / application logout orchestration remains deferred to a future application/profile shell milestone; follow the current roadmap before assigning it to a specific milestone.
* Reactive eviction of already-visible protected screens.
* Real external email delivery integration (SMTP / SendGrid / SES).
* Redis-based token revocation blacklist (stateless JWT residual validity window remains documented and accepted).
* Social / Group / Finance features (Milestones 4–16).

---

## 14. REPORTING FORMATS

### A. Design Decision Report Format
When architectural alignment is needed before implementation:
```text
ISSUE: ...
WHY IT MATTERS: ...
CURRENT SOURCE: ...
OPTION A: ...
OPTION B: ...
TRADEOFFS: ...
RECOMMENDATION: ...
FILES AFFECTED: ...
SECURITY IMPACT: ...
MIGRATION IMPACT: ...
TEST PLAN: ...
MENTOR DECISION REQUIRED: [List explicit questions]
```
*(Then STOP and wait for owner approval).*

### B. Implementation Completion Report Format
After executing an approved slice:
```text
A. Files changed
B. Why each file changed
C. Implementation behavior
D. Architecture implications
E. Security implications
F. Database implications
G. Tests added/changed
H. Focused test results
I. Full regression results
J. Analyze / build status
K. git diff --check
L. git diff --stat
M. git status --short
N. Known limitations
O. Intentionally deferred items
P. KEY CONCEPT FOR MENTOR EXPLANATION
Q. Recommended next step
```
*(Then STOP and wait for commit approval).*

---

## 15. TRIAD OF CORE VALUES

Whenever balancing trade-offs in this repository, protect these three priorities equally:

1. **System Correctness:** Code must work accurately and reliably on real runtimes.
2. **Architectural & Security Integrity:** Invariants, layer boundaries, and data models must not be compromised.
3. **Educational Value for the Owner:** The code must be understandable, explainable in an interview, and reusable in future engineering endeavors.
