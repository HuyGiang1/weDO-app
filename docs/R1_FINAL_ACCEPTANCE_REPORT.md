# R1 final two-device acceptance — 2026-10-22

## Decision

**R1 = BLOCKED, not COMPLETE.** R2 remains IN PROGRESS; R3–R9 remain NOT STARTED.

The requested current-candidate Expense **List** offline check failed: the previously loaded expense and balances disappear into an error-only screen during transient disconnection. This is loss of cached UI, **not evidence of lost PostgreSQL data**; the same expense/balances automatically return after reconnection. In addition, current iOS UI/two-device Discussion and RSVP acceptance could not be observed because the USB UI runner did not initialize. Do not waive an observed failure using the 214 automated passes or relabel an unobserved iPhone flow PASS.

This acceptance made **no production source change or fix** and ran no full suite. It stops further functional testing on the captured Expense List issue. The earlier Discussion/RSVP/hardening reports remain historical evidence, not overwritten as a full final PASS.

## Snapshot and runtime

- Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`, plus the preserved dirty worktree.
- Production source tree SHA256 **before and after**: `a71a9abb90df1fe0987cf07d5c1bb3b529470af5195b8e044004d8395b11c6c8`. Reproduce with `rg --files backend/src/main mobile/lib mobile/android/app/src/main mobile/ios/Runner | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256`. Includes untracked source in those roots, excludes build outputs/secrets.
- Tracked backend/mobile binary-diff SHA256 before/after: `fef2844475eff2973c0d29588106163ad7e3439539ad3f9df32122d258a6f46c`. All earlier uncommitted realtime/P0/PRE-M19/native changes retained, not attributed to this acceptance. Index empty; existing stash unchanged.
- Fresh LAN detection, both start and resume: Mac en0 `<QA_LAN_IP>`; Samsung <QA_ANDROID_SERIAL> `<QA_LAN_IP>`. iPhone requests observed from `<QA_LAN_IP>`; this is access-log evidence, not an assumption about all future networks.
- Backend existing PID55791/JAR UP on localhost and current LAN; actuator DB/Redis UP. PostgreSQL pg_isready, Redis PONG, MinIO readiness localhost/current LAN HTTP200. No backend/Docker/container/volume recreation or restart. Existing JAR SHA256 `47697393e6ebf966be16bcc70f7a9c1b05c6a80b082c8345a98ac532fb790220`, no newer backend main source; realtime coordinator/publisher classes present. Existing verified backend reused, no backend rebuild/tests.

## Candidate synchronization

### Samsung — verified existing current candidate

No rebuild/reinstall needed: no newer `mobile/lib` production file than APK; SHA256 of the **actual installed base.apk** equals the retained latest R1 artifact:

`ed87e925c460633c5a818ec22fdb2f77a917cfc2e3c78f40a1b676b14c1540eb`.

Installed lastUpdateTime2026-10-21 22:49:35; API `http://<QA_LAN_IP>:8080`. Existing session preserved. After overnight resume the app PID was14930; process change is not an APK identity change. No uninstall/data clear.

### QA iPhone — current release built and installed, UI acceptance unverified

- Device only `<QA_IPHONE_UDID>`; Secondary iPhone and unrelated iPhones not targeted.
- `flutter build ios --release --no-pub --dart-define=WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080`: SUCCESS, Xcode31.2s,24.3MB, log `/tmp/wedo-r1-final-ios-build.log`.
- Runner binary SHA256 `29e0178ab1ef9ee13a9772295200cc88a616cf103cbd64966034dabaf31b0d61`. In-place devicectl install/launch succeeded Oct21 at23:02; existing `com.huygiang.wedo` bundle retained. No logout/session clear. Authenticated-looking Home/WS HTTP traffic later occurred, but without UI observation do not assert the exact visible account/route/session acceptance.
- Native app project/Info.plist SHA256 before/after respectively `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8` and `cd88a3e2d1ee3b1c064d214026073303db8f11b2baa9e4dcc00811422ce8a8bd`. No signing/bundle/Firebase configuration change.
- Initial USB UI runner timed out enabling automation mode before app actions (`run-230243827532.log`). After the overnight gap QA iPhone temporarily disappeared, then user reconnected/unlocked it; lockState reports passcodeRequired=false.
- The temporary `/tmp/wedo-ios-acceptance` helper subsequently lacked project.pbxproj/runner Info.plist. Only this **external acceptance tool** was regenerated with its existing helper bundle ID and app-configured team; helper build-for-testing succeeded. No product-source edit, app signing-setting change, test-suite run or second-iPhone preparation.
- Repaired helper still never reached `WEDO_USB_READY`, repeatedly reporting missing device OS/type metadata while initializing. Bounded attempt `/tmp/wedo-ios-acceptance/run-115957123873.log` was interrupted; no app UI actions observed. This is **USER RETEST NEEDED / tooling limitation**, not a fabricated app crash, nor successful final iPhone acceptance.

## Physical results actually obtained

Times are local UTC+07:00; acceptance began Oct21 evening and resumed Oct22 after user confirmation that both phones were unlocked.

| Requested path | Current physical result | Evidence / boundary |
| --- | --- | --- |
| Discussion offline/reconnect, both devices | NOT COMPLETED / USER RETEST NEEDED | No new iPhone UI observation. Prior Oct21 **same-current-Android** cached-Discussion/reconnect PASS remains in [hardening report](R1_FINAL_RELIABILITY_HARDENING.md); not promoted into a fresh two-device PASS. |
| Poll List | PASS on Samsung only | Existing closed `PRE-M19 Poll Lab` card/options remained visible with cached-data feedback offline; feedback cleared automatically after reconnection, no retry tap/vote. |
| Poll Detail | PARTIAL on Samsung | Existing closed Poll question/results retained with offline feedback. First capture attempt lost ADB and was excluded. Retried outage retained data, but early recovery capture still showed feedback and the route was later left; **automatic UI convergence not actually observed**, not a proven product recovery failure or PASS. |
| Task List | PASS on Samsung only | Both existing QA task rows retained with offline feedback; automatic reconnection removed feedback and tasks GET200 at12:04:32. No status/filter/assignment mutation. |
| Task Detail | PASS on Samsung only | `PRE-M19 Task Lab`, IN_PROGRESS, assignees/history retained offline; automatic recovery/no feedback plus detail GET200 at12:05:24. No Task mutation. |
| Expense List | **FAIL — cached UI lost offline**, automatic recovery observed | Existing QA60,000 expense and zero balances visible before outage. Offline error-only screen removes both; after Wi-Fi restored they automatically return, WS101 + expenses/balances GET200 at12:07:45. No Retry/navigation needed for recovery. |
| Expense Detail | NOT RUN in this attempt | Stopped after Expense List issue; earlier focused automated detail evidence only. |
| Settlement List/Detail | NOT RUN | Stopped; no create/confirm/settle/cancel transaction. Existing automated detail evidence does not accept the untouched list. |
| RSVP two-device short smoke | NOT RUN | Current iPhone UI unavailable, then stop-on-issue. Prior physical A–E PASS is historical, not this candidate-pair smoke. |
| Authorization negative | PHYSICAL PENDING | Did not remove/kick/ban any member from retained demo/lab groups. No dedicated newly authorized physical revocation fixture exercised. Prior focused backend/Flutter denial/revocation/stale-response evidence only. |
| Chat transport | PARTIAL / not physical Chat acceptance | Access log WS101 for both phone IPs and current Samsung foreground REST reads; no new Chat send/receive or iPhone screen validation. |

Samsung Wi-Fi was disabled only for bounded per-screen checks and restored using exit traps/explicit enable; final wlan0 IP verified. ADB temporarily lost its daemon/USB during one Poll Detail attempt; startup log reported server didn't ACK, later recovered. Such failed observation batches are tooling failures, not product PASS. User unlocked phones; no passcode collected/entered or security settings changed.

## Exact Expense List finding and stop

Only existing isolated fixture group `a3c7a9d6-32dd-4a5c-b5d0-804cc5636002`, expense `0da50430-f6d8-4a31-897e-3be90a7baa55` (`PRE-M19 Equal Expense Lab`) was viewed. UI before outage showed that expense60,000 and both caller balance directions0. Offline UI showed only `Chưa thể hoàn tất thao tác. Vui lòng thử lại.` / `Thử lại` (plus existing navigation/create affordances), with no cached expense/balance. The restored screen showed the same record and balances.

Read-only source inspection: `ExpenseListController.load(silent:true)` initially retains expenses/balances, but its failure branches assign `ExpenseListState(failure: ...)` without those fields; defaults erase the cached projection. This is **not one of the six Future.error detail/list callbacks hardened earlier**; it was previously documented as separate Finance-list/R2 read-state debt. However this new acceptance explicitly includes Expense List preservation, so an observed failure cannot be silently excluded from its gate. No clean-baseline attribution or claim that the hardening introduced it.

No source repair, broader Finance refactor or additional functional scenario was performed after capture. Only Wi-Fi restoration, current error/data/health/source-identity evidence and documentation followed. No intentional financial, membership, RSVP, Poll, Task or Discussion mutation in this final attempt; normal auth/session/runtime reads may have their ordinary metadata effects.

## Evidence and reliability observations

- `/tmp/wedo-r1-final-{poll-list,poll-detail,task-list,task-detail,expense-list}-{online,offline,recovered}.log` (where captured); do not treat empty/missing tooling-failed files as results.
- Expense offline screenshot `/tmp/wedo-samsung-screen.png` visually inspected; it depicts the error-only list. This temporary path may later be overwritten.
- `/tmp/wedo-accesslog/access_log.2026-10-22.log`: safe IP/method/path/status only; no headers/tokens/bodies used for claims.
- `/tmp/wedo-r1-final-samsung-bounded.log`, PID14930 last3000 process-scoped logcat lines: zero matches for Unhandled/ApiException/FATAL EXCEPTION/EXCEPTION CAUGHT/RenderFlex/setState-after-dispose. No log clearing. iPhone app log audit unavailable; **no cross-device zero-error claim**.
- Reconnects align with deliberate per-screen outages/startup; no repeating refetch/reconnect loop observed in the bounded successful recovery intervals. No stale async overwrite was physically induced; relied on explicit focused tests. No unexpected Login/Welcome seen on inspected Samsung screens; iPhone UI unverified.
- Automated evidence reused, not rerun: final214 Flutter focused passes and clean analyzer in `/tmp/wedo-r1-hardening-{focused,analyze}.log`; previous40 backend focused passes including authorization/after-commit/revocation. They cover all six corrected screen callbacks but **do not waive the observed Expense List cache loss or replace current iPhone UI/RSVP evidence**. No full suite/analyzer/package rerun beyond necessary iOS build and external helper build.

## Handoff / milestone gate

Runtime left healthy/running, Samsung online at Expense List with original record restored. Source tree/diff/native-signing hashes unchanged. Current iOS app remains installed; UI helper stopped. No credentials printed/committed, no Docker/volume/data reset, no source/test edit, no stage/commit/push/merge/reset/restore/stash/clean. Host disk last approximately3.8GiB free; no cache cleanup performed or authorized here.

Next requires review and **separate bounded implementation authority** for Expense List last-good-state/typed-error preservation, or an explicit product decision revising this acceptance criterion. Do not fix automatically or redefine R1 scope to force COMPLETE. Restore a usable iPhone UI observation path/user-assisted acceptance, then perform the short current-pair Discussion/RSVP gate and the remaining agreed representative checks. Authorization physical result remains PENDING unless a safe isolated fixture is explicitly available. Do not start R2 expansion or R3 implementation.
