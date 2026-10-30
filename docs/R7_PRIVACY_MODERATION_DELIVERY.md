# R7 Privacy & Moderation delivery

Date2026-10-27 (Asia/Ho_Chi_Minh). Branch `feat/pre-m19-ui-polish`, HEAD
`cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`. R1/R3/R4/R5/R6 COMPLETE;
R2 IN PROGRESS; **R7 COMPLETE**; R8/R9 NOT STARTED. Entire existing dirty worktree preserved.
No commit/push/merge/reset/restore/stash/clean, finance/signing/Firebase changes,
second iPhone actions or Docker/media cleanup. R6 acceptance is retained exactly.

## Reused foundations / initial audit

| Capability before R7 | Initial state | R7 outcome/evidence |
| --- | --- | --- |
| Four visibility modes, FOF graph, block precedence | VERIFIED by R5/R6 focused evidence | Retained shared CommunityAccess predicate before pagination/detail/media/interaction/profile/recruitment discovery/socket; current focused regressions PASS |
| Block/unblock/list REST and profile controls | VERIFIED, Community management entry PARTIAL | Existing BlockService/Social API unchanged; added Community card block and paged blocked-users management; unit/widget checks PASS |
| Private Moments / signed media | VERIFIED | Existing membership-only Moments remains separate;12 PostgreSQL Moment tests PASS; no Moment key republishing or public preview bypass |
| Post hide/report | PARTIAL: personal hide/post-only structured reports, no reviewer workflow | Extended same table; new hidden-post management/unhide and canonical report submission reuse |
| User/comment reports | MISSING | Implemented authenticated structured target-specific reports with eligibility checks |
| Explicit global moderator / authorized queue / audit | MISSING | V18 role grants + current group-only manager boundary, queue/actions/history/evidence media |
| Shared socket/AFTER_COMMIT/privacy caches | VERIFIED foundation | Reused; manager-only own moderation scope, delivery checks, immediate cache clearing before deferred REST |

For You remains ALL eligible posts (including own eligible private posts). Friends
is overlapping direct-author filter, never a visibility bucket. R5 COMPLETE is
preserved from its documented evidence-based closure, not silently inferred here.

## Privacy / surfaces

- CommunityAccess remains authoritative for For You/Friends/profile/detail/media,
  reactions/comments and socket. Recruitment search/filter/cursor excludes
  ineligible and non-OPEN listings before LIMIT; expired/full/closed post detail
  remains readable when audience permits, but new recruitment entry is denied.
- Community has no separate global text-search or ordinary post-notification body
  pipeline today; recruitment keyword search uses canonical eligibility. R7 does
  not add an unfiltered search index or broadcast report evidence in Notifications.
  Existing canonical group approval notifications stay recipient-specific.
- Bidirectional blocks override all Community audiences and filter comment/reaction
  actors. FOF requires actual active graph/unblocked bridge. Membership/ban loss
  prevents GROUP_ONLY reads and private Moments access. Global moderator evidence
  is a narrowly authorized report exception, not ordinary member/public access.
- Existing Chat policy retained: blocking ends direct friendship/pending friend/DM
  requests; shared-group records and authorized group interaction remain intact.
  It does not retroactively remove members or rewrite Chat/financial history.
  Existing recruitment approval guard rechecks bans/blocks/current policy; pending
  requests are historical canonical facts, not an automatic membership grant.
  Unblock does not recreate friendships or replay pending approvals.
- No precise/live location, phone, private Chat/member/finance DTO in public previews.
  No new public URL or hard deletion of shared object bytes.

## Reports and lifecycle

Reuse `community_reports`, extended targets POST/COMMENT/USER. COMMENT records its
canonical post context, validated both by service and SQL trigger. USER targets an
active other user, never creates account-ban powers. Reasons SPAM, HARASSMENT,
INAPPROPRIATE_CONTENT, SCAM, OTHER; legacy INAPPROPRIATE input remains compatible
and is normalized. Existing reason/evidence rows are migrated forward.

One OPEN report per reporter/target/type via partial unique index. Concurrent
submissions converge; after resolution another report is allowed. First active
report reason is retained. Reporter FK persists but no reporter identity in public
or moderator DTOs/events. Reporting does not hide/delete/quarantine automatically.
Hide affects only the requester; no other-user removal. Unhide is authenticated,
idempotent, and cannot override a block/audience/removal. Hidden management only
returns currently eligible hidden IDs/captions, never stale private metadata.

Canonical content status remains ACTIVE/REMOVED; user-facing ACTIVE = visible if
otherwise eligible. OPEN report is under review, not a separate content state.
RESTORE returns content to ACTIVE with an immutable RESTORE audit entry; it does
not undo author deletion, change audience, restore friendships or reopen a manually
closed recruitment. Under-review does not automatically suppress speech or accounts.

## Authorization and moderation

`community_moderators` is an explicit operator-provisioned, revocable global role.
No public grant API/default seed/global role inferred from group ownership.
The user explicitly approved QA Owner for local moderator acceptance in this task;
one row was added only AFTER isolated V18 tests and QA backup. `granted_by` and
`granted_at` retained; revoke with `revoked_at`, do not delete grant/audit history.
Operator grant changes require a fresh capability/queue read or resubscription;
all reads/actions/deliveries recheck current grant. This is not an account-ban role.

Current unbanned Owner/Admin of an ACTIVE group can review ONLY GROUP_ONLY post/
comment reports belonging to that group. A public recruitment's linked group does
not confer global moderation over its post. USER reports require global moderator.
Read capability flags from backend; ordinary users do not get queue navigation.
Group managers may see a filtered empty queue, not global/public reports.

Queue filters status/reason/type;20-row cursor ordering(created_at,id). Cursor must
itself be in reviewer scope. Detail exposes minimal captured text evidence, current
content state, backend allowed actions and immutable action history; POST media
metadata uses stable IDs, never raw keys. Reviewer-only media URL issuance checks
report scope AND matching post/media every time;60-second signed GET, including
removed evidence where permitted, never author-deleted bytes. Revoked/unrelated/
ordinary requests denied. Previously issued signed URLs retain ≤60-second residual
validity; no claim of instantaneous remote-byte revocation.

DISMISS/RESOLVE close an OPEN report without deleting content. REMOVE/RESTORE act on
post/comment status; USER REMOVE/RESTORE forbidden. No irreversible account ban.
Per-report row lock plus target row lock, UUID command receipt/audit id, actor/action/
reason consistency and rechecked authorization prevent duplicate commands/stale
role writes. No ledger/schema/group membership mutations. Concurrent identical
commands produce one audit. Author-deleted content cannot be restored by moderator.

## REST contract

Authenticated `/api/v1` base; successful JSON200 (existing block POST/DELETE204).

| Endpoint | Purpose |
| --- | --- |
| GET `/moderation/access` | globalModerator / canReview flags |
| GET `/moderation/reports?status=&reason=&type=&before=` | scoped cursor queue |
| GET `/moderation/reports/{id}` | authorized evidence/status/actions/history/media IDs |
| POST `/moderation/reports/{id}/actions` | clientRequestId UUID, action, nonblank reason≤1000 |
| GET `/moderation/reports/{id}/media/{media}/access` | exact report-scoped reviewer signed GET60s |
| POST `/users/{id}/reports` | structured reason, canonical user target |
| POST `/community/comments/{id}/reports` | readable/unblocked comment target |
| POST `/community/posts/{id}/reports` | existing post/recruitment report, same canonical table |
| GET `/community/hidden-posts?before=` | eligible personal hidden list |
| DELETE `/community/posts/{id}/hidden` | authenticated unhide |
| POST/DELETE `/users/{id}/block`; GET `/me/blocked-users` | unchanged canonical Social APIs |

## Realtime / cache behavior

Existing Redis/shared socket and AFTER_COMMIT publication only. `moderation:<own
user UUID>` requires current review capability. `MODERATION_QUEUE_CHANGED` sends
report ID/empty payload only to relevant global/group reviewers, with report scope
rechecked immediately before delivery. No ordinary report evidence/reporter frames.
Group/privacy changes resync/revoke moderator scopes; group reviewer loss filters
out previous group evidence. Removal/restoration uses existing COMMUNITY_POST_UPDATED
or COMMENT_CHANGED, triggering ordinary content scope revocation/refetch and
policy invalidation; no full-feed reload for each report submission.

Flutter new Safety Center, paged blocked/hidden lists, structured post/user/comment
reports, scoped moderation queue with filters, evidence/media/detail/actions/history.
Light/dark/narrow checks PASS. Existing ReliableRead rejects stale/disposed reads;
moderation mutation responses additionally compare read generation. A minimal
RealtimeBinding hook lets these new screens clear permission-sensitive evidence
synchronously before existing coalesced REST refetch; default behavior of other
screens unchanged. Offline errors do not become empty success, known denial clears
protected data, reconnect obtains authoritative state. No added timers/polling/socket
or automatic replay of a moderation mutation.

## Verification

- **68 unique backend checks PASS,0fail/error/skip** across Moderation13,
  Community13, CommunityRealtime6, DomainCoordinator6, BlockService6,
  Recruitment12, Moment12. Logs `/tmp/wedo-r7-backend-final.log`, latest13 rerun
  `/tmp/wedo-r7-moderation-final.log` after evidence-media/concurrent-command additions,
  `/tmp/wedo-r7-moments.log`. Isolated PostgreSQL/Flyway18 tested before QA.
- **244 Flutter PASS**: Community/Recruitment/new Moderation, core realtime,
  Chat/Poll rendering and Moments. Final narrow moderator filtering/style change
  rerun **15/15 PASS**, not counted as15 additional unique tests.
  `/tmp/wedo-r7-flutter-final.log`, `/tmp/wedo-r7-widget-final.log`.
- Analyzer clean2.7s `/tmp/wedo-r7-analyze-clean.log`.
- Initial widget HTTP-only test waited on fake clock; test corrected with runAsync,
  only its own runner terminated and bounded final run passed. No runtime defect
  inferred. Initial analyzer missing Json import/style issues corrected.
- Backend package PASS4.687s. Android debug18.8s, install-r/launchPASS; APK
  `439aad8a6552800c4b9a22a2980b4adeca37f5eb60696532fc23a988be33aa40`.
- iOS release56.0s/install/launchQA iPhone PASS; Runner
  `acecdea7b3a60665661e3fc85f5d5f853cfc948919e52a7128505252d96336cb`.
  Native pbxproj/Info.plist hashes unchanged from R6; no unsupported runner retry.

## QA runtime / actual acceptance checkpoint

Mac<QA_LAN_IP>, Samsung<QA_LAN_IP>, QA iPhone prior verified<QA_LAN_IP>; same current
LAN candidates. BackendPID86087 `/tmp/wedo-r7-runtime.log`, tool session44592,
current LAN/media/local profile, reseedingOFF, credentials privately retained.
First detached shell did not start; old healthy backend stayed running until the
persistent-session launch succeeded. Existing Docker/volumes/MinIO exact-device
relay unchanged. No subnet expansion.12GiB free before build.

V18 applied success=true after isolated tests; **do not edit applied V13–V18**.
Backup `/tmp/wedo-r7-before-v18.dump`336650B/mode0600. Pre/post migration identical:
users5, CommunityPosts4, reports0, memberships21, Moments3. Subsequent new labeled
fixtures via APIs only, no old record/media deletion. One explicitly approved Owner
moderator row. No implicit role grant to any other group Owner/Admin.

New fixture `/tmp/wedo-r7-fixture.json`mode0600:
- Member2 PUBLIC image **R7 QA Privacy Blue**, post
  `b611a54d-7a1a-4fb2-8075-f80a1f18d952`; synthetic128px blue PNG, no personal image.
- Owner PUBLIC **R7 QA Recruitment Moderation**,
  `0b31ecbf-d906-43f1-ac1b-3dc01401505c`; same separate R6 QA group. Existing closed
  and rejected R6 fixtures unchanged. No new join request unless expressly tested.
- Member1↔Member2 confirmed0 active friendship before block test, so no main
  Owner/Member1 friendship is ended. Shared-group records retained.
- Separate normal terminal QA sessions, no phone-session borrowing/logout. Helpers
  `/tmp/wedo-r7-{deploy,create-fixtures,runtime-check}.py`, secrets remain outside
  repo and unprinted. Existing outsider default not present in current seeder;
  selected known Member2 instead, with verified safe relationship scope.

Actual runtime checks: Owner global=true; Member1 global=false/canReview=false,
queue403. Member2 global=false/canReview=true because of another group role; filtered
queue is legitimate, not global authority. Member1 pre-block post200/media200 and
actual authorized PNG bytes PASS; recruitment preview200. **Not physical UI PASS**.
User currently asked on Samsung: view blue image, block Member2, confirm post gone,
then pause before unblock for independent post/media denial checks.

## Physical acceptance — pending unless explicitly recorded

| Gate | Current evidence |
| --- | --- |
| Blue image visible, block→post gone | PASS user reports “ảnh thấy; đã chặn; bài biến mất” on Samsung; no extra physical step inferred |
| Blocked direct post/media denied | PASS correlated current runtime: separate normal Member1 session post404/media404 after physical block; ordinary moderator queue still403 |
| Unblock→eligible post returns | PASS user “bỏ chặn OK; đã báo cáo”; current normal Member1 post200/media200 and PNG bytes corroborate |
| User SPAM report→Owner queue | Samsung submission physical PASS; runtime OPEN/SPAM report `982d3c29-e2c5-45bd-b669-db6f4f977c2b` persisted and returned by Owner authorized queue. Owner UI queue/remove still CHƯA TEST |
| Ordinary-user queue denied | Runtime Member1 HTTP403 + widget denial PASS; no invented physical tap |
| Owner removes→Samsung post disappears | Owner user-operated action corroborated by REMOVED/REVIEWED and one REMOVE audit reason “R7 QA SPAM”; ordinary post/media404. User reports both devices no longer see removed content, exact wording confirmation requested before declaring peer physical PASS |
| Removed recruitment cannot admit | PASS current-runtime API fixture: Member2 SPAM report→explicit Owner moderator REMOVE on dedicated R7 recruitment; outsider preview404/join404, memberships21 and0 pending in dedicated group unchanged. Terminal evidence, not physical device tap |
| Reconnect no leak + adjacent Chat/Poll/Moments/Recruitment | Focused regression PASS; current R7 physical CHƯA TEST |

R7 remains IN PROGRESS pending actual paired acceptance. Physical negative role-loss,
ban/expiry/concurrent-action matrix is isolated automated evidence, not fabricated
main-group removals. User-report resolution does not implement irreversible account
bans. Existing group-private Moments management remains its canonical membership/
creator/Owner/Admin path, not a new global public feed. R8/R9 not started; remaining
R2 parity remains separately IN PROGRESS. Source/disk/session/runtime safety intact.

### Physical delta — Samsung block confirmed

User confirms blue image visible then block author makes post disappear. Separate
Member1 REST post/media both404, versus both200 before block; queue403 remains.
User now asked to unblock via Safety Center, verify eligible image returns and
submit SPAM. That next step remains PENDING. R7 IN PROGRESS, no source/build/test
rerun or change to previous milestone statuses.

### Confirmed R7 refresh defect and bounded backend fix

User confirms unblock/image return and report submission, but observes QA iPhone reloads
once on Samsung block AND unblock. Runtime corroborates restored post/media200,
authorized PNG bytes, canonical OPEN/SPAM report, ordinary Member1 queue403.
No source work resumed without this newly reproduced defect.

Actual isolated socket/PostgreSQL reproduction failed before fix: unrelated Owner
Community feed, open post and moderator scope received privacy invalidations despite
no friendship edge and unchanged eligibility. Original coordinator treated every
FRIEND_* as a global Community/moderator resync. BlockService emits two recipient
relationship events; coalescing made this visible as one reload. No UI crash or
private-content exposure is inferred from the observation.

Minimal fix uses actual canonical friendship UPDATE row count: when block ends an
edge, retain broad graph recheck (third-party FOF may lose permission). When no edge
is ended, emit existing relationship event with server metadata
`communityPolicyScope=RECIPIENT_ONLY` to each involved user. Unblock never recreates
friendship, so its Community policy scope is likewise recipient-only. Coordinator
limits those policy/refetch signals and personal COMMUNITY_POLICY_CHANGED (hide/
unhide) to recipient; involved users still revoke/refetch protected data. Default/
legacy graph events remain conservative/broad. No identifiers/report bodies added
to public feed hints, no new socket/schema/timer/client feature.

Focused **34/34 PASS**: Moderation15 (including two new actual-service/socket cases),
CommunityRealtime7 (including personal-hide isolation), DomainCoordinator6, Block6.
New cases prove unrelated Owner feed/post/moderation gets ZERO frames for nonfriend
block/unblock, involved requester still loses/regains access and gets policy hints,
and true friendship block STILL revokes third-party FOF. Log
`/tmp/wedo-r7-refresh-fix-tests.log`; red reproduction
`/tmp/wedo-r7-refresh-repro.log`. Combined unique backend coverage now71 tests across
this task, not68+34 repeated tests. Flutter244/analyzer-clean/current installations
remain valid; no Dart/native change or mobile rebuild. Backend packagePASS3.257s;
only current weDO JAR restarted, fresh log `/tmp/wedo-r7-refresh-runtime.log`,
persistent session77794. V18/grants/reports/media/phone sessions unchanged.
Physical no-extra-iPhone-reload retest still pending; do not infer it from sockets.

Latest backend refresh-hotfix runtime verified: PID2417, session77794, local/LAN
healthUP, current LAN<QA_LAN_IP>; supersedes original R7 PID86087 only. Physical
questions pending: nonfriend block/unblock no-extra-QA iPhone-reload and Owner SPAM
queue/remove→Samsung automatic removal. Neither is inferred from34 backend PASS.

### Latest physical / runtime delta — moderator removal

User confirms “không còn load lại” for the exact Samsung block/unblock with QA iPhone
Community observation: no-unrelated-reload physical PASS. They then report Samsung
reloaded and did not see removed content, same on iPhone. Exact wording confirmation
requested: do both no longer show blue post? Do not invent screenshots or a separate
manual refresh. Read-only SQL confirms blue post REMOVED/report REVIEWED/SPAM,
exactly one REMOVE audit reason “R7 QA SPAM”; independent normal Member1 post/media404,
ordinary queue403. Owner action is actual user-operated evidence plus DB corroboration.

Dedicated recruitment fixture was then reported SPAM by separate Member2 session and
removed using approved Owner global moderator via normal API, command receipt
`/tmp/wedo-r7-recruitment-removal.json`mode0600. Helper
`/tmp/wedo-r7-removed-recruitment-check.py`. Stranger preview/join404; canonical
memberships remain21 and dedicated group pending requests0. No main demo group
mutation or financial/media deletion. Blue post and recruitment removal reversible;
objects/audits retained. User asked final Samsung offline/reconnect no-resurrection
and current Chat/Poll/Moments/ordinary Recruitment smoke. Those remain PENDING.
R7 stays IN PROGRESS until exact remaining physical gate; no further source/builds.


## Final unchanged-DoD closure — 2026-10-27

**R7 COMPLETE.** User explicitly confirms “bài ảnh xanh đã biến mất trên cả Samsung
và iPhone” and “reconnect không lộ bài; smoke OK” in response to the exact Samsung
Wi-Fi off/on and Chat/Poll/Khoảnh khắc-Album/ordinary Recruitment checklist. These
are genuine user-operated observations, not agent UI captures or inferred automated
physical PASS. They supersede earlier pending/wording-confirmation checkpoints.

| Final acceptance gate | Evidence / result |
| --- | --- |
| Eligible public blue image | User Samsung image visible PASS; pre-block API post/media200 and actual PNG bytes |
| Block author / loss of post | User Samsung post disappears PASS; Member1 direct post/media404 |
| Unblock | User eligible post/image returns PASS; API200/PNG corroboration |
| No unrelated QA iPhone reload | User exact block/unblock retest “không còn load lại” PASS after backend hotfix |
| SPAM report persistence | User submission PASS; canonical report982d3c29-e2c5-45bd-b669-db6f4f977c2b OPEN/SPAM, scoped Owner queue API |
| Explicit authorized moderation | User QA iPhone Owner REMOVE with audit “R7 QA SPAM”; only user-approved QA global role, no implicit other-group privilege |
| Ordinary-user queue denial | Current Member1 queue403 + focused backend/widget authorization PASS; no claimed physical route manipulation |
| Removed post converges on pair | User explicitly confirms blue post gone on both phones PASS; REMOVED/REVIEWED and one audit, direct post/media404 |
| Removed recruitment entry denied | Normal QA API-only fixture removal; true outsider preview404/join404, memberships21/pending0 unchanged; not a claimed physical join tap |
| Reconnect no resurrection | User Samsung Wi-Fi off/on “reconnect không lộ bài” PASS |
| Adjacent regression | User current Chat/Poll/Khoảnh khắc-Album/Recruitment “smoke OK” PASS; no extra finance/action scenario invented |

Unchanged DoD review: shared visibility/block predicate across all implemented
ordinary access paths and pagination verified by focused matrix; reporting/reviewer
scope/actions durable and auditable; automated matrix plus exact physical core
above pass; no private/live location projection added.71 unique backend checks,
244 Flutter checks, analyzer clean and installed Android/iOS retained. Latest34
backend checks include actual nonfriend block routing and preserved third-party FOF
revocation; no mobile changes after its verified build. No DoD text removed/relaxed.

Limits retained: restore/dismiss/user/comment-report, role-loss/concurrency/private
negative edge cases are automated evidence, not fabricated physical actions on main
demo users. Already-issued signed media URLs retain documented≤60second residual
access; new unauthorized issuance denied, global review evidence strictly scoped.
No irreversible account bans, automated AI moderation, R8 ranking or production
hardening claim. R2 remains IN PROGRESS; R8/R9 NOT STARTED. Broader cross-platform
negative/performance matrix belongs to R9. No further source/build/suite rerun for
this documentation closure. Keep runtime, candidates, explicit QA grant, soft-removed
fixtures/audits/object bytes and entire dirty worktree intact; no Git publication.
