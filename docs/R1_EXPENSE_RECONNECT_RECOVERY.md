# R1 Expense reconnect recovery hotfix

## Gate and scope

Validation resumed **2026-10-25**, Asia/Ho_Chi_Minh. **Expense/Settlement expired-token hotfix PHYSICALLY VERIFIED; R1 READY FOR ACCEPTANCE, NOT COMPLETE; R2 IN PROGRESS; R3–R9 NOT STARTED.** This accepts the bounded Android recovery hotfix, not the outstanding two-device R1 gate. Earlier acceptance failures remain historical evidence, not overwritten.

The `wedo-milestone-delivery` skill was used for frozen-source/candidate verification, focused regression and evidence separation. All pre-existing dirty work, stash, protected local files, QA sessions/data, signing and Firebase configuration are retained. No backend/schema/financial-rule/Fund/Reimbursement change; no transaction, membership mutation, iPhone rebuild or second-iPhone operation. No Git mutation.

## Confirmed cause, before production changes

The Oct22 controlled reproduction first showed ordinary fresh-token recovery working. With the same installed old candidate and a **naturally expired** access token, the first loss-triggered REST resync failed offline. After restoration, Samsung independently reached backend health200, but WebSocket upgrades repeatedly returned401 with the expired token. `WebSocketChatRealtimeClient._setState` suppresses repeated identical `reconnecting` states, so `RealtimeSync` did not request another REST read. The existing REST `AuthInterceptor` therefore never got an opportunity to rotate the token. Expense retained cache, stale=true/Add disabled; no successful financial REST response was discarded.

Manual authoritative pull-to-refresh rotated the token, restored WS authorization and cleared stale. This confirms the reproduced mechanism; the earlier19:49 acceptance capture alone did not include token-expiry evidence. Evidence: `/tmp/wedo-expense-reconnect-{before,aged-before,auth-probe,red-auth,red-pong}.log`. No token/header/body was printed or persisted by diagnostic output.

The connected-socket counterpart is deterministically reproduced for both actual financial widgets: transient REST failure has no subsequent subscription ACK if the socket stays connected. Existing PONG proved reachability but previously could not trigger the pending read.

## Bounded production delta

| File under mobile/lib | This task +/− | Purpose |
| --- | ---: | --- |
| features/chat/data/chat_realtime_client.dart | +20/−2 | One local `WS_HANDSHAKE_UNAUTHORIZED` signal per connection outage on a typed WebSocket HTTP401. Existing REST policy decides refresh versus invalidation; no credential rotation in the socket client. Successful connect/disconnect resets the budget; old socket generations cannot signal a new session. |
| core/realtime/realtime_sync.dart | +13/−3 | Route that one signal through existing mounted-scope resync; forward existing PONG to optional recovery callbacks. |
| core/realtime/realtime_binding.dart | +28/−1 | At most one PONG-driven recovery attempt per pending read episode; reuse80ms coalescing/serialization. Failure consumes the budget, rather than issuing reads on every heartbeat. Existing normal invalidation/resume/ACK or a fresh read permits a later episode. |
| features/expense/application/expense_controllers.dart | +21/−0 | Expense List and Settlement Balance opt in only for expected transient authoritative-read failures; not while refreshing/working, denied or disposed. Existing paired atomic publication/generation guards retained. |
| features/expense/presentation/expense_screens.dart | +9/−1 | Wire the two controllers' pending-read state; add the Retry icon's `Thử lại` accessibility tooltip. |

**Production total:5 files,+91/−7.** No unrelated production change. Reverse reconstruction in memory matched all five recorded pre-hotfix SHA256 values; no repository file was restored. `/tmp/wedo-expense-reconnect-scope.jsonl` records counts and baseline verification. These are task-relative counts, not the entire pre-existing dirty worktree diff.

Two already-untracked test files were extended, not newly introduced by this task: `test/core/realtime/realtime_sync_test.dart` **+46/−0**, `test/features/expense/presentation/expense_offline_cache_test.dart` **+322/−0**. **Test total:+368/−0.** The latter adds10 cases, not a new feature implementation. Documentation is this report plus a concise addition to the existing handoff; exact final documentation counts are recorded at closeout. The approximate tool preview is not an authoritative final diff count.

## Automated evidence

Final Oct22 affected command: `flutter test --no-pub test/core/realtime test/core/network test/features/auth/application test/features/auth/data test/features/chat test/features/discussion test/features/expense test/features/activity test/features/poll test/features/task test/features/calendar/presentation/calendar_screen_test.dart --reporter expanded`.

**407 PASS/0 FAIL**, exit0; `/tmp/wedo-expense-reconnect-focused.log`. `flutter analyze --no-pub`: **No issues found (4.3s)**, exit0; `/tmp/wedo-expense-reconnect-analyze.log`. Source unchanged since those checks. No full suite, backend rebuild/test or unrelated scratch-test deletion. Initial red reproductions and fake-async cleanup/fixture errors were resolved before this final result; interrupted intermediate runs are not reported as passes.

Supplementary Oct25 external fake-credential lifecycle gate: **2 PASS/0 FAIL** (`/tmp/wedo-expense-reconnect-security-gate.log`). It exercises the actual session invalidator plus RealtimeSession: invalid refresh authentication or invalid access credentials clears the matching fake session, disconnects the client and produces no further handshake attempts during ten simulated minutes. No real QA credential was revoked.

| Required invariant | Evidence / boundary |
| --- | --- |
| Cache retained stale; successful paired read clears stale/actions | Controller and actual Expense/Settlement widget tests, plus physical smoke below. No invented initial balances or partial paired publication. |
| Failed recovery/working manual Retry | Both widget regressions; repeated PONG after the failed automatic attempt issues no more reads, actual Retry succeeds after restoration. |
| Reconnect/ACK/resume | Real client with controlled connector and actual RealtimeSession lifecycle; existing RSVP/Discussion regressions included. |
| Connected socket, transient REST failure | Both widgets use actual PONG event routing; exactly one paired retry, no socket replacement or recurring REST polling. Physical selective-REST failure not manufactured. |
|401 versus invalid refresh/access credentials | Existing generation-aware AuthInterceptor/invalidator tests, new one-signal outage budget and supplementary joint lifecycle gate. No new refresh/auth policy. |
|403/membership loss | Existing cache-clearing/generation tests and PONG-recovery401/403 tests: denied financial cache removed, subsequent PONG does not retry denial. Physical membership revocation deliberately not performed. |
| Late/disposed and stale failed responses | Existing request-generation/controller tests plus old-handshake/new-session test. No inference from unchanged physical values. |
| Multiple signals/application scope | Existing per-binding80ms coalescing and busy/trailing reload retained; dual prefixes share one widget budget.401 uses the existing mounted-watch resync, not root rebuild, global endpoint fetch or an unmounted-module sweep. The later subscription ACK may legitimately cause another coalesced read; this is not a claim of exactly one GET globally. |
| No financial mutation replay | Recovery invokes only paired REST reads; tests assert zero writes. Physical flows never open/submit financial mutations. |

## Candidate and runtime

- Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`; all older dirty changes preserved, not attributed to this hotfix. Production inventory SHA256 `3d44bdda2f911d32b7163429f5428725618461016a0c7fc0b4704be53c2622fc`.
- The previously interrupted build actually completed Oct22 in13.6s. On Oct25 fresh detection found Mac **en0/<QA_LAN_IP>**, Samsung **<QA_LAN_IP>**. Necessary URL-only Android rebuild **PASS30.4s**, `--dart-define=WEDO_API_BASE_URL=http://<QA_LAN_IP>:8080`; no source/signing/Firebase change. Existing firebase_core/KGP future-compatibility warning only.
- Final APK SHA256 **`5a62f3dae672524a0d2f09238207bb3d36444d7788996e8491314f015e800856`**. `adb install -r` **Success**, appPID23472; retained authenticated QA navigation. VM confirms the installed client's exact current API URL. No uninstall/session clear. Log `/tmp/wedo-expense-reconnect-current-lan-build.log`.
- Docker Engine was stopped after the interruption. Opened Docker Desktop normally (no force restart), started only existing stopped wedo-postgres/redis. Existing backendPID94784 recovered with retained JAR, DB/Redis and local/current-LAN actuatorUP; no backend rebuild/restart. Other Docker Desktop auto-started workloads were not explicitly changed.
- **Independent environment issue:** retained MinIO cannot start because its port binding references<QA_LAN_IP>:9000. Container/volume/config preserved; no recreation/alias/port fix or media acceptance under this financial-read task. Expense/Settlement REST works without it; media/demo readiness must not be inferred.
- iPhone/signing/Firebase unchanged. Existing iPhone API artifact references<QA_LAN_IP>, now different from the Mac; current phone LAN reachability remains **UNVERIFIED**, not a proven Home defect. No iPhone operation in this resumed validation.

## Physical Samsung evidence

Fresh-token Expense smoke **PASS**: existing3 rows5M/500K/60K and actual balances0/0; Add enabled online. Offline preserves rows/balances and disables Add. Automatic WebSocket101 and paired expenses/balances200 clear stale and restore Add, no Retry/navigation/relaunch. Evidence `/tmp/wedo-expense-reconnect-final-fresh-expense.log`, online UI `/tmp/wedo-expense-reconnect-final-expense-online-ui.log`.

Stable connected observation longer than65seconds: **zero financial HTTP requests**, Expense generation4 and Settlement generation1 unchanged, both fresh. `/tmp/wedo-expense-reconnect-final-heartbeat-window.log`; profiler disabled/cleared on exit. Existing heartbeat cadence is25seconds; actual PONG-to-read behavior and its once-only failure budget are separately proven by widget tests, not inferred solely from elapsed physical time. Normal transport reconnection backoff remains; the new budget bounds REST/auth recovery, while definitive session invalidation stops the socket as shown by the supplementary lifecycle gate.

**Naturally expired-token joint Expense/Settlement case: PASS.** Both existing controllers mounted, Settlement visible; actual token expiry17:37:03 local and expired=true verified17:37:07 before disconnection. No expiry/credential/server-clock manipulation. During offline failure both retained balances and3 records, stale=true; Settlement history remained visibly readable with feedback. Samsung-to-backend health independently became200/UP after Wi-Fi restored (first immediate probe failed during reassociation and was not counted as reachability).

- Unique trace: **one WS401** (request started17:37:31.643), four protected GET401 for the two paired projections, **one POST /api/v1/auth/refresh200**, then authoritative expenses/settlements/balances200. First clean controller/Settlement UI observation17:37:34.907: Expense generation6 and Settlement generation4 fresh; subsequent WS101 and authorized resubscription cause the expected further paired200s, ending Expense generation7/Settlement5 before navigation. No manual Retry/reopen/resume was used to obtain these recoveries.
- Only after both controllers and the visible Settlement screen had recovered did Back reveal Expense. Its existing3 rows/0 balances and **Add enabled** were directly observed, without pulling refresh; the normal route-return reload afterward is not the basis for acceptance. Actual0 debt/history-only fixture has no pending payment buttons: restored nonzero/pending-action gating remains automated evidence, not a manufactured financial transaction.
- Deduplicating repeated profiler snapshots by request identity yields8 successful financial GETs (two rounds across both mounted controllers), one refresh and one successful WS upgrade; no repeating401 after rotation, **zero financial mutation requests**. Normal ACK-driven second round is finite, not a new polling loop. Log `/tmp/wedo-expense-reconnect-final-aged-both.log`; wrapper completed EXIT0 and restored keep-awake0. Final appPID23472 remains online at Expense. Bounded process log count is zero for unhandled/fatal/framework/disposed/overflow signatures (`/tmp/wedo-expense-reconnect-final-error-counts.log`), not a global/iOS guarantee.

## Diagnostics, cleanup and remaining work

No instrumentation was added to production source. Task-only external helpers: `/tmp/wedo-expense-vm.py`, `/tmp/wedo_expense_reconnect_probe_test.dart`, `/tmp/wedo-expense-ui.py`, `/tmp/wedo-expense-expiry-check.py`, `/tmp/wedo-expense-security_gate_test.dart`, `/tmp/wedo-expense-hotfix-scope.py`. Each profiling batch restores Wi-Fi, disables profiling/clears its temporary profile and removes its own USB forward in finally. The natural-expiry wrapper restores the original USB keep-awake preference0 in finally. Initial commands missing guaranteed cleanup were rejected and not executed; approved replacements include cleanup in the same action. Sanitized logs retained separately from executable helpers.

Final cleanup: profiler explicitly observed **disabled**, own forwards absent, Wi-Fi restored<QA_LAN_IP>, original USB keep-awake0 restored. Only the six task-created executable helpers listed above and the task-created device XML were removed; sanitized evidence/build/test logs retained. These regeneratable diagnostics are outside the repository and are not production/test patch lines. No pre-existing helper/untracked file, build cache or QA data was deleted. Source fingerprint unchanged from the407-test snapshot; iOS signing hashes unchanged, index empty and stash retained. Exact final9-path breakdown is recorded below. Current R1 two-device/manual gates, iPhone connectivity and separate stale-IP MinIO environment issue remain pending; no R1 COMPLETE claim or R2 expansion.

Final task-relative scope: **9 repository paths,+544/−7 lines**:5 production files **+91/−7**,2 test files **+368/−0**,2 documentation files **+85/−0** (this report78lines and7-line handoff addition). This is not all100 pre-existing tracked changes or the complete untracked realtime directories. Temporary helper source outside the repo:6 files/410lines removed, plus own device XML; retained sanitized logs are evidence, not product instrumentation.
