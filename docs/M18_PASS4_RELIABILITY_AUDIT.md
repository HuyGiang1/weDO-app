# M18 Pass 4: Reliability

## Guarantees (implementation boundary)

- A successful Chat mutation is durable in PostgreSQL. Realtime and push are not commit acknowledgements.
- General domain notifications are created after business commit in isolated REQUIRES_NEW transactions. Once inserted, the inbox survives provider failures; duplicate event/recipient processing is serialized by the existing PostgreSQL advisory lock. This is eventual, best-effort creation, not an atomic business/inbox or exactly-once delivery guarantee.
- Due reminder inbox creation and sent_at remain atomic in the scheduler transaction. Only their push is deferred.
- Redis/WebSocket and FCM are best-effort transports. REST history is authoritative. No durable retry or outbox is introduced.
- Bounded executor rejection is logged and never runs on the caller. A crash, rejection, or persistence failure before general inbox insertion can lose that notification attempt. A crash after inbox commit can lose push. These gaps existed without an outbox; async does not claim to close them.

## Root Cause and Execution Model

The synchronous AFTER_COMMIT listeners acquired secondary database connections before the original transaction's resource cleanup. Twenty senders could occupy the normal ten-connection pool while waiting for REQUIRES_NEW connections. Increasing the test pool to 21 in Pass 2 masked this dependency rather than fixing it.

`PostCommitDelivery` now owns explicit application executors: two `wedo-delivery-` workers with a queue of 256 for inbox/realtime work, and two `wedo-push-` workers with another queue of 256 for provider calls. Rejection logs safe operation/UUID fields and never executes on the caller. Graceful shutdown waits up to 30 seconds per executor; abrupt exit is not durable retry. Inbox/policy transactions finish before push enqueue; slow FCM calls do not occupy inbox workers or keep their persistence transaction open. Provider-result metadata and invalid-token cleanup remain isolated transactions. No common pool, unbounded executor, Hikari increase, new broker, or outbox.

Chat realtime and notification listeners enqueue only after successful commit. Reminder inbox creation/sent_at is unchanged and atomic; its push alone is deferred. No financial locking or mutation transaction changed. Asynchronous execution can reorder transports; message sequence, not arrival time, determines Chat order.

## Failure Matrix

| Failed component | Business commit / API | Durable recovery | Retry / delivery | Safe evidence |
| --- | --- | --- | --- | --- |
| Chat DB / validation | Transaction failure; existing error response, not success | No partial message/sequence from failed transaction; no after-commit frame | Caller may retry per existing API semantics; no new retry | Existing error policy and rollback regression |
| General inbox persistence | Chat/business commit succeeds | Chat REST history survives; failed inbox attempt is absent | Best effort, no persisted retry; advisory lock prevents duplicates when persistence succeeds | Target/recipient or message UUID and exception class only |
| Redis publish | Business commit succeeds | Durable REST history survives; same-node sessions still receive local fanout | Cross-instance Pub/Sub may miss event; reconnect/reopen uses REST | Event/conversation UUID and failure class; injected publish exception passes |
| WebSocket write | Business commit succeeds | Durable REST history survives | Lost frame is not replay-guaranteed; reconnect catch-up | Event/conversation UUID and failure class; injected socket exception contained |
| FCM exception / stale token | Business and existing inbox remain committed | Inbox and originating object remain readable | Best effort, result metadata; confirmed invalid token deactivated; cleanup failure cannot undo business commit | Notification/device UUID and exception class only; no registration token |
| Executor saturation / crash | Committed business unchanged | REST Chat authoritative; already committed inbox survives | Rejected/non-durable queued attempt may be lost; no CallerRuns or automatic retry | Explicit rejection warning; deterministic latch-based saturation test |

## Reconnect and Dedup

The existing API only supports backwards `beforeSequence`. On reconnect Flutter snapshots its latest known durable sequence, reads bounded pages of 100 from the newest page backwards until it reaches that anchor, and merges into retained messages by ID, sorted by conversation sequence. Existing event-ID suppression is bounded to 2,000; durable message merging also handles different event IDs for the same message and REST/realtime overlap. Earlier-history pagination uses the same merge rather than concatenating duplicates. No new endpoint or sync subsystem.

The widget regression starts at sequence 1, commits 104 more synthetic server messages while disconnected, reconnects, reads two pages (null then cursor 6), overlaps duplicate realtime delivery, retains the anchor/sequence 2 and displays sequence 105 exactly once. Existing create/edit/unsend/reaction/read/typing/presence coverage remains passing. This is automated evidence, not a claimed physical 104-message test.

## Firebase Startup Failure and Correction

The first Samsung launch hit Firebase Installations unavailability, then an uncaught token-acquisition exception aborted `main` before UI launch. Provider failure is an environment condition; preventing application launch was a real product bug.

The initial fix was reviewed again during continuation. Initialization, initial-message retrieval, permission and token acquisition now contain only expected FirebaseException, PlatformException and TimeoutException failures. Unexpected programming errors are rethrown and explicitly tested. Registration failure logs exception type/availability only, not provider text/token. Cold-start taps remain queued independently of token acquisition, successful token refresh still registers, and no retry loop was added. Firebase initialization unavailability disables optional push for that process without disabling authenticated app features. Existing API-registration failure handling remains intact.

## Automated Evidence

- Affected backend regression: **137 run, 0 failures, 0 errors, 0 skipped**. Covers normal-pool 20-message concurrency and twenty inbox rows, fault injection, advisory-lock duplicate prevention, reminders, finance, handshake/security and performance. The old 21-connection test override is removed.
- Caller-thread measurement: **27 statements / 3 acquisitions / peak 2 held -> 14 / 1 / 1** for comparable one-recipient Chat send. Delivery work moved to named independent workers; this does not claim total asynchronous SQL disappeared or a percentage latency speedup.
- Query budgets retained: Chat list **3/3** at 1/20 groups; inbox **5/5** at 1/30 Activity items; mixed inbox **12/12**; Home **14/15**; Fund collections **10**; Settlement 100 rows **6**.
- Full backend completed once: **642 run, 0 failures, 0 errors, 1 skipped**, compile PASS. Skipped `OtpResolverTest.resolveEmailVerificationOtp` requires explicit live-E2E system property and is intentionally opt-in. Fresh PostgreSQL 17/Testcontainers and Flyway V0-V12 passed.
- Backend production files are not newer than the final verification report; no backend source changed afterward. Reused the authoritative backend result for Flutter-only continuation.
- Final continuation focused Flutter: **43 passed**, including **15 NotificationPush** tests and affected Chat realtime/presentation tests. Full Flutter: **704 passed, 0 failed**. Final `flutter analyze`: **No issues found** after a test-only brace correction.
- Fresh debug APK build PASS at `mobile/build/app/outputs/flutter-apk/app-debug.apk`, local API define `http://127.0.0.1:8080`. Non-blocking existing firebase_core/Kotlin migration warning remains; no dependency upgrade or signing change.

## Physical Acceptance (2026-10-13)

Actual continuation tools are on Windows `D:/weDO-app`, not the Mac described in the recovery brief. No Mac-specific configuration was imported. Samsung `<QA_ANDROID_SERIAL>` / `SM_G975U1` is detected/authorized. Repository runner started existing PostgreSQL, Redis and private storage without resetting volumes, backend health is UP, reverses are 8080/9000, and fresh verified APK was installed and automatically launched.

After the user unlocked the phone, the actual Flutter UI passed cold launch and force-stop/relaunch with the authenticated QA Owner session restored. All five Home sections loaded, and Home, Groups, Chat, Calendar and Profile tabs remained usable despite Firebase registration failure.

An ordinary UI send (`M18_PHYSICAL_SEND_1013`, sequence 20) persisted in REST and remained visible after reopening. For practical interruption, the app was force-stopped, the API reverse removed and Redis stopped. A second authenticated QA account successfully persisted three messages (sequences 21-23), and REST returned them while Redis was unavailable. After restoring Redis/reverse and launching the app, Chat Home showed the newest preview and the exact conversation displayed all three messages plus the earlier UI send in order. Refresh/history overlap left exactly one visible node for each of the four markers. This is a physical interruption/reopen recovery check; live reconnect pagination over 104 missed messages remains separately proven by the automated widget test. No runtime Redis warning was captured during the short outage, so actual failed Pub/Sub/local fanout is claimed only from fault-injection tests, not this device check.

Final bounded current-process logcat sample: 228 lines; zero `FATAL EXCEPTION`, `Unhandled Exception`, `E/flutter`, `AndroidRuntime`, layout overflow, reconnect, WebSocketException or connection-refused matches. One safely contained registration-unavailable message and seven native FirebaseInstallations matches remained. Firebase cloud push/background/tap acceptance is **ENVIRONMENT FAILURE / NOT EXERCISED**, not a product crash or a fabricated delivery pass. The latest acceptance brief explicitly permits this classification when the app still starts.

Runtime cleanup used `dev-stop.cmd -StopInfra`. The first invocation stopped the backend but Compose required its existing external license-path variable; retry with only that process-scoped path stopped PostgreSQL, Redis and AIStor successfully. No license contents were read, no volumes were deleted, port 8080 has no listener, and no weDO infrastructure containers remain running.

## Boundaries and Closeout

No migration/V13, API expansion, financial lock change, M19 work, stage, commit or push. Accepted boundaries: best-effort external delivery; non-durable post-commit queue/crash gap; existing stateless access-JWT residual window. P2: existing unpaged reads and Kotlin plugin compatibility warning remain documented, not speculative refactors. No demonstrated remaining P0/P1; required visible Samsung acceptance passed. Firebase cloud availability is an external environment follow-up, not a claim that cloud delivery was verified here. Protected files/stash remain untouched. Pass 4 is complete and M18 is ready for commit review, not authorized to commit.
