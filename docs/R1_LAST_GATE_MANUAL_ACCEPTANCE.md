# R1 final gate — closed 2026-10-25; historical attempts retained

## R1 closure — 2026-10-25

**R1 COMPLETE; R2 IN PROGRESS; R3–R9 NOT STARTED.** Closure uses the roadmap's existing Definition of Done unchanged, not a new full-module acceptance requirement or a weakened transport gate. The older READY/BLOCKED and missing-device entries below record earlier attempts, not current status.

### New physical evidence — user reported, not agent-instrumented

The user's explicit closure/delivery instructions confirm actual iPhone QA iPhone + Samsung observations: **iPhone Chat reconnect PASS; RSVP cross-device realtime PASS; Poll vote change and cross-device synchronization PASS**. Earlier replies confirm existing iPhone chat images no longer reload during receipt of five Samsung messages and after sending five iPhone messages. Record **iPhone visual old-image stability PASS** only: no invented pixel/scroll instrumentation, new object transfer, Samsung five-reply receipt capture, exact fixture ID, time or negative-permission scenario.

Earlier agent-observed evidence remains scoped: Samsung Discussion cached visibility/offline/automatic recovery PASS; same-source Samsung Expense/Settlement fresh-token and natural-expired-token authoritative recovery PASS, zero financial mutations. [Environment report](R1_FINAL_ENVIRONMENT_ACCEPTANCE.md) records actual QA iPhone backend HTTP200, user Home/old-image confirmation, candidate identities and preserved storage. Subsequent user results supersede its pending Chat reconnect/RSVP/Poll entries, without rewriting the historical attempt.

### Unchanged foundation DoD review

| Required criterion | Supporting existing evidence / limit |
| --- | --- |
| Reusable architecture reviewed; PostgreSQL authoritative | RSVP consolidation and canonical API§41.6; REST-only mutations, empty invalidation payloads, authoritative detail/participants reads. No local balance/vote truth or fabricated aggregate versions. |
| AFTER_COMMIT / rollback isolation | `RealtimePublisher` rejects non-write transactions; coordinator AFTER_COMMIT queues delivery. Prior backend40 focused PASS includes real PostgreSQL RSVP commit/rollback and delivery-revocation probes. |
| Shared WebSocket and Redis fan-out | Existing `/ws` handler delegates scope commands; Redis channel `wedo:domain:realtime` registered in `ChatWebSocketConfig`. Coordinator dedupes same event across local/Redis echo; existing coordinator test covers remote serialization/delivery. Physical RSVP report observes Redis hints. Not a multi-host load/durability certification. |
| Authorized scopes / revocation | Subscribe and delivery recheck readable user/group/Activity; denied/revoked scopes stop protected frames. Existing automated coordinator/scope/PostgreSQL and Flutter401/403/late-denial tests PASS. Physical destructive membership-loss PENDING, accepted as non-independent blocker by the pre-existing Security gate judgment below. |
| Dedupe / stale / disposal | Existing actual-parser/router and binding/widget generation tests PASS. Latest407 focused PASS and analyzer clean reused as recorded in Expense hotfix; not rerun solely to close R1. |
| Reconnect/resubscribe/resync / targeted REST / no polling | Prior physical RSVP reconnect/ACK/detail+participants recovery; user iPhone Chat reconnect PASS; Samsung expired-token recovery PASS. Mounted-resource coalescing and bounded reachability recovery use existing transport, not periodic business GETs or per-feature sockets. |
| Required physical RSVP | Historical physical join/leave/rejoin/one-person FIFO/reconnect A–E PASS plus explicit current user cross-device RSVP PASS. No claim that the user repeated multi-waiter stress or membership removal. |
| Known limits and protected behavior | Best-effort bounded delivery, no replay/outbox, unversioned refetch and loss-on-healthy-connection limits retained. P0 Poll/Chat and bounded Discussion/Finance blockers fixed and scoped evidence accepted; no current critical shared-foundation defect established. |

**Pending is not PASS:** remaining R2 module/platform parity, fresh Task assignment/completion peer scenarios, Poll Results/Voters edge paths, iOS Finance/Discussion parity, controlled physical out-of-order responses, physical permission loss and R9 full regression. These do not make all R2 functionality a retroactive R1 DoD requirement. New R2-A source changes require their own tests/candidate evidence; R1 closure does not accept them automatically.

Documentation closure only for R1, no Git operation. The subsequent [R2-A delivery record](R2A_POLL_TASK_REALTIME_PLAN.md) separately records authorized source work and current verification.

> Historical execution: [Execution 2026-10-22](#execution-2026-10-22), including the then-observed Expense blocker. Subsequent hotfixes/environment recovery and the closure above supersede its milestone status, not its factual history.

## Decision

**R1 READY FOR ACCEPTANCE, NOT COMPLETE.** R2 IN PROGRESS; R3–R9 NOT STARTED. No newly confirmed code defect; remaining blocker is unobserved current-pair physical acceptance because the iPhone UI helper did not reach readiness. Do not broaden this gate into complete R2 module realtime coverage.

`wedo-milestone-delivery` used for snapshot/runtime/candidate evidence and stop-on-tooling boundary. No production source edit, new tests, full suites, Git mutation, signing/Firebase change, QA fixture reset, financial submission or Secondary iPhone operation. All earlier dirty work retained. Historical acceptance/hotfix reports remain unchanged.

## Exact snapshot and runtime

- Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0` plus dirty worktree, not all authored in this gate.
- Production source fingerprint before/after **`1b2b018cfc43c579264e35585c619f4ef32028418e21e55ebc0ffaa046bb3f3e`**, computed by `rg --files backend/src/main mobile/lib mobile/android/app/src/main mobile/ios/Runner | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256`. Tracked backend/mobile diff hash unchanged **`da33e691aa72542175021c95dbb07e79601e05d46cd68e66dee1578758d414c0`**.
- Fresh Mac en0 **<QA_LAN_IP>**, Samsung **<QA_LAN_IP>**. Both compiled candidate API URLs `http://<QA_LAN_IP>:8080`; current iPhone LAN reachability/visible account still need manual confirmation, not inferred from installation success.
- Existing PostgreSQL pg_isready, Redis PONG, MinIO localhost/LAN readiness PASS. Backend initially not listening; reused existing current JAR without rebuild. Detached launch did not persist; persistent runtime session84267 runs PID67521, local profile, DB port55432, current LAN/media endpoint, external Firebase credential path only. Localhost and LAN actuator UP. Log `/tmp/wedo-r1-last-gate-backend.log`; safe access log `/tmp/wedo-accesslog/access_log.2026-10-22.log`. No container/volume recreation, data reset or backend business edit.
- Backend JAR SHA256 `47697393e6ebf966be16bcc70f7a9c1b05c6a80b082c8345a98ac532fb790220`, no newer backend main source. No rebuild/test rerun needed.
- Samsung actual installed base.apk checksum matches current artifact **`abc2212eba8f87c2863f24b5d10a0a97f962aa243518846f6763d4fc01ddbe71`**; no newer mobile source than APK, no rebuild/reinstall. App PID25486. After backend downtime the view retained cached expense/balances with stale feedback; one pull refresh established online baseline, expense/balances GET200 and WS101. This manual baseline refresh is **not** claimed as fresh automatic-recovery acceptance. Existing session stayed in Expense List, no Login/Welcome/red screen in observed UI. Last1800-line process log `/tmp/wedo-r1-last-gate-samsung.log` has zero Unhandled/ApiException/fatal/framework/overflow/setState-after-dispose matches, not an iOS/global zero-error guarantee.
- QA iPhone only `<QA_IPHONE_UDID>`: latest release build PASS36.8s (`/tmp/wedo-r1-last-gate-ios-build.log`), install-in-place and launch PASS13:27:29; launched again after helper stop13:28:53. Existing bundle `com.huygiang.wedo`, signing unchanged, no uninstall/session clear. Runner binary SHA256 **`61ca954953614a56539da0f88fc7c60f67c2ee3f4809e33214f99f442520e65d`**. Existing data preserved by in-place installation; visible Owner session not observed, must verify manually.
- Native project/Info.plist hashes before/after `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8` / `cd88a3e2d1ee3b1c064d214026073303db8f11b2baa9e4dcc00811422ce8a8bd`.

## Bounded automation and stop

One existing USB-helper attempt at13:27:48 reached runner “Running tests” but **never `WEDO_USB_READY`** in about one minute. No valid iPhone action session/UI assertions. Log `/tmp/wedo-ios-acceptance/run-132748504952.log`; interrupted helper session31563, child xcodebuild67984 no longer running. No helper rebuild/source/signing repair or repeat attempts. This is a tooling/observation limitation, not proof of an application crash. As requested, automation stopped and manual PASS/FAIL is required before closing R1.

No new RSVP/Discussion/chat mutation, financial action, membership change or functional screen matrix after this stop. Runtime stays UP for manual retake.

## Evidence matrix, not extrapolated

| Gate | Existing evidence | Current-pair last pass |
| --- | --- | --- |
| A RSVP | Prior physical join/leave/rejoin/FIFO/reconnect PASS; focused regression PASS | MANUAL PENDING |
| B Discussion | Samsung parent/cache/reconnect PASS in prior hardening; focused regression PASS | MANUAL PENDING on newly synchronized pair |
| C Expense | Exact current Samsung APK offline/cache/disabled Add/automatic recovery PASS in hotfix | Latest iPhone + paired last pass MANUAL PENDING |
| C Settlement | Samsung history/cache/recovery PASS before final per-response denial guard; final automated parity PASS | MANUAL PENDING; no transactions |
| D Poll/Task | Prior Samsung Poll List + Task list/detail PASS; Poll Detail recovery unobserved; six-screen automated PASS | Short smoke MANUAL PENDING, not broad R2 acceptance |
| E Security | Existing backend commit/rollback/scoped delivery/dedupe/revocation and Flutter401/403/scope/stale/dispose tests PASS | Physical permission-loss PENDING, not fabricated PASS |
| F Chat/Auth | Historical Chat evidence; current Samsung authenticated baseline/WS101 only | Current two-device message delivery MANUAL PENDING |

Automated evidence reused, not rerun: **236 focused Flutter PASS /0FAIL**, analyzer clean2.8s; earlier backend40 focused PASS (including consolidated RSVP10, coordinator/scopes/after-commit/rollback/revocation). Existing report sources [Expense hotfix](R1_EXPENSE_OFFLINE_CACHE_HOTFIX.md), [hardening](R1_FINAL_RELIABILITY_HARDENING.md), [RSVP physical](RSVP_REALTIME_PHYSICAL_ACCEPTANCE.md). No false full-suite or fresh backend run claim.

### Security gate judgment

For **R1 foundation scope**, existing explicit automated after-commit/rollback, denied subscription, membership-loss delivery revocation, event-ID dedupe,401/403, stale/disposed response and paired late-denial evidence is sufficient security evidence, given unchanged backend and current mobile focused tests. A physical removal scenario is **PENDING but not independently mandatory to close R1 under this gate**, as no safe separate revocation fixture is currently prepared. Do not kick/ban members from retained QA/finance groups. This judgment does not complete module-specific R2 permissions or claim a physical PASS. R1 still cannot close until the other current-pair manual criteria pass.

## Exact manual retake — reply PASS/FAIL per letter

Preparation: keep both phones on Mac's LAN, use newly installed **QA iPhone=QA Owner**, **Samsung=QA Member1**. Confirm both load the existing group **PRE-M19 Acceptance Lab 2026-10-17**, Activity **PRE-M19 Capacity Lab**. If either phone cannot load or shows wrong session/Login unexpectedly, report it; do not reset data or change signing.

1. **A — RSVP:** open the same Activity on both. Samsung currently GOING: leave once, then rejoin once. Without refreshing iPhone, confirm count1→0→1 and participants contains Member1 only once. No full FIFO retest needed.
2. **B — Discussion:** display the existing QA comment on Samsung in that Activity. Temporarily disable **Samsung Wi-Fi only**. Existing Activity/Discussion/comment must remain with offline feedback. On iPhone, edit only the existing labelled QA comment to a recognizable suffix such as “R1 last gate”. Restore Samsung Wi-Fi; without Retry/reopening, confirm updated comment and feedback clears. Do not alter unrelated comments.
3. **C — Expense/Settlement:** on each candidate needing final confirmation, open existing **Chi tiêu**, then **Số dư & Thanh toán**. For each visible screen, briefly disable its connectivity and restore. Existing60K expense, actual0/0 balances and settlement history must remain marked stale; Add/payment/confirm actions must not proceed while stale; reconnect automatically clears feedback. **Do not create, confirm, reject or cancel a transaction.** Pending-action/nonzero-debt states are covered by automated fixtures, not manufactured financial data.
4. **D — Poll/Task:** briefly open existing **PRE-M19 Poll Lab** list/detail and **PRE-M19 Task Lab** list/detail. For a short offline/reconnect observation with each relevant screen visible, confirm cached content, no red screen/crash, eventual automatic recovery. Do not vote/change task status, repeat broad module tests or require all R2 fan-out behavior.
5. **E — Security:** no physical membership mutation. Record “automated PASS; physical permission-loss PENDING” as above.
6. **F — Chat/Auth:** open the same existing QA group chat on both. Send one clearly labelled “R1 last gate” message from each phone; confirm receipt on the other, no unexpected Login/Welcome or red screen. No historical FCM matrix.

Reply **A PASS/FAIL, B PASS/FAIL, C Expense PASS/FAIL, C Settlement PASS/FAIL, D PASS/FAIL, F PASS/FAIL**, with the screen/action for any failure. If a defect appears, stop that acceptance, capture its exact symptom, and request the smallest authorized hotfix; do not fix source in this gate. After all required manual results pass, review evidence and mark R1 COMPLETE, R2 IN PROGRESS, R3–R9 NOT STARTED. Until then retain READY FOR ACCEPTANCE.

## Execution 2026-10-22

### Scope, candidate and environment

New user instruction: **EXECUTE R1 FINAL PHYSICAL ACCEPTANCE**, not implementation. Actual device work began around19:43 local (Asia/Ho_Chi_Minh). No application source/test edit, build/reinstall, full suite, signing/Firebase change, database reset, financial write, membership mutation or second-iPhone operation. External `/tmp` UI observations only; all prior worktree changes preserved. Historical reports above and elsewhere are not rewritten or promoted to a new PASS.

- Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`.
- Production inventory fingerprint before/after: **`816c0ac8f5f9509fc26022795d212a514c8726516636f17a99ec550d430aed04`**, using the same sorted source-file SHA256 command documented above.
- Fresh current Mac **en0/<QA_LAN_IP>**, Samsung **<QA_LAN_IP>**. Local and LAN backend actuator UP, PostgreSQL/Redis UP; LAN MinIO ready. Existing backendPID94784 and media relayPID94760 retained, no restart/recreation. Roughly3.4GiB free at closeout; no build/cache cleanup.
- Samsung actual installed base.apk SHA256 read on-device: **`9742911db447f6b4f21223391f10906252dc21c8de5313a552ad7caf178dce9d`**, matches frozen artifact. AppPID5558, QA Member1 retained. Local JAR hash `951183dbf89aae2eafe125acfe8754747d38ca3c26988d5caa2d480ac9a9ee1b`; local iOS executable `e6b52ca5a45fc39c3597edfe5d9b4d6b73e1641e58b800d38d378206c89b3eea`, matching the last deployed handoff. No fresh installed-iOS binary/UI verification is claimed.
- One existing iPhone helper attempt: `/tmp/wedo-ios-acceptance/run-194308890379.log`. Reached `WEDO_USB_READY`, but the first app query returned only `Find: Application`, no usable app tree. One bounded activation/screenshot command then failed copying to the runner container. Runner ended with **remote-process communication / connection invalidated**; QA iPhone became **unavailable**, still unavailable at closeout. This is tooling/connection failure, not a proven weDO crash or product test failure. No helper rebuild, signing repair or repeated runner initialization. User asked once to reconnect/unlock; unrelated Samsung tests continued.
- Detached ADB startup initially failed. Standard default-loopback foreground `adb nodaemon server` restored access (persistent session96489); no installed data/settings cleared. No remote-control listener exposed to LAN.

### Current-attempt matrix

PASS entries below identify their actual Samsung-only scope. A full row is CHƯA TEST when a required invariant was not exercised; subcase successes remain recorded, not discarded or extrapolated.

| Test | Status | Devices actually exercised | Action / expected vs observed / evidence |
| --- | --- | --- | --- |
| A Poll vote/change/realtime | CHƯA TEST | Samsung readiness; iPhone helper attempt only | No new vote/change or peer UI observation. iPhone unavailable. Safe labelled Poll888e24d1 remains readable/OPEN/canVote by current Member API probe; that API success is not physical vote acceptance. |
| B Chat old images | CHƯA TEST | Samsung initial existing Chat tree only | Did not run the new required five texts each direction, continuous flicker/scroll observation or old-byte GET counting. Earlier task's passes remain historical, not this execution. |
| C Chat reconnect | CHƯA TEST | iPhone connection attempt only | Could not disconnect/reconnect iPhone or observe its missing-message catch-up. Did not substitute a Samsung/terminal case for this specified iPhone case. |
| D RSVP | CHƯA TEST | Samsung account/API/DB precondition only | Member GET Lab returns404. One read-only PostgreSQL query confirms membership **LEFT** in Lab groupa3c7a9d6. Did not rejoin group, change roles or use another Activity and call it the required Capacity Lab result. iPhone also unavailable. |
| E Discussion offline | PASS | Samsung, read-only scope | Existing comment+reply stayed visibly present under stale feedback, embedded Activity/Discussion remained visible; after restoring Wi-Fi the banner cleared automatically, no Retry/reopen. No observed unhandled error. Optional iPhone edit was not possible and is not claimed. Evidence below. |
| F Expense/Settlement | FAIL | Samsung Expense | Cached rows/balances preserved and Add disabled offline, but still stale/Add disabled >100s after Wi-Fi restored despite Samsung→backend health200. Stopped this Finance test. Settlement/iPhone financial views not executed after the blocker. |
| G Poll/Task offline | CHƯA TEST | Samsung | Four cache/recovery subcases PASS: actual Poll List/Detail and Task List/Detail retained data, showed stale state, then automatically cleared it. No Task/vote mutation. No controlled older-response/newer-response inversion was induced: do not label that race physically verified or infer it from unchanged values. No iPhone parity claim. |
| H Chat/Auth | CHƯA TEST | Samsung navigation; no usable iPhone app UI | Samsung retained authenticated QA navigation without Login/Welcome/red screen in observed screens; required new message in each direction not executed. |

### E — Discussion observations

Existing shared QA group **Nhóm74DCTT23**, Activity `c81b9fff-ac99-4a97-957e-ebee6059e49d`, two existing QA Member1 comment/reply texts. No comment edited or submitted. First pass retained section/error feedback offline and later recovered; second observation completed the missing direct offline screenshot because Android semantics merges comment text under the composer node.

- `/tmp/wedo-r1-discussion-online.png`: loaded comment/reply visible.
- `/tmp/wedo-r1-discussion-offline.png`: same two actual texts visible with “Không thể cập nhật bình luận. Đang hiển thị dữ liệu trước đó. Thử lại”; Activity parent/card retained. No inference from a successful REST request alone.
- `/tmp/wedo-r1-exec-discussion-confirm-offline-recovery.log`: Wi-Fi disabled20:07:14.578, restored20:07:17.668; stale text absent at the20:07:27.363 observation and clean UI confirmed20:07:29.889. No Retry, reopening or app resume intervention.
- Earlier logs `/tmp/wedo-r1-exec-discussion-{online,offline-recovery,late-no-touch}.log` retained. One agent-created incidental screenshot with an unrelated notification banner was excluded and its own host/device temporary copies removed; user photos/notifications untouched, no unrelated content quoted in reports.
- This establishes cached visibility and unchanged authoritative read recovery on Samsung. A remote edit from iPhone, widget identity instrumentation and an iOS equivalent are **not** claimed.

### F — exact reproduced blocker; no implementation authorized

1. On frozen APK, open existing shared QA **Chi tiêu**. Online UI shows three expenses:5,000,000 /500,000 /60,000 VND, actual balances0/0, Add enabled (`/tmp/wedo-r1-exec-expense-online.log`).
2. Disable Samsung Wi-Fi at **19:49:43.491**. Before any pull refresh the same valid rows/balances remain, stale feedback appears and **Thêm khoản chi becomes disabled**. One additional read-only offline pull was exercised, never a financial action (`/tmp/wedo-r1-exec-expense-offline-recovery.log`).
3. Restore Wi-Fi at **19:49:51.639**. Do not Retry, refresh, navigate, relaunch or resume the app while observing this screen.
4. At **19:51:33**, wlan0 has the same LAN IP and a direct HTTP request **from Samsung** to `http://<QA_LAN_IP>:8080/actuator/health` returns200/UP. A no-touch UI snapshot saved19:51:36 still shows **“Dữ liệu chưa được cập nhật. Chưa thể hoàn tất thao tác. Vui lòng thử lại.”**, all three cached expenses/0 balances and **Add disabled** (`/tmp/wedo-r1-exec-expense-late-no-touch.log`). This is at least102s after restoration, not an immediate reassociation snapshot.

**Observed defect:** automatic Expense resynchronization was not observed within that >100s healthy-network window; cached data was not lost. Do not claim permanent failure, database corruption, an exact authentication cause, or a universal reconnect failure from this bounded result. No HTTP500 or unhandled exception was observed/captured for this case. No existing diagnostic access logs were reused as if they belonged to this pass.

**Most likely affected area:** ExpenseListController's realtime-resync/reload integration and/or its shared connection/subscription recovery path. Exact cause is **unconfirmed**, not investigated/fixed under this acceptance-only request. This is **newly observed on the final frozen candidate**, distinct from the earlier fixed cache-loss defect. Later Discussion/Poll/Task recovery success does not erase this scoped failure.

Finance test stopped after capture. Returning to underlying Group Info showed its Retry-only state; one explicit read-only Retry restored that separate navigation baseline for independent E/G tests. This later manual action is **not** counted as automatic Expense recovery. Settlement was not exercised; no financial dialog, payment, confirmation, retry transaction, status change or write was submitted.

### G — four actual cache/recovery subcases; response-order limit

Existing Activityc81b9fff, not inaccessible Capacity Lab. No statuses, assignments or votes changed.

- **Task Detail:** `Test Assign GOING Member1`, DONE, Member1 assignee and existing history all retained under offline banner. Wi-Fi off19:59:58.115/on20:00:00.759; a no-touch snapshot saved20:01:28 has the same actual data and no stale banner. Logs `/tmp/wedo-r1-exec-task-detail-{online,offline-recovery,late}.log`.
- **Task List:** four existing rows retained offline, later no-touch UI clean at20:04:04. Logs `/tmp/wedo-r1-exec-task-list-{before-offline,offline-recovery,late}.log`. No filter/status write.
- **Poll List:** existing `Chọn địa điểm`, percentages100/0 retained under offline feedback; restored20:04:56.775, clean UI confirmed20:05:04.010 without refresh. Logs `/tmp/wedo-r1-exec-poll-list-{online,offline-recovery}.log`.
- **Poll Detail:** actual options1/0 votes retained, restored20:06:10.781; clean confirmed20:06:22.969, no vote action. Logs `/tmp/wedo-r1-exec-poll-detail-{online,offline-recovery}.log`.

No controlled out-of-order API responses, dispose race or remote state mutation was introduced. Visible unchanged-data recovery is not a proof that an older response cannot overwrite a newer successful response. Prior focused tests remain separately scoped automated evidence, **not** a new physical PASS for that invariant. Hence the full G row remains CHƯA TEST pending the stronger race/peer-state observation.

### Logs, safety and remaining manual steps

`/tmp/wedo-r1-exec-safe-error-scan.log` is a bounded current-PID5558 scan of available logs from19:42 onward for unhandled/fatal/framework/disposed-state patterns, credential-bearing matches excluded. No observed iOS log audit or global zero-error guarantee. No product unit/widget/full suite/analyzer rerun. Existing31 backend/244 Flutter passes are historical evidence only.

For each CHƯA TEST, after reconnecting/unlocking QA iPhone on the same Mac LAN:

1. **A:** open labelled `P0 Poll replacement QA2026-10-22` in Demo Hoạt động Nhóm–WeDO on both; iPhone submit/change A→B while Samsung observes without refresh, then reverse sender/observer. Verify selected option/count/no duplicate/error, not just API status.
2. **B:** same QA chat, two decoded old images visible; send five uniquely labelled texts each direction. Observe old-image spinners/flicker/scroll and unique receipt; record old-image GETs separately from avatar/initial loads. Do not reuse prior task's results as this pass.
3. **C:** keep iPhone chat open, disable only its network, send new labelled Samsung message(s), restore iPhone network. Confirm automatic catch-up once and old-image stability; no manual Refresh/reopen.
4. **D:** first resolve legitimate Lab access with the Owner/user; Member1 is currently LEFT. Do not mutate DB/roles or silently reenroll to force PASS. Once an authorized fixture is agreed, both open PRE-M19 Capacity Lab; Samsung leave/rejoin, iPhone count/list updates and one participant row without refresh.
5. **G remaining invariant:** on an agreed safe QA resource, overlap an older read with a newer peer change/read during reconnect; observe latest list/detail stays current and is not replaced by the earlier result. The four basic Samsung offline/cache/recovery flows above do not need repetition absent a new candidate. If ordinary manual control cannot establish response order, keep that invariant pending rather than inventing evidence.
6. **H:** new labelled message from each physical phone, verify receipt on the other and no Login/Welcome/red screen. Samsung navigation-only observations are insufficient for two-way delivery.

Settlement and any iOS Finance parity remain pending after F's stop. Review the narrow Expense recovery finding before authorizing a retest/hotfix; **no new implementation is authorized by this report**. Do not reopen broad architecture work or mark R1 COMPLETE. Runtime left UP and every temporary Samsung Wi-Fi interruption restored in `finally`.

**R1 READY FOR ACCEPTANCE (this execution has an unresolved FAIL), R2 IN PROGRESS, R3–R9 NOT STARTED. Commit/Push/Merge/Reset/Restore/Stash/Clean: NO.**

### Reconnected iPhone follow-up — 21:02–21:12 local

After the user confirmed reconnection/unlock, QA iPhone was available (paired). One resumed existing USB-helper session reached `WEDO_USB_READY` at21:02:43; unlike the earlier attempt, an actual app hierarchy was obtained. Home displayed **“Không thể tải trang chủ.”** One read-only Home Retry showed loading, then the same error. This did not establish an online baseline, the visible Owner identity, or any new functional PASS. Do not infer an application/authentication defect without confirming iPhone LAN reachability.

- Evidence: `/tmp/wedo-ios-acceptance/run-210227301895.log`, `/tmp/wedo-r1-resume-iphone-screen.json`, `/tmp/wedo-r1-resume-iphone.png`, `/tmp/wedo-r1-resume-iphone-baseline-retry.json`, `/tmp/wedo-r1-resume-iphone-baseline-final.json`.
- Read-only Settings Wi-Fi inspection reached Wi-Fi labels, but the subsequent state query timed out. No confirmed current iPhone Wi-Fi switch, SSID or IP was obtained; no network/privacy setting was changed. At21:08:05.237 the runner reported **“Exiting due to IDE disconnection.”** Xcode internally attempted recovery, then the overall helper ended EXIT65. No further manual runner initialization. QA iPhone still appeared **available (paired)** afterward: this control-session failure is not the earlier device-unavailable state and is not evidence of a weDO crash.
- Restored weDO foreground with `devicectl` at21:11:56 after inspecting Settings. Successful launch is not a loaded-data or authenticated-Owner acceptance result. The helper/xcodebuild process ended; no automation session remains to retry implicitly.
- Local/LAN backend health UP and MinIO ready at21:11:55; Mac still<QA_LAN_IP>, Samsung<QA_LAN_IP>. Existing backend/media relay/data retained, no restart. Disk about4.39GiB; no cleanup. Production fingerprint remains `816c0ac8f5f9509fc26022795d212a514c8726516636f17a99ec550d430aed04`.
- No new votes, chat messages, RSVP, comments or financial writes; no source/build/signing/Firebase/Git mutation or second-iPhone operation. **Matrix unchanged:** E Samsung read-only PASS; F Expense FAIL from the earlier bounded observation, **not retested**; G four basic Samsung subcases PASS but full invariant pending; A/B/C/D/H CHƯA TEST. R1 NOT COMPLETE; R2 IN PROGRESS.

Before another paired attempt, the remaining manual connectivity preflight is: on QA iPhone open Safari `http://<QA_LAN_IP>:8080/actuator/health`, record JSON/UP versus the exact network error, then return to weDO and try Home Retry once. Safari reachability alone does not prove weDO Local Network permission, auth or functional acceptance. Do not request repeated USB reconnections or begin another implementation cycle from this unresolved precondition. The Expense blocker and the manual steps above remain separately pending.
