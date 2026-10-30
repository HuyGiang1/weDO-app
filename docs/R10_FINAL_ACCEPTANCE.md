# R10 final acceptance — 2026-10-29

## Decision and evidence rules

**R10 COMPLETE — 2026-10-29.** The existing roadmap Definition of Done is unchanged. Final user reply: “lịch sử/reconnect OK; smoke OK”. The current-device core journey, check-in, review, conversion, navigation/retry and reconnect/smoke gates are supported by the combined physical, focused automated and read-only/runtime evidence below. Historical pending notes later in this report are superseded by this closure decision; they remain as an audit trail. Automated regressions and successful builds do not establish physical acceptance. PASS below is limited to its stated scope; PENDING is neither a reproduced failure nor permission to reset fixtures. R1/R3/R4/R5/R6/R7 COMPLETE; R2 IN PROGRESS; R8/R9 NOT STARTED.

## Criterion matrix

| Criterion | Implementation | Automated evidence | Samsung physical | QA iPhone physical | Remaining gap | Decision |
|---|---|---|---|---|---|---|
| One Activity, multiple child Stops; correct detail association | Implemented | Journey PostgreSQL / Flutter | Open Activity and lunch Stop observed | User opened same Activity/Stop | None for detail association | PASS for navigation/association |
| Stop create/edit/order and peer convergence | Implemented | CRUD/stale/reorder/permission regressions | Held timeline automatically moves lunch first; no manual refresh | User edited notes and performed reorder | None for observed edit/reorder | PASS scoped |
| Status, early execution, completed-parent policy | Implemented | Lifecycle/early execution/terminal-parent regressions | Held timeline automatically changes lunch to IN_PROGRESS; detail agrees | User set active status | Terminal-parent negative backed by automated evidence; early-time policy not new physical claim | PASS scoped |
| Fresh Stop camera capture and persistent Check-in | Implemented | Persistence, client-request dedupe, source association | Correct Owner image/server timestamp on lunch Stop | User: “đã sửa; đã gửi check-in” | None for this capture/send/read | PASS scoped |
| Check-in peer live arrival | Implemented | Shared targeted realtime coverage | Held timeline count1→2, no refresh; new Owner photo08:33 opens correctly | User sends second photo | None for observed live count/photo | PASS |
| Correct fullscreen image and zoom | Implemented | Protected media/gallery coverage | Actual new Check-in image/fullscreen1of1 and double-tap zoom reviewed | Earlier paired image display accepted; no new explicit Check-in zoom claim | No separate QA iPhone zoom PASS invented | PASS criterion; platform scope explicit |
| Check-in history/reconnect/expired signed URL | Implemented | Runtime real expiry403→authorized reissue200 | Offline retains Stop/photo; automatic recovery without Retry | User final history/reconnect PASS for2Checkins | Forced-expiry injection in phone UI not performed | PASS combined evidence |
| Private Check-in access, server timestamp, no GPS claim, no Community API | Implemented | Scoped authorization/source regressions; prior routing fix | Author/time and explicit non-verification label observed | Prior affected media/send accepted | No physical cross-group negative claimed | PASS automated; physical negative untested |
| Task camera/preview/submission, correct private Task association | Implemented | Evidence persistence/permission/idempotency regressions | User captured/submitted twice in QA Task | User live peer image/fullscreen PASS | No extra upload required | PASS scoped |
| Review reject/resubmit/approve and canonical completion state | Implemented | Reviewer restriction/concurrency/single DONE history | User confirms automatic rejected/approved/DONE; actual UI/API corroborate | User rejected then approved new proof | None for observed cycle | PASS |
| Evidence realtime/fullscreen/history/URL recovery | Implemented | Runtime real expiry403→authorized reissue200 | Fullscreen/reopen/history/Wi-Fi automatic recovery PASS | Live arrival/fullscreen/history/reconnect PASS | Forced-expiry injection in phone UI not performed | PASS combined evidence |
| Poll → Task editable title and retained source | Implemented | Conversion/title/source regression | Canonical target independently read | User edited Task title/create/View Task list PASS | None for mandatory gate | PASS |
| Poll → Stop editable title and retained source | Implemented; title input/API completed this gate | New custom-title/source/idempotency PostgreSQL + Flutter tests | Canonical Stop/source independently read | User create/View correct; name field seen, deliberately left default | Physical custom-name edit not performed; covered automatically | PASS combined evidence |
| Explicit choice, canonical target, authorization, retry creates no duplicates | Implemented | Conversion/permission/idempotency regressions | Runtime old/new UUID replay returns same2targets;4links unchanged | User explicitly chose Đi suối and created both targets | No physical double-tap claimed | PASS automated/runtime; creation/navigation physical |
| Adjacent Chat old media, Chat Poll, RSVP, Moments, Home/Community | Implemented; accepted UI preserved | Existing affected regression evidence reused | New-candidate Home/Community actual RO navigation PASS; no extra full-app claim | User final smoke PASS for explicit listed checklist | Broader all-platform/negative matrix belongs to R9 | PASS scoped |

## New fixes and focused verification

Only four production files changed in this final gate: StopComposer spacing in `journey_screens.dart`; editable Stop title in `poll_action_screen.dart`; optional `stopTitle` in `ActionDtos.java`; Stop title use in `PollActionService.java`. The first fixes the user's reproduced touching coordinator/notes outlines, with 16px separation. The second fills the explicit DoD requirement for editable converted Stop titles; legacy requests still use option text, source option remains in notes/link, and retries return the existing target without renaming it. No schema, financial, Activity lifecycle, shared transport, Home or global theme change.

Red tests reproduced both gaps before correction. New focused run: **14 PostgreSQL tests PASS, 0 failure/error/skip; 50 Flutter tests PASS; analyzer clean**. Earlier 59 backend/360 Flutter and later 13 Journey/28 Journey+Task results are historical overlapping evidence, not an additive unique total. Logs: `/tmp/wedo-r10-final-{red,backend,flutter,analyze}.log`.

Backend package PASS, runtime restarted only because source changed. Android debug build PASS (11.4s), iOS Profile PASS (40.9s). After the user confirmed the completed review cycle, both new candidates were installed in place and launched successfully; sessions/data retained. Android APK SHA256 `7a8eaf52f912fe2492c2182cf4d17f32a18aafa5ad91c40ba27c37a6649a3771`; local signed Profile Runner SHA256 `711120d5e281ad3559c0f9cccbbda383df573e8d91e856b9e5954b4184c010b4`. QA iPhone install bundle `com.huygiang.wedo`, installation container `596D84F3-A23D-48AF-8A5F-2F6B06795A35`. Signing project hash unchanged `ad773f3c…`. Install/launch logs `/tmp/wedo-r10-final-new-{android,ios}-{install,launch}.log`. No debug-runner retry or signing change.

## Fixtures and runtime checkpoint

Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`; 259 dirty paths pre-existed this gate. Preserve prior edits and protected files/stash. Mac en0 `<QA_LAN_IP>`, Samsung `.110`, QA iPhone `.101` at recorded runtime check; backend/PostgreSQL/Redis/MinIO/media relay healthy. Disk 8.7 GiB on latest read. Runtime addresses must be detected again if network changes.

Use open Activity `990df43b-b1e6-4ecd-8f2d-1bac86becd32` (“R10 QA Lịch trình mở 28-10”), lunch Stop `d761f219-c76c-482f-a38f-33e556b81b2b`. New dedicated Task `472cffef-76a1-43a9-b236-a8862654007d` (“R10 FINAL QA Review”) assigned to existing GOING QA Member1, REQUIRE_REVIEW. Created through canonical API only; do not change other Tasks or force permissions. Old Activity `aac8e962-ae84-4f00-8d3d-8ab4ce05e516` is COMPLETED and intentionally remains locked.

Poll `679b6c38-cdd3-40b7-bfc1-a765043643e7` already has Task and Stop targets for its first option. Retrying that option must return old targets; use an unconverted option for a genuinely new editable-title acceptance. No fixture deletion or state reset.

## Device evidence and next actions

Samsung screenshots inspected: `/tmp/wedo-r10-final-checkin-samsung.png`, `...-fullscreen.png`, `...-zoom.png`. These prove the actual displayed Check-in and viewer, not live arrival/reconnect. User confirms QA iPhone edited and sent Check-in; reviewer screen is now open. Samsung camera was opened, then a system Gemini overlay appeared. User elected to capture/send manually, so agent Samsung taps are paused. Subsequent canonical GET execution returned HTTP 200, exactly one PENDING evidence record and Task TODO under REQUIRE_REVIEW; no premature completion. Reviewer was asked to confirm live arrival/fullscreen and reject with a QA reason. That intermediate checkpoint is superseded by the later physical review-cycle PASS below. Do not send anything through Gemini or infer its screen as weDO evidence.

1. Confirm successful Samsung submission and pending-review state without premature DONE; Owner observes peer arrival, opens correct private image, rejects with QA reason; Member observes rejection, resubmits; Owner approves and both show DONE/history.
2. Install built candidates in place after no unsent photo remains; preserve sessions and signing. Recheck only changed StopComposer/converted-title UI and necessary final-candidate paths.
3. Observe itinerary status/reorder live convergence, Check-in/evidence history through reconnect and signed media recovery.
4. Explicitly convert an unconverted Poll option to Task and Stop, inspect editable title/source, View destinations and duplicate-free retry. Run short adjacent smoke.
5. Close only after these exact mandatory gates are supported. No further broad audit, full-suite rerun or unrelated implementation.

Commit NO; push NO; merge NO. No business changes beyond the additive R10 Stop-title requirement; no QA data/volume reset.

### Task gate continuation

User QA iPhone reply: **“ảnh tự hiện; mở được; đã từ chối”**. This is scoped physical PASS for live arrival on the already-open reviewer screen, correct fullscreen image and first rejection. A subsequent independent execution GET shows first proof `e33c3401-64c0-4549-9248-3f4518b7b50f` REJECTED, second proof `aa846e90-c4e3-41e6-9786-38b9cfac9c92` APPROVED, reviewer QA Owner, both CAMERA_CLIENT_DECLARED, and Task DONE under REQUIRE_REVIEW. Actual review feedback is “Cần thử lại”; do not substitute the suggested test phrase as observed input. User was asked to confirm the intervening resubmission/approval and automatic Samsung completion; that physical confirmation is still pending. No further submission requested after DONE.

### Physical Task review and reconnect PASS

User confirms “thấy từ chối; đã gửi lại và đã duyệt” and “Đúng, đã gửi lại/duyệt và Samsung tự hoàn thành”. This closes the observed reject → resubmit → approve → Member automatic DONE gate. Read-only Samsung UI shows accepted and rejected evidence/history with QA Owner feedback; screenshot `/tmp/wedo-r10-final-task-reviewed.png` was inspected. After new in-place installation, actual Task list/detail/evidence shows Hoàn thành and retained approved proof. Agent disabled Wi-Fi on Samsung, observed explicit network error while valid DONE/evidence stayed visible, restored Wi-Fi, verified actual FPT Telecom connection/IP `.110`, then observed the error clear automatically without Retry. Screenshot `/tmp/wedo-r10-final-task-reconnected.png` inspected. This is scoped Samsung reopen/network recovery PASS; explicit expired-signed-URL failure/reissue and iPhone reconnect history remain unverified.

### Current-candidate form, conversion and access evidence

User QA iPhone confirms **“form OK; lịch sử còn”** for corrected coordinator/notes spacing and retained two Task proofs after in-place installation. User confirms Task/Stop creation and both View destinations (“Có nhé. rồi nhé”); canonical API corroborates one Task `26a4ee63-0c1f-49e1-ba44-f45384cd5ce5` titled **“R10 Final chuẩn bị đi suối”**, one Stop `8cd8a91a-b66c-4583-b2b8-6b9567c9bf4d` titled **“Đi suối”**, both sourced from the selected “Đi suối” option in Poll “R10 QA Chốt lịch trình 28-10” and parent open Activity. Source text is retained in Task description/Stop notes and durable links. User clarifies **“Có ô tên, tôi chưa sửa tên Stop”**: Stop field availability is physically confirmed; unchanged Stop title is expected, not a reproduced save defect. Edited Stop-title persistence is covered by the new PostgreSQL and Flutter regression, not a fabricated physical edited-title PASS.

Runtime API replay, for each TASK and STOP: original request UUID and a fresh UUID for the same option/type/Activity both return the existing canonical target; conversion link count remains4. This is API idempotency evidence, not an invented physical double-tap. Read-only QA Member2 outside the group receives404 for Task execution, Stop detail/checkins and both evidence media access endpoints. No membership/role changes were made.

Samsung new candidate reopens reviewed proof fullscreen correctly (`/tmp/wedo-r10-final-task-fullscreen.png`, inspected). User now asked to move lunch Stop to first position, mark IN_PROGRESS and send an additional QA Check-in while Samsung remains on the timeline (baseline2/5 completed, lunch PLANNED/1checkin). Await observation before claiming reorder/status/checkin live convergence.

### Journey / Check-in convergence and protected expiry

Samsung remained on the timeline without manual refresh while Owner operated QA iPhone. Before: lunch third, PLANNED,1checkin. After: lunch first, IN_PROGRESS,2checkins and active summary banner; other completed Stops remain completed. Stop detail agrees and still links completed QA Review Task. New Owner photo/server time29/10 08:33 displayed correctly and opens fullscreen1/1; `/tmp/wedo-r10-final-checkin-new-fullscreen.png` inspected. This now supports actual live timeline convergence, not just a later API read.

Samsung Check-in detail kept valid data while Wi-Fi was disabled and displayed an offline notice. After actual FPT reconnection/IP `.110`, notice cleared without Retry and the correct Stop/photo remained. Task and Check-in private signed URLs each independently returned200 initially,403 after their real60second expiry, then200 after authorized access-API reissue. No clock/TTL/auth weakening, relay manipulation or public sharing. This is **runtime HTTP expiry/reissue evidence**, not a fabricated forced-expiry phone UI test. Two signed-URL diagnostic JSON files created solely for this check were removed afterwards; no repo/QA/media/cache deletion.

Await only the current QA iPhone reopen/reconnect and adjacent short-smoke checklist before the final unchanged-DoD decision. Physical custom Stop-title edit and physical unauthorized-user negatives are not newly claimed; custom-title persistence/security are backed by focused PostgreSQL/Flutter and scoped runtime evidence.

## Final unchanged-DoD decision

User final physical confirmation on current QA iPhone candidate: **“lịch sử/reconnect OK; smoke OK”**, answering Wi-Fi off/on + reopen same Stop/Task with2Checkins/2proofs, followed by Home, Community, Chat old images/Poll, RSVP list and Moments/Album. Samsung separately demonstrates timeline order/status/checkin-count convergence while held open, fresh correct image/fullscreen/zoom, Task review convergence, reopen and automatic Wi-Fi recovery. Samsung final-candidate Home and Community read-only screens load as observed. No full-app or all-platform physical matrix is inferred.

The unchanged DoD is met by durable PostgreSQL contracts/V19-V20, AFTER_COMMIT authorized shared transport, focused role/privacy/stale/disposal/idempotency regressions; real paired Journey/Check-in/Task review/Poll conversion and navigation; runtime duplicate-free retry and real signed-URL expiry/reissue; and the scoped final reconnect/adjacent smoke. No newly reproduced critical R10 defect remains. **R10 COMPLETE.**

Explicit limits retained for R9: no newly performed physical unauthorized-member/role-loss or competing-review race; no physical phone forced-expiry injection; Owner left converted Stop title at default, so custom-title persistence has automated rather than new physical evidence. These are not untested mandatory functional criteria: corresponding behavior has focused backend/Flutter/runtime evidence and core physical flows above. No DoD wording was removed or changed, and no whole-project completion is claimed. R2 IN PROGRESS; R8/R9 NOT STARTED. Do not implement another milestone or repeat these accepted tests without a new user request/reproduced defect.

Final read-only verification: disk8.8GiB; installed Samsung base.apk SHA256 independently matches final7a8eaf52f9…artifact. Documentation consistency/changed-path whitespace checksPASS. Backend and Docker runtime left running, Samsung Wi-Fi restored; no subsequent source/build/test cycle started.
