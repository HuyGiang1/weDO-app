# R1 final reliability hardening — 2026-10-21

## Outcome and boundary

**R1 RELIABILITY READY FOR FINAL ACCEPTANCE**, not R1 COMPLETE. The requested Activity parent blocker and all six confirmed failed-future callbacks are corrected. Focused automated evidence: **214 PASS / 0 FAIL**; analyzer clean. Samsung-only Activity/Discussion offline preservation and authoritative reconnect PASS. Full cross-platform/negative-permission acceptance and physical checks of the six screens are still required; no extrapolation from one handset/flow.

This follows [Discussion hotfix](DISCUSSION_REALTIME_RELIABILITY_HOTFIX.md) and preserves the original [RSVP A–E physical results and stop](RSVP_REALTIME_PHYSICAL_ACCEPTANCE.md). No R2 functionality expansion, R3/Moments/Community, backend/schema/migration, QA reset, financial mutation, signing/Firebase edit or iPhone operation. All other dirty work retained; no Git staging/commit/push/merge/reset/restore/stash/clean.

## Activity offline root cause and fix

`ActivityDetailController._load` replaced valid detail/participants with a failure-only state on REST error. The screen's `detail == null` branch then unmounted the embedded Discussion, destroying its last-good local state. Keeping the data alone was insufficient: a focused test additionally exposed that conditionally inserting the offline banner changed ListView child indices and recreated the Discussion State.

- Reuse last-good detail/participants only for the same Activity and transient network/timeout/5xx read failure. Preserve them during manual refetch too; no spinner replacing valid content. Keep the banner slot stable so the same Discussion State survives error and recovery. The UI explicitly labels cached data.
- Before any successful load, show loading followed by a meaningful offline/retry state, never a successful empty Discussion. A genuinely loaded empty Discussion keeps its existing explicit empty state.
- HTTP401/403/404 are prioritized over transport classification and clear protected detail/participants; show login/permission/missing feedback. Typed mutation authorization failures also clear protected cache. Current known denial is not downgraded into network permission by a later failed resync.
- A scope DENIED/REVOKED control immediately clears protected cached data and invalidates in-flight reads before REST can fail or return late. Discussion has the same immediate-denial behavior when used alone. Existing auth interceptor/session/root gate remains unchanged.
- Existing scope subscribe ACK/resync performs authoritative REST reload. Controller request generations and disposal guards remain authoritative. Detail/participant parsing/programming failures now reach FlutterError reporting instead of being converted silently into an unknown connectivity failure by the repository.

Tests use the actual Activity screen with actual Discussion widget: last-good comments remain mounted in the **same State instance** offline and after ACK recovery; first-load offline terminates loading; permission/unauthorized/not-found removes protected content; scope revocation rejects an already-running late success; programming error is reported. Existing stale/disposed Activity tests and RSVP UI regressions also pass.

## Six-location audit and resolution

All six previously caught an error and assigned a new `Future.error` for a later FutureBuilder build. That separately failed future could be unhandled before listener attachment; valid data was replaced by error state. Prior `mounted`/future-identity checks were not a complete request-order guard. Successful subsequent scoped reconnect/refetch could recover **after an initial successful load established the scope**, but the exception/data loss and races remained. Detail screens without initial resource context still provide explicit initial-load Retry rather than inventing a subscription scope.

| File / method | Previous unhandled possible / valid state lost | Prior reconnect behavior | Risk before fix | Status / reason |
| --- | --- | --- | --- | --- |
| `features/poll/presentation/screens/poll_screens.dart` — `_PollListScreenState._refreshRealtime` | YES / YES | Successful scoped read could recover; deadline callback used same unsafe path | MEDIUM | FIXED — shared safe read; existing deadline scheduling retained |
| Same file — `_PollDetailScreenState._refreshRealtime` | YES / YES | Recoverable once Activity scope known | MEDIUM | FIXED — safe read, existing scope/deadline/selection behavior retained |
| `features/task/presentation/screens/task_screens.dart` — `_TaskListScreenState._refreshRealtime` | YES / YES | Successful scoped read could recover | MEDIUM | FIXED — safe read; filter changes reset context rather than presenting old-query rows as valid data |
| Same file — `_TaskDetailScreenState._refreshRealtime` | YES / YES | Recoverable once Activity scope known | MEDIUM | FIXED — safe read, current server-projected Task permissions retained |
| `features/expense/presentation/expense_screens.dart` — `_ExpenseDetailScreenState._reload` | YES / YES | Recoverable once verified group scope known | HIGH | FIXED — classified failure, labelled read-only cached projection, authoritative REST recovery |
| Same file — `_SettlementDetailScreenState._reload` | YES / YES | Recoverable once verified group scope known | HIGH | FIXED — same; successful mutation response also invalidates older pending reads and cannot publish over a newer read/revocation |

Paths above are relative to `mobile/lib/`. Post-fix residual risk: MEDIUM pending physical acceptance of those six screens, not a remaining proven instance of this failed-future defect.

### Narrow shared correction, not a realtime rewrite

New `core/realtime/reliable_read.dart` owns immediate async completion/error handling and explicit AsyncSnapshot state via ValueNotifier. The six screens retain their existing resource-specific UI, API endpoints, mutation methods and bindings. Initial/manual/realtime reads share one generation; expected transient failures retain last-good data plus visible feedback. Cached screen bodies are temporarily noninteractive until an authoritative read succeeds (including scrolling through that cached body); Retry remains available outside the interaction guard. This conservative Finance behavior does not permit writes from a stale projection or imply that cached amounts are current.

401/403/404 remove data; known denial persists through failed network resync. Unexpected parsing/programming failures are explicitly reported through FlutterError and end initial loading. No new timer/polling/retry loop/socket. Existing transport coalescing and reconnect remain unchanged. The only existing shared sync/binding change is an optional immediate access-loss callback for server scope DENIED/REVOKED, used by the corrected paths; unaudited modules retain their prior behavior. Transport authentication, dedupe, connection lifecycle and event protocol are not redesigned. Focused router/binding/Chat socket regressions cover this additive hook; no substantial shared-infrastructure rewrite requiring the full suite.

ExpenseFailure now retains its originating ApiException metadata so Finance can distinguish expected network/server failure from denied access **without parsing Vietnamese messages**. Existing financial messages and amount parsing remain unchanged. PostgreSQL/API responses remain authoritative; no balance, ledger, approval, settlement or Fund rule was altered.

### Adjacent confirmed Task async error

Task detail also started an initial member-name `.then` lookup with no error handler. A focused RED test independently reproduced unhandled ApiException after the primary Task read was already handled (`/tmp/wedo-r1-member-names-red.log`). The same screen now owns this lookup's typed API/Group failures, mounted/generation guards and unexpected-error reporting; failed lookup can retry on a later existing realtime/resync callback. No assignment/eligibility/business rule change or new member realtime feature. This small adjacent fix is required to avoid claiming Task-detail offline reliability while another startup Future still leaks.

## Automated evidence

Command (from `mobile`):

```sh
flutter test --no-pub test/core/realtime test/features/discussion test/features/poll test/features/task test/features/expense test/features/activity test/features/calendar/presentation/calendar_screen_test.dart --reporter expanded
flutter analyze --no-pub
```

- Final focused result **214 PASS, 0 FAIL**, exit0, `/tmp/wedo-r1-hardening-focused.log`. Includes the 33 earlier RSVP/realtime/Calendar cases plus affected feature tests; not the full Flutter suite. No `temp_test.dart` edit/removal.
- Six-screen matrix independently checks targeted refresh failure with valid data, initial offline/retry,401/403/404, immediate scope revocation while REST fails, late failed/successful reads versus newer success, disposal, malformed-response error reporting, readonly stale body, reconnect ACK recovery, zero writes and no autonomous retry loop. These are actual screen + repository/API + RealtimeHost/Sync tests, not inference from a helper-only pass.
- Dedicated ReliableRead tests cover timeout/503, denial, stale/disposed outcomes and invalidating pending reads when an authoritative mutation response is accepted. Dedicated Activity/Discussion tests cover the parent lifecycle boundary above.
- Analyzer **No issues found (2.1s)**, exit0, `/tmp/wedo-r1-hardening-analyze.log`.
- During iteration: one missing required test-fixture groupId, an unpumped fake-async Dio request, the real conditional-banner lifecycle defect, and four brace-only lints were resolved before the final run. The independently reproduced Task names failure was fixed; intermediate failures are not final PASS evidence.
- Backend unchanged: no backend tests/build, database write tests, full suite or new cloud/FCM acceptance. Prior backend40 focused passes remain historical, not rerun here.

## Samsung physical evidence — bounded parent offline recheck only

- Fresh detection: Mac en0 `<QA_LAN_IP>`; Samsung <QA_ANDROID_SERIAL> `<QA_LAN_IP>`. Existing backend/dependencies healthUP. No backend/Docker restart or config edit.
- Android debug build current LAN SUCCESS,10.9s; in-place install SUCCESS, session retained. APK SHA256 `ed87e925c460633c5a818ec22fdb2f77a917cfc2e3c78f40a1b676b14c1540eb`, appPID29211. Build log `/tmp/wedo-r1-hardening-android-build.log`. Initial accessibility read raced app startup; retrying app launch exposed normal Home, not a demonstrated product failure.
- Existing Capacity Lab Activity `3a09b926-2ba4-4f3c-b266-d729ed072053`, same existing QA comment `15c36abd-9f66-4c6d-8652-68a068486b9b`. Samsung opened loaded Discussion; only Samsung Wi-Fi disabled. **Offline screenshot visually confirms Discussion still visible with old comment plus explicit failed-refresh/cached-data feedback**, unlike the previous attempt. No manual reload/navigation/relaunch during outage/recovery.
- Terminal QA Owner edited only that labelled comment while Samsung offline to `QA R1 final reliability — authoritative reconnect`. Wi-Fi automatically restored via shell exit trap; same IP verified. Access log at22:51:39 shows Samsung WS101 and Activity/participants/comments GET200; UI automatically obtained the new content and removed refresh-error feedback. No direct scope-ACK wire capture in this bounded smoke; ACK behavior separately covered by focused tests.
- `/tmp/wedo-r1-hardening-{online-ui,offline-ui,recovered-ui}.log`, offline screenshot visually inspected at `/tmp/wedo-samsung-screen.png`; `/tmp/wedo-r1-hardening-samsung.log` new-process bounded scan: zero Unhandled/ApiException/FATAL EXCEPTION/setState-after-dispose/RenderFlex/EXCEPTION CAUGHT matches. No log clearing or claim of all-session/system/device-wide absence.
- Existing RSVP unchanged going1/waitlist0, Member GOING/Owner NOT_GOING; no repeat of RSVP A–E, financial write, membership/role change or reset. No iPhone commands, builds or signing changes. Runtime left running.

## Source delta for this task only

12 production files (not the whole dirty worktree):

1. `core/realtime/reliable_read.dart` — new focused safe-read state/builder.
2. `core/realtime/realtime_sync.dart` — optional access-loss signal.
3. `core/realtime/realtime_binding.dart` — optional feature denial hook.
4. `features/activity/application/activity_controllers.dart` — last-good read state and immediate denial.
5. `features/activity/data/activity_failure.dart` — auth/status/transient classification.
6. `features/activity/data/activity_repository.dart` — preserve unexpected read failures for reporting.
7. `features/activity/presentation/screens/activity_runtime_screens.dart` — stable offline banner, denied/initial error feedback.
8. `features/discussion/presentation/widgets/activity_discussion_section.dart` — immediate denial and pending-read invalidation; previous hotfix retained.
9. `features/poll/presentation/screens/poll_screens.dart` — two safe refresh integrations.
10. `features/task/presentation/screens/task_screens.dart` — two integrations and confirmed adjacent lookup failure.
11. `features/expense/data/expense_failure.dart` — preserve source failure metadata.
12. `features/expense/presentation/expense_screens.dart` — two integrations and stale mutation-response guard.

Tests: new `core/realtime/{reliable_read_test,six_refresh_paths_test,activity_offline_discussion_test}.dart`; append denial regression to existing Discussion realtime test. Documentation: this report plus concise updates to current handoff/roadmap, preserving all historical entries. Existing realtime/native/P0/PRE-M19 dirty work must not be attributed wholesale to this task.

## Remaining gates and exact final physical retest

No known remaining source blocker in the **authorized Activity + six-callback error-handling slice**. R1 remains IN PROGRESS pending final acceptance, not complete from tests alone. Physical negative authorization and the six-screen matrix are still unaccepted; iPhone QA iPhone still runs the previous unpatched candidate. The second iPhone is out of scope.

**Physical retest required: YES.**

1. For final two-device acceptance, deploy this verified snapshot to QA iPhone only using existing local signing unchanged; retain Samsung current candidate and detect current LAN again. Keep Owner/Member sessions. Do not touch Secondary iPhone.
2. In the existing isolated QA Activity with a labelled QA comment, show Discussion on both devices. Interrupt only observer connectivity, confirm cached content + offline feedback persists (no false empty/loading); change that QA comment from the other account and reconnect. Verify authoritative content, no duplicate/error/retry loop. Samsung-only version of this step already passed; do not rerun all RSVP join/leave/FIFO flows unnecessarily.
3. Open each of Poll list/detail, Task list/detail, Expense detail, Settlement detail with known valid isolated data. One bounded connectivity interruption per visible path: show labelled cached/read-only state, restore connectivity and confirm authoritative refresh/no unhandled error. Do **not** submit financial actions merely to test refresh.
4. In a separately approved disposable membership fixture, revoke observer access while detail/Discussion or a financial detail is open. Verify protected data disappears immediately and late/in-flight responses do not repopulate it; REST denies. Restore only that fixture through normal approved membership flows. Do not remove members from retained demo groups just for this check.
5. Capture candidate identity, bounded handset logs and remote-observer UI; accept only demonstrated paths. iPhone/negative-permission/six-screen physical results must not be inferred from Samsung Activity smoke or prior RSVP PASS.

Remaining R2 gaps unchanged: Home/Calendar/group aggregate fan-out defaultOFF; module-by-module mutation/list/detail/read-model coverage; Poll deadline lifecycle completeness; successful Task name/form snapshots beyond failure retry; Social/admission lifecycle guards; Finance/Fund collection/selective-resync races, failure-only state and form snapshots; Notification/FCM end-to-end acceptance. Existing binding's broad catch on **unaudited modules** remains review debt; corrected paths explicitly report unexpected failures. Do not expand these under this hotfix or start R3–R9.
