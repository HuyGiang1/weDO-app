---
name: wedo-milestone-delivery
description: Standard workflow for planning, branching, implementing, reviewing, testing, documenting, committing, and pushing every weDO milestone or substantial feature safely.
---

# weDO Milestone Delivery

Use this workflow for every weDO milestone or substantial feature. Treat the
current repository state, approved milestone contract, and explicit user
authorization as the delivery boundary. When old handoff text conflicts with
repository or runtime state, repository or runtime state is authoritative.

## 1. Milestone Intake

1. Read the canonical milestone roadmap, relevant requirements/specification,
   API contract, and requested acceptance criteria.
2. Identify the current base commit, intended target branch, and whether the
   request is planning-only or includes implementation.
3. Preserve all unrelated local work and every existing stash. Never reset,
   restore, checkout, drop, pop, or amend without explicit authorization.
4. Read the repository guidance before acting: root `AGENTS.md` when present,
   relevant module guidance, current docs, and the existing implementation.

## 2. Git Safety Gate

Every milestone normally has its own branch; never implement it directly on
`dev`. Before creating a feature branch, run and record:

```powershell
git status --short
git branch --show-current
git fetch origin
git rev-parse HEAD
git rev-parse <base-branch>
git rev-parse origin/<base-branch>
git stash list
```

Only create the branch once the requested baseline is verified. If the expected
local and remote bases differ, stop and report rather than guessing. Keep
expected user-local files, including `docs/LEARNING_HANDBOOK_M0_M2.md` in this
repository, untouched. Create a milestone branch using the approved convention,
for example `feat/m8-poll-task-discussion`, and confirm it starts from the
verified base commit.

## 3. Contract and Code Audit

Plan from the current contract before editing. Inspect, as applicable:

- milestone roadmap and requirements;
- canonical ERD/database documentation and all relevant Flyway migrations;
- current JPA entities, repositories, services, controllers, DTOs, and tests;
- class diagram and API contract documentation;
- current Flutter data/domain/presentation/routing code and tests;
- completed adjacent milestones, especially shared permission and lifecycle
  behavior.

Do not infer that a feature is absent solely because its UI is absent. Distinguish
between existing schema, partial implementation, contract-only definitions, and
future design material. Record conflicts and resolve them with the stated source
of truth before implementation.

## 4. Planning Output

Before implementation, provide a concise, actionable plan that states:

- in-scope user outcomes and explicit deferrals;
- backend, mobile, persistence, API, test, and documentation slices;
- API endpoints, permission/ownership rules, and lifecycle states;
- whether a new migration is needed, with the exact reason;
- dependencies, risks, and contract ambiguities needing a decision.

Implement in reviewable vertical slices: database/domain, backend service/API,
backend tests, Flutter data/repository, Flutter controller, Flutter UI,
integration, then Samsung E2E. Keep generated or unrelated changes out of the
milestone. Backend is authoritative; Flutter renders server state and must not
unnecessarily duplicate business rules.

## 5. Database Rules

Flyway migrations are implementation history; canonical diagrams describe the
final current schema. For every schema change:

1. inspect all prior migrations affecting the table;
2. add the next ordered migration only when the implemented schema requires it;
3. preserve PostgreSQL constraints, nullability, indexes, and FK behavior;
4. update the canonical ERD/database documentation and class-diagram source in
   the same milestone;
5. fold corrective migration effects into their functional/domain ERD rather
   than creating a diagram per migration.

Never add planned tables merely because older design documents mention them.
Treat migrations first, current entities second, and canonical current database
documentation third as schema authority.

## 6. Implementation Discipline

- Follow established package boundaries and local naming conventions.
- Prefer existing helpers, domain models, error handling, authorization patterns,
  and UI components over parallel abstractions.
- Make permission checks server-authoritative; clients may hide unavailable
  actions but must not be the enforcement point.
- Preserve behavior outside the requested milestone. Avoid opportunistic
  refactors and unrelated formatting churn.
- Use full Vietnamese diacritics in consumer-facing Vietnamese; never expose
  raw technical enums or jargon unless explicitly intended.
- For any user-facing deadline, due-at, or expiry field, collect and validate
  a complete local date and time. Same-day future times are valid. Serialize
  API timestamps with an explicit UTC offset/format; use date-only semantics
  only when the canonical product specification explicitly requires them.
- Do not pull Chat, WebSocket/Redis, Expense, or other future scope forward
  unless the current contract makes a dependency necessary.
- Add focused tests with each behavior slice, covering success, authorization,
  validation, lifecycle, and regression paths appropriate to the change.

## 7. Verification Ladder

Run the narrowest relevant checks while implementing, then the required full
checks before closeout. Unless the milestone specifically changes the commands,
verify:

```powershell
cd backend
.\mvnw.cmd test

cd ../mobile
flutter analyze
flutter test --reporter compact
flutter build apk --debug --dart-define=WEDO_API_BASE_URL=http://127.0.0.1:8080

cd ..
git diff --check
git status --short
git diff --stat
git stash list
```

Wait for each command to exit and report its final result, not an intermediate
progress line. Do not rerun unaffected suites without reason; state the last
authoritative result when appropriate.

## 8. Samsung Physical-Device E2E

When physical-device validation is requested or available, use the local runner
and do not change Windows execution policy permanently:

```powershell
.\scripts\dev-run.cmd
.\scripts\dev-stop.cmd
.\scripts\dev-stop.cmd -StopInfra
```

After a mobile runtime defect is confirmed and fixed, first complete the
focused verification and debug build, then automatically install/run the
verified build on the configured Samsung device when it is available. Do not
deploy unverified mobile changes.

The user is the primary manual tester. Install the verified debug APK, exercise
the milestone's real user journey on the Samsung device, capture the outcome
and any blocker, then stop local services cleanly. Classify reported issues as
milestone bug, UX refinement, expected behavior, or deferred scope. Keep
device-only configuration out of source control.

## 9. Documentation Closeout

Update only documentation affected by the delivered behavior. At minimum,
consider roadmap/status, API contract, canonical ERD/database docs, class
diagram source, developer/runtime instructions, and agent rules. Ensure the
docs describe final behavior and final schema, not a speculative future state.

## 10. Pre-Commit Review

Before proposing a commit:

1. inspect every tracked and untracked file and classify it as milestone
   implementation, legitimate generated output, documentation, local-only,
   accidental, unrelated, or suspicious;
2. inspect `git status --short`, `git diff --check`, and `git diff --stat`;
3. read the complete diff for every changed tracked file;
4. confirm no protected stash or unrelated user file is affected;
5. confirm tests/builds required by the milestone have final successful output;
6. summarize residual risks, skipped checks, and generated artifacts.

## 11. Commit and Push Authorization

Commit requires explicit user approval. Push requires separate explicit user
approval; never interpret approval to commit as approval to push. When
authorized, commit only the reviewed milestone files with a conventional,
accurate message. Push only the approved branch, then report the resulting
commit SHA and remote branch. Do not amend or rewrite published history without
explicit authorization.

## 12. Speed Without Carelessness

Use targeted searches and focused reads (`rg` first), parallelize independent
inspection, and avoid broad re-audits once the relevant contract is understood.
Move quickly through small reversible steps while preserving the baseline,
unrelated work, and final verification evidence.
