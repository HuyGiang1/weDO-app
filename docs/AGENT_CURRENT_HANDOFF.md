# weDO — Agent Current Handoff (`docs/AGENT_CURRENT_HANDOFF.md`)

> **Live Handoff Document** — Update this file whenever milestone status, corrective passes, verification counts, or next actions change.

## Current Pre-M19 Acceptance Candidate Transfer (2026-10-17)

- User explicitly approved one candidate commit and feature-only push on `feat/pre-m19-ui-polish`, based on `a3810701b747520cae25c8f3a0706c3296703c76`, with subject `feat(ui): polish mobile experience for pre-m19 acceptance`. No dev merge/push is authorized. This snapshot accompanies that candidate commit; recover its SHA with `git log -1` and verify the remote feature ref before continuing on macOS.
- Pre-commit live classification: 54 intended paths (50 tracked modified plus four new UI/audit/test files), three protected untracked files, no unexpected paths, index initially empty, diff check clean. Local and remote dev both remain at the base; remote feature did not exist at preflight. Protected stash OID `f6d2c8029dd5a9a2549bead7d67a61d29e0cab1a` intact.
- Existing verified source result reused, without rerunning unchanged suites: full Flutter 725 passed / 0 failed, analyze clean, debug APK and bounded Samsung agent regression PASS. UI-01..14 resolved; remaining known audit P0/P1/P2/P3 = 0/0/0/0. Evidence and fixture limitations remain in the Batch 3 snapshot and `docs/PRE_M19_UI_UX_AUDIT.md`.
- This is an ACCEPTANCE CANDIDATE, not final user acceptance. USER PHYSICAL ACCEPTANCE: PENDING. macOS/iPhone and Samsung+iPhone two-device acceptance: PENDING. M19: NOT STARTED. Next: fetch/check out the feature branch on Mac, configure local platform services/credentials outside Git, and perform personal UI/two-device acceptance and teacher-demo preparation. No deployment or dev merge approval is implied.
- Exclude and preserve `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `mobile/android/app/google-services.json`, ignored design/runtime/log/build files and protected stash. Windows-only local files are not transferred by this commit. No post-commit handoff-only commit is needed; verify actual Git refs rather than inserting the candidate's own SHA here.

## Historical Pre-M19 Final UI Batch 3 (2026-10-14)

- Same branch `feat/pre-m19-ui-polish`, unchanged HEAD/base `a3810701b747520cae25c8f3a0706c3296703c76`. Audit and Batches 1/2/3 COMPLETE; M18 CLOSED; M19 NOT STARTED. USER PHYSICAL ACCEPTANCE: PENDING. No staging/commit/push authorization.
- UI-04 audited Login/Profile/Calendar/Group administration/admission/reminder/root-tab copy now Vietnamese, including SDK Material date/time localization. UI-05 shared role/status/privacy display mappings preserve all wire values. UI-06 owner name/avatar resolves existing members by authoritative `ownerUserId`, independently of caller role, with honest unavailable fallback. UI-14 retains only the Activity create FAB, including empty lists; its create navigation remains intact.
- Narrow sweeps fixed three Chat attachment notices and five Notification fallback literals with mojibake; existing public-profile fix retained. Existing JoinRequest/Ban identity/avatar DTO fields are now decoded rather than showing IDs or fabricated Admin identity. No backend/API/migration changes. No new authorization logic or feature scope.
- Physical cross-screen sanity exposed lost Search context after Chat -> Group -> Groups. Home/Groups root routes now recover missing Search args from the application's configured args while preserving explicit args/repositories. Added navigation regression; Samsung confirms Search remains available and opens after that path.
- Final affected-feature focused suite: 242 passed, 0 failed, exit 0; final route/Chat navigation focused: 61 passed, 0 failed, exit 0. Final complete Flutter: **725 passed, 0 failed**, final `All tests passed!` at 01:08, exit 0. Analyze: **No issues found**, exit 0 (9.7s). Final loopback debug APK built in 18.8s, exit 0, `mobile/build/app/outputs/flutter-apk/app-debug.apk`, installed successfully and auto-launched on R58M36JQYVY. Backend tests not rerun because backend unchanged. Existing firebase_core KGP future-compatibility build warning is nonblocking; no dependency upgrade attempted.
- Samsung: all UI-01..14 revisited in this bounded continuation, five root tabs/back and sampled Invitations/Discussion/Search/Poll/Notifications/public Profile/Login. Groups/Search/Notifications and owner/Profile/Privacy/Calendar checked at 1.1/1.5. Owner's real QA Owner name/orange avatar, localized roles/policies/status, Vietnamese date picker and single Activity create navigation verified. Login empty errors clear on valid input; Owner login restored. Poll disabled/selected contrast checked after animation settles, no vote sent. Chat still opens latest image-heavy history. JoinRequests/Bans empty states checked physically; populated identities/fallbacks covered by widget fixtures, not fabricated device data. No financial, membership or lifecycle writes; drafts cancelled, inbox read state may change through normal taps. No fresh multi-account/push acceptance claimed.
- Final PID 21392 bounded logcat: 979 lines; Flutter fatal 0, unhandled 0, Android crash 0, overflow 0, Material/widget assertions 0. Same Firebase registration-unavailable environment diagnostic remains. Host-only evidence `C:/Users/truon/AppData/Local/Temp/wedo-pre-m19-batch3/`; audited final evidence mapping and limits in `docs/PRE_M19_UI_UX_AUDIT.md` (some intermediate captures are not acceptance evidence).
- Remaining known audit P0/P1/P2/P3: **0/0/0/0**. READY FOR USER ACCEPTANCE: YES, not USER ACCEPTED. Candidate remains installed; runner exited and `scripts/dev-stop.cmd -StopInfra` stopped backend/PostgreSQL/Redis/AIStor with volumes retained. Device font restored 1.1; temporary USB keep-awake disabled. Start `scripts/dev-run.cmd` for user testing.
- Git classification A: 50 tracked modified UI/docs/test/dependency files plus four intended new files (audit, display mapping, display-mapping test, existing Pre-M19 group widget fixture); B: three protected untracked handbook/Stitch inventory/google-services.json plus ignored design/runtime paths; C: none. Index empty; diff check clean. Protected stash remains `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`, OID `f6d2c8029dd5a9a2549bead7d67a61d29e0cab1a`. No commit/push/merge/rebase or destructive Git operation.
- Next: user personally tests root tabs/back; Groups owner/roles, members/invitations/join/bans; Calendar filters/date picker/reminders; Discussion reply menus; Chat open/reopen/history/keyboard; Search categories -> destinations -> return; Poll select/unselect; Notifications; Profile/Privacy/public message label; Login validation. Obtain separate approval before staging/commit; do not start M19.

## Historical Pre-M19 UI Fix Batch 1+2 (2026-10-13)

- User authorized all P1 plus selected P2 from the audit. Same live branch `feat/pre-m19-ui-polish`, unchanged HEAD/base `a3810701b747520cae25c8f3a0706c3296703c76`; M18 CLOSED, M19 NOT STARTED. No staging/commit/push authorization.
- Implemented and physically checked UI-01 Groups responsive header; UI-02 own reply projected edit/delete menus and one-level reply rule; UI-03 existing invitation name/avatar/inviter projection decoding; UI-07 bottom-anchored Chat; UI-08 compact accessible notification action; UI-09 full wrapping Search labels; UI-10 enabled Poll contrast; UI-11 Login revalidation; UI-12 invite-link ExpansionTile Material; UI-13 public Profile Vietnamese message literal. No backend/API/migration changes.
- Final verification: final affected-feature focused 209 passed after Chat adjustment/test formatting; final Chat 38 passed; final full Flutter 714 passed, 0 failed (command exited 0); analyze clean; fresh loopback debug APK built (20.6s), installed and auto-launched. Test-only formatting afterward is mechanical; unrelated formatter churn in the Groups model test removed while retaining its six projection assertions/fixture lines. Backend suites not rerun because backend unchanged.
- Samsung R58M36JQYVY: all fixed issues exercised, all five root tabs/back, 1.1/1.5 Groups/Search, long QA Discussion reply menu/edit-save-unchanged/delete-cancel/parent reply composer, five human-readable invitations, Poll selected/disabled contrast, Notifications, public Profile and Login. Initial estimated-extent Chat approach failed image-heavy physical acceptance and was replaced by a small `reverse: true`/index/send-offset correction; final open/reopen shows newest M18_RECOVER_1013_3, real images, older history and keyboard work. REST transport interruption/recovery sanity passed; no fresh two-account catch-up/push claim. Pagination with 120 variable-height messages verified automatically; device fixture had no older-page button.
- Bounded final PID 16651 logcat: 292 lines, fatal/unhandled/overflow/Material matches all 0; exercised invite-link expansion runner also had 0 Material/Flutter diagnostics. Known Firebase registration-unavailable environment diagnostic remains; no new cloud acceptance. No new P0/P1 observed. Remaining P2 UI-04/05/06 (3), P3 UI-14 (1), intentionally deferred.
- Audit history preserved and result sections appended to `docs/PRE_M19_UI_UX_AUDIT.md`. Host-only after captures `C:/Users/truon/AppData/Local/Temp/wedo-pre-m19-fixes/` 01-40, final Chat 37/39. Existing QA reply saved unchanged, deletion cancelled, drafts discarded; no financial/membership/lifecycle mutation. Font restored 1.1, keep-awake off; runners exited and stop script stopped backend/infra with volumes preserved. Candidate remains installed; use `scripts/dev-run.cmd` for user testing.
- Intended files: ten Flutter implementation + seven tests (new `pre_m19_group_polish_test.dart`) + audit/current handoff. No unexpected changes, nothing staged. Protected local docs/google-services.json remain untracked; `.stitch/` not edited; runtime files only managed by runner. Protected stash `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`, OID `f6d2c8029dd5a9a2549bead7d67a61d29e0cab1a`, intact.
- USER TEST CANDIDATE: YES. Next: user visual acceptance on Groups/invitations/Discussion/Chat/Search/Poll/Notifications/public Profile/Login/invite links and root navigation. Do not start M19, broad copy redesign, or stage/commit/push before separate user approval.

## Historical Pre-M19 UI Audit (2026-10-13)

- M18 feature `3cb4c332dd3f09df78d6e6b097778f729bf88b55` merged and pushed to dev as `a3810701b747520cae25c8f3a0706c3296703c76`; M18 CLOSED. Live branch now `feat/pre-m19-ui-polish`, created from that verified local/remote dev baseline. M19 NOT STARTED.
- User unlocked Samsung; resumed the same audit/worktree. Pass 1 reachable-surface inventory COMPLETE: 61 explicitly counted screen/sheet/interaction surfaces (not 61 routes), 120 temporary screenshots; P0 0, P1 3, P2 10, P3 1. See `docs/PRE_M19_UI_UX_AUDIT.md` for reproduction, evidence, source locations, limits and three proposed fix batches. No application code changed; no staging, commit, push, deployment or M19 work.
- P1: Groups header breaks words at font scale 1.5; own Discussion replies lack edit/delete controls; invitations show group/inviter UUIDs instead of human identities. P2: mixed language/raw enums, placeholder group owner, Chat opens old history, Notification header compression, truncated selected Search labels, Poll enabled foreground contrast, stale Login validation, decorated ListTile feedback diagnostic, corrupted public Profile message copy. P3: duplicate Activity create affordances. These are an inventory, not permission to implement fixes.
- Samsung R58M36JQYVY / SM_G975U1 authorized and unlocked; current loopback debug APK rebuilt/installed/auto-launched by repository runner. Backend health UP during audit; retained PostgreSQL/Redis/AIStor data; reverse only 8080/9000. All five canonical Home sections and root tabs reviewed; Search's four destination types, existing Finance media/decimal values and pending/completed Settlement history reviewed. Font 1.1 -> 1.5 stress -> restored/reverified 1.1; USB keep-awake disabled. No secret/license contents read.
- Limits: primarily QA Owner session; separate admin/member/removed/banned UI, read-only Discussion lifecycle variants, future reminders/FCM, live Chat reconnect/new uploads, Finance mutation/forms and unavailable fixture states were not re-accepted. No full suites rerun for this documentation-only pass. Final bounded PID 9388 logcat: 1270 lines, zero fatal/unhandled/RenderFlex matches; separate Flutter runner emitted the documented ListTile decoration warning, so do not claim zero framework warnings. Known Firebase registration-unavailable startup diagnostic remains outside cloud-push acceptance.
- QA data: one parent comment and one nested reply posted through Flutter under `M15_Device_Reminder_QA_20260929`, prefixes `UI_AUDIT_20261013` / `UI_AUDIT_REPLY`; retained as visual evidence. No financial/membership/lifecycle mutations; unsaved drafts discarded. Screenshots stay outside Git at `C:/Users/truon/AppData/Local/Temp/wedo-pre-m19-audit/`.
- Cleanup: audit Flutter runner exited normally; repository stop script stopped backend and PostgreSQL/Redis/AIStor, final zero 8080 listeners/no running containers, volumes preserved. No manual protected runtime/design file edits. HEAD/base unchanged; index empty; protected stash OID `f6d2c8029dd5a9a2549bead7d67a61d29e0cab1a` intact. Protected handbook, Stitch inventory and google-services.json remain untracked.
- Next: user reviews/approves the three-batch plan; begin with UI-01/02/03 only after implementation authorization. Preserve current audit/handoff work and all local-only/stash state. Do not restart M18 or begin deployment.

## Historical M18 Pass 4 Continuation (2026-10-13)

- Live Windows workspace `D:/weDO-app`, branch `feat/m18-hardening`, unchanged HEAD/base `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9`; this tool session is not a Mac workspace despite the recovery brief. Existing Pass 1-4 worktree intact and preserved; nothing staged, committed or pushed. Pass 1 Security, Pass 2 Concurrency, Pass 3 Performance and Pass 4 Reliability COMPLETE, including required visible Samsung acceptance. M18 ready for commit review only.
- Root fix: `PostCommitDelivery` runs general inbox/realtime after commit on 2 named workers / bounded queue 256; separate 2-worker push queue 256. No caller-runs rejection, Hikari increase or outbox. Keep REQUIRES_NEW inbox/policy/metadata transactions and PostgreSQL advisory-lock duplicate prevention. Reminder inbox/sent_at remains atomic; only push deferred. General inbox creation is eventual/best effort before insertion; queued work/rejection/process crash can lose attempts. Persisted inbox survives provider failures. See `DEC-M18-03` and `docs/M18_PASS4_RELIABILITY_AUDIT.md`.
- Backend affected verification 137/0/0/0, including twenty concurrent Chat sends and twenty inbox rows with the normal pool. Caller-thread diagnostic 27 statements / 3 acquisitions / peak 2 held -> 14 / 1 / 1. Pass 3 budgets retained: Chat 3/3, inbox 5/5, mixed 12/12, Home 14/15. Definitive full backend **642 run, 0 failures, 0 errors, 1 skipped**; compile PASS; fresh PostgreSQL 17/Testcontainers + V0-V12 PASS. Optional live OTP resolver skip is intentional. Backend production files unchanged after final verification (timestamp/source inspection); reused result for Flutter-only continuation.
- Flutter Chat reconnect walks existing bounded backwards REST pages to pre-reconnect durable sequence, merges by ID and sorts by sequence; 104 missed messages plus duplicate realtime overlap test passes. Samsung initially found an uncaught Firebase token failure preventing UI launch. Reviewed/narrowed final fix to expected Firebase/platform/time-out exceptions only and added initialization fallback in `main`; unexpected programming errors remain visible. Token-refresh registration and cold-start taps still work; no retry storm/logged secrets. Focused continuation **43 passed**, including **15 NotificationPush** tests; full **704 passed, 0 failed**; final analyze clean. Fresh debug APK PASS at `mobile/build/app/outputs/flutter-apk/app-debug.apk` with loopback API define. Test-only missing brace corrected after full run; no behavior changed.
- Samsung `R58M36JQYVY` / `SM_G975U1` authorized. Repository runner started existing dependencies and fresh backend, health UP, reverse only 8080/9000, installed/auto-launched verified current APK. After user unlock, cold launch despite Firebase failure, authenticated session restore after force-stop, five Home sections and all five tabs PASS. Ordinary UI Chat send sequence 20 persisted/reopened. App/API reverse interruption plus Redis stopped: second QA account persisted sequences 21-23 and REST returned them. After recovery/relaunch, preview and all four messages rendered in order; refresh left each marker visible exactly once. This physical reopen recovery is distinct from the automated 104-message live reconnect test. No runtime Pub/Sub failure warning captured in the short outage; injected Redis/socket failures separately pass.
- Final bounded app logcat: 228 lines, zero fatal/unhandled/Flutter/AndroidRuntime/overflow/reconnect/socket/refused matches; expected registration-unavailable/native FirebaseInstallations diagnostics remain. FCM cloud/background/tap acceptance ENVIRONMENT FAILURE / NOT EXERCISED as permitted by the latest brief, not a fake pass. Runtime stopped through repository script; Compose cleanup needed the existing process-scoped external license path. Backend stopped, no 8080 listener, PostgreSQL/Redis/AIStor stopped, no volume reset. M19 NOT STARTED. Next: user review of audit/diff and separate commit approval; no implementation, stage, commit or push authorization.
- Preserve handbook, Stitch inventory, google-services.json, .stitch and protected `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. Runner-managed logs/state only were used for the explicitly authorized local runtime; do not manually rewrite protected runtime files. No Firebase Admin JSON or license contents were read. Final path classification: 48 intended M18 files (37 modified tracked + 11 new), 3 protected untracked files, 0 unexpected paths; nothing staged. No remaining demonstrated P0/P1. P2 and accepted durability/deployment boundaries are in the final reliability audit.

## Historical M18 Pass 3 Closeout (2026-10-11)

- Branch `feat/m18-hardening`, unchanged HEAD/base `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9`. Pass 1 security and Pass 2 concurrency are closed for their authorized gates; all existing unstaged work was preserved. No stage, commit, push, merge, destructive Git command, stash operation, Flutter change, or migration occurred in Pass 3.
- Measurement: new test-only JDBC statement/connection counter, real fresh PostgreSQL 17/Testcontainers with V0-V12, bound actual read SQL replayed through EXPLAIN ANALYZE/BUFFERS. Synthetic initial fixture: 2,000 messages, 300 notifications, 1,500 Activities/participants, 300 expenses/shares, 30 Fund collections; growth adds 19 groups/1,900 irrelevant Activities, nine notification target classes, 100 settlements/history entries and 330 backed Fund ledger rows. No credential/device fixtures or printed SQL binds. See `docs/M18_PASS3_PERFORMANCE_AUDIT.md` for inventory, counts, plans, index decisions and residual bounds.
- Measured optimizations: Chat steady-state list 1/20 group conversations **8/122 -> 3/3 statements** (existing projection plus missing-only materialization and set-based sequence repair); Notification Activity inbox 1/30 records **5/63 -> 5/5** (page-local batched authorization/target facts), mixed nine classes 9/18 records **12/12**; Fund 30 collection summaries **126 -> 10** (batched children/reversals and deduplicated users with unchanged amount/status calculator); Settlement list 100 records/history **404 -> 6** (batched users/history with list/detail parity); Calendar replaces a global 1,500-row participant aggregate with 29 selected-Activity indexed probes, still one SQL statement and identical overlap/filter/count results. No new index, cached financial balance, error policy, API pagination, or reliability implementation.
- Home total on initial data **72 -> 14 statements**; twenty groups **15**, including an extra page count once recent-group page is full, not per-group ledger work. Standalone component counts: Recent Groups 2, Upcoming 1, Finance 3, Actions 4, inbox/Recent Updates 5 (shared ORM context avoids a duplicate user read inside Home). Finance is still 3 at twenty groups. Chat history remains 10 at page size 1 or 30, indexed/batched already. Expense list 300 rows remains 4; Fund ledger 330 rows uses 7 with one distinct creator. Unpaged canonical list APIs remain explicitly documented; no arbitrary truncation introduced.
- Final stable affected combined command completed with exit 0: **78 run, 0 failures, 0 errors, 0 skipped**. Suites: performance 1, Chat REST/service 14, Chat realtime 5, Notification 10, Home 6, Calendar/reminder 6, Fund 16, Expense/balance 14, Settlement 6. Query-growth, distinct-target, mixed-route/stale-state, revocation, DM unread/peer/request/archive, and Settlement list/detail parity assertions pass. Intermediate diagnostic failures were fixture UTC/payment-time omissions and a new collection-code qualification error, fixed before this authoritative result; they are not unresolved product regressions.
- Production files touched in Pass 3: `ChatService.java`, `NotificationService.java`, `CalendarRepository.java`, `FundService.java`, `ExpenseService.java`. Tests: new `ReadPerformanceIntegrationTest.java`, one list-projection regression in existing `ChatServiceIntegrationTest.java`. Financial mutation boundaries/locking were not changed. No full backend rerun: prior Pass 1 629/0/0/1 remains historical, current affected suites pass; definitive full verification is Pass 4. No Flutter source/test changed here, so no analyze/full Flutter/APK/device rerun.
- Pass 4 evidence: one Chat send/one recipient/no devices executes **27 statements, 3 connection acquisitions, peak 2 concurrently held**, on caller thread with synchronous AFTER_COMMIT + REQUIRES_NEW work. The normal ten-connection pool starvation found in Pass 2 remains unfixed; no production pool increase. Next authorized reliability pass must fix/fault-test this, reconnect/REST catch-up, duplicate/replay handling, Redis outage/degradation, FCM failures, and notification failure not rolling back business commits; then full backend, Flutter/analyze/APK, and Samsung acceptance.
- Protected handbook, Stitch inventory and `google-services.json` remain untracked/untouched; `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**` and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync` untouched. All work remains unstaged. Pass 3 is ready for review, not permission to commit or begin Pass 4 automatically.

## Historical M18 Pass 1 Closeout + Pass 2 (2026-10-11)

- Live branch remains `feat/m18-hardening`, HEAD/base `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9`. All prior Pass 1 edits were preserved. No staging, commit, push, merge, reset, stash operation, or migration occurred.
- Pass 1 security closeout: supported Flutter WebSocket uses the Authorization header; no supported production query-token dependency was found. Removed the backend query-token fallback, updated the canonical API and security audit, and appended `DEC-M18-02`. Real handshake regression proves bearer success and missing/invalid bearer plus valid query-only/token-like query 401 rejection; that test disables framework web DEBUG logging to avoid query credential logging.
- Flutter Fund/Finance compatibility: new narrow Fund decimal-string parsing/rendering test plus existing Fund screen and Expense model tests: **9 passed**. Exact minor-unit parsing covers `0.00`, `60000.00`, `1234567.89`; `flutter analyze`: **No issues found**. No Flutter production source changed in this continuation; prior Pass 1 Chat header change remains intact. No full Flutter/device suite required for these test-only additions.
- Pass 2 added persisted-state contention assertions for final RSVP capacity/row uniqueness, concurrent two-slot FIFO promotion and duplicate leave, twenty durable Chat sequences, Fund obligation over-reservation, expense-versus-reimbursement spending/rollback, reimbursement approve/cancel, and Settlement participant/confirm/cancel races. Existing duplicate confirmation/reversal tests remain. Current authoritative combined PostgreSQL run exited 0: **88 tests, 0 failures, 0 errors, 0 skipped**, including **13 concurrency-focused tests**. Suite counts: Activity 4, Chat service 13, Fund 16, Settlement 6, Chat realtime 5, Security 44.
- Concrete deferred reliability finding: the initial combined run had 88 tests, 0 failures, 1 timeout error because twenty Chat workers saturated the default ten-connection pool; synchronous AFTER_COMMIT notification REQUIRES_NEW work needs another connection before outer cleanup. The Chat test class now uses 21 connections, and its focused twenty-send rerun plus final combined rerun passed. This proves message sequence correctness with sufficient connection capacity, NOT a production starvation fix. Pass 4 must address/fault-test saturated-pool notification delivery; swallowed delivery failures remain a risk. Do not lose this finding or claim default-pool high-load reliability passed.
- No capacity/ledger/Settlement race invariant failed and no financial production lock or shared primitive was changed. The only production source change this continuation is `ChatWebSocketHandshakeInterceptor.java` query fallback removal. See `docs/M18_PASS2_CONCURRENCY_AUDIT.md` for transaction boundaries, lock-order deviation without demonstrated cycle, persisted assertions, and deferred observations.
- Prior full backend remains the Pass 1 **629 run, 0 failures, 0 errors, 1 skipped** result before the query-fallback removal; the current affected security/concurrency suites passed. Do not rerun the full suite until M18 Pass 4 unless a broad shared change warrants it. Pass 3 next: measure Chat/Notification/Calendar/Finance query counts/plans and bounds; no speculative index/migration. Pass 4: pool starvation, reconnect/catch-up/dedup, Redis outage, FCM/after-commit failure isolation, then full regression.
- Preserve untracked local handbook, Stitch inventory, `google-services.json`, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and protected `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. Nothing staged; no commit/push authorization. M18 remains a coherent uncommitted branch; do not seek a Pass 1-only commit or start performance/reliability implementation without the next pass instruction.

## Historical M18 Pass 1 Snapshot (2026-10-11)

- Branch `feat/m18-hardening` was created from the exact pushed `dev` / `origin/dev` baseline `d05aac0190897381a9c0eeeb8992c7c9ed21a4c9` after M17 closed. The post-M17 handoff-only edit was saved outside the repository, then the exact file was restored under the user's narrow authorization before branching. No stage, commit, push, merge, or migration occurred.
- Pass 1 audited the protected Auth/Profile, Social, Group, Activity, Poll, Task, Discussion, Chat, Expense, Settlement, Fund, Notification, Calendar/Reminder, Media, Search, and Home surfaces. See `docs/M18_PASS1_SECURITY_AUDIT.md` for the compact server-side matrix and Pass 2-4 boundaries. Proven changes: nested Fund collection parent-ID check, legacy public media avatar-only read, active-account enforcement on personal Notification operations, removal of raw local verification email/code logging, and exclusion of Spring Security's unused generated-password default user.
- The deferred Fund baseline assertion was a production DTO serialization mismatch. Fund response `BigDecimal` fields now use decimal JSON strings consistently with Expense/Balance; request values and schema are unchanged. API blueprint and `DEC-M18-01` record the contract.
- Focused Docker-backed security/Fund/media tests: 156 run, 0 failures, 0 errors, 0 skipped. A further `SecurityConfigTest` run after the startup password-log fix passed. Final full backend `mvnw.cmd test`: **629 run, 0 failures, 0 errors, 1 skipped**, with Docker/Testcontainers PostgreSQL and Flyway through V12. Docker Desktop initially lacked an engine; restarting it outside the sandbox recovered the engine. Flutter Chat subsequently dropped the redundant JWT query parameter while retaining the already-supported bearer handshake header; focused Chat realtime tests: 2 passed, `flutter analyze`: no issues. Full Flutter/device regression was not run; no UI or server auth/error contract changed, and the local backend stack was down.
- Local manual signup verification no longer exposes one-time codes in logs; the seeded QA accounts remain the documented local testing path until a private email delivery mechanism is configured. The known stateless access-JWT residual window after remote logout remains an accepted architecture boundary, not a newly introduced blacklist.
- Preserve untracked `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `mobile/android/app/google-services.json`, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. Next: review the unstaged M18 Pass 1 security diff; seek separate commit approval. Then plan Pass 2 concurrency without starting performance or reliability implementation prematurely.

## Current M17 Pass 2 (2026-10-05)

- Branch `feat/m17-home-product-completion` is based on `fde49ba0880bba2e39a7b2ec5b4e5f32aec3184c`. M17 passed closeout and was approved for a feature commit; inspect live HEAD and worktree for the current commit state. No push, merge, migration, or stash operation was approved.
- Home now returns and renders all five canonical sections: Recent Groups, Upcoming Activities, Finance Summary, Actions Required, and Recent Updates. Updates reuse recipient-scoped persisted Notification inbox records, current target actionability, and the existing Notification router; scan newest 30 and display up to five. See `DEC-M17-02`.
- `GET /api/v1/me/actions-required` reuses Home's exact action query; `GET /api/v1/groups/recent` reuses Home's existing active-membership Group Service projection. The global tab order is exactly Home / Groups / Chat / Calendar / Profile. Each tab opens its real root, including Profile; Group Info's Groups tab opens the list, not the current detail. Authenticated login and session restore land on Home. Search's four existing destination mappings remain intact; some noncanonical legacy paths may still lose Search UI context, which is state-restoration polish rather than a wrong destination.
- Focused backend `HomeControllerIntegrationTest`: 6 run, 0 failures/errors/skips, PostgreSQL/Testcontainers active. Full backend: 624 run, 1 failure, 0 errors, 1 skipped. The only failure remains the pre-existing `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` at line 596 (exact JSON decimal-string assertion); do not change the unrelated `FundDtos.java` status-only marker. Focused Flutter Home/routes/Chat/Calendar: 67 passed. Full Flutter: 698 passed, 0 failed. `flutter analyze`: no issues found. Fresh debug APK built at `mobile/build/app/outputs/flutter-apk/app-debug.apk` with local API define.
- Samsung `R58M36JQYVY` (`SM_G975U1`) was authorized. `scripts/dev-run.cmd` started the local services, installed/launched the current M17 build, and the QA login landed on Home. All five Home sections rendered; no upcoming Activity was available. Recent Group opened its Group Info, an available action opened its Poll detail, and a Recent Update opened its exact Group Chat via the existing notification target flow. Home / Groups / Chat / Calendar / Profile each opened its real root and the selected tab matched. Force-stop/relaunch restored the authenticated Home session. Back from Chat returned to Home; Chat remained usable. Backend health was UP, MinIO readiness returned 200, ADB reverse 8080/9000 was active, and the checked logcat window showed no Flutter exception, fatal crash, or overflow. The runner/backend and Docker services were stopped after testing.
- FundDtos on-disk `CollectionSummaryResponse` has each component once and matches HEAD; both semantic diffs are empty. `.\mvnw.cmd -DskipTests compile` completed BUILD SUCCESS. No FundDtos file action was needed; VS Code's open buffer/Problems view is not accessible here, so whether its stale diagnostic cleared could not be observed. Do not save a stale editor buffer.
- Product gap re-audit: Recent Updates, HOME-02, GROUP-03, canonical Groups root, Profile/main-tab consistency, and canonical Search destinations are closed. No new P0 or P1 found in the M17 implementation audit. Upcoming Activity navigation was not exercised because QA data had no upcoming items. P2: legacy Search-context state retention on some entry paths can be reviewed in M18 if it causes real user friction. M18 retains security/logging/performance hardening; M19 retains deployment/demo/signing readiness. M17 was approved for a feature commit; feature push approval is the next gate. The known unrelated Fund baseline and inaccessible VS Code Problems state remain recorded.
- Preserve pre-existing `FundDtos.java` marker, untracked `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `mobile/android/app/google-services.json`, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. The M17 feature commit was explicitly approved; pushing still requires separate approval.

## Current M17 Pass 1 (2026-10-05)

- Branch `feat/m17-home-product-completion` was created from exact pushed `dev`/`origin/dev` baseline `fde49ba0880bba2e39a7b2ec5b4e5f32aec3184c`. No stage, commit, push, merge, migration, or stash action occurred.
- Before M17, authenticated login/session restore landed on Groups; the five-item bottom bar displayed Home without a route. M17 adds `GET /api/v1/home`, one four-section authenticated aggregation, Flutter Home data/controller/screen, Home landing, and navigation into existing Group, Activity, Poll, Task, and Settlement details. The existing Search argument is carried across Home/Groups/Chat/Calendar tab transitions.
- Home sections: up to five recently updated active-member Groups, up to five future scheduled Planning/Confirmed Activities, exact-string ledger-derived owed/receivable totals plus four group rows, and up to eight current-user RSVP/Poll/Task/Settlement actions. Visibility is enforced server-side; no new table or Flyway migration. `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md` and `DEC-M17-01` describe the Pass 1 read model.
- Focused backend `HomeControllerIntegrationTest`: 4 run, 0 failures/errors/skips; Testcontainers PostgreSQL started and Flyway validated V0-V12. Full backend before the last test-only coverage addition: 621 run, 1 failure, 0 errors, 1 skipped. The sole failure is the known pre-existing `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` decimal JSON baseline recorded in M16; do not alter the status-only `FundDtos.java` marker as part of M17. Flutter focused Home/routes: 62 passed; final affected Home/routes/Groups/Chat/Calendar: 75 passed; full Flutter before the final route-argument carry-through: 696 passed; final `flutter analyze`: no issues found. Debug Android APK built at `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Samsung `R58M36JQYVY` was unavailable (`adb devices -l` showed no devices); no physical Home runtime result is claimed. Do not infer a device PASS from automated tests. The generated debug APK was not installed.
- Pass 2 product gaps: P1: canonical Recent Updates section and HOME-02 actions endpoint remain unimplemented; `GET /api/v1/groups/recent` contract has no standalone implementation; canonical Group five-tab surface is not present. P2: Profile remains a pushed screen rather than a persistent tab; Group Info and some legacy entry points still do not preserve Search route context. M18: review pre-existing token-bearing WebSocket URI under DEBUG transport logging and final security/performance matrices. M19: demo/deployment environment and signing readiness. No new P0 finding was established in this pass.
- Preserve unstaged post-M16 handoff history below, content-empty `FundDtos.java` marker, untracked `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `mobile/android/app/google-services.json`, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. Next: review the four-section Home slice, run physical sanity when Samsung returns, and plan remaining M17 Product Completion work before any commit approval.

## Current M16 Dev Push (2026-10-05)

- Active branch `dev` is at local merge `fde49ba0880bba2e39a7b2ec5b4e5f32aec3184c` (`merge: integrate m16 media and search`). Parent 1 is prior dev `05b4da2431c772c31abe315458674a99b9ce68e6`; parent 2 is pushed M16 feature `a1e28a06d88199bb0ea3f3663596bd9a729819ff`.
- The merge had no conflicts or content changes beyond M16. Its tracked tree matches `feat/m16-media-search`; the effective diff from the M15 dev base is the approved 95 files, 5,651 insertions, and 343 deletions. Existing M16 verification is reused; no full suites were rerun for a pure merge.
- After explicit approval, `git push origin dev` advanced remote dev from `05b4da2431c772c31abe315458674a99b9ce68e6` to `fde49ba0880bba2e39a7b2ec5b4e5f32aec3184c` without force. Local `dev` and `origin/dev` match; the M16 feature and merge commits are both reachable remotely. No new commit, merge, rebase, or amend followed the local M16 merge.
- Preserve the status-only `FundDtos.java` marker, untracked `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `mobile/android/app/google-services.json`, and protected `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. The previous temporary Windows sync-note patch was saved outside the repository before its explicitly authorized narrow restore.
- Mac demo signing, bundle-ID, Info.plist, Docker, database, and dummy Firebase changes remain machine-local and are not part of this merge. M17 has not started. Next action: begin M17 intake only after its scope and branch are approved.

## Historical M16 Final Closeout (2026-09-30)

- Branch `feat/m16-media-search` remains based on `05b4da2431c772c31abe315458674a99b9ce68e6`; no stage, commit, push, or migration change. The live worktree is the source of unfinished M16 changes. Preserve the protected stash, local-only files, and the semantic-empty `FundDtos.java` status marker.
- Closeout corrected pending stranger direct requests to TEXT-only at both CHAT_IMAGE presign and message creation. Accepted/group conversations retain image-only, caption plus image, and four-image behavior. The pending Chat composer hides image attachment while leaving text send available. API contract documentation now states the rule.
- Focused backend `ChatServiceIntegrationTest,UploadControllerIntegrationTest`: 16 run, 0 failures, 0 errors, 0 skipped. Full backend: 618 run, 1 failure, 0 errors, 1 skipped; the sole failure is the known unrelated `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` baseline. Testcontainers PostgreSQL started successfully.
- Focused Flutter Chat screen: 25 passed. `flutter analyze`: no issues. Full Flutter: 690 passed. Fresh debug APK built with `WEDO_API_BASE_URL=http://127.0.0.1:8080` at `mobile/build/app/outputs/flutter-apk/app-debug.apk` and installed on Samsung `R58M36JQYVY`.
- Samsung narrow sanity: a pending QA Outsider direct request offered text send and no image attachment; text send succeeded. Accepted QA group chat offered image attachment and rendered existing image messages. Current app logcat sample contained zero fatal/Flutter/overflow markers. Temporary backend was stopped; port 8080 has no listener, and ADB reverse remains limited to 8080 and 9000.
- A1 storage/avatar, A2 Chat/Finance media, and Phase B Search audits found no new M16 closeout blocker beyond the accepted Fund test baseline. No V13 or M16 migration, no secret file staged, and the Chat repository shared media-uploader fallback remains wired for all route constructors.
- Security follow-up outside M16: under DEBUG WebSocket transport logging, a local runtime disconnect log included a token-bearing WebSocket URI. Do not reproduce log values. Avoid DEBUG transport logging or query-string tokens in shared/production logs; assess redaction in a separate security hardening task. This did not originate in the M16 media/search diff.
- Next action: review the exact M16 include/exclude list, then seek explicit commit approval. Do not stage or commit during closeout; separate approval is required for push.

## Historical M16 Phase B Global Search Implementation (2026-09-30)

- **Branch/base**: `feat/m16-media-search`, based on `05b4da2431c772c31abe315458674a99b9ce68e6`. M16-A1/A2 work remains in place. No migration, commit, or push was made for Search.
- **Approved contract**: exactly PEOPLE, GROUPS, ACTIVITIES, CONVERSATIONS; query length 2..100; accent-sensitive PostgreSQL ILIKE substring matching with literal `%`/`_`; All mode up to five per category and independent `hasMore`; typed mode page/size with 0/20 defaults and size 1..50; safe typed response projections and existing domain authorization before pagination. Conversations represent the newest visible matching text message and navigate to the exact conversation without message anchoring.
- **Backend implementation**: typed Search DTOs, controller validation, bounded SQL projections, and PostgreSQL integration coverage are in `backend/src/main/java/com/wedo/backend/search/` and `backend/src/test/java/com/wedo/backend/search/SearchControllerIntegrationTest.java`. Focused Search backend tests pass: 6 run, 0 failures, 0 errors, 0 skipped. Full backend: 618 run, 1 known unrelated baseline failure, 0 errors, 1 skipped. The only failure is `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` (expected true, was false); not changed by M16-B.
- **Flutter implementation**: typed models/API/controller, Search screen and route, Groups search entry point, identity-based authorized avatar resolution, exact destination navigation, 300 ms debounce, typed pagination, duplicate suppression, and stale-response handling. Search-focused tests pass (4); `flutter analyze` is clean; full Flutter suite passes: 688 tests.
- **Build/device**: fresh debug APK built at `mobile/build/app/outputs/flutter-apk/app-debug.apk` and installed on Samsung `R58M36JQYVY`. All five categories fit the phone viewport. On-device checks returned QA people, joined QA group, six matching M15 activities (All-mode `Xem tất cả` then typed results), and matching group conversation; people/profile, Group Info, Activity Detail, and exact conversation navigation opened. Backend PostgreSQL integration tests cover hidden discovery, both-direction blocks, outsider visibility, archive/history, literal wildcards, accents, and page offsets. Two-account privacy assertions were automated, not manually switched on Samsung.
- **Audit/runtime**: no V13, external search engine, `unaccent`, or trigram dependency; `git diff --check` clean. The temporary foreground backend was stopped after Samsung acceptance. Current device logcat has no Flutter fatal/error markers; ADB reverse is restricted to ports 8080 and 9000. No staging, commit, or push. Keep the protected stash and local-only files untouched.

## Historical M16 Phase B Search Contract Review (Superseded, 2026-09-30)

The review gaps were resolved by `DEC-M16-04` and the implemented Search contract summarized above.

## Historical M16 Phase A2 Status (Superseded by Phase B, 2026-09-30)

- **M15 status/base**: M15 is closed and pushed to `dev`. M16 branch `feat/m16-media-search` is based on `05b4da2431c772c31abe315458674a99b9ce68e6`.
- **A1 implementation**: Added provider-neutral S3 storage, local private MinIO compose services, authenticated 10-minute `AVATAR`/`GROUP_AVATAR` presigning, direct Flutter PUT, owner/group-scoped key and metadata validation, authorized 5-minute signed reads, profile/group avatar upload UI wiring, and best-effort after-commit old-object deletion. No migration was added. Onboarding and initial group creation reject supplied avatar keys; attach avatars after the resource is active/created.
- **A2 contract/implementation**: `DEC-M16-03` and the API blueprint now specify exactly `CHAT_IMAGE`, `EXPENSE_RECEIPT`, `FUND_CONTRIBUTION_PROOF`, `FUND_EXPENSE_RECEIPT`, and `FUND_REIMBURSEMENT_RECEIPT`; JPEG/PNG/WebP, 10 MiB per file, four Chat images, and one Finance key per current nullable column. Context is exact conversation ID for Chat and group ID for Finance. Server-generated namespaced keys, object metadata/size validation, current domain authorization, post-upload finalization checks, private authorized reads, durable Chat attachment metadata/order, image-only empty content, notification fallback, and after-commit best-effort cleanup are implemented. No migration/V13 was added; Global Search remains unimplemented.
- **Backend verification**: Prior A2 focused suites: 62 run, 1 known baseline failure, 0 errors, 0 skipped. This acceptance added `UploadControllerIntegrationTest.fundExpenseReceiptPresignIsReadOnlyAndRequiresManagerPermission`: focused class 4 run, 0 failures/errors/skips. Full backend after the production fix: 612 run, 1 failure, 0 errors, 1 skipped. The sole failure remains the known baseline `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` (expected true, was false); Docker/Testcontainers started PostgreSQL and Flyway applied through V12. `FundDtos.java` has no content diff; preserve its existing modified status marker.
- **Flutter verification**: Previously verified focused Chat/media/Expense/Fund tests: 46 passed; full suite: 684 passed, 0 failed; `flutter analyze`: no issues found. No Flutter source changed during final acceptance. The existing fresh debug APK remains at `mobile/build/app/outputs/flutter-apk/app-debug.apk` and was used on Samsung.
- **Bootstrap closeout**: AIStor uses `quay.io/minio/aistor/minio:RELEASE.2026-09-19T17-05-25Z` with the external license mounted read-only at `/minio.license`; the runner sets only a process-scoped license path and never reads the license. Compose config validates. Backend `S3BucketBootstrapper` successfully bootstrapped the private bucket; it performs HEAD/create, accepts a create race only after successful re-HEAD, never changes existing bucket policy/objects, and fails startup generically when enabled storage is inaccessible. `media.s3.bootstrap-bucket` remains true in local, false globally/production and in tests. ADB reverse is limited to 8080 and 9000; console 9001 remains host-loopback only.
- **Samsung A1 acceptance (2026-09-30)**: External license path exists (contents not inspected); Samsung `R58M36JQYVY` authorized; Docker Engine 29.7.2 accessible. AIStor readiness returned HTTP 200 and backend actuator returned UP with Flyway current through V12. Owner presign + direct signed PUT + Profile UI upload, persistence, replacement, old-object cleanup, and authenticated private read passed. With AIStor stopped, Profile UI showed `Unable to upload your photo. Your current photo is unchanged.`; app stayed alive and persisted avatar remained readable after storage recovery. Group avatar UI upload/replacement and reopen persistence passed; member presign/finalization were denied (403), wrong group context was rejected (400), signed private reads succeeded, anonymous reads returned 403. Final sampled device logcat: 0 fatal exceptions, 0 Flutter errors; ADB reverse list contains only 8080 and 9000.
- **Repository state**: No staged files; no commit or push. Preserve the status-only `FundDtos.java` marker, `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, untracked `mobile/android/app/google-services.json`, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`.
- **A2 Samsung Chat send fix (2026-09-30)**: Reproduction showed Send enabled with the selected preview, then the generic connection snackbar and zero presign calls. Group/notification routes create ChatRepository instances with ChatApi but no MediaUploadService; `uploadChatImage` therefore threw `StateError` before HTTP. ChatRepository now uses the app-registered shared uploader as its default, and the composer enables Send only for nonblank text or queued images while not sending and within the four-image cap. Widget coverage exercises empty/text/image/caption states, upload failure retention, returned-key forwarding, four accepted/five rejected, and rapid-tap deduplication. Focused Chat/media: 35 passed; `flutter analyze`: clean; full Flutter: 683 passed; fresh APK built and installed.
- **A2 two-account Chat acceptance (2026-09-30)**: Samsung recipient `owner@wedo.local` and authenticated API/WebSocket sender `member1@wedo.local` exercised production CHAT_IMAGE presign, direct signed PUT, and REST message creation. While the exact group conversation was active, one durable image-only message produced exactly one `MESSAGE_CREATED`, one rendered image item, and one attachment; REST history after reopen retained it. While away/backgrounded, another image message produced one visible FCM system notification with the existing Vietnamese Chat title and image fallback body, no key/URL, and tapping opened the exact conversation with the image rendered. With the exact conversation active again, one realtime image rendered and no redundant Android system push appeared. Sampled Samsung logcat showed zero Flutter errors and zero fatal Android exceptions. ADB reverse remains limited to TCP 8080 and 9000.
- **A2 Finance Samsung acceptance (2026-09-30)**: All four wired flows passed and persisted/reopened with private image previews: Expense receipt and replacement; Fund contribution proof (left PENDING); Fund manager expense receipt; member reimbursement receipt (left PENDING). Existing Fund contribution/expense/reimbursement records have no post-submit receipt-replacement UI, so replacement is not applicable for those flows. Authorized API media access returned 200 for Expense and all three Fund categories; outsider reads were denied (404), and outsider presigns for Expense and Fund expense were denied (404). Cross-group Finance receipt reuse and Chat image-as-Expense-receipt mutations were rejected (400), with the target second-group expense unchanged. A controlled Expense replacement using a valid presigned key but no PUT was rejected (400); the previous receipt reference remained unchanged. The previously attempted Fund expense upload failure was traced to `authorizeMediaPresign` calling a manager helper that issued stale-manager cleanup DELETE inside a read-only transaction. The read-only authorization now checks mutable membership and `canManageFund` without cleanup; the new PostgreSQL endpoint regression proves owner success and member denial. This is the only backend code change during final acceptance.
- **A2 closeout**: All required two-account Chat/FCM and implemented Finance media acceptance gates passed. No Search implementation or migration was added. Ready for M16 Search review; do not begin Search until separately authorized.
- **Final runtime state**: The freshly started backend from this checkout passed actuator health and used Flyway V12, then was stopped cleanly after acceptance; port 8080 has no listener. `wedo-minio`, `wedo-postgres`, and `wedo-redis` remain running. Samsung `R58M36JQYVY` remains authorized with only `tcp:8080 -> tcp:8080` and `tcp:9000 -> tcp:9000` reverse mappings.
- **A2 realtime refresh runtime correction (2026-09-30)**: Fresh Samsung logcat traced repeated `setState() callback argument returned a Future` errors to `ChatHomeScreen._refresh`, where an expression-bodied state callback returned the conversations Future. Changed it to a synchronous block and added a realtime refresh widget regression. Focused Chat Home test passes; `flutter analyze` is clean; full Flutter suite: 684 passed. Fresh debug APK rebuilt and installed at `mobile/build/app/outputs/flutter-apk/app-debug.apk`. On `R58M36JQYVY`, opening Chat Home exercised realtime refresh with no Flutter errors; one new image-only send through the final APK rendered in the conversation. These observations do not close the outstanding multi-account/FCM/Finance acceptance items above. No backend code or migration changed; no commit or push.

## Historical M15 Phase C Snapshot (2026-09-29)

- **Branch/commit**: `feat/m15-calendar-reminder` at M15 commit `09fd2614007bb117d13d99fe3b6c23efbe74d727`; no push, merge, rebase, or amend performed.
- **Implemented**: Phase A/B Calendar/reminder configuration and Phase C bounded due-reminder scheduler. It claims in batches of 100 at a 45-second cadence, locks Activity before reminder with `SKIP LOCKED`, revalidates eligibility, and atomically persists/deduplicates the ACTIVITY inbox item with `sent_at`; M14 push policy is dispatched after commit. Reuses V9; no migration change or V13.
- **Backend verification**: Phase C focused suites: 35 run, 0 failures, 0 errors, 0 skipped. The last full backend result remains 589 run, 1 failure, 0 errors, 1 skipped; the sole failure is the unrelated known Fund JSON decimal assertion at `FundServiceIntegrationTest.java:594`. Backend production code was not changed in this continuation, so the full suite was not rerun.
- **Flutter verification**: the isolated Calendar test now passes after correcting its timezone/date-boundary fixture while retaining the real API response display and activity-ID tap assertions. Focused Calendar (5), Notification (21), and route (56) tests: 82 passed. `flutter analyze`: no issues. Full `flutter test --reporter compact`: `+672: All tests passed!` Fresh debug APK built and installed at `mobile/build/app/outputs/flutter-apk/app-debug.apk` using API base `http://127.0.0.1:8080`.
- **Runtime**: Docker Desktop 4.86 / Engine 29.7.2; PostgreSQL healthy and Testcontainers started PostgreSQL. Current backend PID 21680 (Java; started 2026-09-29 22:32:10 local), actuator health `UP`; Samsung `R58M36JQYVY` authorized. Host, device, and PostgreSQL UTC clocks agreed within about one second. Firebase Admin credential path was set and existed; its contents and device tokens were never read or printed.
- **Samsung Phase C acceptance**: (1) UI-configured due reminder created one ACTIVITY inbox item, sent after commit, produced a visible Firebase system notification, tapped into the exact Activity detail, marked the notification read, and had no duplicate inbox/push after two more scheduler ticks. (2) With ACTIVITY preference off and global push on, a second reminder persisted and finalized `sent_at`, was `SUPPRESSED_CATEGORY_DISABLED`, and produced no matching system notification; ACTIVITY preference was restored. (3) While the group was muted and both user preferences enabled, a third reminder persisted once with `SUPPRESSED_GROUP_MUTED`; no reminder push appeared and the group was unmuted afterward. (4) Reschedule: the 23:15 local original due instant passed without inbox row or push after the Activity was moved later; offset stayed 5 minutes and the new 23:25 due instant produced one inbox row (`GATEWAY_ACCEPTED`) and one visible Samsung notification, still one after two further ticks. `GATEWAY_ACCEPTED` is provider handoff, with the physical notification separately proving device appearance.
- **Other acceptance/audits**: disable-before-due physical case was not run; automated disable/scheduler race coverage remains. Final bounded Samsung logcat: 0 `FATAL EXCEPTION`, 0 `AndroidRuntime`, 0 `FirebaseMessaging`, 0 `FirebaseApp` matches in last 3000 lines. No migration/V13; no generated artifact staged. `google-services.json` remains untracked; external Admin credential remains outside Git. Preserve the status-only `FundDtos.java` marker, both local-only docs, `.stitch/**`, `.dev-runtime/**`, `.dev-logs/**`, and `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`.
- **M15 Calendar filter pre-commit correction (2026-09-30)**: fixed `CalendarScreen` so each omitted filter argument preserves its current selection while an explicit null clears only that filter; added Clear filters for intentional reset-all. Calendar widget coverage verifies changing each filter preserves the others, combined query parameters, individual clear, reset-all, month navigation, Month/Agenda rendering, and activity opening. Focused Calendar tests: 5 passed; `flutter analyze`: no issues; full Flutter suite: 672 passed. Fresh debug APK rebuilt at `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Root cause was the screen callback assigning all three nullable callback parameters on every change; repository serialization was already correct.
- **M15 filter physical recheck**: NOT RE-RUN — device/runtime unavailable; focused and full automated regression PASS. This is nonblocking for the approved commit retry because the fix is isolated to Flutter filter state, no backend/reminder delivery code changed, and prior Samsung Calendar/Reminder/FCM acceptance passed.
- **Next**: M15 implementation is committed locally; wait for separate push authorization before publishing the branch.

## 1. Historical M15 Git & Branch State

- **Active Branch**: `feat/m15-calendar-reminder`
- **Base Commit (`dev`)**: `5e288f0098543d486ee1c2010a8f8f7b765d8ff1` (M14 merged and pushed; M14 closed)
- **Active Milestone**: **M15 — Calendar + Reminder (implementation and acceptance complete; committed locally, not pushed)**. Scope includes Activity-derived Calendar, personal reminders, due delivery through M14 Notification/FCM policy, and live Samsung acceptance. The post-fix Calendar filter device recheck was not rerun because the device/runtime was unavailable; this is nonblocking under the approved automated acceptance. M14 feature commit: `d4fc8571959d92e17b139be936669f64c459b6d8`.
- **Preserved Stash**: `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync` — **DO NOT** pop, apply, or drop.
- **Local-Only Untracked Files (Never Stage/Commit)**:
  - `docs/LEARNING_HANDBOOK_M0_M2.md`
  - `docs/M8_STITCH_FIDELITY_INVENTORY.md`
  - `.stitch/**`

---

## 2. Historical M10 Implementation (`feat/m10-chat-realtime`)

### Database Schema (`V4__chat.sql` — No New Migration Required)
- M10 reuses existing `V4__chat.sql` tables (`conversations`, `messages`, `conversation_read_states`, `user_presence_snapshots`).
- `ChatService.recordLastSeenSnapshot(userId, now)` upserts `user_presence_snapshots(user_id, last_seen_at)` when a user's last active WebSocket session disconnects.
- No existing Flyway migrations (`V0`..`V12`) were modified and no new migration (`V13+`) was required.

### Backend (`backend/src/main/java/com/wedo/backend/chat/realtime/...` & `ChatService.java`)
- **WebSocket Endpoints & Security (`ChatWebSocketConfig`, `ChatWebSocketHandshakeInterceptor`, `SecurityConfig`)**:
  - Registers `/ws` and `/api/v1/ws`.
  - Handshake interceptor validates JWT access token (`Authorization: Bearer <token>` header or `?access_token=<token>` query param) and verifies `UserStatus.ACTIVE`, rejecting unauthenticated/invalid handshakes with HTTP 401.
- **Transactional Event Bridge (`ChatRealtimeTransactionalBridge`)**:
  - `ChatService` publishes `DomainMutationEvent` (`send`, `edit`, `unsend`, `react`, `pin`, `unpin`) and `DomainReadEvent` (`markRead`).
  - `ChatRealtimeTransactionalBridge` listens with `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` so WebSocket/Redis frames are dispatched strictly after durable PostgreSQL transaction commit.
- **Redis Pub/Sub, Typing TTL & Multi-Session Presence (`ChatRealtimeCoordinator`, `ChatWebSocketHandler`)**:
  - Publishes and subscribes to Redis channel `wedo:chat:realtime` (`RedisEnvelope` deduplicated by `eventId`).
  - Ephemeral typing TTL keys `typing:{conversationId}:{userId}` (`5s` TTL) with `TYPING_START` / `TYPING_STOP` client frames and `TYPING_UPDATED` server broadcasts.
  - Multi-session presence set `presence:user:{userId}:sessions` (`120s` TTL): user stays online across multiple concurrent sockets until the last session closes, broadcasting `PRESENCE_UPDATED` to shared conversation peers and persisting `user_presence_snapshots.last_seen_at`.
  - Graceful local fallback when Redis is unreachable so REST Chat and single-node WebSocket delivery never fail.
- **Durable mutation boundary**: WebSocket accepts subscription, typing, heartbeat, and read-state commands only. Message send/edit/unsend/reaction mutations use M9 REST endpoints; unsupported WebSocket mutation commands return `VALIDATION_FAILED` without changing PostgreSQL state.

### Mobile (`mobile/lib/features/chat/...` & `main.dart`)
- **Files Implemented/Updated**:
  - `mobile/lib/features/chat/data/chat_realtime_event.dart` (`ChatRealtimeEvent`, `ChatRealtimeEventType`, `ChatRealtimeConnectionState`)
  - `mobile/lib/features/chat/data/chat_realtime_client.dart` (`ChatRealtimeClient`, `WebSocketChatRealtimeClient`, `NoopChatRealtimeClient`)
  - `mobile/lib/features/chat/data/chat_api.dart`, `chat_repository.dart`
  - `mobile/lib/features/chat/presentation/chat_formatters.dart`, `chat_home_screen.dart`, `chat_screen.dart`
  - `mobile/lib/main.dart`
- **Capabilities & Preserved M9 Pass 6 UX**:
  - Automatic WebSocket connection, `SUBSCRIBE`/`UNSUBSCRIBE` lifecycle, exponential-backoff reconnect, and silent reconnect history reconciliation.
  - `ChatRepository.defaultRealtimeClient` wired in `main.dart` so all navigation routes (`MyGroupsScreen`, `GroupInfoScreen`, `ChatHomeScreen`) share the live `WebSocketChatRealtimeClient` instance, and `SUBSCRIBED` initial `onlineUserIds` snapshot excludes `viewerUserId` so `"Đang hoạt động"` reflects other active participants.
  - Deduplicated live updates for `MESSAGE_CREATED`, `MESSAGE_EDITED`, `MESSAGE_UNSENT`, `MESSAGE_REACTION_UPDATED`, `READ_STATE_UPDATED` (moving reader mini-avatars in real time), `TYPING_UPDATED` (`"<Name> đang nhập..."` with 6s timeout), and `PRESENCE_UPDATED` (`"Đang hoạt động"` header badge and Chat Home green dot).
  - Preserves all M9 Pass 6 UX rules (no per-bubble default timestamp, `>= 30m` & date-boundary centered time separators breaking author runs, single-tap 2s exact timestamp reveal, long-press quick reactions & actions sheet).

---

## 3. Historical M10 Test, Static Analysis & Two-Account Samsung Realtime Acceptance

- **Backend Focused Chat + Realtime Suite** (`.\mvnw.cmd -Dtest="ChatRealtimeIntegrationTest,ChatControllerTest,ChatServiceIntegrationTest" test`):
  - **16 tests run, 0 failures, 0 errors, 0 skipped**
- **Backend Full Suite** (`.\mvnw.cmd test`):
  - **529 tests run, 0 failures, 0 errors, 1 skipped**
- **Mobile Static Analysis** (`flutter analyze`):
  - **Clean (`No issues found!`)**
- **Mobile Full Test Suite** (`flutter test --reporter compact`):
  - **626 passed, 0 failures**
- **Two-Account Samsung Physical Device Realtime Acceptance (`R58M36JQYVY`)**:
  - **PASSED END-TO-END WITHOUT MANUAL REFRESH**:
    - **Samsung client (`R58M36JQYVY`)**: `member1@wedo.local` (`QA Member 1`) viewing `weDO QA Team` (`groupId: 3ba858f7-858f-40db-a5d1-444fd6f88c36`, `conversationId: f2af179e-4627-4fa7-8972-5665c153bc36`).
    - **Local realtime harness client**: `member2@wedo.local` (`QA Member 2`) and `outsider@wedo.local` over `/ws` + M9 REST mutation endpoints.
    - Verified live `MESSAGE_CREATED` (both directions + duplicate suppression), live `TYPING_START` (`"QA Member 2 đang nhập..."`), live `TYPING_STOP`, typing TTL auto-expiry, live `MESSAGE_REACTION_UPDATED` (`❤️ 1` -> `👍 1` + `"Biểu cảm"` reaction details bottom sheet), live `READ_STATE_UPDATED` (`QM` reader mini-avatar movement), live `MESSAGE_EDITED` (`"Chào trực tiếp M10 (đã chỉnh sửa)"`), live `MESSAGE_UNSENT` (`"Tin nhắn đã được thu hồi"`), multi-session `PRESENCE_UPDATED` (`"● Đang hoạt động"` remains online with 2 sessions -> 1 session, goes offline on 0 sessions), reconnect/resubscribe with gap message delivery, and `outsider@wedo.local` security negative checks (`ERROR:ACCESS_DENIED` / `ERROR:GROUP_NOT_FOUND`).

---

## 4. Current M11 Handoff

- M11 implements Expense create/list/detail/edit/cancel and derived group/pair balances using existing V7 finance tables. No migration was added; M12 settlement actions and M13 fund remain deferred. Receipt upload is not implemented.
- Backend service integration covers deterministic equal/custom splits, audit history, settlement reservations, archived read-only permission projections, member/outsider authorization, multi-account visibility, inverse pair balances, maximum monetary JSON precision, and concurrent edit/cancel consistency.
- Flutter provides a group-specific Expense list, create/edit/detail/cancel and balance views. Amount handling uses integer minor units and decimal strings in both directions. Edit retains custom shares and the activity reference; edit and cancel controls independently consume server flags. Dates render in local time, audit states are Vietnamese, and reference IDs are not displayed.
- Samsung `R58M36JQYVY` acceptance completed using the local QA group: created 50.00, edited to 60.00 with two 30.00 shares, observed the caller's owed balance increase to 30.00, then cancelled and observed it return to 0.00.
- A cancel/reload `setState` Future-return crash was found and fixed, covered by a widget test and a successful fresh 5.00 create/cancel device check. Final corrected APK was rebuilt, installed and launched on Samsung; local time, translated cancellation history and zero balance were rechecked visually. No Flutter runtime exception appeared in the final app process logs.
- The original backend on port 8080 was pre-M11 and was not stopped or changed by this M11 continuation. Current M11 source ran on temporary port 8081 for device checks. The temporary M11 backend and debug sessions are now stopped. Final APK uses `http://127.0.0.1:8080`; the temporary device `tcp:8080 -> host tcp:8081` mapping was restored to `tcp:8080 -> tcp:8080`. Local cancelled QA expense rows remain as audit history.
- Preserve local-only docs and `.stitch/**`; preserve `stash@{0}: On dev: codex-m7-foundation-pre-m6-sync`. Do not stage, commit, or push without separate authorization.

### Latest Verification (2026-09-28)

| Gate | Authoritative result |
| --- | --- |
| Backend compile `mvnw.cmd -DskipTests compile` | `BUILD SUCCESS` |
| Focused backend `ChatRealtimeIntegrationTest,ExpenseServiceIntegrationTest` | 18 run, 0 failures, 0 errors, 0 skipped (`BUILD SUCCESS`) |
| Full backend `mvnw.cmd test` | 542 run, 0 failures, 0 errors, 1 skipped (`BUILD SUCCESS`) |
| Focused Flutter Expense tests | 15 passed, 0 failed |
| `flutter analyze` | No issues found |
| Complete `flutter test --reporter compact` | 641 passed, 0 failed; command exited successfully |
| Debug APK with standard 8080 define | Successful; `mobile/build/app/outputs/flutter-apk/app-debug.apk`, 201414780 bytes |
| Samsung | Create/edit/cancel/balance reversal passed; final local-time/history fixes verified on installed APK |
| Migration audit | V0 bootstrap and V1-V12 retained unchanged; no new migration |
| Debug/temp audit | No temporary paths, QA credentials, debug prints, TODO/FIXME in new M11 production files |

### Realtime Package Recovery & Blocker Resolution

- The stale/conflicting working-tree modification in `backend/src/main/java/com/wedo/backend/chat/realtime/ChatRealtimeCoordinator.java` (from an earlier pre-review M10 replay that added WebSocket `SEND_MESSAGE`/`EDIT_MESSAGE`/`UNSEND_MESSAGE`/`SET_REACTION` handlers) was restored to committed M10 `HEAD` (`3c0b151aaaa2d5838ceb354778df43488e164c76`).
- All 6 production files under `backend/src/main/java/com/wedo/backend/chat/realtime/` and `backend/src/test/java/com/wedo/backend/chat/ChatRealtimeIntegrationTest.java` now match `HEAD` with zero working-tree diffs and zero empty/truncated files.
- `ChatRealtimeIntegrationTest.durableMessageMutationsAreRejectedOverWebSocket`, the focused `ChatRealtimeIntegrationTest,ExpenseServiceIntegrationTest` suite (`18/18`), and the full backend suite (`542` run, `0` failures, `0` errors, `1` skipped) all pass. No blocker remains for M11 closeout.

### Exact M11 Include Candidates (Not Staged)

Backend production:
- `backend/src/main/java/com/wedo/backend/common/error/ErrorCode.java`
- `backend/src/main/java/com/wedo/backend/expense/controller/ExpenseController.java`
- `backend/src/main/java/com/wedo/backend/expense/dto/ExpenseDtos.java`
- `backend/src/main/java/com/wedo/backend/expense/service/ExpenseService.java`

Backend tests:
- `backend/src/test/java/com/wedo/backend/expense/ExpenseServiceIntegrationTest.java`

Flutter production:
- `mobile/lib/app/routes.dart`
- `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
- `mobile/lib/features/expense/application/expense_controllers.dart`
- `mobile/lib/features/expense/data/expense_api.dart`
- `mobile/lib/features/expense/data/expense_failure.dart`
- `mobile/lib/features/expense/data/expense_models.dart`
- `mobile/lib/features/expense/data/expense_repository.dart`
- `mobile/lib/features/expense/presentation/expense_screens.dart`

Flutter tests:
- `mobile/test/app/routes_test.dart`
- `mobile/test/features/expense/data/expense_models_test.dart`
- `mobile/test/features/expense/presentation/expense_detail_screen_test.dart`

Canonical docs/handoff:
- `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md`
- `docs/ERD_DATABASE_DESIGN_v1.0.md`
- `docs/architecture/CLASS_DIAGRAM.puml`
- `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`
- `docs/LOCAL_DEVELOPMENT.md`
- `docs/AGENT_CURRENT_HANDOFF.md`
- `docs/AGENT_DECISION_LOG.md`

## 5. Current M12 Handoff (`feat/m12-settlement`)

### Implementation Summary
- **Database Schema (`V7__finance.sql` — No New Migration)**:
  - Uses existing `settlements` and `settlement_status_history` tables (`V7__finance.sql`). No authoritative `debts` table and no M13 Group Fund tables are modified.
- **Backend (`ExpenseController`, `ExpenseService`, `ExpenseDtos`, `ErrorCode`, `SettlementServiceIntegrationTest`)**:
  - Endpoints:
    - `POST /api/v1/groups/{groupId}/settlements`
    - `GET /api/v1/groups/{groupId}/settlements`
    - `GET /api/v1/settlements/{settlementId}`
    - `POST /api/v1/settlements/{settlementId}/confirm`
    - `POST /api/v1/settlements/{settlementId}/reject`
    - `POST /api/v1/settlements/{settlementId}/cancel`
  - Enforces `SET-01`..`SET-05`: direction derivation (`I_PAID` vs `I_RECEIVED`), active debt validation (`NO_OUTSTANDING_DEBT`, `SETTLEMENT_AMOUNT_EXCEEDS_DEBT`), pending debt reservation (`ledger.pending`), counterparty-only confirmation/rejection (`SETTLEMENT_CONFIRMATION_NOT_ALLOWED`), creator-only cancellation while `PENDING`, `SETTLEMENT_ALREADY_RESOLVED` protection under `FOR UPDATE` locking, archived group read-only projection, and `settlement_status_history` logging.
- **Mobile (`expense_models.dart`, `expense_failure.dart`, `expense_api.dart`, `expense_repository.dart`, `expense_controllers.dart`, `expense_screens.dart`, `routes.dart`, `group_info_screen.dart`)**:
  - `ExpenseBalanceScreen` (`Số dư nhóm` / `AppRoutes.groupSettlements = '/groups/settlements'`) displays member balances with `Thanh toán` (`YOU_OWE` -> `I_PAID`) and `Đã nhận tiền` (`OWES_YOU` -> `I_RECEIVED`) actions, prefilled settlement dialog supporting partial or full repayment, and `Lịch sử thanh toán` with server-projected `Xác nhận` / `Từ chối` / `Hủy yêu cầu` actions.
  - `SettlementDetailScreen` (`Chi tiết thanh toán`) displays full settlement attributes, localized status badges, action buttons, and `Lịch sử trạng thái` (`statusHistory`) in local time.
  - `GroupInfoScreen` adds `Thanh toán công nợ` navigation directly to `AppRoutes.groupSettlements`.

### Latest Verification (2026-09-28)

| Gate | Authoritative result |
| --- | --- |
| Focused backend `ExpenseServiceIntegrationTest,SettlementServiceIntegrationTest` | 17 run, 0 failures, 0 errors, 0 skipped (`BUILD SUCCESS`) |
| Full backend `mvnw.cmd test` | 546 run, 0 failures, 0 errors, 1 skipped (`BUILD SUCCESS`) |
| `flutter analyze` | No issues found |
| Complete `flutter test --reporter compact` | 642 passed, 0 failed |
| Debug APK (`WEDO_API_BASE_URL=http://127.0.0.1:8080`) | Built & installed (`mobile/build/app/outputs/flutter-apk/app-debug.apk`) |
| Samsung `R58M36JQYVY` Physical-Device E2E & Multi-Account QA | Verified `owner@wedo.local`, `member1@wedo.local`, `outsider@wedo.local`: initial 150,000.00 debt -> 60,000.00 `PENDING` (balance remains 150,000.00) -> 100,000.00 overpayment rejected (`SETTLEMENT_AMOUNT_EXCEEDS_DEBT`) -> outsider rejected (`404 GROUP_NOT_FOUND`) -> 60,000.00 confirmed (`COMPLETED`, remaining debt 90,000.00) -> 90,000.00 `I_RECEIVED` confirmed (`COMPLETED`, remaining debt 0.00) -> Samsung UI live confirmation of 20,000.00 (`50.000 ₫` -> `30.000 ₫`) & `SettlementDetailScreen` status history verified |
| Migration audit | V0..V12 unchanged; no new migration |

### Exact M12 Include Candidates (Not Staged)
- Backend production:
  - `backend/src/main/java/com/wedo/backend/common/error/ErrorCode.java`
  - `backend/src/main/java/com/wedo/backend/expense/controller/ExpenseController.java`
  - `backend/src/main/java/com/wedo/backend/expense/dto/ExpenseDtos.java`
  - `backend/src/main/java/com/wedo/backend/expense/service/ExpenseService.java`
- Backend tests:
  - `backend/src/test/java/com/wedo/backend/expense/SettlementServiceIntegrationTest.java`
- Flutter production:
  - `mobile/lib/app/routes.dart`
  - `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
  - `mobile/lib/features/expense/application/expense_controllers.dart`
  - `mobile/lib/features/expense/data/expense_api.dart`
  - `mobile/lib/features/expense/data/expense_failure.dart`
  - `mobile/lib/features/expense/data/expense_models.dart`
  - `mobile/lib/features/expense/data/expense_repository.dart`
  - `mobile/lib/features/expense/presentation/expense_screens.dart`
- Flutter tests:
  - `mobile/test/app/routes_test.dart`
  - `mobile/test/features/expense/data/expense_models_test.dart`
  - `mobile/test/features/expense/presentation/expense_detail_screen_test.dart`
- Canonical docs/handoff:
  - `docs/AGENT_PROJECT_CONTEXT.md`
  - `docs/AGENT_CURRENT_HANDOFF.md`
  - `docs/AGENT_DECISION_LOG.md`
  - `docs/architecture/CLASS_DIAGRAM.puml`

## 6. Current M13 Handoff (`feat/m13-group-fund`)

### Implementation Summary
- **Database Schema (`V8__fund.sql` — No New Migration)**:
  - Reuses all 9 existing `V8__fund.sql` tables (`group_funds`, `fund_managers`, `fund_collections`, `fund_collection_obligations`, `fund_contributions`, `fund_expenses`, `fund_reimbursements`, `fund_transactions`, `fund_transaction_reversals`). No Flyway migration (`V0`..`V12`) was edited and no `V13+` migration was added.
  - Strictly separated from M11/M12 pairwise `expenses` / `settlements` (`V7__finance.sql`).
- **Backend (`com.wedo.backend.fund.*`, `ErrorCode`, `FundServiceIntegrationTest`)**:
  - Dedicated domain boundary (`FundController`, `FundService`, `FundDtos`) implementing `FUND-01`..`FUND-17` and all 18 M13 `ErrorCode` constants.
  - Enforces single fund per group (`VND`), `OWNER` implicit fund governance + up to 2 assigned active `ADMIN` `Fund Manager` rows (`fund_managers`), automatic stale `Fund Manager` cleanup on `GroupMembershipEndedEvent` and admin demotion, derived obligation statuses (`UNPAID`, `PARTIAL`, `PAID`, `OVERDUE`), derived `ledgerBalance = sum(IN) - sum(OUT)` and `availableBalance = ledgerBalance - pendingReimbursements`, `FOR UPDATE` row-level locking across all balance/contribution/reimbursement/reversal/close mutations, immutable compensating `REVERSAL` entries (`fund_transaction_reversals`), and fund close preconditions (`ledgerBalance == 0`, `0` open collections, `0` pending contributions, `0` pending reimbursements).
  - M13 hardening serializes collection close/cancel and contribution transitions on the parent fund before child rows to avoid lock-order inversion; rejects amounts with meaningful precision beyond the schema's 2 decimal places rather than silently rounding.
- **Mobile (`mobile/lib/features/fund/*`, `routes.dart`, `group_info_screen.dart`)**:
  - Dedicated Flutter feature boundary (`fund_failure.dart`, `fund_models.dart`, `fund_api.dart`, `fund_repository.dart`, `fund_controllers.dart`, `fund_screens.dart`) registered at `AppRoutes.groupFund = '/groups/fund'` (`FundRouteArgs`) and wired from `GroupInfoScreen` (`'Quỹ nhóm'`).
  - Renders 4 localized Vietnamese tabs (`Tổng quan`, `Đợt thu`, `Chi quỹ & Hoàn tiền`, `Sổ giao dịch`) driven strictly by server-projected permission flags (`canCreateFund`, `canManageFund`, `canManageManagers`, `canContribute`, `canRequestReimbursement`, `canCloseFund`, `canReverse`, `readOnly`).

### Latest Verification (2026-09-28)

| Gate | Authoritative result |
| --- | --- |
| Focused backend `FundServiceIntegrationTest,ExpenseServiceIntegrationTest,SettlementServiceIntegrationTest` | 29 run, 0 failures, 0 errors, 0 skipped (`BUILD SUCCESS`; Testcontainers PostgreSQL started) |
| Full backend `mvnw.cmd test` | 558 run, 0 failures, 0 errors, 1 skipped (`BUILD SUCCESS`) |
| `flutter analyze` | No issues found |
| Focused Flutter `fund_screen_test.dart` + `routes_test.dart` | 59 passed, 0 failed |
| Complete `flutter test --reporter compact` | 645 passed, 0 failed |
| Debug APK (`WEDO_API_BASE_URL=http://127.0.0.1:8080`) | Built & installed (`mobile/build/app/outputs/flutter-apk/app-debug.apk`) |
| Samsung `R58M36JQYVY` Physical-Device E2E & Multi-Account QA | Real Flutter UI verified owner-created collection, member contribution submission, delegated Admin confirmation, direct expense, member reimbursement request, Admin approval, transaction reversal, and insufficient-available-balance rejection. Ledger returned to 80,000 VND after reversal; insufficient-funds UI error shown; `0` `FATAL EXCEPTION` in device logcat. The fund and delegated manager were already present in seed data; no REST calls were used for the claimed flows. |
| Migration audit | V0..V12 unchanged; no new migration |

### Exact M13 Include Candidates (Not Staged)
- Backend production:
  - `backend/src/main/java/com/wedo/backend/common/error/ErrorCode.java`
  - `backend/src/main/java/com/wedo/backend/fund/controller/FundController.java`
  - `backend/src/main/java/com/wedo/backend/fund/dto/FundDtos.java`
  - `backend/src/main/java/com/wedo/backend/fund/service/FundService.java`
- Backend tests:
  - `backend/src/test/java/com/wedo/backend/fund/FundServiceIntegrationTest.java`
- Flutter production:
  - `mobile/lib/app/routes.dart`
  - `mobile/lib/features/groups/presentation/screens/group_info_screen.dart`
  - `mobile/lib/features/expense/data/expense_api.dart`
  - `mobile/lib/features/fund/application/fund_controllers.dart`
  - `mobile/lib/features/fund/data/fund_api.dart`
  - `mobile/lib/features/fund/data/fund_failure.dart`
  - `mobile/lib/features/fund/data/fund_models.dart`
  - `mobile/lib/features/fund/data/fund_repository.dart`
  - `mobile/lib/features/fund/presentation/fund_screens.dart`
- Flutter tests:
  - `mobile/test/app/routes_test.dart`
  - `mobile/test/features/fund/fund_screen_test.dart`
- Canonical docs/handoff:
  - `docs/AGENT_PROJECT_CONTEXT.md`
  - `docs/AGENT_CURRENT_HANDOFF.md`
  - `docs/AGENT_DECISION_LOG.md`
  - `docs/architecture/CLASS_DIAGRAM.puml`

---

## 7. Current M14 Handoff (`feat/m14-notification-fcm`)

### Implementation Summary
- **Database Schema (`V1__identity_and_auth.sql`, `V9__notifications.sql`, `V10__cross_module_indexes.sql` — No New Migration)**:
  - Reuses existing `user_devices` (`V1`), `notifications`, `user_notification_settings`, `group_notification_settings` (`V9`), and `uq_user_devices_active_push_token` (`V10`). Zero Flyway migrations (`V0`..`V12`) were modified and no `V13+` migration was added.
- **Backend (`com.wedo.backend.notification.*`, `ChatRealtimeCoordinator`, domain event emitters)**:
  - Implemented `NotificationController`, `NotificationService`, `NotificationDtos`, `NotificationDomainEvent`, `NotificationDomainEventListener`, `PushGateway`, and `FcmPushGateway` covering `NOTI-01`..`NOTI-06` and `/api/v1/me/devices` (`GET`, `POST`, `DELETE /{deviceId}`).
  - Notification persistence is `AFTER_COMMIT` and `REQUIRES_NEW`; per-recipient duplicate checks serialize with a PostgreSQL transaction advisory lock. Push dispatch happens after the persistence transaction. A post-commit database failure is isolated from business state but can lose that notification because there is no durable outbox.
  - In-app inbox persistence is independent of push policy. User global/category settings suppress push only; group mute suppresses noncritical push only. Only waitlist promotion, settlement confirmation, fund contribution confirmation, and fund reimbursement approval are marked critical; join-request approval is not a critical bypass.
  - `ChatRealtimeCoordinator.isUserSubscribedToConversation` checks an open local socket and active conversation subscription; unsubscribe/disconnect remove local state. Subscription state is not shared across backend instances, so open-chat suppression is best-effort in a multi-instance deployment.
  - `FcmPushGateway` sends via Firebase Admin `FirebaseMessaging` using ADC, maps invalid/transient/provider failures, and returns provider acceptance only after Firebase returns a message ID. Device token values are not logged. `NotificationService` retains `AFTER_COMMIT` + `REQUIRES_NEW` isolation and PostgreSQL advisory-lock duplicate prevention.
  - Flutter uses `firebase_core`/`firebase_messaging`, Google Services Gradle integration, Android notification permission, stable secure device IDs, initial/token-refresh registration, logout deactivation, and foreground/background/opened/cold-start handlers. The untracked local `mobile/android/app/google-services.json` must remain excluded.
- **Mobile (`mobile/lib/features/notification/*`, `routes.dart`, `my_groups_screen.dart`, `group_info_screen.dart`)**:
  - Dedicated Flutter module (`notification_failure.dart`, `notification_models.dart`, `notification_api.dart`, `notification_repository.dart`, `notification_controllers.dart`, `notification_screens.dart`) registered at `AppRoutes.notifications = '/notifications'` and `AppRoutes.notificationSettings = '/notifications/settings'`.
  - Wired `"Thông báo"` header action in `MyGroupsScreen` and `"Tắt thông báo nhóm"` bottom sheet (`1 giờ`, `8 giờ`, `1 ngày`, `Cho đến khi bật lại`) in `GroupInfoScreen`.

### Latest Verification (2026-09-29)

| Gate | Authoritative result |
| --- | --- |
| Focused backend notification/producer suites (`M8MultiAccountIntegrationTest`, `ExpenseServiceIntegrationTest`) | 18 run, 0 failures, 0 errors, 0 skipped |
| Full backend `mvnw.cmd test` | 573 run, 1 failure, 0 errors, 1 skipped; sole failure is `FundServiceIntegrationTest.maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization` at line 594; exact test also fails at base commit `a34de335cefa283b218bf80f5e421ccff58b96b3` |
| `flutter analyze` | No issues found |
| Focused Flutter notification push/API/router tests | 21 passed, 0 failed |
| Complete `flutter test --reporter compact` | 666 passed, 0 failed |
| Debug APK (`WEDO_API_BASE_URL=http://127.0.0.1:8080`) | Fresh debug build succeeded at `mobile/build/app/outputs/flutter-apk/app-debug.apk`; installed on Samsung `R58M36JQYVY` |
| Samsung `R58M36JQYVY` E2E | Fresh Chat push+system tap opened the exact group conversation and marked read; active-conversation realtime message appeared without a redundant card, then away-message push returned. Activity push+tap opened its matching detail. Poll and Task push+taps opened their parent Activity detail and marked rows read. Finance Expense push+tapped to Expense detail. Fund collection push+tapped to Group Fund. Read/unread count updated. Global-off and Poll-off were toggled in Flutter UI; inbox persisted and server dispatch decisions were `SUPPRESSED_USER_PUSH_DISABLED` / `SUPPRESSED_CATEGORY_DISABLED`. Group mute was selected in Flutter UI; a fresh Poll persisted with `SUPPRESSED_GROUP_MUTED` and no matching Android card. While muted, critical Fund contribution-confirmed was `GATEWAY_ACCEPTED` and appeared on the Samsung. Preferences and group mute were restored. Open-chat foreground behavior verified. Cold-start tap not verified. |
| Provider evidence | Real Firebase sends persisted `GATEWAY_ACCEPTED`; stale active fake-prefix QA device rows were deactivated, and no active fake-prefix rows remain |
| Device logcat | Final bounded logcat scan: 0 `FATAL EXCEPTION`; 14 AndroidRuntime lines, 0 FirebaseMessaging lines, 0 FirebaseApp lines in the last 3000 lines. No credential or token contents printed. Stay-awake was disabled and DND restored to Priority (`zen_mode=1`). |
| Migration/security audits | V0..V12 unchanged; no V13. Secret-pattern scan had no matches in code/source; external Firebase Admin JSON was never opened. Google Services JSON remains untracked/unstaged. One active real device registration; no fake-prefix active token. |

### M14 Environment Recheck (2026-09-29)
- `GOOGLE_APPLICATION_CREDENTIALS` resolved to the requested external path and `Test-Path` was true; the credential file was never opened, copied, logged, or staged.
- Docker Desktop 4.86.0 / Engine 29.7.2 and Testcontainers PostgreSQL work with elevated access; ordinary sandbox access to the Docker named pipe is denied.
- Device token values and Firebase Admin credential contents were never written to logs or reports. Two stale fake-prefix local QA device records were removed; the real Samsung token is active.

### M14 Closeout and M15 Transition (Historical Notes)
- Full backend suite has one failing Fund JSON decimal-string assertion (`FundServiceIntegrationTest.java:594`); the exact test also fails at clean base `a34de335cefa283b218bf80f5e421ccff58b96b3`, so it is pre-existing. Do not fold an unrelated Fund behavior change into M14 without review.
- Notification coverage audit added Activity confirmed schedule/location change notices to GOING/MAYBE participants, Poll create/close notices, and Task assignment/status-change notices. Focused integration tests prove exact recipients/categories/targets; Flutter route tests cover supported target types. Existing policy producers remain for Group invitation/join approval, Chat message, Activity creation/waitlist promotion, Expense/Settlement, and Fund. Social/Discussion do not have canonical notification producers.
- Live warm/background acceptance now covers Chat, Activity, Poll, Task, Finance, and Fund notification routes/taps; mark-read behavior and unread count; global/category suppression; Flutter UI group mute; critical Fund bypass while muted; and open-chat suppression versus away-chat push. Cold-start/terminated tap was not verified; no product defect remains from the current required scenarios.
- `FundDtos.java` has no normalized content diff; `git ls-files --eol` reports mixed working-tree line endings, leaving a status-only modified marker. No content was restored or staged.
- Verification retained: backend focused 18 passed; full backend 573 run, 1 confirmed clean-base Fund serialization failure, 0 errors, 1 skipped; Flutter focused 32 passed; analyze clean; full Flutter 667 passed; fresh debug APK built and installed. The only known suite failure is baseline and is not an M14 blocker.
- M14 is closed. Feature commit `d4fc8571959d92e17b139be936669f64c459b6d8` was merged to and pushed on `dev` as `5e288f0098543d486ee1c2010a8f8f7b765d8ff1`.
- M14 acceptance baseline includes inbox/read/unread, Firebase Admin sends, Samsung token lifecycle, Chat/Activity/Poll/Task/Finance/Fund producers, push taps/deep links, global/category suppression, group mute, critical bypass, open-chat suppression, and warm/background Samsung E2E. Cold-start push tap remains unverified. The one full-backend Fund JSON decimal assertion is confirmed on clean base and remains nonblocking.
- The M15 intake notes and plan below are superseded by the current M15 Phase C snapshot at the top of this file. The reminder delivery contract is recorded in `DEC-M15-01` and scheduler/idempotency semantics in `DEC-M15-03`; the live acceptance record is `M15-VER-01` in the decision log.
- Preserve/exclude `mobile/android/app/google-services.json`, both local-only docs, `.stitch/`, `.dev-runtime/`, `.dev-logs/`, and the protected stash.
