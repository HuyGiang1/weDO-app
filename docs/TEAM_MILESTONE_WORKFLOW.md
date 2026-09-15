# weDO — CANONICAL MILESTONE EXECUTION WORKFLOW
## TEAM STANDARD FROM M3 ONWARD

---

### PURPOSE

This is the mandatory execution protocol for EVERY weDO milestone from M3 onward.

Both developers and all AI coding agents MUST follow the same workflow.

A milestone may have a different owner, but it must NOT have a different engineering process.

This document supplements:
- `docs/AI_AGENT_RULES.md`
- latest `docs/AI_AGENT_HANDOFF_*.md`
- `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`

If rules conflict:
`AI_AGENT_RULES.md` remains authoritative for permanent operational/security rules.

---

## 0. MILESTONE OWNERSHIP MODEL

Every milestone has:

**MILESTONE OWNER**
→ primarily responsible for analysis, implementation, tests, documentation, integration evidence, and final report.

**REVIEWER**
→ the other teammate.  
→ reviews architecture, API, database impact, business rules, tests, and PR.

**MENTOR / OWNER APPROVAL**
→ required at architecture/security/database boundaries as defined by `AI_AGENT_RULES.md`.

Milestone ownership does NOT mean:
> "Only the owner needs to understand the feature."

Both teammates should understand the important API, schema, business rules and architecture before the milestone is merged.

### Milestone Assignment Matrix

| Milestone | Owner | Dependency để CODE an toàn |
|---|---|---|
| **M3 Profile + Privacy** | Giang | M2 :white_check_mark: |
| **M4 Social** | **NA** | M3 privacy/user contract |
| **M5 Group Core** | Giang | Chủ yếu M2/M3 user identity; không cần chờ toàn M4 |
| **M6 Group Invite/Join/Ban** | **NA** | M5 hard dependency |
| **M7 Activity/RSVP/Waitlist** | Giang | M5 hard dependency, không nhất thiết chờ M6 |
| **M8 Poll/Task/Discussion** | **NA** | M5 Group/Membership/Permission; một số flow có thể liên quan M7 |
| **M9 Chat REST** | **NA** | M4 Social + M5 Group/Membership |
| **M10 WebSocket + Redis** | Giang | M9 hard dependency |
| **M11 Expense + Balance** | Giang | M5 Group/Membership; có thể tương đối độc lập với Chat |
| **M12 Settlement** | **NA** | M11 hard dependency |
| **M13 Group Fund** | Giang | M5 Group Core + finance conventions đã ổn |
| **M14 Notification + FCM** | **NA** | Cần business events từ các module trước; foundation có thể chuẩn bị sớm |
| **M15 Calendar + Reminder** | **NA** | M7 Activity hard dependency |
| **M16 Media + Search** | **NA** | Search phụ thuộc nhiều module; media foundation có thể làm sớm hơn |
| **M17 Product Completion** | Cả hai | M3–M16 phần core |
| **M18 Hardening** | Cả hai | Hệ thống gần hoàn chỉnh |
| **M19 Deployment** | Cả hai | M18 |

> **Lưu ý vai trò**: Bạn đảm nhận vai trò **NA**. Mọi milestone do NA phụ trách sẽ tuân thủ nghiêm ngặt Dependency Gate và quy trình Canonical Milestone Workflow đã đề ra.

---

## 1. MILESTONE BOOTSTRAP — REQUIRED BEFORE ANY CODE

At the beginning of EVERY milestone:

Run:
```bash
git branch --show-current
git log -1 --oneline
git status --short
```

Then read, in this order:
1. `docs/AI_AGENT_RULES.md`
2. latest `docs/AI_AGENT_HANDOFF_*.md`
3. `docs/TEAM_MILESTONE_WORKFLOW.md`
4. `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`
5. relevant BA / Product specification
6. relevant API Contract
7. relevant architecture/database documentation
8. existing production source
9. existing tests
10. relevant Git history when needed

Then establish:
- **MILESTONE**: e.g. M4 Social / Friends / Block
- **OWNER**: developer name
- **BRANCH**: e.g. `feat/m4-social`
- **DEPENDENCIES**: which previous milestone contracts are required
- **CURRENT DEPENDENCY STATUS**: READY / PARTIAL / BLOCKED

No implementation before this context has been established.

---

## 2. DEPENDENCY GATE

A milestone does NOT automatically have to wait until every previous numbered milestone is 100% complete.

Instead evaluate the exact dependency.

Three levels exist:

- **ANALYSIS READY**
  → analysis may start even when dependencies are not yet implemented.

- **IMPLEMENTATION READY**
  → required schema, API, service contracts and business rules from dependencies are stable enough to build against.

- **INTEGRATION READY**
  → required dependencies are merged and runnable, so full E2E/integration can be proven.

**Example:**  
M6 depends heavily on M5 Group Core.  
While M5 is being implemented:
- M6 analysis = **ALLOWED**.
- M6 production implementation = **NOT ALLOWED** until required M5 contracts are stable.
- M6 E2E = **NOT ALLOWED** until required M5 implementation is integrated.

*Never guess a dependency contract.*

---

## 3. PHASE A — BUSINESS ANALYSIS

Before architecture or code, reconstruct the feature behavior.

Answer:
- WHAT problem does this milestone solve?
- WHO are the actors?
- WHAT actions are allowed?
- WHAT actions are forbidden?
- WHAT states exist?
- WHAT transitions exist?
- WHAT permissions apply?
- WHAT validation rules apply?
- WHAT edge cases exist?
- WHAT happens on duplicate requests?
- WHAT happens on invalid state transitions?
- WHAT happens under concurrent requests?
- WHAT sensitive data exists?
- WHAT behavior is current implementation vs future product intent?

For stateful features, write a state-transition model.

**Example:**
```text
NONE
→ REQUEST_PENDING
→ FRIENDS
→ BLOCKED
```

Do not invent business rules.

If BA/Product/API documents disagree:
**REPORT THE CONFLICT.**  
Do not silently choose one.

---

## 4. PHASE B — DATABASE / SCHEMA REVIEW

Inspect existing Flyway migrations and JPA mappings.

For every milestone determine:
- TABLES USED
- TABLES CREATED, if any
- COLUMNS USED
- FOREIGN KEYS
- UNIQUE CONSTRAINTS
- CHECK CONSTRAINTS
- INDEXES
- NULLABILITY
- CASCADE RULES
- LOCKING REQUIREMENTS
- TRANSACTION BOUNDARIES

Ask explicitly:
**DOES THIS MILESTONE REQUIRE A NEW MIGRATION?**

If **NO**:
state:
> `NO DATABASE MIGRATION REQUIRED.`

If **YES**:
architecture/database review is mandatory before writing the migration.

*Never edit an already-applied Flyway migration.*  
*New schema evolution must use a new migration.*

---

## 5. PHASE C — API CONTRACT REVIEW

For every API involved establish:
- HTTP METHOD
- PATH
- AUTH REQUIREMENT
- REQUEST DTO
- RESPONSE DTO
- SUCCESS STATUS
- ERROR STATUS
- DOMAIN ERROR CODES
- PAGINATION if relevant
- SORTING/FILTERING if relevant
- IDEMPOTENCY behavior if relevant
- PERMISSION behavior

Never let Flutter invent fields that do not exist in the backend contract.  
Never silently change backend contract to make the UI easier.  
**Backend/API is runtime source of truth.**

---

## 6. PHASE D — ARCHITECTURE ANALYSIS ONLY

Before important implementation, produce an **ANALYSIS ONLY** report.

*No production code modifications during this phase.*

Report:
- ISSUE / FEATURE
- BUSINESS RULES
- DEPENDENCIES
- DATABASE IMPACT
- BACKEND CLASSES REQUIRED
- API CONTRACT
- FLUTTER LAYERS REQUIRED
- SECURITY IMPACT
- TRANSACTION IMPACT
- CONCURRENCY IMPACT
- SHARED FILES AFFECTED
- TEST PLAN
- RISKS
- OPEN QUESTIONS
- RECOMMENDATION

**Then STOP.**  
Wait for approval when required by `AI_AGENT_RULES.md`.

---

## 7. BACKEND IMPLEMENTATION ORDER

After approval, use the following general backend order:

```text
Existing Schema / Migration
        ↓
Entity
        ↓
Repository
        ↓
DTO Request / Response
        ↓
Mapper if required
        ↓
Permission / Policy component if required
        ↓
Service
        ↓
Controller
        ↓
ErrorCode / Exception handling
        ↓
Tests
```

Responsibilities must remain:

- **CONTROLLER**
  → HTTP boundary only  
  → `@Valid`  
  → authentication principal  
  → request/response mapping  
  → thin

- **SERVICE**
  → business rules  
  → transactions  
  → state transitions  
  → orchestration

- **REPOSITORY**
  → persistence queries  
  → locks  
  → DB access

- **ENTITY**
  → persistence model

- **DTO**
  → external API contract

Do not place major business logic in controllers.  
Do not return JPA entities directly from REST APIs.

---

## 8. BACKEND TEST GATE

Backend implementation is NOT considered ready merely because:
> "the endpoint works manually."

Required tests depend on the feature but should consider:
- HAPPY PATH
- VALIDATION
- AUTHENTICATION
- AUTHORIZATION
- NOT FOUND
- DUPLICATE / CONFLICT
- INVALID STATE TRANSITION
- DATABASE CONSTRAINTS
- TRANSACTION ROLLBACK
- LOCKING / CONCURRENCY where relevant
- SENSITIVE FIELD FILTERING

Backend tests must pass before Flutter integration is considered stable.

---

## 9. API FREEZE GATE

After backend behavior and tests are stable, declare:
> `API CONTRACT FOR THIS SLICE: STABLE`

Record:
- METHOD
- PATH
- REQUEST
- RESPONSE
- STATUS
- ERROR CODES
- AUTH
- PERMISSIONS

"Stable" does NOT mean immutable forever.  
It means: the Flutter implementation and dependent milestones may now safely build against this contract.  
Any later breaking change must be communicated before implementation.

---

## 10. FLUTTER IMPLEMENTATION ORDER

Do NOT start with the screen.

Use:
```text
API Model
        ↓
Feature API client
        ↓
Repository
        ↓
Application / State layer
        ↓
Screen
        ↓
Reusable widgets if justified
```

Typical responsibility:

- **SCREEN**
  → rendering  
  → input  
  → user interaction  
  → presentation state

- **APPLICATION / STATE**
  → feature state  
  → orchestration

- **REPOSITORY**
  → feature data operations

- **API**
  → HTTP details / serialization

- **CORE NETWORK**
  → Dio / auth interceptor

Screen must NOT directly access:
- `Dio`
- raw `accessToken`
- `refreshToken`
- `SecureStorage`
- JWT internals

unless an explicitly approved architecture change says otherwise.

---

## 11. UI DESIGN SOURCE

For visual implementation:
**approved Stitch/design** → visual source of truth.

Use it for:
- layout
- spacing
- typography
- component hierarchy
- icons
- visual states

But:
**STITCH IS NOT BUSINESS LOGIC SOURCE OF TRUTH.**  
Backend/API/business rules remain authoritative for runtime behavior.  
Never implement fake production behavior only to make a design look complete.

---

## 12. SCREEN STATE STANDARD

Every screen must consider applicable states:
- INITIAL
- LOADING
- CONTENT
- EMPTY
- SUBMITTING
- SUCCESS
- VALIDATION ERROR
- DOMAIN ERROR
- NETWORK ERROR
- UNAUTHORIZED / SESSION FAILURE where relevant

Do not implement happy-path-only UI.  
Not every screen needs every state.  
Only implement states that are meaningful for that feature.

---

## 13. FLUTTER TEST GATE

Depending on the slice, verify:
- MODEL PARSING
- API MAPPING
- REPOSITORY BEHAVIOR
- APPLICATION/STATE LOGIC
- WIDGET RENDERING
- LOADING STATE
- ERROR STATE
- SUCCESS STATE
- NAVIGATION
- PERMISSION-DRIVEN UI where relevant

Run:
```bash
flutter analyze
```
and relevant Flutter tests.

---

## 14. INTEGRATION GATE

After backend + Flutter are ready:

Connect:
```text
Flutter Screen
→ Application
→ Repository
→ API
→ Dio
→ Spring Security
→ Controller
→ Service
→ Repository
→ PostgreSQL
→ Response
→ Flutter render
```

Verify REAL API behavior.
- No fake tokens.
- No fake production responses.
- No hidden mock fallback.
- No debug bypass endpoint.

---

## 15. E2E / MANUAL VERIFICATION

For the milestone's Definition of Done, demonstrate the main business flow.

Examples:
```text
User action
→ HTTP request
→ backend business rule
→ database state change
→ API response
→ updated Flutter state
```

Also verify important failure flows.

For concurrency-sensitive features:
prove the race behavior with automated tests where practical.

Do not claim:
> `E2E PASS` if only backend unit tests were executed.

Do not claim:
> `physical-device tested` unless a device was actually used.

---

## 16. SHARED FILE POLICY

Shared/high-conflict files include examples such as:
- `mobile/lib/app/routes.dart`
- `mobile/lib/app/app.dart`
- backend common `ErrorCode`
- central `SecurityConfig`
- shared API documentation
- `pom.xml`
- `pubspec.yaml`
- Flyway migrations
- global navigation
- shared core components

Do not casually modify shared files.

When a shared change is required, report:
```text
SHARED FILE:
...

WHY:
...

EXACT REQUIRED CHANGE:
...

IMPACT ON OTHER MILESTONES:
...
```

If the team has assigned an Integration Owner, that person should perform or approve shared wiring.  
This prevents two agents from independently rewriting shared infrastructure.

---

## 17. CROSS-MILESTONE RULE

A milestone owner may NOT "helpfully" implement the next milestone.

**Example:**  
M4 owner notices M5 will need Group API.  
Do NOT create Group API during M4.  
Instead report:
> `DEFERRED DEPENDENCY / FUTURE REQUIREMENT.`

Stay inside the current approved milestone.

---

## 18. BRANCH STANDARD

Default branch naming:
- `feat/m3-user-profile-privacy`
- `feat/m4-social`
- `feat/m5-group-core`
- `feat/m6-group-invite`
- ...

One milestone owner works primarily on that milestone branch.
- Do not commit directly to main unless the team explicitly changes its Git strategy.
- Do not force-push.
- Do not rewrite shared history.
- Do not merge another milestone automatically.

---

## 19. COMMIT STANDARD

Commit only after approval as defined by `AI_AGENT_RULES.md`.

Commits should be focused.

**Examples:**
- `feat: add user profile update API`
- `test: cover user privacy enforcement`
- `feat: integrate profile editing flow`
- `docs: document M3 profile API`

Avoid commits such as:
- `update M3 stuff`
- `fix everything`
- `profile + privacy + social`

One commit = one coherent technical change.

---

## 20. PRE-REVIEW CHECK

Before asking for merge/review:
- run relevant backend tests
- run relevant Flutter tests
- run `flutter analyze`
- run `git diff --check`
- inspect `git diff --stat`
- inspect `git status --short`

Review:
- unexpected files
- temporary files
- secrets
- IDE files
- unrelated changes
- debug code
- fake production behavior

---

## 21. STANDARD MILESTONE COMPLETION REPORT

Every milestone owner must return the same report structure:

```text
==================================================
MILESTONE COMPLETION REPORT
==================================================

MILESTONE:
...

OWNER:
...

BRANCH:
...

DEPENDENCIES:
...

DEPENDENCY GATES:
Analysis Ready: YES/NO
Implementation Ready: YES/NO
Integration Ready: YES/NO

--------------------------------------------------
A. BUSINESS SCOPE COMPLETED
--------------------------------------------------

...

--------------------------------------------------
B. DATABASE
--------------------------------------------------

Tables:
...

Migration:
YES / NO

Constraints / indexes:
...

--------------------------------------------------
C. BACKEND
--------------------------------------------------

Files added/changed:
...

Services:
...

Transactions:
...

Permissions:
...

Concurrency:
...

--------------------------------------------------
D. API
--------------------------------------------------

Endpoints:
...

Contract status:
STABLE / NOT STABLE

--------------------------------------------------
E. FLUTTER
--------------------------------------------------

Screens:
...

Repositories:
...

Application/state:
...

UI states:
...

--------------------------------------------------
F. TESTS
--------------------------------------------------

Backend focused tests:
...

Backend full regression:
...

Flutter tests:
...

flutter analyze:
...

E2E/manual:
...

--------------------------------------------------
G. SECURITY
--------------------------------------------------

...

--------------------------------------------------
H. SHARED FILES
--------------------------------------------------

Touched:
...

Required integration changes:
...

--------------------------------------------------
I. KNOWN LIMITATIONS
--------------------------------------------------

...

--------------------------------------------------
J. DEFERRED ITEMS
--------------------------------------------------

...

--------------------------------------------------
K. GIT
--------------------------------------------------

git diff --check:
...

git diff --stat:
...

git status --short:
...

--------------------------------------------------
L. KEY CONCEPTS FOR MENTOR EXPLANATION
--------------------------------------------------

...

--------------------------------------------------
M. READY FOR REVIEW
--------------------------------------------------

YES / NO
```

Then STOP.

---

## 22. DEFINITION OF DONE

A milestone is NOT DONE because:
- "The screens are finished."
- "The backend endpoints exist."
- "The agent says everything works."

DONE means, where applicable:
```text
BUSINESS RULES VERIFIED
+
DATABASE MODEL CORRECT
+
API CONTRACT CORRECT
+
BACKEND IMPLEMENTED
+
AUTHORIZATION VERIFIED
+
VALIDATION VERIFIED
+
TESTS PASS
+
FLUTTER USES REAL API
+
LOADING/ERROR/EMPTY/SUCCESS STATES HANDLED
+
INTEGRATION PROVEN
+
DEFINITION OF DONE SATISFIED
+
CODE REVIEW COMPLETE
```

---

## 23. LEARNING REQUIREMENT

weDO is also a learning project.

After completing an important milestone, the owner must be able to explain:
1. What problem did this milestone solve?
2. What tables does it use?
3. Why do those constraints exist?
4. What is the HTTP flow?
5. Why is business logic in the Service?
6. Where is the transaction boundary?
7. What can race?
8. What security check exists?
9. How does Flutter call the backend?
10. What happens if the server fails?
11. What did tests prove?
12. What would a naive implementation get wrong?
13. How would you rebuild the same pattern in another project?
14. How would you explain this milestone in a Backend Intern interview?

If the owner cannot explain these questions, the learning goal of the milestone is not complete even if the code runs.

---

## 24. REVIEWER RESPONSIBILITY

The reviewer must not approve based only on:
> "UI looks correct."

Reviewer checks:
- business rules
- API compatibility
- database impact
- service boundaries
- permissions
- security
- transactions
- concurrency
- tests
- shared files
- dependency impact

Reviewer should be able to summarize the milestone after review.  
This keeps both teammates knowledgeable about the entire weDO system.

---

## 25. FINAL TEAM PRINCIPLE

- Different milestone owners.
- Same architecture.
- Same workflow.
- Same quality bar.
- Same Definition of Done.

The repository must never evolve into:
> "Giang's code" + "Friend's code".

It must remain:
**ONE weDO SYSTEM.**
