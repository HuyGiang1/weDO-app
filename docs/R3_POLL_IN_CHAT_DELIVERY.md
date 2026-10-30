# R3 Poll-in-Chat — resumed delivery

## Closure — user acceptance 2026-10-26

**R3 COMPLETE.** User's R4 request explicitly confirms physical QA iPhone Choice One/Samsung synchronization, participant list, anonymous privacy and Chat image/scroll stability PASS. Preserve exact user-reported scope; do not invent new agent actions, avatars used, timing or fixture details. Together with55 focused backend/198 Flutter/analyzer/build and recorded Samsung reconnect evidence this closes R3. Earlier pending statements below describe their historical checkpoints, not current status. R1 COMPLETE, R2 IN PROGRESS, R4 separately authorized/IN PROGRESS.

Date: 2026-10-25. Branch `feat/pre-m19-ui-polish`, HEAD `cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0` (uncommitted shared worktree).

**R1 COMPLETE; R2 IN PROGRESS; R3 IN PROGRESS; R4–R9 NOT STARTED.** This is implementation delivery, not final paired acceptance or a claim that all dirty files belong to R3.

## Checkpoint resume — history scroll correction and current acceptance scope

Recovered the existing implementation/candidates, verified disk~16GiB and runtime first, and preserved the user-reported QA iPhone receipt of Poll activities. No cleanup, new backend feature/schema, socket or Poll rewrite. Current Mac `en0=<QA_LAN_IP>`; dependencies/backend local and LAN health UP. Final disk~14GiB.

One genuine remaining defect was reproduced: inserting a Poll timeline item while scrolled upward moved historical content~50px. Only `chat_screen.dart` production changed in this resume: stable per-item zero-height anchor, restore an actual visible point after a coalesced frame, only while away from bottom/not manually scrolling; stale/disposed/detached render guards, no arbitrary timer, full history GET or bottom animation. Existing message/image keys and cache behavior remain. One new test in existing `chat_screen_test.dart` verifies a fully visible historical item remains at the same screen coordinate through a duplicate incoming activity while scrolled up. Initial fixed-index fixture assumptions were corrected, not suppressed.

Fresh final evidence: backend **55/55 PASS,0fail/error/skip**, Flutter **198 PASS/0FAIL**, analyzer **No issues found2.5s**. Same focused commands as UX section below; `/tmp/wedo-r3-checkpoint-{backend,flutter,analyze-final}.log`. Backend JAR unchanged/reused, not rebuilt unnecessarily. Android build9.0s/install-r/sessionPASS APK `5aaab2dda8799f11f09af2ef7b0ab36b34947e0b1b44a8f85cac8d3e01befd1a`; iOS release35.7s/install/launchQA iPhone onlyPASS Runner `833e9d23c9b6f0b2b1f6819a3caf6c9d08ecfa16c10afed8560f8fd9cd579930`. Same `.110:8080`; native signing hashes unchanged. No unsupported iOS runner retry. Production inventory SHA256 `75adf5e4c834e9d25063fe92632a6f87bec95c826e835fd3a13ff504ba470ebd`.

Current physical evidence:

| Check | Evidence / status |
| --- | --- |
| QA iPhone receives activity | User's earlier **“Có thấy”** retained PASS, exact visibility scope only. |
| Public Choice One peer vote | **PENDING**. User now says “Đã gửi”, but the new committed ballot is in the anonymous fixture, not linked public Poll; public original1/firstActivity1/changeActivity1 unchanged. Informed user, no fabricated public PASS. |
| Samsung anonymous vote/change | **PASS for observed UI**: newly labeled `R3 UX Anonymous QA`, canonical `78185a51-58c3-4272-ac87-a0b407057b5c`, group-only; two ballots total, own change gives1/1, no voter preview/list action or vote timeline. DB only originalPOLL1/activity0. Anonymous API/payload security is automated evidence, not a complete two-device physical privacy audit. |
| Samsung reconnect | **PASS**: Wi-Fi loss retains exact valid data, transient/read-only state; restored Wi-Fi automatically clears banner/reenables actions without Retry/reopen. Same public/anonymous message counts, no duplicate history. Wi-Fi restored `.182`. No expired-token scenario repeated. |
| Participant names/avatars | Prior Samsung public per-option names/initials PASS retained; current QA iPhone list/real-photo avatars **PENDING**. |
| Images / upward reading | Automated image state/cache/byte/history regression and new upward-anchor check PASS; current paired visual stability **PENDING**. |

Remaining manual gate on installed QA iPhone: choose the **public `R3 QA Linked Poll 25-10` above the anonymous card**, submit Choice One then change it, confirm one update per actual change on peer; open participant names/avatar list; inspect anonymous no voter identities; paired reconnect/closure and old-image/upward-reading stability. Do not delete/recreate fixtures or mark R3 COMPLETE from focused tests. All previous evidence below remains historical at its recorded candidate.

## Latest R3 UX redesign and controlled disk recovery (2026-10-25)

This section supersedes the initial slice's no-per-vote-Chat-row design below for **PUBLIC** Polls, under the user's explicit Zalo-inspired UX request. Original implementation/history/evidence are retained.

- Compact theme-aware bordered Poll surface replaces the nested Chat bubble/card: small icon/label, question, selected options, proportional allowed-result bars after voting/closure, unique participant count, bounded avatar preview, Bình chọn/Đổi bình chọn and details/results/close. Public voters/results now show permitted names/avatars per option; multiple-choice participants are counted once. Narrow280px light/dark tests pass.
- PUBLIC Chat-linked actual first vote/change atomically appends one `POLL_VOTED`/`POLL_VOTE_CHANGED` row, ordinary conversation sequence/unread semantics, stable UUID, localized content and canonical pollId. Original POLL remains unique. Existing MESSAGE_CREATED after-commit delivery/shared socket/Redis feeds the compact clickable timeline renderer; targeted Poll GET updates the original card without per-vote Chat history reload. Timeline activities cannot be edited/unsent.
- Same option set is a no-op. Optional vote `clientRequestId` is saved transactionally in new `poll_vote_commands` receipts; duplicate/delayed commands cannot reapply an older choice after a newer success. Poll lock serializes receipt/ballot changes. Legacy no-ID callers retain same-state no-op protection, not delayed-command identity. Current Flutter API supplies UUIDs; Chat card retains the same UUID after an uncertain failed submission and changes it for a new selection. No second vote store.
- **Anonymous privacy takes precedence over per-vote timeline activity:** no anonymous vote activity row, even generic, because sender/timing can identify voters. Existing actor-free hints continue aggregate convergence. Preview is empty and voters denied for anonymous Polls. PUBLIC AFTER_CLOSE voters/previews are also denied until results become visible. This anonymous exception is explicit, not an invented privacy-safe per-vote system sender or a fully accepted product gate.
- New forward-only **V14**, not a rewrite of applied V13. Validated isolated PostgreSQL first, then QA reports V13/V14 success. Before/after migration counts identical: users5, polls10, messages92, ballots11. Later own QA votes intentionally add rows. API/ERD/class diagram updated.
- Final focused backend **55/55 PASS,0fail/error/skip** (M8 28, ChatService14, ChatRealtime5, ChatController1, Coordinator6, PollService1), Flutter **197 PASS/0FAIL**, analyzer **clean3.0s**. Logs `/tmp/wedo-r3-ux-backend-final.log`, `/tmp/wedo-r3-ux-flutter-verified.log`, `/tmp/wedo-r3-ux-analyze-verified.log`. Same focused command families as below, backend adds PollServiceTest. New regressions cover actual change/no-op/delayed retry, rollback/concurrency, anonymous/hidden-result identity denial, receipt/sequence atomicity, names, narrow/themes, retry UUID, durable timeline insertion/reconnect dedupe plus old image state/cache/history/scroll checks. Intermediate fixture failures are superseded, not hidden final passes; no full suite.
- Build/packagePASS2.820s; Android debugPASS13.6s/install-r/session retained, APK `5b025718897d24d4a7034d03be1e3b136937f15014b2267e53edd47e60566597`; iOS releasePASS36.6s/install/launchQA iPhone only, Runner `94a478894d5df9e01667b3bdebacc227bc7c2196b2997d322f2f1e02162912c3`. API `.110:8080`, native signing hashes unchanged. Logs `/tmp/wedo-r3-ux-{package,android,ios}.log`. Secondary iPhone untouched; no repeated unsupported iOS UI automation.
- **Controlled disk cleanup removed NOTHING.** Prior audit~655MiB, interrupted pre-cleanup baseline660MiB. On resumed validation external state already had16.6GiB free, so Phase1/2 were skipped, editors left running, no root/system deletion attempted. All three Git fingerprints matched the pre-cleanup baseline (tracked diff/status/untracked content). Final post-test/build disk about16GiB, above5GiB safety floor. Do not attribute external recovery to agent deletion.
- PostgreSQL/Redis/MinIO local were healthy; backend/old LAN relay had stopped during interruption. Verified new JAR cold-start uses existing container credentials privately, unchanged local auth configuration, external Admin path, current LAN/media endpoint and disables fixture reseeding. Current backend PID77265 `/tmp/wedo-r3-ux-runtime.log`; local/LANhealthUP. Existing exact media relay/allowlist restarted unchanged, LAN MinIO ready succeeds; original buckets/S3 auth untouched. Temporary helper `/tmp/wedo-r3-ux-start-backend.py` is outside repo. No Docker restart/recreation/reset/financial mutation.
- Physical Samsung current candidate: authenticated Home loads; original group/linked cards show new layout/count/initial avatars; first vote on existing **R3 QA Linked Poll 25-10** visibly adds one durable “QA Member 1 đã tham gia bình chọn…” timeline item and count1. Earlier paired R3 slice observations below are not UX-redesign acceptance. Current iPhone build installed/launched but visible peer activity/anonymous/reconnect/image acceptance pending user observations.
- Samsung subsequent actual change One→Two visibly adds one “đã thay đổi bình chọn” item, original card0/1 and participant1. Read-only DB confirms exactly originalPOLL1/POLL_VOTED1/POLL_VOTE_CHANGED1 for this Poll. Tapping participant count opens per-option list with **QA Member 1** and initials under Choice Two, not the old selection. Physical first/change/name-list smoke PASS. In reply to the bounded QA iPhone question asking whether the first/change activity messages are visible, user answered **“Có thấy”**: record user-reported peer timeline visibility PASS only. This does not establish immediate delivery latency, exactly-once reconnect, a submitted iPhone vote, participant names/real-photo avatars on iPhone, or anonymous/image acceptance. No new QA Poll needed; existing linked fixture/history retained.
- Remaining gate: paired first/change activity exactly once, participant names/avatar behavior on both devices, anonymous no identity/timing activity, reopen/reconnect without duplicates, upward-scroll and old-image physical stability. Automated results are not physical PASS. Existing QA Polls/history kept; do not restart implementation/recreate fixtures or mark R3 COMPLETE solely from tests/builds.

## Recovery and scope

The interrupted activity-required slice was preserved and completed, not replaced. Recovered Chat controller/request/response/service, proposed V13, Poll service and Flutter composer/card/form/message plumbing were partial and unverified. Missing group-only ownership/history, migration compatibility, deadline idempotence, tests and deployment were completed here. Existing R1/R2 websocket/reliable-read/auth/image fixes remain intact; Task, Finance, signing and Firebase were not rewritten.

R3 implementation paths:

- Backend Chat: `ChatController`, `ChatRequests`, `ChatResponses`, `ChatService`.
- Backend Poll: `PollEntity`, `PollResponse`, `PollRepository`, `PollService`, new `GroupPollController`; migration `V13__chat_poll_reference.sql`.
- Flutter Chat: `chat_api.dart`, `chat_models.dart`, `chat_screen.dart`, new `chat_poll_card.dart`, `chat_poll_create_screen.dart`.
- Flutter Poll: `poll_models.dart`, `poll_api.dart`, `poll_repository.dart`, `poll_screens.dart` (retains earlier R2-A changes).
- Tests: existing `M8MultiAccountIntegrationTest.java`, existing `chat_screen_test.dart`, new `chat_poll_test.dart`. These files also include pre-existing regression work; their full HEAD diff is not this task's delta.
- Canonical docs: API blueprint, ERD and class diagram updated; roadmap/handoff updated without replacing history.

## Final contracts and behavior

`POST /api/v1/conversations/{id}/polls` accepts optional `activityId`, required `clientMessageId` (UUID) and the existing validated Poll draft. It returns the ordinary Chat Message DTO with nullable `pollId` added compatibly. GROUP conversations only; current authorized/mutable membership required. Optional Activity must belong to the same group. No hidden Activity or second ballot store.

Poll creation, options, sequence allocation, typed `POLL` message/reference and normal Chat event are one transaction. The existing sequence row serializes conversation writes. Retrying the same command UUID returns its existing same-sender/same-conversation Poll message; an unrelated ID collision is denied. Transaction rollback leaves no Poll/message/sequence/event. `EntityManager.flush` orders the canonical Poll before the JDBC message FK insert. Existing after-commit fan-out is reused; no second socket or vote-generated Chat message flood.

All Polls have canonical `groupId`; `activityId` is optional. Activity-linked Polls remain in Activity history; `GET /api/v1/groups/{id}/polls` returns authorized group history, including linked Polls. Database trigger preserves legacy Activity-only inserts by deriving their group and rejects mismatched linkage. Messages permit TEXT/IMAGE/POLL, with unique non-null reference required only for POLL. Existing text/image payloads remain readable. POLL text editing is disallowed; normal unsend hides the card without deleting the Poll/history.

Existing vote replacement, option validation, SINGLE/MULTIPLE, creator/manager close, anonymous-voter denial and result-visibility contracts are retained. Anonymous vote hints omit actor identity. Group-only Poll hints use `group:{id}`; linked hints use `activity:{id}` with the owning group. Subscription checks/revocation reuse the existing shared authorized transport and Redis fan-out. Group-only Polls use ordinary Chat notification delivery, not a fabricated Activity notification/deep link.

Deadline enforcement is server-authoritative even without an open UI. List reads project effective CLOSED after expiry **without writing every expired Poll**. Authorized single-detail/public-voter reads lock one Poll, materialize the transition once and publish a committed closure hint; repeated reads do not repeat it. An expired vote is rejected. There is no scheduler/polling: idle DB status may remain OPEN until an authorized detail read, while responses/actions already enforce expiry. The client reuses its existing one-shot deadline boundary refresh.

The composer always offers **Chỉ trong nhóm**, even if optional Activity lookup fails. Existing Activity selection is explicit and excludes completed/cancelled Activities for new linkage. A per-form UUID survives uncertain retry; double submission is guarded. The existing validated creation form is reused, with Chat-only multiple-choice control. Cards use `ReliableRead` and aggregate-filtered shared bindings: authoritative GET, first/change vote, results/detail/close, retained read-only transient cache, denial clears protected data, generation/dispose safety and reconnect/resync. A vote hint refreshes its card, not conversation history. Stable message keys, image providers, pagination and scroll reducer remain in place.

## Migration/runtime evidence

Before editing V13, QA `flyway_schema_history` had no V13 row. The corrected migration passed real fresh isolated PostgreSQL integration tests before packaging/deployment. QA then reports `13 | V13__chat_poll_reference.sql | success=true`. Do not rewrite this migration after this application; future corrections require a new forward migration.

Immediately before/after migration, existing counts were unchanged: users **5**, Polls **8**, messages **90**, ballots (`poll_votes`) **9**. A first diagnostic used the nonexistent name `poll_ballots`; corrected read-only query above succeeded. No reset, fixture deletion or volume recreation occurred. Subsequent explicitly labeled QA Poll/vote creation intentionally adds records; it is not migration data loss.

Mac `en0=<QA_LAN_IP>`; Samsung `<QA_LAN_IP>`. Backend packaged successfully (tests skipped only after final focused pass), existing backend process replaced with the verified JAR while copying runtime configuration in memory; new PID **37691**, log `/tmp/wedo-r3-runtime.log`. Local and LAN actuator health UP. Existing local PostgreSQL55432, Redis, MinIO/media relay, external Firebase credential and data retained. No credential content printed. The helper `/tmp/wedo-r3-resume-backend.py` is a restart helper requiring an existing backend, not a cold-start script.

## Verification

Backend command (isolated Testcontainers PostgreSQL):

```sh
GOOGLE_APPLICATION_CREDENTIALS=/tmp/wedo-r3-synthetic-adc.json GOOGLE_CLOUD_PROJECT=wedo-r3-test ./mvnw -Dtest=M8MultiAccountIntegrationTest,ChatServiceIntegrationTest,ChatRealtimeIntegrationTest,ChatControllerTest,DomainRealtimeCoordinatorTest test
```

**49 run, 49 PASS, 0 failures/errors/skips**: M8 23, ChatService14, ChatRealtime5, ChatController1, Coordinator6. Log `/tmp/wedo-r3-resumed-backend-final.log`. The external ADC contains synthetic test-only values, not the user's Admin key. Earlier intermediate failures/counts are superseded, not additional final passes.

Coverage includes atomic linked/group-only create, retry/concurrent UUID dedupe, rollback, group isolation/legacy ownership, same ballots/overlapping multiple replacement, anonymous results, expiry enforcement, idempotent detail closure and read-only list expiry. Existing after-commit/rollback/authorization tests are included; this does not claim every possible physical negative case.

```sh
flutter test --no-pub test/features/chat/presentation/chat_poll_test.dart test/features/chat/presentation/chat_screen_test.dart test/features/poll test/core/realtime --reporter expanded
flutter analyze --no-pub
```

**193 PASS, 0 FAIL; analyzer No issues found (3.0s)**. Logs `/tmp/wedo-r3-final-flutter.log`, `/tmp/wedo-r3-final-analyze.log`. Tests cover actual selector→form→atomic POST for linked/group-only (including Activity lookup503), card votes/multiple/privacy/close, hints/dedupe/ACK resync, denial/revocation, transient retention, stale/disposed responses and overlap. Chat regression asserts image State/provider and byte/auth GET counts, scroll offset and history requests are unchanged by Poll-only events; pagination tests retained. No full suite or deletion of `temp_test.dart`.

Builds after final focused results:

- Backend package PASS (5.877s), `/tmp/wedo-r3-package.log`; JAR SHA256 `f53ccd35a02a771a7d4eef32ed98198be47bd94cda2be0d6c121c095cddac392`.
- Android debug PASS (17.6s), API `http://<QA_LAN_IP>:8080`; install-r PASS/session retained. APK SHA256 `29b38b93ca6a8cb9c7e064555d4eca8cf71dd72050ca57285497fe274d20c400`. `/tmp/wedo-r3-android-build.log`. Existing Kotlin plugin compatibility warning did not fail build; no dependency migration in this slice.
- iOS release PASS (34.1s), same API; install-in-place and native launch on **QA iPhone only PASS**. Runner SHA256 `3cf87af02d3d1cf34cd033d02eb96294018a14e27dad35af239bdaa93bb9d313`. `/tmp/wedo-r3-ios-build.log`. Xcode project hash `ad773f3ca0646bfd2275f088c1b0eacefedc643e90c16249f05ccf4ce5c8c6b8`, Info.plist `cd88a3e2d1ee3b1c064d214026073303db8f11b2baa9e4dcc00811422ce8a8bd`, unchanged. No second iPhone action or repeated unsupported UI runner attempt.

## Physical evidence and remaining gate

Samsung actual UI: existing session retained, Home eventually loaded after runtime replacement (transient initial error recovered, not a reproduced persistent defect); shared QA chat opened; **Chỉ trong nhóm** selector→form→create produced **R3 QA Group Poll 25-10**, one card, canonical Poll `ba13b568-892e-4eb7-8e6b-5b4f7751d349`, message `a647732f-ed3b-4bae-9a84-1c4a6b95916c`, null Activity and correct group. First vote changed visible total0→1. Later, without Chat manual refresh, peer voting changed the Samsung card to total2, A1/B1. User explicitly reports on QA iPhone: **“Đã thấy cập nhật phiếu”** after being asked to open this exact card/vote. This supports real paired card/vote synchronization, not the whole R3 acceptance matrix.

Samsung group history shows this Poll with the same current results and existing Activity Polls. A subsequent actual Samsung change-vote produced A2/B0, total2, without a duplicate card/ballot. Peer observation of that exact change remains pending. Do not infer a deadline, reconnect or privacy physical PASS from first vote/peer synchronization; those are automated unless separately recorded below.

Samsung also created **R3 QA Linked Poll 25-10** through the existing **R2A QA 25-10** selector; visible card and group history PASS. Canonical Poll `6b4de6eb-3052-40a5-80d8-1736c44ecc3c`, message `eaecccdd-8b5e-4702-832d-61984cc8ed9e`, Activity `71bdfaea-29c5-43bf-9467-fd38d1b3ad5f`, same owning group verified by read-only SQL. Its Activity-history rendering and peer interaction remain unobserved physically; isolated backend history/Flutter paths pass. Final Samsung left online in shared Chat; QA iPhone installed/launched, no unsupported runner loop. Final backend LAN health UP and existing LAN MinIO ready endpoint succeeds.

Still required before R3 COMPLETE:

1. Two-device change-vote convergence and manual close→both read-only; confirm one card after reopening/reconnect.
2. Use existing **R3 QA Linked Poll 25-10** (already created), verify the same Poll in Activity history and peer Chat. Group history and correct linkage are already observed; do not create duplicates or use/change a real outing Poll.
3. R3-specific offline/reconnect, anonymous/AFTER_CLOSE and deadline UI acceptance; protected revocation remains automated unless a safe explicitly approved membership fixture exists.
4. Observe old images/scroll during actual Poll updates and text traffic on both platforms; automated provider/request/state checks are PASS, earlier R1 physical image evidence is not fresh R3 evidence.

No new production blocker known at this checkpoint; acceptance remains pending. User can perform QA iPhone observations; do not repeatedly debug the unavailable iOS UI automation stack. Keep current runtime/candidates/data for this bounded gate. R2-A peer Task and iOS edge-path gaps remain separate, R4–R9 have not started.

## Safety/closeout

Full dirty worktree and protected stash retained; index empty, no commit/push/merge/reset/restore/stash/clean. Full-tree `git diff --check` still reports pre-existing EOF blank lines in group/profile tests outside this slice; scoped changed-path check is clean, do not fix unrelated edits. Final production inventory (`rg --files backend/src/main mobile/lib | sort | xargs shasum -a 256 | shasum -a 256`) is `00b0c66263f6bd3261a5fc3082e1208dbfca3cdeb25cee03cbcf59ea2209b6b9`. Temporary helpers/logs remain outside the repository. Disk was about1.1GiB before builds, about1.0GiB afterward: no cache cleanup or Docker pruning performed; monitor space before further builds. Existing source/signing/Firebase/data preserved.
