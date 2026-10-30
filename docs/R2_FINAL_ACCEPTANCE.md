# R2 final closure — 2026-10-29

**R2 COMPLETE. R1/R3–R7/R10 COMPLETE; R8/R9 NOT STARTED.** This closes existing-module realtime parity, not full product regression, OS push acceptance or release readiness. No milestone scope or Definition of Done was removed.

## Unchanged Definition of Done and gate decision

“Every in-scope mutation has reviewed publication/consumption and appropriate tests plus physical evidence; no unexplained detail/list/read-model stale paths; realtime matrix and residual limitations recorded; no global completion claim from partial coverage.”

Publication/consumption was reviewed against the existing services and bindings, not inferred from RSVP. Focused PostgreSQL tests cover mutation, rollback, authorization and deterministic delivery; controller/widget tests cover state, races and recovery. Previously accepted module evidence is reused within its original scope. New paired Task, financial, notification, aggregate and Chat gates below close the specifically missing R2 acceptance journeys. No critical R2 synchronization/authorization defect remains established. Physical evidence is journey-specific; unperformed destructive/rare branches are explicitly separated below and retain their automated evidence. This is not a claim that every mutation was physically exercised on both platforms.

## Mutation → scope → consumer → evidence matrix

All domain hints follow successful PostgreSQL commit through the existing AFTER_COMMIT coordinator, Redis/shared WebSocket and authorized scopes. REST remains authoritative; hints do not carry financial truth. Existing event-ID dedupe, resubscribe/resync and bounded transient-read recovery are retained.

| Module / mutations reviewed | Events and scope / Flutter consumer | Automated evidence | Physical evidence / exact limits |
|---|---|---|---|
| Activity create/update/lifecycle; RSVP join/leave/rejoin/FIFO/count | ACTIVITY_*; activity + group; Activity detail/list, participant view; private HOME_*/CALENDAR_* | M8 personas, coordinator/access tests; Activity/realtime widgets | Reused R1 paired RSVP/FIFO/reconnect and R10 Activity evidence. New held Samsung detail and QA iPhone Calendar receive scheduled time, no refresh. |
| Poll create/vote/change/options/close; results and anonymity | POLL_* on group or activity; list/detail/results/voters/Chat; related Home hints | M8 real-PG vote idempotency/rollback/privacy/personas; focused Poll/core widgets | Reused accepted R3 user pair voting/change/privacy/Chat stability, R2-A Samsung results/voters offline recovery. No new universal scheduled-close service: existing deadline read evaluation and one-shot authoritative refresh retained; deadline boundary stress is R9. |
| Task create/update/assignees/claim/status/completion/delete; evidence/review | TASK_* on activity; list/detail/assignee lookup; Home hints; R10 evidence scopes retained | M8 Task personas/deletion/outsider rules; core scoped/dedupe/stale/dispose tests; R10 review regressions reused | New Samsung UI status TODO→IN_PROGRESS→DONE; Owner live list/detail confirms. Owner adds QA Owner retaining Member1; Samsung live names. Canonical PATCH QA title/due appears on peer, user confirms Task OK. New notification Tasks appear once on held Samsung list. Reused R10 reject/resubmit/approve→DONE pair. No physical Task deletion performed. |
| Group create/update/roles/lifecycle/membership, invitation/join submit/approve/reject/cancel | GROUP_* private/group scopes; Group info/list, admission panels; HOME_ACCESS_CHANGED/CALENDAR_ACCESS_CHANGED for access changes | Existing M8 scope/revocation and admission tests; new current-member fanout/access invalidation tests | New canonical QA rename → held Samsung detail and user-held QA iPhone Group List update; Home card shows same name. Reused R6 request pending/no-membership, approve/count, reject and close; R7 access/privacy scope. No membership revoked in shared QA groups. |
| Friendship request/accept/reject/cancel/remove | FRIEND_* personal recipient scopes; received/sent requests/friends list | Current M8 friendship lifecycle and recipient-only scope tests PASS | Prior R5/R7 accepted friend visibility/block-policy journeys reused within scope. Fresh request/unfriend race is not a new physical PASS; isolated automated lifecycle evidence remains distinct. |
| Discussion comment/reply/edit/delete/moderation | DISCUSSION_* on activity; targeted section read; no unrelated Home/Calendar fanout | Prior hotfix safe-read, transient/auth/disposal/stale tests reused | Prior Samsung Discussion offline/reconnect PASS, retained; Activity-parent preservation acceptance reused. No new Discussion implementation. |
| Expense create/edit/cancel, shares/balances | EXPENSE_* group; expense list/detail/shares and balances; Home | Existing canonical financial tests; changed-path recovery tests | New synthetic 2,000→4,000→6,000₫ updates both devices, split/share and needed totals; Owner held Home 2,000→3,000₫ auto. No physical deletion/cancellation of expense/history. |
| Settlement create/confirm/reject/cancel, balances/history | SETTLEMENT_* group; balance/list/detail and Home | 7 focused backend tests; existing safe-read/reconnect widgets | New pending 3,000₫ auto appears without prematurely clearing debt; actual Samsung confirmation → completed/history and both balances 0; Owner Home auto 0. Prior R1 expired-token recovery reused. |
| Fund collection/contribution/approval/correction/expense/reimbursement/reversal | FUND_* group; main workspace, collection/member totals/history/tabs; deliberately no unrelated Home/Calendar fanout | 17 focused backend tests; new Fund controller/read-race tests | Actual Samsung submits exactly one 1,000₫ contribution; held Owner sees pending, approves; both show 1,000₫. Expense 200 → ledger800; reimbursement100 → available700/reserved100; user approves → ledger700; canonical expense reversal → ledger900 and retained reversed-history row. Both canonical accounts900, four immutable transactions. Samsung offline retains labelled stale data and automatically recovers. No bank transfer. |
| Notification creation/read/read-all/count; reconnect | NOTIFICATION_* user-only; authoritative inbox + badge, existing authorized target router | 11 backend tests; new controller read/mutation/badge/dispose/auth regressions | Owner user sees Task1 notification live, opens correct context, read persists. Samsung Wi-Fi off retains old list/count74; one Task2 notification created server-side; reconnect independently HTTP200 then inbox auto reconciles75; tap/read →74; re-open already-read row remains74 and same readAt. No new OS push PASS claimed. |
| Home / Calendar / group-list dependencies | Existing personal hints now default-enabled with optout; dependency filtering; immediate access-sensitive clear before REST | New fanout5 + M8 aggregate tests; Home/Calendar access-loss widgets | Owner Home financial 2,000→3,000→0₫; Calendar user “Lịch tự cập nhật”; group list user “tên nhóm tự cập nhật”. Samsung corresponding details live. |
| Activity reminder dependent child | ACTIVITY_* activity/id binding → GET authoritative personal reminder; ReliableRead | New six reminder regressions; 148 final affected focused tests | Reproduced stale child while parent received schedule. Final Samsung panel shows configured15min; terminal changes disabled Member reminder to30 and commits QA Activity update: held panel auto30 without remount. User final QA iPhone “nhắc nhở OK”. No reminder enabled or scheduled notification created for this test. |
| Chat/media isolation | Existing canonical Chat transport/mounted images; no new binding or root refresh | Existing retained-image tests and dependency filtering reused; no Chat source edits in R2 | Final actual Samsung sends three QA texts in Nhóm74DCTT23; user holding old image on QA iPhone confirms “Chat ảnh/cuộn OK”. Earlier accepted image stability retained. Third actual text rendered “FINAL Chat 3”; do not infer three identical labels or a transport failure from the test input. |

## Confirmed gaps fixed, task-only scope

Twelve production paths compared with pre-R2 file copies (not the entire shared dirty diff):

- `backend/src/main/java/com/wedo/backend/realtime/RealtimeReadModelFanout.java`: enable existing fanout by default, retain explicit optout, current-member recipient query, deterministic private IDs, dependency filtering and access-sensitive hints.
- `mobile/lib/features/fund/application/fund_controllers.dart`, `data/fund_failure.dart`, `presentation/fund_screens.dart`: retain/label valid cache on expected transient failure, disable unsafe stale writes, generation/access/dispose guards, collection/mutation late-response protection, bounded existing reachability recovery and protected-overlay closure.
- `mobile/lib/features/notification/application/notification_controllers.dart`, `data/notification_failure.dart`, `data/notification_repository.dart`, `presentation/notification_screens.dart`: authoritative post-mutation inbox/count, older badge/read rejection, deny clearing and bounded recovery, preserve unexpected-error reporting.
- `mobile/lib/features/home/application/home_controller.dart`, `presentation/home_screen.dart`, and `mobile/lib/features/calendar/presentation/calendar_screen.dart`: access-sensitive cache/filter invalidation and recovery without redesigning accepted Home.
- `mobile/lib/features/calendar/presentation/activity_reminder_panel.dart`: narrowly reproduced parent/child stale state; reuse ReliableRead/RealtimeBinding, ignore old/disposed/revoked replies, preserve unsaved offset, prevent duplicate saves, refresh on scoped Activity/reconnect. Existing layout retained.

No ledger formula, migration, new socket, API business contract, Firebase or signing configuration changes. Temporary QA launchers, probes, metadata and logs remain outside the repository under `/tmp/wedo-r2-*`; no pre-existing files were deleted. QA fixtures/history retained. Separate modified tests and documentation are not production changes.

## Verification actually completed

- Backend focused PostgreSQL: **75 PASS, 0 failure/error/skip**, 50.960s; fanout5, M8 personas28, coordinator6, scope1, Fund17, Settlement7, Notification11. `/tmp/wedo-r2-backend-focused-final.log`.
- Initial expanded backend run had35 FirebaseADC context errors, not passing tests. Resolved only via FirebaseApp/Messaging mocks in three isolated test classes; final75 is authoritative. No real Admin credential used in isolated tests.
- Flutter: **315 broad affected PASS**, then **69 changed-path PASS**, then **148 final reminder/Activity/Calendar/core PASS**. These overlap; **do not add them together**. Six new reminder cases cover scoped update, transient/reconnect/isolation, revocation/old response, disposal, unsaved offset/save once and save-after-revocation. Reminder RED reproduced before the fix. Logs `/tmp/wedo-r2-focused.log`, `...-final-changed.log`, `...-reminder-{red,focused}.log`.
- Final analyzer **clean**, 3.0s, `/tmp/wedo-r2-reminder-analyze.log`.
- Existing backend package PASS,3.105s; current JAR reused after hotspot change because fresh against source. No backend build for Flutter-only reminder fix.
- Final Android debug build PASS13.2s and in-place install/launch PASS; SHA256 `90c7a32ffbd10e5ef76b4770932aa5cf9029adafaa683e82f5e8307b6e006c9e`.
- Final iOS Profile build PASS42.0s and QA iPhone install/launch PASS; Runner SHA256 `cf3be3650166414c4adc8fa806507df04e49d901a2969b2fd7f7026fb63d0d98`; installed container `CA8ADFA8-6880-49D6-A5D0-EB2BA32CA051`. No debugger dependency, repeated unsupported automation or second iPhone.
- Signing project hash remains `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8`.
- Full suites intentionally not rerun. Whole shared `git diff --check` reports pre-existing extra EOF blank lines in group/profile tests outside this task; left untouched. Task paths checked separately.

## Current preserved QA runtime / fixture traceability

en0 **<QA_HOTSPOT_IP>**, Samsung **<QA_HOTSPOT_IP>**, QA iPhone hotspot **<QA_HOTSPOT_IP>**. Both candidates use `http://<QA_HOTSPOT_IP>:8080`. Final local/LAN actuator UP; PostgreSQL pg_isready PASS; Redis PONG; MinIO LAN ready PASS. Backend PID93051 (`/tmp/wedo-r2-hotspot-backend.log`), media relayPID97246 (`/tmp/wedo-r2-hotspot-media.py`). Existing containers/volumes untouched. Free space about7.0GiB at final check. Dynamic addresses must be redetected after network changes.

Relay forwards current LAN9000 to existing loopback MinIO, allowlist only .3/.4/.1. Automatic approval initially rejected gateway access; user explicitly authorized **“Cho phép riêng<QA_HOTSPOT_IP> cho media QA iPhone”**, subsequent approval succeeded. Signed/private-media checks unchanged, no broad gateway/subnet exposure authorized.

Dedicated group `8cb1a5f4-677b-47eb-a9e3-96d3667b27fa`, now **R2 FINAL QA29-10 · Đồng bộ** (actual UI spaces: “R2 FINAL QA 29-10 · Đồng bộ”). Activity `500572d2-e9ec-45cc-a8c8-99621de16d39`, scheduled29Oct16:22–17:07 Asia/Ho_Chi_Minh; description updated only for Reminder parity QA. Final ordinary Task DONE; Expense6000 split3000 each; Settlement COMPLETED; Fund ledger/available900/reserved0. IDs and dedupe guards in `/tmp/wedo-r2-fixture.json`0600. Do not rerun creation helpers blindly or delete fixtures.

Notification target contract is parent Activity detail for a Task notification, not a new direct Task-detail route; actual Samsung confirmed correct Activity context. Owner Task1 notification read=true (readAt07:40:18.354235Z); initial unread27→new28 then final26 included another read, so do not claim isolated minus-one for Owner. Samsung Task2 notification read=true07:48:38.448606Z and exact75→74/idempotent re-open verified. Another QA user's mark-read was rejected404.

## Explicit R9 follow-up / limits (not fabricated physical PASS)

- Exhaustive two-platform deletion/cancellation/reject/read-all permutations, live membership/role/ban loss while financial/modal reads race, and repeated refresh-token invalidation under long partitions. Isolated authorization/rollback/race tests are the evidence for these branches; no destructive shared-fixture retest performed.
- Fresh Friendship request/unfriend physical lifecycle, long-lived open Task picker eligibility changes (existing snapshot revalidated by server on save), Poll exact deadline/clock-skew/background boundary. Poll deadline uses existing one-shot read-time contract; no unsolicited scheduler/polling added.
- Broad OS FCM foreground/background/terminated matrix, stress/load/multi-node outages, long-scroll media-download instrumentation and full platform regression remain R9. Foreground in-app notification delivery is not proof of OS push.
- Best-effort realtime has no new durable outbox; reconnect authoritative refetch is convergence path. No unsupported claim that every branch was physically exercised.

**Remaining required R2 gates: none in the bounded closure journeys; no observed blocking defect.** R8 may be prepared only when separately requested. No R8 implementation started.

Worktree preserved; branch/HEAD unchanged; commit/push/merge/reset/restore/stash/clean NO.

<details><summary>Historical execution checkpoints (superseded by verified closure above; retained for provenance)</summary>

# R2 final closure — active checkpoint2026-10-29

**R2 IN PROGRESS.** Unchanged original DoD: every in-scope mutation has reviewed publication/consumption, appropriate tests and physical evidence; no unexplained detail/list/aggregate stale paths; matrix and limitations recorded. R1/R3–R7/R10 COMPLETE; R8/R9 NOT STARTED.

| Module | Existing PASS reused | Missing behavior / remaining evidence | Evidence | Required action |
|---|---|---|---|---|
| Activity/RSVP/waitlist | R1 paired join/leave/rejoin/FIFO/reconnect | Dependent Home/Calendar publication disabled | R1 acceptance; live fanout condition | Enable tested dependency-scoped fanout, no new transport |
| Poll | R3 physical vote/change/privacy/activity/Chat | Deadline and dependent read-model parity must be reviewed | R3/R2-A delivery | Reuse verified Poll; inspect precise remaining deadline semantics |
| Task | R2-A own create/assign/complete; R10 paired evidence/review/automatic DONE | Ordinary peer edit/reassignment/delete/list/counter evidence; Home fanout | R2-A + R10 final matrix | Targeted canonical mutation/consumer regressions and pair fixture |
| Group/admission/Friendship/Discussion | Prior R1/R6/R7 scoped evidence retained | Aggregate scopes and unexplained stale paths require review | Existing after-commit services and private/group bindings | Avoid reimplementing accepted flows; record exact consumers |
| Expense/Settlement | R1 physical expired-token recovery, cached-state/reconnect | Mutation-to-summary parity and current pair financial evidence | R1 reports; Home fanout disabled | Scoped read-model fix and synthetic QA fixture; no ledger formula edits |
| Fund | Existing canonical contributions/approval/expense/reimbursement APIs and after-commit hints | Transient resync discards valid workspace; access-loss hook absent; targeted recovery/physical parity pending | GroupFundController.resync; GroupFundScreen binding | Reproduce/fix narrow read reliability; preserve authoritative financial rules |
| Notifications | AFTER_COMMIT created/read hints, own-user scope, guarded inbox reads | Read mutation vs late list/badge races and disposed responses; physical unread/reconnect pending | NotificationCenterController | Reproduce before changes; keep OS push separate |
| Home/Calendar/group-list | Scoped consumers already implemented | Secondary fanout defaultOFF; cache revocation/recovery review pending | RealtimeReadModelFanout condition and R2-A | Minimal dependency-aware publication and focused tests |

## Safety / runtime

Branch feat/pre-m19-ui-polish, HEAD cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0.260 short-status entries pre-existed this execution; existing tracked diff178files/+10441/-3304 is not this task's work. Current protected stash actually reports local iOS signing config; preserved without mutation. Baseline status/stat and touched-file copies are under `/tmp/wedo-r2-*`. Disk8.8GiB; dynamic network detection en0/<QA_LAN_IP>; backend/PG/Redis/MinIO healthy, Samsung authorized. No cleanup/reset/financial changes yet.

## Execution order

1. Reproduce aggregate fanout/default/dependency/rollback/auth behavior and Fund transient/recovery/stale/disposal losses in focused tests.
2. Correct existing fanout and Fund read paths only; no new sockets, schema or cached money.
3. Confirm Notification mutation/read races and related Home/Calendar access-loss gaps; fix only reproduced cases.
4. Focused PostgreSQL/Flutter/analyzer, necessary verified candidate installs, safe paired Task/Finance/Fund/Notification acceptance. Preserve prior physical PASS and record all remaining R2 gates.

No commit/push/merge/reset/restore/stash/clean. Do not close R2 from this initial matrix.

## Verified implementation checkpoint

RED assertions reproduced Fund cache/collection race, default-disabled aggregate fanout,3Notification races and2membership cache cases. A further Fund mutation-workspace late response was reproduced RED and guarded by access generation. Test-only Home double-dispose and a fake backend that wrongly granted access after revocation were corrected without weakening production guards.

Backend focused final: **75 PASS/0fail/error/skip**,50.960s; initial expanded run40PASS/35context errors due missing FirebaseADC, corrected with FirebaseApp/Messaging mocks only in3isolated testclasses. No realAdmincredential used. Flutter broad focused **315PASS**; final changed-path run **69PASS** (overlap, not additive). Extra widget/controller tests prove Fund stale cache, one bounded PONG attempt/no healthy request, revocation/late request, Notification transient/401 and mutation races. Analyzer clean3.1s. Logs `/tmp/wedo-r2-{backend-focused-final,focused,final-changed,analyze-final}.log`. No full suite.

Source changes reuse existing fanout (defaultenabled/optout retained), deterministic private personal hints and existing80ms binding. Discussion/Fund/JourneyStop changes do not invalidate unrelated Home/Calendar data. Access-changing group hints use HOME_ACCESS_CHANGED/CALENDAR_ACCESS_CHANGED to clear sensitive snapshots before authoritative REST; ordinary refresh retains Home layout/scroll policy. Fund transient state labelled stale, no financial writes while stale; reads/collection selection and pending mutation responses cannot repopulate denied/disposed state. Notification mark/read-all performs targeted authoritative inbox+count read rather than publishing an old snapshot or page-local count; older badge results rejected. No ledger math, new schema, socket, API business contract, signing or Firebase config changes.

Dedicated canonical API fixture (not reset old data): Group “R2 FINAL QA29-10”8cb1a5f4-677b-47eb-a9e3-96d3667b27fa; normal invitation accepted by Member1; Activity500572d2-e9ec-45cc-a8c8-99621de16d39; ordinary Task27ad4622-6ec8-4a20-be31-115a6a757b87 assigned Member1; empty Fund17c51a89-106d-430d-9f31-3711fd79c649; synthetic1000collectioneda85f1d-0d81-494f-9697-e63ed373eeb3. No actual payment or previous-group mutation. Metadata `/tmp/wedo-r2-fixture.json`0600, setup `/tmp/wedo-r2-fixture.py`; never blindly rerun if membership already active.

Backend packagePASS3.105s; scoped runtime restart underway `/tmp/wedo-r2-runtime.log`. New Android/iOS Profile builds underway `/tmp/wedo-r2-{android,ios}-build.log`; no installs yet. Required physical Task/Expense/Settlement/Fund/Notification/aggregate gates remain PENDING. OS push is separate and not a new physical PASS from these socket tests.


## Physical acceptance continuation / hotspot recovery

Prior verified same-source R2 pair: Member Task status progression, Owner assignment and API metadata edit→peer detail/list update PASS; user “Task OK”. Expense create2000/edit4000/edit6000→live list/detail/shares/balances PASS; Owner held Home receive2000→3000 PASS; pending Settlement3000 does not prematurely clear debt, Member actual confirmation→balance0 and Owner Home0 PASS. Task title edit is canonical PATCH terminal QA; current pencil UI is assignee editing, not a newly implemented title form. No QA records deleted.

Network changed to hotspot Mac<QA_HOTSPOT_IP>/Samsung<QA_HOTSPOT_IP>. Existing tested JAR restored, no backend rebuild. Same-source endpoint-only Android13.3s/iOSProfile42.1s builds/install/launchPASS; signing unchanged. Gateway media initially rejected by automatic approval review; after explicit user informed approval, relay permits only .3/.4/.1 and retains privateS3auth. Existing QA containers/volumes and sessions retained. Disk7.3GiB at recovery. No new source changes or repeated suites.

New physical Fund evidence on hotspot: Samsung real UI contribution1000→exactly1PENDING/ledger0; Owner held collection user confirms automatic arrival and approves; Member live collection/history/own totals/ledger1000 PASS, user Ownerledger1000 PASS. Samsung offline preserves valid workspace under stale label and restores automatically after real Wi-Fi reconnect without Retry. Synthetic FundExpense200→liveledger800/counter1; Member Reimbursement100→liveledger800/available700/reserve100/counter1, Owner user confirms and approves; Member liveledger700/reserve0/approved row. Owner API correction reverses only that expense→liveledger900/reversed badge; both canonical accounts900 and exactly4immutabletransactions. No actual payment, no formula changes. User Owner final900 confirmation and Notification gate still pending at this checkpoint.

</details>
