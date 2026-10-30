# R2-A — Poll + Task realtime audit, implementation and acceptance

Date: 2026-10-25 (Asia/Ho_Chi_Minh). Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0` plus preserved dirty worktree.

**R1 COMPLETE; R2 IN PROGRESS.** The later accelerated-delivery instruction superseded the earlier plan-only instruction and authorized bounded source fixes/focused tests in this execution. R3–R9 NOT STARTED; this is not Poll-in-Chat authorization.

## Reused architecture — no duplicate implementation

Poll/Task mutations already use PostgreSQL transactions and `RealtimePublisher.activityResource`; `DomainRealtimeCoordinator.afterCommit` delivers hints only after commit on the existing workers. Existing shared `/ws` scope commands, Redis `wedo:domain:realtime`, authorized `activity:<activityId>` subscriptions, event-ID dedupe and targeted REST resync remain unchanged. Poll mutations do not disclose anonymous voter identity in the hint; most Poll hints intentionally have null actor/group IDs. Task hints carry resource and Activity scope. Neither creates a new socket or mutation replay.

Flutter `RealtimeSync` routes `POLL_`/`TASK_` by Activity and optional aggregate ID. List screens watch all matching resources; details derive the Activity scope from their first successful REST response. ACK/resync/resume and dependent `ACTIVITY_UPDATED` refresh projections; Task also reacts to RSVP/participant changes for eligibility permissions. `ReliableRead` preserves labelled cached data only on expected transient failure, clears denied401/403/404 content, rejects stale/disposed responses and reports programming errors. Backend permissions remain authoritative. Generic80ms coalescing is not business polling.

## Existing REST contract

All paths below are under `/api/v1`; no new endpoint/schema/migration is needed.

| Module | Endpoints |
| --- | --- |
| Poll | `POST/GET /activities/{activityId}/polls`; `GET /polls/{pollId}`; `PUT /polls/{pollId}/vote`; `POST /polls/{pollId}/options`; `PATCH/DELETE /polls/{pollId}/options/{optionId}`; `POST /polls/{pollId}/options/{optionId}/disable`; `POST /polls/{pollId}/close`; `GET /polls/{pollId}/voters`. |
| Task | `POST/GET /activities/{activityId}/tasks` (GET filters `status`, `assignedToMe`); `GET/PATCH/DELETE /tasks/{taskId}`; `PUT /tasks/{taskId}/status`; `POST /tasks/{taskId}/claim`. |

## Audit classification / mutation-consumer matrix

IMPLEMENTED AND VERIFIED means the named evidence only; it does not mean every platform or every physical case passed. DEFECTIVE entries below identify reproduced pre-fix behavior and its disposition, not an unresolved defect unless stated.

| Capability | Existing publication / consumer | Classification and evidence boundary |
| --- | --- | --- |
| Poll create / first vote / replacement | `POLL_CREATED`, `POLL_VOTE_CHANGED`; list/detail targeted GET | IMPLEMENTED AND VERIFIED: transactional replacement flush/lock/rollback retained from R1; PostgreSQL persona/repeat/concurrent/rollback tests. User reports physical vote-change/cross-device synchronization PASS. No new first-vote physical result invented. |
| Poll option add/edit/delete/disable | `POLL_OPTIONS_CHANGED`; Activity-scope list/detail/Results/Voters | IMPLEMENTED; backend option rights/voted-option restrictions verified. Every option mutation's final two-device UI remains IMPLEMENTED BUT UNVERIFIED. |
| Poll manual close | `POLL_CLOSED`; same targeted views | IMPLEMENTED AND VERIFIED in backend persona/scoped-event tests and new visible lifecycle widget regression. Fresh physical close observation pending. |
| Poll deadline closure | Reads evaluate server time; `closeIfDue` has no general deadline-close domain hint. List/detail/live views have nearest-known-deadline one-shot REST timer. | IMPLEMENTED BUT UNVERIFIED for full device deadline boundary. A universal server-driven close event is MISSING, not silently added. Preserve existing evaluate-on-read contract; one-shot deadline fetch is not polling. |
| Poll Results/Voters | `_LivePoll` Activity binding existed, but catch-all failure UI, no generation guard or access-lost clear; voters launched a separate Future on rebuild | DEFECTIVE, reproduced then FIXED here: use existing `ReliableRead` for current Poll + optional public-voter read, retain valid pair on transient failure, immediately deny on scope loss, preserve navigation/retry, guard late responses. No anonymous voters GET. Results visibly reflect open/closed state. |
| Poll privacy / result visibility | Backend hides counts until allowed and rejects anonymous voters; UI consumes flags | IMPLEMENTED AND VERIFIED in existing PostgreSQL personas plus new anonymous-voter no-request test. No private identities in realtime payload. Not fresh physical negative-access acceptance. |
| Task create / metadata update / assignment / claim / status / delete | `TASK_CREATED`, `TASK_ASSIGNMENT_CHANGED` (metadata update shares this invalidation), `TASK_STATUS_CHANGED`, `TASK_DELETED` | IMPLEMENTED AND VERIFIED backend personas/scoped events; list/detail invalidation, visible completion, dedupe and authoritative recovery widget tests. Final two-device create/reassign/complete/delete parity pending. No redundant `TASK_UPDATED` protocol added. |
| Task assignee names | Detail initially loaded group members, retried names only after error | DEFECTIVE, reproduced then FIXED here: refresh names after successful realtime Task read even if previous lookup succeeded; member-read generation tied to current Task generation. Existing independent member-request/dispose guards retained. |
| Task eligibility / permissions | New assignment/claim requires ACTIVE membership + GOING; status assignee-only; retained historical assignments survive RSVP departure | IMPLEMENTED AND VERIFIED in current backend personas/permissions and prior pre-demo physical evidence. Preserve DEC-PREDEMO-01, not obsolete M8 manager-status bypass. Picker uses fresh eligible-assignee REST on open; already-open picker remains a snapshot, server rejects invalid save. Live picker redesign not implemented. |
| Poll/Task list/detail error, revocation, stale/disposed | Existing `ReliableRead` on four screens | IMPLEMENTED AND VERIFIED: prior six-screen evidence retained; expanded matrix now covers Results/Voters,401/403/404, immediate scope loss, late successful/failed reads, dispose and no unhandled expected errors. Physical negative membership fixture pending; no real member removed. |
| Connected socket / failed REST read | Existing bounded PONG mechanism was opt-in for Finance only | MISSING, reproduced then IMPLEMENTED AND VERIFIED here for Poll list/detail/Results/Voters and Task list/detail: opt in only for expected transient read failure. At most one PONG attempt per failure episode, no healthy/denied reads, no socket recreation, no retry loop. Later ACK/resync or manual retry remains available after budget exhaustion. |
| Home/Calendar/aggregate parity | Secondary fan-out retained default OFF | MISSING end-to-end accepted parity; remaining R2 batch, not secretly enabled here and not an R1/R2-A foundation regression. |

### Known bounded limits / product decisions

- Deadline closure follows current read-time contract, no new scheduler/migration. Persisting `closed_at` consistently from read-only service paths and a general cross-client deadline hint need a dedicated test/design decision if stronger durable transition semantics are required; no claim of a new verified deadline event.
- Already-open Task assignment/create sheets and identity/name changes with no domain hint are snapshots. Authoritative save validation prevents unauthorized assignment. Decide whether live sheet edits should reset, warn or merge before expanding UX.
- Poll Results' optional repository-less constructor remains a static snapshot compatibility mode; the actual detail navigation supplies the repository. Do not mistake compatibility mode for a live screen.
- Poll+voter reads are paired for safe publication/error handling, not an invented transactionally atomic REST snapshot. An option concurrently removed between reads is not dereferenced blindly; subsequent hints/resync reconcile the latest permitted state.
- No durable event replay/outbox, no fabricated aggregate revision or guarantee against a lost hint on an otherwise healthy socket. Reconnect/resume/ACK restore through REST.

## Executed small vertical slices

1. Reuse R1 vote-replacement and transport behavior; do not rewrite them. Close R1 with exact existing/user evidence.
2. Extend current six-screen fixture with Results/Voters reliability cases; demonstrate failure before source fix. Replace only `_LivePoll`'s unsafe state and nested voter Future with existing reliable-read policy.
3. Demonstrate Task member-name resync staleness; refresh its auxiliary names safely after a successful targeted Task read.
4. Demonstrate missing connected-PONG recovery on all six Poll/Task visible paths; opt into the existing bounded mechanism, not shared-core changes.
5. Focused backend/Flutter/analyzer, then necessary Samsung build/install/smoke if tools allow. Record current physical scope separately; do not convert unit tests into a two-device PASS.

## Automated verification — executed, not a future plan

- RED Results/Voters extension:59 PASS/14 FAIL before correction. Separate Task assignee-name resync RED. Connected-PONG6 RED after correcting a test-only missing `rawType` argument; fixture compilation failure was not counted as a product reproduction.
- Final focused Flutter command: `flutter test --no-pub test/core/realtime test/features/poll test/features/task test/features/activity test/features/chat/presentation/chat_screen_test.dart --reporter expanded`: **252 PASS/0 FAIL**, exit0, `/tmp/wedo-r2a-focused-final.log`. Expanded screen matrix includes92 tests; no full suite or scratch-test removal. Existing RSVP/Chat regressions included, not full Finance regression rerun.
- `flutter analyze --no-pub`: **No issues found (5.4s)**, exit0, `/tmp/wedo-r2a-analyze-final.log`.
- Backend: `./mvnw -Dtest=M8MultiAccountIntegrationTest,TaskServiceTest,TaskPermissionsTest,DomainRealtimeCoordinatorTest,RealtimeScopeAccessTest test`: **31 run/31 PASS/0 failures/0 errors/0 skipped**,22.096s, `/tmp/wedo-r2a-backend-final.log`.16 M8 PostgreSQL integration +15 coordinator/scope/Task unit tests. Testcontainers PostgreSQL only, never QA DB.
- Initial backend run:15 PASS/16 context errors due to missing ADC, not a failed Poll/Task assertion. Rerun used explicitly synthetic authorized-user ADC under `/tmp/wedo-r2a-synthetic-adc.json` and fake test project, no real Firebase credential or configuration change. Production backend source unchanged; no new backend implementation required.

## Focused physical gate / R3 prerequisites

Reuse user-confirmed physical Poll change/sync and R1 Chat reconnect/image stability; no unnecessary repeat of that foundation investigation. For the new R2-A candidate, record device/hash/API and observe:

1. Both users see first vote/change and current list/detail/results without manual refresh; explicit close disables voting and updates all open projections. Anonymous Poll never exposes voter identities; no new Poll-in-Chat behavior.
2. On safe Task fixture, creator creates/updates, eligible assignee sees assignment without manual refresh, assignee completes, peer list/detail and current filters agree. Non-assignee cannot change status. Preserve unrelated QA history.
3. Results/Voters and Task views retain labelled valid cache offline, recover from reconnect/resync automatically, and show denial rather than protected cache after a safe separately authorized membership-loss fixture. Do not remove retained QA/finance members merely for this gate.
4. Use focused deterministic tests for response-order/disposal invariants; do not fabricate physical packet timing. No financial writes, no second iPhone, no signing changes.

### Actual device execution — current R2-A snapshot

- Fresh network detection: Macen0 `<QA_LAN_IP>`, Samsung `.182`; existing backend healthUP with DB/Redis. No backend restart/rebuild or storage reconfiguration in this task.
- Samsung buildPASS14.5s, APK SHA256 `7db0a46d71d57d8ed6c3061800bdbdf8e26f6df1082c75740791a9495c6d05b1`, install-rSuccess/session retained, appPID11217, API `.110:8080`. Build log `/tmp/wedo-r2a-android-build.log`.
- **Samsung Results and public Voters physical PASS:** existing `Chọn địa điểm`,1/0 votes,100/0%. On each new screen Wi-Fi interruption preserved actual values under “Dữ liệu chưa được cập nhật. Không thể kết nối…”; restoring Wi-Fi automatically cleared banner with values intact, no Retry/navigation. Both interruptions restored Wi-Fi in finally. No vote/old-poll mutation. This verifies these two Android cache/recovery views, not a newly changed remote vote or deadline.
- **Samsung Task create/assign/complete/list-detail physical PASS:** new unscheduled Activity `R2A QA 25-10`, ID `71bdfaea-29c5-43bf-9467-fd38d1b3ad5f`, in existing QA group `a3ba5950-2fb4-47f5-8d97-82ce42927e42`. Creator Member1 set GOING only in this new Activity; picker contained solely QA Member1, excluding other non-GOING members. New Task `R2A QA Task 25-10`, ID `bd7850c3-1ffb-47fa-8909-d3afadede773`, assigned to Member1, created through real UI, shown TODO, then completed by that assignee; detail shows DONE and TODO→DONE history. Read-only PostgreSQL confirms DONE. Underlying list agrees on return, no pull refresh. Earlier automation tapped the title while the keyboard obscured Submit; no POST/row existed then, not a product Save hang or duplicate request. Final real submit occurred only after keyboard dismissal.
- Exact new QA fixture records/history are **retained**, not reset/deleted. No financial transaction or pre-existing activity/task mutation. Bounded last1000 current-app log lines:0 unhandled/fatal/Flutter-error signatures, not a global/iOS guarantee.
- The user asked agent-operated iPhone observation. Existing compiled USB runner successfully activated the **previous** candidate and returned actual Poll UI and screenshot; this is not a current-source R2-A PASS. Necessary current-source iOS release buildPASS33.9s/24.3MB, in-place install/launchPASS on QA iPhone only, API `.110:8080`, executable SHA256 `f5a34981916b89214a14b6f0a2b2bfc98c4fcca38c6ce040c933fbafce75e7d8`. Native project/Info.plist hashes unchanged, no signing/Firebase edits. Logs `/tmp/wedo-r2a-ios-{build,install,launch-final}.log`.
- After this install, one resumed runner reached `WEDO_USB_READY`, but command returned no matching response; Xcode reported **“Restarting after unexpected exit, crash, or test timeout”**, then `TEST EXECUTE FAILED`, EXIT65. `/tmp/wedo-r2a-ios-ui-final.log`. No evidence identifying a weDO process crash; no current UI assertions. Runner ended; native weDO launch restored, no further runner loop/rebuild. Temporary USB helper `/tmp/wedo-r2a-ios-ui.py` and its bounded command artifacts remain outside repository for audit; no LAN control server. Generated xctestrun removed by helper finally. The original functioning media relay/runtime helpers remain untouched.

**R2-A PARTIAL: implementation/focused gates and Samsung edge-path smoke PASS; current-candidate two-device Task create/reassign/status/peer list-detail and iOS Results/Voters recovery pending because the UI runner exited.** Physical negative membership/anonymous/deadline edges remain unclaimed; automated authorization/privacy/stale-order evidence is separate. R3 may be prepared after verified Poll/Chat prerequisites without unrelated Finance/Home parity, but no full R2-A physical sign-off or R3 implementation starts in this execution.

## Scope and preservation

This execution modifies only two production files: `mobile/lib/features/poll/presentation/screens/poll_screens.dart`, `mobile/lib/features/task/presentation/screens/task_screens.dart`; one already-existing/untracked test file `mobile/test/core/realtime/six_refresh_paths_test.dart`; and closure/roadmap/handoff/this documentation. Existing large dirty worktree is not attributed to this task. No shared socket/core/schema/ledger/signing/Firebase edit, data reset, Git mutation or R3 implementation.
