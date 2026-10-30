# R1 Expense offline-cache hotfix — 2026-10-22

## Scope and milestone gate

**R1 remains BLOCKED / NOT COMPLETE pending full final acceptance.** This separately authorized hotfix addresses the concrete failure recorded in [final acceptance](R1_FINAL_ACCEPTANCE_REPORT.md); it does not overwrite that historical failure or accept all R1/R2 functionality. R2 remains partial/IN PROGRESS, R3–R9 NOT STARTED. Used `wedo-milestone-delivery` for bounded implementation, focused evidence and explicit physical-vs-automated gates; the user's narrower focused-test/no-Git scope takes precedence over normal milestone closeout.

Preserved all earlier dirty work, signing, Firebase, QA records and runtime. No backend, schema, ledger, finance calculations, Fund, socket policy or shared-core change. No iPhone operation, database reset, financial submission, cleanup, staging, commit, push or merge.

## Exact root cause (reported before edits)

`ExpenseListScreen.reloadRealtime` → `ExpenseListController.load(groupId, silent:true)` → parallel `ExpenseRepository.list` + `myBalances` REST reads → typed `ExpenseFailure` → failure-only `ExpenseListState`. Both `expenses` and `balances` revert to their empty/null defaults. The controller loses its public last-good projection, not merely the widget hiding it; repository/DB records remain intact. The widget then selects whole-page failure instead of rows/balances. Initial failure and refresh failure were incorrectly represented identically. Existing generation/disposal guards alone did not prevent this.

`SettlementBalanceController.load` has the identical transition: failure-only `SettlementBalanceState` discards balances and settlement history. Corrected with the same policy. `SettlementDetailScreen._reload` already uses the earlier `ReliableRead` mechanism, with auth clearing, stale read-only state and generation guards; unchanged and covered by existing six-screen regressions. No unrelated Settlement redesign or Fund changes.

## Implementation

Only two production files changed in this task, preserving their prior edits:

- `mobile/lib/features/expense/application/expense_controllers.dart`: Expense List and Settlement Balance distinguish initial/loading, refreshing, loaded, stale and denied. Reuse existing `ReadFailure` classification and preserved `ExpenseFailure.apiError` metadata: network/timeout/5xx retain the complete last-good projection;401/403/404 clear protected data. Known denial cannot become cached permission after a failed network retry. Unexpected programming/parsing errors are reported through `FlutterError`, not silently classified as network failure.
- `mobile/lib/features/expense/presentation/expense_screens.dart`: loaded rows/balances remain scrollable with nonblocking Vietnamese stale feedback and Retry. Empty loaded lists are distinguished using the successfully loaded balance snapshot, not `expenses.isEmpty`. Initial offline shows error/Retry, no invented zero/empty-success. Existing realtime resync refetches; no polling, arbitrary delay, new socket or mutation retry.

Both paired reads publish only after all necessary responses succeed; no new-expenses/old-balances mixture. A per-response denial guard ensures a later401/403 from the other response still clears cache after an earlier transient error; obsolete-context responses cannot clear newer data. Requests use generations/disposal guards; group changes drop old projections. Widget group/repository replacement disposes the old controller and rebinds scopes, protecting context changes. These two screens expose no user-selectable query filters; no new filters or cross-user persistent cache introduced. Existing session/root auth lifecycle remains unchanged.

Scope DENIED/REVOKED immediately calls `denyAccess`, clears data and invalidates pending responses. Only a new successful authoritative read restores access. Financial buttons are disabled during initial/refetch/stale/denied state; opening mutable detail from these cached rows is blocked while stale. Scrolling/reading and Retry remain available. Settlement mutations additionally enforce `canMutate` and group identity at controller entry, block entry while current state is read-only/working, and reject late action completions after a newer read/context/revocation. Mutation failures conservatively make retained data read-only until an authoritative reload; successful server responses never optimistically calculate balances. No automatic mutation replay.

## Automated evidence

Final command, from `mobile`:

```sh
flutter test --no-pub test/core/realtime test/features/discussion test/features/poll test/features/task test/features/expense test/features/activity test/features/calendar/presentation/calendar_screen_test.dart --reporter expanded
flutter analyze --no-pub
```

**236 PASS / 0 FAIL**, analyzer **No issues found (2.8s)**. Logs `/tmp/wedo-expense-hotfix-focused.log`, `/tmp/wedo-expense-hotfix-analyze.log`. No full suite/backend test; backend unchanged. Pre-existing `temp_test.dart` untouched.

New `mobile/test/features/expense/presentation/expense_offline_cache_test.dart`:22 tests independently cover Expense and Settlement initial offline/no fabricated balances, retained nonzero amounts and rows/history, disabled financial writes, pending partial response and atomic recovery, old success/error, disposal,401/403 (including authorization arriving after the paired network failure), denial surviving network retry, membership revocation invalidating pending success, group isolation, real-screen repository/group replacement and initial Retry, actual realtime resync/recovery/revocation with no unhandled errors or writes. Existing RSVP/Discussion and Settlement Detail reliability tests pass in the same focused run. Initial iteration had one incorrect assertion expecting the old12,000 amount after recovery had correctly replaced it with15,000; test assertion corrected, not an application failure.

## Android and bounded physical evidence

- Fresh detection Mac en0 `<QA_LAN_IP>`, Samsung <QA_ANDROID_SERIAL> `<QA_LAN_IP>`; backend actuator localhost/LAN UP (DB/Redis UP). Existing runtime/JAR/containers unchanged. Disk about3.8GiB before build; no cleanup.
- `flutter build apk --debug --no-pub --dart-define=WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080`: PASS, Gradle24.2s. Existing firebase_core/KGP future-compatibility warning, not build failure; no dependency change. `adb install -r` PASS, same package/session, PID22719. APK SHA256 `96229e0ec3a95f906d1ffda9e3f3fc0ce206d488a83dc11a6ea184fec9868f64`.
- Existing isolated Acceptance Lab expense `0da50430-f6d8-4a31-897e-3be90a7baa55`60,000 and real caller balances0/0 retained offline with stale banner. Add Expense accessibility `enabled=false`; a tap stayed on the same Expense List, no form/submission. Balance zeros are existing server data, not fabricated fallback; nonzero retention separately tested.
- Expense automatic recovery PASS: first bounded captures were too early and still stale; later **no-touch** capture shows banner gone, same row/balances and Add reenabled. Safe access log WS101 + expenses/balances GET200 at12:28:09. No Retry, navigation or app relaunch needed. Evidence `/tmp/wedo-expense-cache-{online,offline,disabled,recovered,recovered-later}.log`.
- Process-scoped bounded log `/tmp/wedo-expense-cache-samsung.log` (last1800 lines, PID22719) has no Unhandled/ApiException/FATAL EXCEPTION/framework/overflow/setState-after-dispose matches. This is not an all-device/iOS error guarantee.
- Settlement List physical retention/scroll/recovery PASS: existing completed20K/10K, rejected30K and cancelled30K history plus actual0/0 balances remain visible offline with stale feedback, and can still be scrolled. First capture after restoring Wi-Fi was too early; later no-touch UI shows banner gone with same history. WS101 + balances/settlements GET200 at12:29:33. Evidence `/tmp/wedo-settlement-cache-{online,offline,recovered,recovered-later}.log`. No pending transactions/debts in this retained fixture, so pending-action disabled controls are automated-only evidence; no financial record created/confirmed/cancelled to manufacture a physical result. Settlement Detail not newly physically tested.
- Final last2500 PID22719 log scan `/tmp/wedo-expense-cache-final-samsung.log` likewise has zero matching unhandled/fatal/framework errors; Wi-Fi restored<QA_LAN_IP>, app left at online Settlement history. No unapproved business mutation or runtime shutdown.
- **Final candidate after paired-denial guard:** rebuild11.3s/install-r PASS, APK SHA256`abc2212eba8f87c2863f24b5d10a0a97f962aa243518846f6763d4fc01ddbe71`, PID25486, same API/session. Exact-snapshot Expense smoke PASS again:60K row and0/0 balances retained stale, Add disabled; Wi-Fi restored, no-touch recovery removed banner/re-enabled Add, paired REST20012:33:47. Evidence `/tmp/wedo-expense-cache-final-{online,offline,recovered}.log`, bounded new-process log `/tmp/wedo-expense-cache-final-candidate.log`. Settlement physical result above belongs to the preceding hotfix iteration; its paired-denial guard behavior is covered by final focused tests, not a newly repeated Settlement physical claim. Final app left online at Expense List.

## Remaining acceptance and risks

iPhone **USER RETEST NEEDED**: untouched, still previous snapshot lacking this Expense/Settlement-list change. No excessive retry of the known USB automation initialization issue and no iOS PASS claim. Build/install this snapshot to QA iPhone using existing signing when final acceptance is scheduled; Secondary iPhone untouched.

Final R1 gate still needs current-pair Discussion/short RSVP smoke, remaining representative screen checks (including Settlement Detail), safely approved physical negative-permission fixture, candidate/log evidence and iOS Expense/Settlement offline/recovery. Do not remove users from retained finance groups simply to test revocation. Tests alone do not complete R1.

Remaining R2 debt unchanged: module/list/detail/aggregate parity, default-OFF read-model fan-out, Poll deadlines, Task/member/form snapshots, Social/admission lifecycle, Finance/Fund selective reload/form state, Notification/FCM acceptance and unaudited shared-binding broad catch. This is in-memory display retention only, not a persistent offline financial workflow. Offline cannot discover server-side revocation until an authoritative denial/scope control arrives; no local permission invention. Physical nonzero debt/pending-action coverage uses automated fixtures because retained QA finances currently have zero debts and completed/rejected/cancelled history; no new ledger transaction created to manufacture coverage.
