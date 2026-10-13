# M18 Pass 2: Concurrency Verification

Baseline: `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9`, branch `feat/m18-hardening`.
Tests use PostgreSQL 17/Testcontainers, proxied service calls in independent worker transactions, start latches, bounded futures, and persisted-state assertions. No timing sleeps, JVM serialization, blind retries, or migrations were introduced.

## Authoritative Boundaries

| Area | Transaction and serialization | Persisted invariant exercised |
| --- | --- | --- |
| Activity final slot | RSVP transaction; mutable group participation then pessimistic Activity/participant/sequence locks; V5 participant and waitlist uniqueness | Two callers, one slot: one GOING, one WAITLIST; unique participant rows |
| Waitlist | Same Activity lock serializes slot release and FIFO promotion | Concurrent allocation; two releases promote first two waiters; duplicate leave releases one slot and promotes once; remaining order and history counts |
| Chat | Service transaction; atomic sequence UPDATE RETURNING; V4 unique conversation/sequence | Twenty sends persist exactly twenty distinct messages with sequences 1..20 and matching sequence counter |
| Fund obligation | READ_COMMITTED; Fund before collection/obligation; recompute pending plus confirmed under lock; V8 positive amounts and obligation uniqueness | Two 80 submissions against 100 accept only one; persisted pending 80, confirmed 0, remaining 20, obligation OPEN |
| Fund spending | READ_COMMITTED Fund lock; ledger-derived balance minus pending reimbursement reservations; V8 ledger domain-reference uniqueness | Expense 80 versus reimbursement 80 against 100: one commit, no partial loser business/ledger rows, available 20; SQL ledger rebuild agrees |
| Fund resolution | Reimbursement lock then Fund; transactional state/ledger mutation | Approval versus cancellation resolves once, leaves no pending reservation, ledger changes only for approved outcome |
| Settlement | Transaction; mutable Group FOR UPDATE before Settlement FOR UPDATE; re-read debt under lock; V7 state/amount constraints | Duplicate confirmation, both participants, and confirm versus cancel produce one terminal transition/history event and one debt update |

Settlement is a declaration followed by its designated counterparty confirmation, not two independently accumulating confirmation flags. Creator confirmation is denied or sees an already-resolved settlement, according to which serialized call runs first.

## Lock Order

Activity slot allocation and promotion share the Activity lock. Fund collection/contribution paths serialize on Fund before children; Settlement paths serialize on Group before Settlement and ledger reads. No contradictory order creating a demonstrated cycle was found in these paths.

Fund reimbursement resolution and transaction reversal lock their existing child before Fund, unlike collection/contribution paths. No operation taking Fund then those same existing reimbursement/transaction rows was found; this is a concrete ordering deviation to preserve in review, not evidence of a live deadlock. No speculative production lock refactor was made.

## Connection-capacity Finding (Pass 4)

The initial combined run was 88 tests, 0 failures, 1 error: the twenty-send Chat future timed out with the default ten-connection pool. Synchronous AFTER_COMMIT notification processing requests REQUIRES_NEW while the completed send transaction still retains its connection until cleanup. Under saturation, secondary transactions cannot acquire connections; notification exceptions are caught, so delivery can be lost even though business commits survive.

The Chat load-test class explicitly provisions 21 connections for its twenty workers plus one secondary transaction. This isolates sequence correctness; it is NOT a production starvation fix. The focused twenty-send rerun passed. Production pool/backpressure and notification delivery fault injection remain required Pass 4 work; do not describe default-pool high-load reliability as proven.

## Deferred Pass 3 Observations

- Chat history has the existing conversation/sequence unique index. Measure actual page query counts and projection costs before adding indexes.
- Notification maps each page row through target-actionability SQL (up to 100 rows); existing recipient/time/unread indexes do not eliminate that per-row work. Measure N+1 cost and plans.
- Calendar joins a participant-count subquery grouped across activities before applying outer date/user filters, sorts by start/id, and has no result limit. Measure PostgreSQL plans and range sizes; no missing-index claim without EXPLAIN.
- Finance/Fund builds list projections and ledger aggregates, including list lookup after create. Measure unbounded list size and aggregate cost before changing contracts.

No query-count benchmark or EXPLAIN was performed in this pass; these are source-grounded measurement candidates, not measured performance regressions.

## Deferred Pass 4 Observations

- Flutter reconnect has bounded backoff and event-ID dedup; verify REST catch-up after disconnect rather than assume realtime replay.
- Redis publish failures are caught and local fanout continues; cross-instance delivery during Redis outage needs fault injection.
- Notification AFTER_COMMIT + REQUIRES_NEW isolates business transactions from provider failure; delivery retries/durability and the demonstrated pool starvation need separate acceptance.
- No realtime, Redis, FCM, or notification delivery refactor was made in Pass 2.

## Verification

- Flutter Fund/Finance model and Fund screen tests: 9 passed. Decimal strings `0.00`, `60000.00`, `1234567.89` parse to exact minor units; formatting is exercised. Analyze: no issues.
- Final combined PostgreSQL security/concurrency run exited 0: 88 tests, 0 failures, 0 errors, 0 skipped. Classes: Activity RSVP concurrency 4, Chat service 13, Fund service 16, Settlement service 6, Chat realtime 5, Security config 44. Thirteen named concurrency-focused tests passed within these suites; existing Chat conversation-open and Fund duplicate-confirm/reversal cases are included.
- Prior Pass 1 full backend: 629 run, 0 failures, 0 errors, 1 skipped. Not rerun here; next full regression is Pass 4.
- No financial production primitive changed. The only production change in this continuation is removal of WebSocket query authentication; Flutter additions are tests only.
