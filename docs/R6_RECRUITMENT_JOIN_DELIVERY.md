# R5 acceptance + R6 Recruitment / Join

Date2026-10-27; branch `feat/pre-m19-ui-polish`, HEAD
`cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0`. Preserve the entire existing dirty
worktree. R1/R3/R4/R5 COMPLETE; R2 IN PROGRESS; **R6 COMPLETE**; R7–R9 NOT STARTED.

## R5 short acceptance decision

Unchanged DoD reviewed: implemented Community surfaces and safe visible-post
interactions pass automated/physical acceptance; feed/pagination authorized;
Moments remains separate. Existing user PUBLIC-image/peer-interaction, mixed
eligible For You/own FRIENDS post, keyboard and Samsung reconnect PASS retained.
The current request explicitly permits automated evidence where shared physical
fixtures cannot safely be altered; no deletion or block changes to main fixtures.

| Outstanding R5 gate | Evidence | Physical scope |
|---|---|---|
| Visibility/FOF/group/block/detail/media | Isolated Community PostgreSQL matrix + scoped transport tests PASS | Dedicated negative physical fixture CHƯA TEST |
| Edit/delete and observer convergence | New actual author edit → socket hint + authoritative second-user GET; delete → SCOPE_REVOKED; unauthorized delete denied; Flutter observer refetch/removal with zero writes PASS | New cross-device edit/delete CHƯA TEST |
| Hide/report/moderation | Personal hide, persisted structured reason/idempotency, other-user content remains, unauthorized management denied PASS | CHƯA TEST; shared fixtures preserved |
| Pagination/scroll | Isolated cursor under new creation, no duplicate IDs; actual widget scroll offset>0 unchanged on new-post hint, no feed refetch; loaded depth survives resync PASS | Long-feed physical CHƯA TEST |

These complete the remaining gate using the evidence substitution explicitly
authorized by this task, together with real existing core device observations.
**R5 COMPLETE**, not a claim every negative path was physically performed. The
unperformed physical edge matrix carries into R9; the DoD is not rewritten.

## Architecture and permission decisions

Reuse canonical R5 CommunityPost: GENERAL plus LOOKING_FOR_MEMBERS. No parallel
public feed or membership store. `community_recruitment` is one-to-one metadata;
`recruitment_applications` only links a canonical GroupJoinRequest to its originating
post for accounting. Membership rows are created exclusively by existing
`GroupAdmissionService.admitMemberUnderGroupLock` inside authorized approval.
No invite code published; no AUTO_JOIN fallback from a public post.

Publishing is explicit consent by current Owner/Admin of ACTIVE,
APPROVAL_REQUIRED group. Ordinary Member is not authorized to recruit externally,
regardless of member-create-Activity settings. There is no group privacy/public
flag in current schema; this conservative policy plus explicit manager publication
is the opt-in. Other authorized invitation flows remain unchanged.

Linked Activity must be same-group and not CANCELLED/COMPLETED. External preview
uses manager-approved snapshots of group name and optional Activity title/start,
plus the recruitment caption/broad location/tags/dates. It does NOT return full
Group/Activity DTOs, private descriptions, member lists, Chat, Moments, Finance,
phone numbers or live coordinates. Private name/title edits are not automatically
republished into an old public preview. No GPS/location provider or ranking engine.

R5 visibility predicate applies to discovery/detail/preview/media/interactions/
profiles/socket. PUBLIC is not membership. FRIENDS/FOF/GROUP_ONLY are unchanged;
For You remains mixed eligible posts, Friends an author filter. Bans and blocks
against any active group manager additionally prevent recruitment admission.
All group-only ownership and Activity links are validated server-side and in SQL.
Hide/report reuse canonical post IDs/rules. Current group Owner/Admin can close;
generic caption/visibility edits additionally require current recruiter rights and
cannot move GROUP_ONLY ownership away from the linked group. Author may remove
their own post under existing canonical deletion rules; no object bytes deleted.

## Count and lifecycle semantics

- Target1..100, immutable after publication. Credit = DISTINCT users with canonical
  APPROVED requests originating through this post, lifetime history. PENDING,
  REJECTED and CANCELLED do not count. Leaving later does not undo an approval or
  reopen a filled lifetime target. Actual membership/access is always current.
- Group capacity100 is independent. Available slots=min(target−credits,
  100−current active members), floored0. Group membership does not create RSVP;
  Activity RSVP capacity/waitlist remains independent and unchanged.
- OPEN requires active eligible group/author/policy, noncancelled/noncompleted
  Activity, no manual closure, future expiry and capacity. FILLED if target or
  group cap reached. CLOSED takes precedence for manual closure/ineligible group/
  author/Activity; EXPIRED if deadline passed; then FILLED, otherwise OPEN.
- Manual close records closed_at/by, is idempotent and not reopenable here.
  Metadata target/group/Activity remain immutable; create a new post for a new
  recruitment campaign. Caption/visibility edits reuse Community APIs.
- Explicit expiry, else plannedAt, else30days from creation. Both collected dates
  include time and UTC serialization; past values rejected, same-day future valid.
  Status is projected from canonical facts/clock on reads and enforced on writes;
  no polling/scheduler is introduced to push a clock edge to an otherwise idle card.
  Reconnect/REST obtains current state; a stale button cannot bypass deadline.

## Canonical admission and concurrency

R6 calls new canonical `requestForRecruitment`, which always persists PENDING,
reuses existing pending group request and admin/requester realtime. No new member
before approval. Existing Group approval emits existing approval Notification
events; this does not claim physical FCM delivery. Review actions delegate to
canonical approve/reject/cancel, not duplicate membership logic.

Quota guard is inside **all** canonical approval entry points for provenance-linked
requests, including existing `/group-join-requests/{id}/approve`. Lock order group
row → recruitment metadata → managed request refresh. Competing approvals serialize
and recheck post/visibility/block/policy/quota before the existing group100-capacity
admission. Reject/cancel share locks for recruitment requests. JPA flush precedes
Jdbc projection on wrapper responses. Two concurrent approvals for one slot yield
one approved member, one denied; pending does not reserve capacity.

One canonical PENDING request per group/user. Retry returns it without new rows;
requests pending via a different campaign/invite remain that original provenance,
not stolen/credited to another post. PENDING is preferred when projecting current
request state; resolved R6 history uses provenance creation time to avoid wrong
IDs when request timestamps tie. After membership loss, old APPROVED does not
masquerade as current MEMBER. New requests via closed/expired/deleted posts denied;
reading an existing PENDING/MEMBER state is an idempotent no-op. Other canonical
flows, including own-request cancellation, remain available where policy permits.

## REST contract

Authenticated `/api/v1/community`, successful defaults200:

| Method | Path | Purpose |
|---|---|---|
| GET | `/recruitment-options` | Actual Owner/Admin ACTIVE approval-required groups |
| POST | `/recruitments` | Canonical idempotent post + metadata transaction |
| GET | `/recruitments` | OPEN eligible discovery, cursor20 rows |
| GET | `/recruitments/{post}/preview` | Safe viewer-specific preview/request state |
| POST | `/recruitments/{post}/join` | Canonical PENDING; never direct membership |
| POST | `/recruitments/{post}/cancel` | Cancel own pending canonical request |
| POST | `/recruitments/{post}/close` | Manager idempotent manual closure |
| GET | `/recruitments/{post}/requests` | Only current manager's originating pending requests |
| POST | `/recruitments/{post}/requests/{request}/approve\|reject` | Validated provenance then canonical resolution |

Create: clientRequestId,groupId,optional activityId,caption,visibility,
requestedCount,broadLocation,tags,optional plannedAt/expiresAt,mediaKeys.
Tags≤6,1..32 Unicode letters/numbers/spaces/_/−; broad location≤160. No real-time
coordinate fields. Media can reuse canonical Community upload/reference rules;
R6 composer is text+metadata, existing Community image posts/viewer unaffected.

Discovery filters: keyword over caption/broad location/tags, exact case-insensitive
tag, broad-location substring, optional from/to planned timestamps, opaque before
UUID. Literal search escaping, all eligibility/OPEN filters before LIMIT; stable
created_at/id ordering. Closed details remain readable if ordinary post access
permits; closed posts omitted from OPEN discovery on authoritative refresh.

Canonical Post adds optional recruitment projection: group/name snapshot, optional
Activity/title/start snapshot, target/credits/remaining, broad location/tags/dates,
status, own requestState/requestId and canRequest/canCancel/canManage flags.
Requester states NOT_REQUESTED/PENDING/MEMBER/REJECTED/CANCELLED; no other applicants'
names in a public DTO. Own APPROVED with no current membership becomes NOT_REQUESTED.

## Realtime and Flutter

No new transport. Existing AFTER_COMMIT/Redis/domain events:
POST_CREATED + RECRUITMENT_CREATED availability hints only to eligible viewers;
COMMUNITY_RECRUITMENT_CHANGED targets post/reviewer scopes on request/resolution/
closure and relevant Group/Activity mutations. Existing canonical user-scope admin/
requester events remain. Group-join events no longer globally reset Community
feeds; relevant membership eligibility resync is requester-specific. R6 cards
targeted REST, not global refresh. No credentials/applicant data in public hints.

New `review:<post>` uses current post access AND current manager policy, separately
from public `post:<post>`. Losing role can revoke review and clear cached applicant
names immediately while the public post remains readable, including offline.
Existing eventId dedupe, generation guards, resubscribe/resync retained.

Community Create Post chooser offers ordinary Post or Tìm thành viên. Actual group/
Activity selector, number/caption/broad location/tags/full-date-time/visibility,
dedicated discovery filters and cursor list, compact recruitment card, external
preview, own request status/cancel, Owner/Admin pending review and close actions.
Readonly cached offline state, scoped permission clearing and stale/disposed reply
protection. New-post indicator preserves scroll; no per-keystroke polling or forced
scroll jump. Existing R5 keyboard controls reused in new fields. Light/dark/narrow
focused tests passed. No fake recruitment listings or hidden Activity creation.

## Completed verification

- Backend **59PASS,0failure/error/skip**: RecruitmentIntegration12,
  CommunityIntegration13, CommunityRealtime6, legacy DomainCoordinator6,
  GroupAdmissionService13, GroupAdmissionConcurrency9.
  `/tmp/wedo-r6-backend-acceptance.log`. Actual isolated PostgreSQL/Flyway17.
  Includes safe preview, role/visibility/block/ban, canonical duplicate/pending,
  quota concurrency including old endpoint, status/capacity/lifetime, rollback,
  after-commit, filters/cursor; R5 short gate above. No full backend suite.
- Flutter **272PASS,0FAIL**:18R6,19R5 Community plus affected routes/core realtime/
  Chat/Poll rendering. `/tmp/wedo-r6-flutter-verified.log`.
- Analyzer clean3.3s `/tmp/wedo-r6-analyze-verified.log`.
- Caught/corrected fixture timezone/ended_at/unique filter scope, and a genuine
  request-status selection issue under tied timestamps; regression retained.
- Android debug11.3s/install-r/launchPASS, APK
  `bd35bfd95f8448e1d0506ea7acc628aea6674384f3d1ef43f31a1fd962450cef`.
- iOS release36.9s/install/launchQA iPhone PASS, Runner
  `53b4d3c4f680f518dfdf91c88106f732a440171c6e15f5c8c6291bf89c5bafbf`.
  Original pbxproj/Info.plist hashes unchanged. No unsupported UI runner retries.
  Logs `/tmp/wedo-r6-{android,ios,ios-install}.log`. Tests do not substitute for
  unobserved physical UI results; no physical FCM/media upload claim here.

## QA deployment / physical checkpoint

Mac<QA_LAN_IP>, Samsung`.110`, QA iPhone`.112`; FPT Telecom. Existing MinIO exact-device
relay and credentials unchanged. BackendPID99378 `/tmp/wedo-r6-runtime.log` current
LAN/media config, local profile, fixture reseeding disabled. Docker untouched.
V17 applied success=true AFTER isolated verification. Pre-migration backup
`/tmp/wedo-r6-before-v17.dump`324139bytes/mode0600. Before/after migration counts
unchanged: users5, Moments3, CommunityPosts2, memberships19. **Do not edit applied
V13–V17**. No QA database/media deletion or reset. Disk~13GiB; no cleanup performed.

Dedicated new QA-only group created through normal Owner API in a separate terminal
auth session, not by SQL or a seeder: **R6 QA Recruitment 27-10**,
`122bd06a-2f08-44dc-8deb-bd050cf216df`, APPROVAL_REQUIRED, only Owner. Member1 and
Member2 both verified NOT active members before request. Old groups unchanged.
QA credentials read privately from existing local defaults, not printed/copied
into repository; terminal auth/fixture files mode0600 under `/tmp`, phone sessions
preserved. User controls Samsung; no automatic taps while they test. No Secondary iPhone.

### Actual current physical / independent runtime evidence

| Gate | Result / evidence |
| --- | --- |
| QA iPhone create PUBLIC recruitment | PASS user-operated; actual caption “Tìm 1 người đi ba vì”, target1; post `c02386ed-6956-4098-b97d-8f95f3194bfe` |
| Samsung discovery/preview/request | PASS user-reported “đã gửi, chưa duyệt” after the explicit Find People/preview/request sequence; not an agent video/UI capture |
| Canonical pending, no membership before approval | PASS read-only QA SQL: one PENDING `6c31546f-d1d3-4abd-9087-cc03536ca29d`, applicant `d78a1d06-2d51-4ca5-914f-b0d33b0e4f98`; only Owner has ACTIVE membership |
| Repeat request | PASS independent Member1 terminal session: POST join returns same request UUID, PENDING; no duplicated request or membership |
| True outsider safe preview | PASS independent Member2 terminal session, actual non-member of new group; projection matches safe field allowlist, OPEN/0approved/1remaining, canManage=false |
| True outsider private reads | PASS runtime HTTP: canonical private Group GET404; recruitment manager requests GET403; no private body returned |
| Owner approval → requester convergence | PASS user reports “Đã duyệt; samsung đã cập nhật”. Read-only SQL confirms1 APPROVED and exactly1 ACTIVE MEMBER plus Owner; independent outsider preview FILLED, approved1, remaining0. Exact count corroborated by backend, not separately inferred as a user-read label |
| FILLED → new outsider join denied | PASS current runtime: separate Member2 POST join403; no admission bypass. Private Group404/reviewer list403 still denied after approval |
| Owner close → CLOSED / peer convergence | PASS user reports “đóng tuyển OK; smoke OK”. SQL confirms closed_at set; independent outsider preview CLOSED/approved1/remaining0; new join403, private Group404/review403 remain denied |
| Current R6 adjacent Chat/Poll/Moments/ordinary Community smoke | PASS user-reported “smoke OK” in response to the explicit Chat/Poll/Album-Moments/ordinary Community checklist; no invented additional mutations, screenshots or reconnect scenario |

Read-only post-deployment health: local/LAN backendUP, PostgreSQL ready, RedisPONG,
MinIO ready; Mac still<QA_LAN_IP>, disk13GiB. Original signing hashes unchanged,
index empty and protected stash retained. Helpers `/tmp/wedo-r6-outsider-check.py`
and `/tmp/wedo-r6-requester-retry.py` use separate normal QA logins; secret files
remain mode0600, never printed. No phone logout/session swap, main-group removal,
blocking of demo users, financial mutation or object upload/deletion.

## Final unchanged-DoD closure — 2026-10-27

**R6 COMPLETE.** User reports “đã từ chối” after the explicit QA iPhone Owner rejection
check for separate QA Member2 fixture. Read-only QA SQL confirms canonical request
`f86aa6f9-3b92-4427-b1fe-40d019227077` is REJECTED and Member2 has NO ACTIVE
membership; dedicated group remains exactly Owner+the previously approved Member1.
No membership was created by rejection. This closes the precise last physical gate;
no new code/build or test-suite rerun was needed.

Unchanged roadmap DoD: durable, authorized discovery-to-membership and lifecycle
flow physically accepted; rejection/ban/expiry paths verified. Primary user device
create/discover/request/approve/realtime/count/close and adjacent smoke PASS above;
separate Owner rejection now user physical PASS + SQL corroboration. Duplicate,
no-membership-before-approval, full/closed outsider denial and safe preview are
independent runtime evidence. Ban/expiry/concurrency/rollback/AFTER_COMMIT and
reconnect/permission/stale-response paths are focused automated evidence, not
invented physical negative tests. Retain59 backend/272 Flutter PASS, analyzer clean,
verified current Android/iOS installations. No DoD wording/scope removed or changed.

## Remaining boundaries

No known mandatory R6 acceptance blocker remains. R2 stays IN PROGRESS; R7–R9 NOT
STARTED. Separate rejection fixture “R6 QA Reject 27-10”
`bc1162a0-c9ae-4d41-b06b-85602d89b311` is retained with REJECTED request, not deleted
or automatically closed. Its metadata remains mode0600 under `/tmp`; accepted
closed campaign and Member1 unchanged. Physical ban/expiry/reviewer-role-loss and
concurrent approvals were not performed on main demo memberships; isolated tests
supply that evidence. Broader R9 matrix remains future work. Exact clock edge on
idle UI requires authoritative read/resync; no periodic expiry broadcast. No
metadata target/group/Activity editing/reopen or R7/R8 implementation is claimed.
Entire dirty worktree, QA/runtime, signing/Firebase and sessions preserved. No
stage/commit/push/merge/reset/restore/stash/clean or media/volume cleanup.
