# R4 acceptance gate → R5 Community Core

Date: 2026-10-27. Branch `feat/pre-m19-ui-polish`; HEAD
`cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`. Entire pre-existing dirty worktree
preserved. R1 COMPLETE; R2 IN PROGRESS; R3 COMPLETE; **R4/R5 COMPLETE;
R6 IN PROGRESS; R7–R9 NOT STARTED**.

## Final R5 closure — 2026-10-27

**R5 COMPLETE; R6 IN PROGRESS.** This supersedes historical pending statuses below without rewriting the DoD. Existing user PUBLIC image/reaction/comment realtime, own mixed eligible For You feed, keyboard dismissal and Samsung reconnect PASS are retained. The R6 delivery request explicitly permits isolated automated evidence where shared physical fixtures are unsafe: remaining privacy/block/media matrix, actual socket edit/delete convergence, hide/report persistence and cursor/scroll tests now pass. [Exact evidence and physical exclusions](R6_RECRUITMENT_JOIN_DELIVERY.md#r5-short-acceptance-decision). Combined relevant regression59 backend/272 Flutter PASS, analyzer clean. Unperformed physical negative/edit-delete/long-feed cases are R9 follow-up, not claimed physical PASS. Moments remains separate; no R7 moderation workflow or R8 ranking claimed.

## R4 decision is separate

**Final decision: COMPLETE.** User subsequently explicitly replied “Album OK,
chat OK, Poll OK, RSVP Ok.” to the requested same-Album photo/video and current
adjacent smoke gate. [Unchanged-DoD review and exact scope](R4_MOMENTS_ALBUM_DELIVERY.md#final-closure--2026-10-27-supersedes-pending-checkpoints-below).
Retained R4 isolated privacy/revocation tests and current runtime anonymous
Moment401 supply authorization evidence; not a physical removed-member PASS.
Initial pending gate/network notes below are historical and do not supersede
this closure. No R4 test-suite rerun or main-group membership change.

Retain the exact [R4 evidence](R4_MOMENTS_ALBUM_DELIVERY.md): Samsung photo/video,
Album/linking/offline recovery; user QA iPhone photo/reaction/comment, video play/seek
and reopen persistence. “Vẫn còn” did not separately confirm opening both media
from the SAME Album. Remaining mandatory short gate is same-Album media on QA iPhone,
brief current-candidate Chat/RSVP/Poll smoke and unauthorized access evidence.
Existing isolated R4 isolation/revocation tests remain valid; no repeat of the
completed R4 backend/Flutter suites or removal of main demo group members.

At R5 intake Mac changed to<QA_LAN_IP> and Samsung<QA_LAN_IP>, while installed
R4 candidates targeted<QA_HOTSPOT_IP>. A stale endpoint is an environment condition,
not an invented application regression. Independent R5 implementation proceeds
as explicitly authorized. Do not silently mark R4 COMPLETE from R5 test results.

## Inventory and implemented slice

No existing Community schema/backend/Flutter feature was found. Private group
Moments remains separate and unchanged. R5 reuses active users, friendships,
blocks, group membership, signed object storage/upload streams, R4 image renderer,
ReliableRead and the existing authenticated WebSocket/Redis AFTER_COMMIT workers.

V16 adds `community_posts`, `community_media`, `community_reactions`,
`community_comments`, `community_hidden_posts`, `community_reports`. GENERAL is
the only implemented post type; the named column permits a forward migration for
R6, not fake LOOKING_FOR_MEMBERS data. UUID commands make creation/comments
idempotent; post row lock serializes interactions. Stable cursor `(created_at,id)`,
20 rows/page; predicate applied before LIMIT and to cursor lookup. Soft delete
and audit retain rows/objects; no automated media deletion or fixture reset.

## REST contract

Authenticated `/api/v1/community`:

| Method | Path | Behavior |
|---|---|---|
| GET | `/posts?feed=FOR_YOU\|FRIENDS\|PROFILE&authorId=&before=` | Eligibility-filtered cursor feed; PROFILE requires authorId |
| POST | `/posts` | `clientRequestId,caption,visibility,groupId,mediaKeys` |
| GET/PATCH/DELETE | `/posts/{id}` | Detail; edit caption/visibility/group; soft delete |
| PUT | `/posts/{id}/reaction` | Existing six emoji or null; one per viewer |
| GET/POST | `/posts/{id}/comments` | Cursor read / UUID-idempotent `clientRequestId,content` |
| DELETE | `/posts/{id}/comments/{comment}` | Comment author or authorized post moderator |
| PUT | `/posts/{id}/hidden` | Idempotent personal hide; no global deletion |
| POST | `/posts/{id}/reports` | Structured `reason`: SPAM/HARASSMENT/INAPPROPRIATE/OTHER; one report/viewer/post |
| GET | `/media/{id}/access` | Current authorized60-second signed GET |

Page `items,nextBefore,hasMore`. Post includes author public summary, caption,
GENERAL type, visibility/groupId, timestamps, media IDs/type/name/size/order,
viewer-safe counts/myReaction, moderationStatus and projected permissions.
No object keys, credentials or location fields in post/comment read DTOs.
Successful REST defaults200. Caption5000, comment2000, max8 images/post.

## Visibility and moderation baseline

`CommunityAccess.ELIGIBLE` is reused by feed/detail/media/interactions/profile
post lists and realtime authorization. Authenticated active user and active author,
live ACTIVE post and not personally hidden; bidirectional blocks override all
visibility. Counts and comment pages also exclude blocked/inactive actors.

| Visibility | Eligibility |
|---|---|
| PUBLIC | Any active unblocked viewer |
| FRIENDS | Author or direct ACTIVE friendship |
| FRIENDS_OF_FRIENDS | Author/direct friend or confirmed two-hop ACTIVE graph; active bridge, no blocked intermediate edge |
| GROUP_ONLY | Required valid group FK plus active readable membership, nondeleted group and no current ban; author has no membership bypass |

**User update2026-10-27:** For You mixes ALL posts the current viewer may read,
including their own FRIENDS/FOF/GROUP_ONLY posts; visibility is server-side
eligibility, not an exclusive tab bucket. Friends adds direct-author friendship
as a convenience filter and overlaps For You. Own posts also remain accessible
through “Bài viết của tôi”. Profile post lists reuse the same
predicate; avatar/name taps use existing public profile routing, whose established
profile contract is unchanged. No location collection/ranking/recruitment rules.

Publishing GROUP_ONLY requires mutable membership and matching group relationship.
Creator edits/deletes; current group Owner/Admin may moderate GROUP_ONLY content,
but may not republish another author's protected media into PUBLIC. Archived group
content is read-only. There is no invented global admin role. Hide affects only
the viewer. Reporting records OPEN status and structured reason, does not itself
hide/remove another user's post, and exposes no reports inbox to ordinary users.
Full review/dashboard, user-report API (none existed), appeals and global moderation
are R7 follow-up. No main QA friendship/block/membership mutation for testing.

## Images

Existing presign upload gains COMMUNITY_IMAGE with contextId authenticated uploader
UUID, never trusted group ownership. Match JPEG/JPG, PNG or WebP MIME/extension,
declared metadata/actual size and uploader/context; default10MiB/image, max8/post.
Own namespace and authorization prevent reusing a guessed private Moment object
as public content. No automatic object copies or duplicate media store; separate
explicit publications upload their selected images. R4 native video is unchanged;
Community video is deliberately outside this coherent image-post MVP.

New media reads return stable IDs, signed URLs only after current post eligibility.
Existing60-second residual validity of already-issued URLs remains, not immediate
cryptographic revocation. UI removes protected visible state on scope loss/policy
change, with generation/disposal guards. As with R4, existing storage validates
metadata rather than decoding file bytes; no transcoder/orphan-object collector.

## Realtime

Use existing DOMAIN_CHANGED/AFTER_COMMIT/Redis only. No separate socket/polling.
Community scopes are `community:<own-user-id>` for availability/policy hints and
`post:<post-id>` for currently authorized visible content. Scope authorization
uses the same predicate at subscribe and delivery. Newly committed posts create
an availability hint only for eligible feed viewers; payload/actor are empty.
Visible post reaction/comment events target only its resource, not the whole feed.

Post edit/delete sends actor/post-free policy hints to subscribed Community feeds,
and targeted authorized detail invalidations/revocations. Friendship/block/group
events recheck Community scopes, including two-hop graph effects; generic policy
hints contain only the recipient's UUID, never a private author's/post's ID.
Client clears protected feed DTOs immediately before refetch even when offline.
Per-scope event IDs are deterministic derivations of the original mutation eventId
to avoid the client's cross-scope duplicate suppression dropping a second frame;
no aggregate versions invented. Existing bounded best-effort worker semantics
remain; no new durable outbox/replay claim.

## Flutter

Home “Cộng đồng” action opens an authenticated dedicated route. For You/Friends,
own/author post lists, compact theme-aware cards, relative time, native cached
image grid/fullscreen, caption/multi-image composer/progress/retry, four visibility
choices, actual group selector, detail/comments, react/unreact, edit/delete,
hide/structured report. Find People destination clearly states R6 is upcoming;
no fake recruitment listings. Main Group Chat/Moments navigation unchanged.

Stable post/media keys preserve image widget/signing identity through reactions.
Incoming posts show “Có bài viết mới”, no forced scroll command or feed REST call.
Refresh resyncs the previously loaded page depth, preserving authoritative older
pages; generation-owned cursor updates reject late responses. Transient reads
retain labeled read-only valid data;401/403/404 clears it. Failed upload/write
retries retain successful upload keys and command IDs. No automatic mutation replay.

## Verification completed

**Latest user-feedback correction:** user observed FRIENDS post on Member's
Friends tab but not For You/Owner's current view, then explicitly requested a
mixed eligible For You feed. Changed only the FOR_YOU discovery filter; shared
visibility/block/group predicate remains intact. No schema/migration or permission
weakening. iPhone touch keyboard retained focus by platform default; composer and
comment input now provide explicit outside-content unfocus, drag dismissal and a
visible keyboard-hide action. Unsent text retained; dismissing never publishes.

Final backend **34PASS,0failure/error/skip** (CommunityIntegration12,
CommunityRealtime4, legacy18), `/tmp/wedo-r5-feed-backend.log`.
Final Flutter **207PASS,0FAIL**, including18Community tests and two iOS platform
touch regressions, `/tmp/wedo-r5-final-flutter.log`. Analyzer clean2.4s,
`/tmp/wedo-r5-final-analyze.log`. Temporary focus diagnostics removed. Failed
intermediate keyboard tests were corrected to test outside body content and use
the platform-variant fixture rather than leaking a debug global; successful tests
still assert real touch dismissal, preserved text and no write. Initial AppBar
title touch was not the body interaction; explicit hide control covers header use.
Mixed-feed backend package3.244s deployedPID65754,
`/tmp/wedo-r5-feed-runtime.log`; V16 unchanged and both QA posts retained.
Initial33/205 results below remain historical, not the latest totals.

- Backend **33PASS,0failure/error/skip**: CommunityIntegration11, CommunityRealtime4,
  legacy DomainRealtimeCoordinator6, ChatRealtime5, MediaReference2, UploadService5.
  `/tmp/wedo-r5-backend-final.log`. Real isolated PostgreSQL/Flyway16, mock storage;
  not physical upload evidence. SQL predicate whitespace and test constructor
  fixture issues were caught and corrected before this final successful result.
- Flutter **205PASS,0FAIL**, including16new Community tests plus affected routes,
  Home and realtime reliability. `/tmp/wedo-r5-flutter-delivery.log`.
- Analyzer **clean2.4s**, `/tmp/wedo-r5-analyze-delivery.log`.
- Reproduced/fixed unbounded root feed layout before device install; retained
  inline sizing for resource cards. Red/green narrow layout evidence retained.
  Two later fixture failures were corrected (adapter always returned p for older
  ID; ambiguous test scrollable with GridView). No remaining suppressed failures.
- Backend package5.438s PASS; Android debug31.2s/install-rPASS; iOS release40.3s
  buildPASS. Install/device outcomes recorded below as actually observed.

## Deployment / preservation

V16 passed isolated PostgreSQL before QA. Backup
`/tmp/wedo-r5-before-v16.dump`304304bytes, mode0600. QA V16 success=true; old users5,
Moments3/media3/Albums2 unchanged across migration. **Do not rewrite applied V13–V16**.
Runtime PID48989, log `/tmp/wedo-r5-runtime.log`, current LAN<QA_LAN_IP>;
external credentials copied privately from exact existing backend process,
local profile retained, fixture reseeding disabled. Existing Docker services/data
untouched. No QA reset/financial write/signing/Firebase edit/Secondary iPhone action.

Automatic review rejected the initial subnet-wide MinIO relay as broader exposure
than authorized. It was replaced with the safer exact-device allowlist, initially
Mac<QA_LAN_IP> and Samsung<QA_LAN_IP> only. QA iPhone LAN IP must be verified before
adding it; same Wi-Fi name alone is not an IP. No rejection bypass or permanent
public object URL. Runtime-only helper `/tmp/wedo-r5-media.py` retains S3 signing.
Disk14GiB around builds; no cache/source/data cleanup performed. A failing widget
test rendering storm was stopped by exact test PIDs;352MB diagnostic log retained.

## Physical checkpoint and remaining acceptance

### Latest installed/device evidence (supersedes initial checkpoint below)

**Final user-feedback candidates:** Android9.8s build/install-r/launchPASS,
APK `41c96149a0bd1153f0b4c765e1caf9e64af2aa39b18385b2ca6395992660f594`;
iOS39.9s build/install/launchQA iPhone PASS, Runner
`af53f2e2060bf8772ce61a6bebc3bd1295984f75908de832bb133dd37103532d`.
Logs `/tmp/wedo-r5-final-{android,ios,ios-install}.log`. Native signing hashes
unchanged; no dependency/Firebase/signing change in this feedback correction.
BackendPID65754 is the mixed-feed snapshot, current healthUP. No migration17.
These hashes supersede initial candidates below; sessions/data preserved.

User confirms Samsung R5 offline/reconnect “Ok” to bounded no-Retry instructions.
They physically saw initial Friends post eligibility and its old For You exclusion;
that exclusion motivated the new product rule, not a new permission bypass.
Final mixed For You/own-post and iOS keyboard physical confirmation requested;
user subsequently explicitly confirms **“feed OK, bàn phím OK nếu sau nầy ko được
tôi báo lại sau”**. Current final-candidate mixed For You/own FRIENDS post and
keyboard-dismiss/text-retention check are user-reported PASS, not a guarantee
against future defects or an invented broader scenario. Existing PUBLIC image/
peer interaction evidence and Samsung reconnect PASS remain at their scopes.
Ineligible/blocked physical fixture, edit/delete/hide/report and physical long-feed
pagination remain CHƯA TEST; their scoped automated tests are PASS. No main QA
relationships or group memberships changed and no existing fixture deleted.

| Final R5 physical check | Result |
|---|---|
| Owner PUBLIC image, Samsung eligible feed/image | PASS user-reported |
| Member reaction/comment → Owner automatic update | PASS user-reported |
| FRIENDS publication / existing friend eligibility | PASS user-reported plus persisted row; no friendship edits |
| Mixed For You includes own FRIENDS post | PASS user-reported on final candidate |
| iPhone keyboard dismiss / unsent text | PASS user-reported on final candidate; two iOS focused regressions PASS |
| Samsung offline/automatic reconnect | PASS user-reported; no Retry/relaunch claimed beyond requested scope |
| Current Chat/Poll/RSVP/Moments adjacent smoke | PASS R4 user gate, prior exact evidence retained |
| Ineligible/blocked physical fixture | CHƯA TEST physically; automated matrix/privacy PASS |
| Physical edit/delete/hide/report/long pagination | CHƯA TEST; focused backend/Flutter PASS |

R5 is ready for remaining physical acceptance, **not COMPLETE**. No further source
change/build/broad investigation needed absent a newly reproduced defect or
network change. User controls Samsung; leave all fixtures/candidates/runtime intact.

- Both candidates installed in place with sessions preserved. Android31.2s:
  APK SHA256 `aae671afdbf13301e0b46f587c7e50e7fe0ff9707be2811dbec7a25a1de6bad9`.
  iOS40.3s/install/launchQA iPhone PASS: Runner
  `b2b0da070d034565199fee2bab3dcc32ecda2738b37c437e953c22443d7253f2`.
  Original pbxproj/Info.plist hashes unchanged; Secondary iPhone not operated.
- Samsung actual authenticated Home→Community→real empty For You and composer
  observed. Subsequent native picker automation stopped after user navigated;
  user confirms **they are controlling Samsung**. No further automatic taps
  until user relinquishes. This concurrent navigation is not an app defect;
  no agent-created Member Community post was committed by that attempt.
- User reports Owner PUBLIC QA image post created and then **“ảnh OK, realtime
  OK”** to Samsung feed/image/react/comment and QA iPhone automatic update steps.
  Actual onePUBLICpost/oneimage/comment persisted at read-only inspection.
  This is user-reported physical PASS for that journey, not proof of physical
  negative privacy, pagination, hide/report or edit/delete acceptance.
- Current Owner/Member1 ACTIVE friendship verified read-only; no relationship
  changes. Manual Friends feed/For You exclusion and Samsung offline/reconnect
  requested. Pending results remain pending until explicitly reported.
- Fresh QA iPhone app source<QA_LAN_IP> observed on backend after install/launch.
  Exact relay allowlist now Mac`.109`/Samsung`.110`/QA iPhone`.112`, PID53832,
  local/LAN MinIO and backend healthy. Initial broad relay review rejection was
  resolved with this narrower approved action; no blocked approval remains.
- Disk~12GiB; scoped diff-check clean, whole-worktree only two pre-existing group/
  profile test blank-EOF warnings, unchanged. Index empty; branch/HEAD/stash
  preserved. No commit/push/merge/reset/restore/stash/clean or QA cleanup.

Android installed in place, authenticated Member session preserved; QA iPhone is paired
and available. Physical post/photo/feed/reaction/comment/edit/hide/reconnect checks
are in progress; not inferred from205tests. Do not retry unsupported iOS UI runner.
User manual steps after candidate installation: Home→Cộng đồng; create labeled
PUBLIC QA image post; observe Samsung availability, react/comment there; observe
peer counts; test FRIENDS only against existing eligibility, no main-account block
or friendship manipulation. R4 same-Album/media and brief Chat/RSVP/Poll gate stays
separate. Record actual observations below, not a global PASS.

R5 remains IN PROGRESS until its physical gate. R2 parity remains separate; R6–R9
not started. Whole dirty worktree preservation is not a claim all changed paths
belong to R5. No stage/commit/push/merge/reset/restore/stash/clean.

## Changed-path boundary

New R5: `backend/.../community/{CommunityAccess,CommunityService,CommunityDtos,
CommunityController}.java`, V16, CommunityIntegrationTest/CommunityRealtimeTest;
Flutter `features/community/{data/community_api,presentation/community_screen}.dart`
and `community_test.dart`; this delivery report. Extended existing media category/
upload/reference services, Home entry/routes/route test and existing uncommitted
R1 `DomainRealtimeCoordinator`/`RealtimeScopeAccess` only for Community eligibility.
That already-untracked realtime directory is pre-existing R1 work, not a new R5
transport. Updated affected roadmap/handoff/R4 closure/API/ERD/class diagram and
append-only decision log. No claim all123+ tracked or other untracked dirty paths
are R5 changes. No R4 source rewrite or finance/signing/Firebase changes.
