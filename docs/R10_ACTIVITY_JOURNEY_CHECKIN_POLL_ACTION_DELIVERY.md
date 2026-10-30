# R10 Activity Journey, Live Check-in & Poll-to-Action

Started2026-10-27; current checkpoint2026-10-28 (Asia/Ho_Chi_Minh).
Branch feat/pre-m19-ui-polish, HEAD cdb0bd7e3ef564a0430e45b1db331b80cfbf10f0.
R1/R3/R4/R5/R6/R7 COMPLETE; R2/R10 IN PROGRESS; R8/R9 NOT STARTED.
Entire old dirty worktree retained; no Git publication/destructive commands.

## Implemented business slice

- New ActivityStop is a child of canonical Activity, derives Group from parent;
  no extra Activity or stop RSVP. Activity RSVP unchanged. Owner/Admin or Activity
  creator manages stops, designated current organizer additionally changes status.
  All current members read; writes require active group and nonclosed Activity.
  Explicit ban checks supplement membership for new R10 reads/writes.
- Stable UUID create, title/notes, full start/end timestamps, broad location label,
  optional organizer/cost estimate (no financial mutation), stable order, status,
  timestamps and soft deletion.200 active stops max. End after start and within
  scheduled parent boundaries where present. PLANNED→IN_PROGRESS/COMPLETED/SKIPPED/
  CANCELLED; IN_PROGRESS→terminal. Terminal stop cannot restart. Parent completion
  does not fabricate completed child states; it freezes child writes.
- Parent Activity row lock serializes create/edit/reorder/check-in. Edit/state/delete
  require expectedUpdatedAt; reorder expected/current full ID order prevents stale
  list overwrite, repeated already-applied order returns same canonical list.
- Check-in is exactly one canonical Moment plus association to Stop. Same bytes/media
  IDs power Stop history, Activity/Group Moments and existing selected Album items.
  No automatic public Community publication; Album linking uses canonical selection,
  no silent new album/copies. Moment's linked Activity cannot later be moved away.
- Camera capture uses existing image_picker/native camera from Flutter; preview,
  front/rear preference/native switching, retake, optional caption, progress, cancel
  before commit, bounded safe retry. Up to4 camera photos; evidence may choose one
  explicitly labeled gallery image. Mixed gallery/camera batch not relabeled fresh.
  Client command/uploaded keys retained on uncertain response; known rollback
  validation permits correction, no automatic command replay.
- Source CAMERA_CLIENT_DECLARED is truthful client metadata, not sensor/EXIF/GPS/
  attendance verification. Server received_at is authoritative receipt time;
  optional client_captured_at explicitly untrusted. No coordinates/background location.
- Shared authorized fullscreen gallery for check-ins, evidence, Moments, Albums and
  Community, fit-contain, zoom/pan/double-tap, PageView swipe and back. Swiping disabled
  while zoomed. Original authorized URL, thumbnail decode960px/viewer4096px cap;
  actual camera images capped2560px before upload. No uncontrolled public file cache.
- Canonical Task TODO/IN_PROGRESS/DONE retained. Default evidence mode NONE for old
  Tasks (absent task_execution row). DIRECT_COMPLETE commits proof + canonical DONE;
  REQUIRE_REVIEW leaves Task status unchanged with PENDING proof until authorized
  different creator/Owner/Admin approves. Approval records canonical Task history.
  Assignee alone submits, current membership required. Old generic DONE endpoint
  cannot bypass configured proof. Projected canCompleteWithoutEvidence defaults true
  in old DTO constructors/Flutter fixtures; proof Tasks hide generic DONE choice.
- Evidence private to canonical Task readers; not silently added to Moments/Community.
  Up to4 photo references, server author/time/source; feedback/reviewer history retained.
  Latest pending superseded on new proof/config change, no rejected/history deletion.
  Snapshot timestamp + current assignment/current active author membership guard
  approval after edits/reassignment/departure. Reopened Tasks require fresh proof.
  Completed history remains historical if later metadata changes. Identical concurrent
  review creates one review/DONE history. Tasks with evidence cannot hard-delete;
  canDelete reflects this, assignee management stays authorized. No new CANCELLED Task
  enum; old Task status/assignment rules preserved.
- Poll conversion explicit confirmation, any chosen nondisabled canonical option,
  never automatic winner; multi-choice sources supported via explicit per-option
  conversions (no all-or-nothing bulk conversion API). Results must be visible and
  participantCount≥1; OPEN/CLOSED both allowed under policy. Group-only Poll requires
  target Activity selection; linked Poll requires same Activity. Group match enforced.
  Canonical TaskService assignment/GOING eligibility used; Stop needs Journey manager.
  UUID command + unique(option,kind,Activity) + parent lock prevents double targets.
  One option can explicitly create both Task and Stop; another Activity allowed only
  for group-only source. Source question/option snapshots survive source deletion;
  target Task deletion with no evidence nulls FK, old link stays. No financial actions.

## REST endpoints (authenticated /api/v1)

| Endpoint | Purpose |
| --- | --- |
| GET /activities/{a}/journey | authorized summary + ordered stops/permission projections |
| POST /activities/{a}/journey/stops | UUID create |
| GET/PATCH/DELETE /activities/{a}/journey/stops/{s} | same-parent detail, optimistic edit/soft-delete |
| PUT .../stops/{s}/status | expectedUpdatedAt + explicit transition |
| PUT /activities/{a}/journey/order | expectedOrder / orderedIds |
| GET/POST .../stops/{s}/checkins |20-row cursor / canonical Moment association |
| GET .../stops/{s}/tasks | canonical linked Task projections |
| GET/PUT /tasks/{t}/execution | current mode/Stop/evidence/permissions or manager configuration |
| POST /tasks/{t}/evidence | UUID, source, caption, mediaKeys |
| POST /tasks/{t}/evidence/{id}/review | UUID, approve, reason (rejection requires reason) |
| GET /tasks/{t}/evidence/media/{m}/access | exact Task-authorized signed URL60seconds |
| GET/POST /polls/{p}/actions | context/source links / explicit conversion |
| GET /journey/targets/{TASK|STOP}/{id}/sources | current target-authorized durable source history |

Private media reuses MOMENT_IMAGE group/uploader policy; evidence objects do not
become Moments unless explicitly shared in a separate authorized flow. Already
issued signed URLs retain documented≤60sec residual window, no instant-byte claim.

## Realtime / navigation

Existing PostgreSQL AFTER_COMMIT → Redis/shared WebSocket → authorized Activity/
Group scopes, eventId dedupe, targeted reliable REST. ACTIVITY_STOP_CREATED/UPDATED/
DELETED/REORDERED/STATUS_CHANGED/CHECKIN_CREATED/CHECKIN_CHANGED/TASK_CHANGED;
TASK_EVIDENCE_CHANGED, existing TASK_STATUS_CHANGED, POLL_CONVERTED. Canonical
MOMENT_UPDATED/DELETED and linked Task changes bridge only to affected Stop. No new
socket, global app refresh, polling or artificial aggregate revision.

Activity authenticated typed entry→Journey→Stop→camera→shared gallery; existing
Task detail→Evidence→camera/review/gallery; Poll detail/results (including Chat card
entry)→explicit action→created Task/Stop. Back context preserved. Parent overview
retains RSVP/reminder/Discussion, adds real Journey progress/next-stop summary and clear Journey/Task/Moments/Poll navigation.
Check-in indicator when reading older history preserves scroll; no forced jump.
ReliableRead generation/disposal protection, permission clearing and reconnect
resync retained; mutation results displayed only after authoritative commit.

## Tests / visual evidence checkpoint

-59 backend focused PASS,0fail/error/skip (Journey11, existing M8/Poll/Chat/Task and
 Moments regressions); latest Journey11 rerun PASS. Logs /tmp/wedo-r10-backend-final.log,
 /tmp/wedo-r10-backend-verified.log. Isolated PostgreSQL/Flyway19+20 before QA.
-360 affected Flutter PASS,0FAIL in final complete focused run15s (Journey15,
 Moments, Community, shared realtime, Task, Poll, Chat, Activity and routes).
 /tmp/wedo-r10-flutter-verified.log. No unrelated full suite.
-Analyzer clean2.9s /tmp/wedo-r10-analyze-verified.log.
-Test fixtures initially had wrong UpdateTaskRequest order/single-choice maxSelections/
 Activity creator JSON key; corrected tests, no canonical weakening. Genuine Spring
 proxy direct-field event access fixed by injecting publisher in each service.
-Actual readable narrow light/dark Flutter harness renders viewed:
 /tmp/wedo-r10-timeline-{light,dark}.png,320logical px/DPR2, local test font and weDO
 theme. These are NOT physical phone screenshots. Physical design review pending.

## QA/runtime checkpoint

V19 and V20 applied success=true AFTER isolated tests. **Never rewrite applied
V13–V20.** Backup /tmp/wedo-r10-before-v19.dump349219bytes/mode0600.
Before/after migration identical: users5/Activities5/Tasks9/Polls12/Moments3/
CommunityPosts6/memberships21/reports2. Docker/volumes/MinIO/signing/Firebase and
all old fixtures unchanged. Subsequent labeled R10-only fixtures created via normal
API, no SQL seeding or old records reset.
Macen0 <QA_LAN_IP>, Samsung .110, QA iPhone previous .112. BackendPID56152,
/tmp/wedo-r10-runtime.log, persistent session70524, current LAN/media, reseedingOFF.
Existing exact-device MinIO relay unchanged.10GiB free before builds.
Final Android10.8s build/install-r/launchPASS,
APK dbd934e16a1223b9f7201de46e9a68b602b9f4c80adb17761b3cf35dcf7a5686.
Final iOS36.2s build/install/launchQA iPhone PASS,
Runner dbe71cd76c1bfeadc3a8350ca4a38cb28c6062951098093a613cf2ac0bee8e56.
Logs /tmp/wedo-r10-final-{android,ios}{,-install,-launch}.log.
Final runtime backend LAN UP, PG ready, RedisPONG, MinIO LAN ready;12GiB free.
pbxproj/Info.plist hashes unchanged; no unsupported runner/Secondary iPhone action.

Dedicated fixture in group R6 QA Recruitment27-10, current Owner+Member1 membership:
-Activity “R10 QA Đi Ba Vì 28-10” aac8e962-ae84-4f00-8d3d-8ab4ce05e516,
 unscheduled parent, explicit new Owner/Member1 GOING setup, no RSVP duplication.
-Three stops IDs7dfd9b1a-2fb7-479e-b95f-65732d73cf94,
 43e1203b-3f6e-49ee-badb-a158975f610a,cabdccef-1c20-40a4-898e-4d3559ce5219;
 tomorrow7/9/12VN, broad QA location, editable dedicated itinerary.
-Task “R10 QA Mua rau”13296242-f76f-45fe-ac1b-955a95daa184 assigned Member1,
 REQUIRE_REVIEW, linked lunch stop. No photo proof submitted or fake completion.
-Canonical Chat Poll “R10 QA Cuối tuần đi đâu?”d46e71a5-1afa-47ef-9530-9123b7dcac93,
 linked new Activity, anonymous multi-choice, one normal QA Member vote for mountain;
 no automatic conversions. First helper used wrong /votes URL; corrected to canonical
 PUT /vote, stable fixture IDs reused, no duplicate Poll/Activity/Task.
-Metadata /tmp/wedo-r10-fixture.json0600; helpers /tmp/wedo-r10-{deploy,create-fixtures}.py,
 separate normal QA login, credentials unprinted/outside repo, phone sessions intact.

## Pending physical acceptance / remaining boundaries

No new R10 physical PASS claimed. Need actual pair itinerary reorder/time/location,
real camera capture/preview/check-in arrival, fullscreen zoom/swipe, Task camera
proof→Owner review→DONE/history, Poll option→Stop and other option→Task/source retry,
network/permission/revocation and adjacent Chat/Poll/RSVP/Moments/Community smoke.
Use only dedicated fixtures, no main-group removal or finance transaction. User
controls Samsung; avoid concurrent automated taps. iOS automation unsupported;
use precise user steps instead of restarting runner. Screenshot/design gate must
identify test-harness vs actual-device evidence honestly.

R10 IN PROGRESS until required acceptance. No ranking/R8 or unrelated R2 expansion.
Whole dirty worktree preserved; no commit/push/merge/reset/restore/stash/clean.

Final manual gate requested: both phones open R6 QA Recruitment27-10 → R10 QA Đi Ba Vì28-10 → Lịch trình & Check-in; verify3stops and Owner edit/reorder convergence. Await user evidence; no physical PASS inferred from install/launch. Samsung NotificationShade observed, no automated taps or screenshot claimed.

## Confirmed physical blocker hotfix —2026-10-28

User reports media failure on both phones. Actual Samsung screenshot
`/tmp/wedo-r10-checkin-error.png` shows the existing Owner check-in on first Stop
with “Không thể tải media. Thử lại”. One real check-in exists; no synthetic photo
or replacement check-in created. Root cause is Flutter JourneyApi inheriting
CommunityApi.mediaUrl: canonical Moment IDs were requested from Community media.
Exact current check-in independently reproduces404 via wrong route and200 via
Moment route for both Owner and Member1; object1115016bytes readable. This is a
client routing error, not lost storage or weakened authorization.

Bounded fix: override JourneyApi.mediaUrl with `/moment-media/{id}/access`.
EvidenceMediaApi keeps Task-specific authorization; Community remains unchanged.
New concrete-Dio tests (not mocked mediaUrl) reproduce two failures before fix
and verify correct Moment route, separate Task/Community routes, and denied403
without cross-domain fallback. No backend/schema/data change or backend rebuild.

User additionally requests simpler Activity detail. Production route no longer
mounts/subscribes Discussion; canonical Discussion module/data remain untouched.
Removed duplicate “Công cụ hoạt động” card. Four navigation actions use matching
OutlinedButton icons, surface/border/colors, equal-width two-column layout; status
chips and capacity captions wrap on narrow screens. Existing optional injected
Discussion test slot retained for prior offline regression, not mounted by actual
Activity route. New320px navigation test checks all actions/no duplicate controls,
equal geometry and no overflow. An initial narrow-test capacity overflow was
corrected before final pass.

Affected focused Flutter164PASS/0FAIL, analyzer clean2.7s. Logs
`/tmp/wedo-r10-media-ui-{tests,analyze}.log`. Prior59 backend evidence retained;
no backend changes and no redundant backend/full-suite run. Corrected candidates built Android13.3s/iOS38.3s for<QA_LAN_IP>,
installed in place and launched on Samsung+QA iPhone successfully. APK
6a9387cdf94c44c5249ffe3c0440d8fcb877a34f2d94271c7fd33d95fd2c7017;
Runner68035e6dce89a46f6d1a3feb9afdc3c60a2aafa2e9f510a74b3889bd02e2604f.
Signing hashes unchanged. Exact existing-check-in/fullscreen and four-button retest
requested; physical result pending. User requested existing screenshot left open; no UI taps performed.
R10 remains IN PROGRESS, no new physical PASS invented.

## Paired image PASS and Journey clarity follow-up —2026-10-28

User explicitly confirms “Ảnh Ok cả hai” after media hotfix: existing check-in
image loading physically PASS on both phones. This does not complete the full
camera/zoom/swipe/privacy/task/conversion acceptance matrix. User requests smaller
navigation, clearer execution state and early execution independent of plan time.

Four consistent controls now54px (from68),18px icons,13px semibold labels and10px
corners. Timeline gives active Stop highlighted tile, explicit status badges/icons,
active titles above progress and completed count. Detail labels plan time “Dự kiến”
and uses explicit start/complete action verbs. Activity overview distinguishes
actual active Stop(s) from next planned Stop. No time inference or auto-completion.

Backend inspection confirms no scheduled-time gate exists for start/check-in.
New isolated PostgreSQL test verifies future planned Stop permits early check-in,
start, another check-in and completion, without relaxing completed/closed or
membership rules. No backend production/schema changes or runtime rebuild.
12Journey integration PASS18.794s;98 affected Flutter PASS4s; analyzer clean4.1s.
Logs `/tmp/wedo-r10-{early-tests,status-tests,status-analyze}.log`. Final updated Android12.0s/iOS37.7s builds/install-in-place/launchPASS both phones.
APK7880f05a8fc5d23e0aab4605c0c88a27ba4f16f668c0e387d128d0bbb638f9d4;
Runner7b638d06e2982ea2c1224c2079fd3134bcdcba87eee1380918e34cb5f81da2ea.
Native signing hashes unchanged; exact compact/status physical retest pending.
No financial mutation, QA record rewrite, signing/Firebase changes or Git actions.

## Missing completion action — parent already completed,2026-10-28

Current original QA Activity API shows COMPLETED/groupACTIVE while first Stop is
IN_PROGRESS. Both Owner and Member projections correctly disable all Stop
writes/check-in under terminal parent; no time gate or silent membership change.
User cannot find child completion because parent was already ended. Preserve this
Activity and its photos/history; no reopen/reset or authorization bypass.

Fresh normal-API fixture “R10 QA Lịch trình mở 28-10” in same QA group has3planned
future Stops, Owner+Member1 GOING, Owner canChangeStatus/checkIn true. Stable metadata
`/tmp/wedo-r10-open-fixture.json`0600; no copied photos/Task/Poll or old record edits.
Next physical test is inside first Stop: start→complete→observe Samsung badge/count.
No new build/test/source change; lifecycle explanation, physical result pending.

## Poll conversion manual entry —2026-10-28

User acknowledges Stop flow usable, but cannot discover conversion. Existing entry
is Chat Poll→Xem chi tiết→Tạo công việc / lịch trình, with results visibility.
Prepared one new Chat-linked Poll “R10 QA Chốt lịch trình 28-10” in open Activity
“R10 QA Lịch trình mở 28-10”, stable UUID and separate terminal Member1 QA vote.
Owner resultsVisible=true, one participant, links0, Journey manager=true. Old Poll
still tied to completed Activity, unchanged. No target auto-created. User must
choose option/kind and explicitly confirm dates/location; title reuses option.
Physical conversion/source-navigation/cross-device result still pending. No source,
build or test changes for this entry guidance/fixture addition.

## Conversion confirmation feedback —2026-10-28

User reports missing confirmation after conversion. Read-only canonical actions
shows exactly one TASK and one STOP target already persisted for open QA Poll;
no target replay or deletion. PollActionScreen now uses successful POST response
to show type-specific creation SnackBar and “Xem” navigation to returned target.
Feedback does not depend on a subsequent REST reload succeeding;400/503 do not
show false success and existing uncertain retry command remains stable. No
backend/schema/Notification Center changes or new automatic actions.
22focused Journey testsPASS, analyzer clean4.3s; logs
`/tmp/wedo-r10-confirm-{tests,analyze}.log`. Final Android11.8s/iOS45.7s build/install-in-place/launchPASS both phones;
APK05f1288e6ebacab55d41613768312f17237c86bceaeb2b5d50cb95157bf19432,
Runner648e405c59cd44fa059ff1b4d24eb3029648ed78503040ac5938d658f8ed4cc5.
Native signing hashes unchanged; physical feedback acceptance not yet claimed. Existing data/QA/signing preserved.

## Centered success confirmation —2026-10-28

User confirms bottom success notification appears, then requests middle-screen
presentation. Replaced successful conversion SnackBar with centered AlertDialog,
success icon/title, target-specific text and “Đóng”/“Xem”. Close does not mutate;
View opens returned target after authoritative reload; failures do not show success.
22Journey focusedPASS/analyzer clean3.5s. Same local scope, no backend/schema/QA
changes. Android14.2s/iOS41.9s build/install-in-place/launchPASS both phones;
APKa49d73e69ca6439d5955b7b2c9924edc98adf34f96462e020492e1fa1a3900b1;
Runnerb97e9a3875c49ec34fe8ccc8421a0eb1f4e61221fb998b78364379a7277978b0.
Native signing hashes unchanged; exact centered-dialog physical acceptance pending. Previous SnackBar implementation evidence is historical.

## Meaningful converted Task names / Task-list View —2026-10-28

User accepts center confirmation, asks Task success View to open Activity's Task
list and points out “Mua hoa quả” with option “Ở chợ” must retain action meaning.
Additive optional Convert.taskTitle≤255, backend defaults TASK title to question,
allows explicit nonblank trimmed title, preserves selected option in description
and durable source snapshots. Existing request shape remains accepted. STOP naming
remains option text. UI prefills editable title once, preserves edits on refresh,
freezes uncertain retry. Existing UUID/natural-key link replay does not rename or
recreate old targets. Existing Task metadata can be edited through normal UI.

Success View for TASK now opens canonical TaskListScreen of returned Activity;
existing source-history detail links and STOP navigation unchanged. No schema,
financial, transport or authorization change.13Journey PostgreSQLPASS,
28Journey+Task FlutterPASS, analyzer clean4.9s. Backend package8.526sPASS, runtime
restartPASS PID69223/session46625 with currentLAN healthUP and reseedingOFF.
Android17.3s/iOS48.1s build/install-in-place/launchPASS both devices;
APK9799b60473a93cea03354a7389413b6aa4f9e7980fb32ecd0380dcbb25e81e34;
Runner1290dfaba607175ccbe922d983320990f0a855e7c23fd76e007dc25089a16138.
Native signing hashes unchanged; physical naming/list navigation pending.

## Cross-cutting navigation delivered —2026-10-28

Global page120ms fade/main-tab0ms retained state/reduced-motion policy is now a
user-authorized R10/R9 UX requirement, without business/API/DB changes.266focused
FlutterPASS/analyzer clean; both candidates installed. QA iPhone user core fade/back/
scrollPASS and Samsung route/back/scroll/Album/fullscreen smoke recorded exactly
in [navigation report](GLOBAL_NAVIGATION_UX_REPORT.md). This does not close R10.
[Complete session handoff](R10_SESSION_HANDOFF_2026-10-28.md) preserves all interim
media/UI/lifecycle/Poll conversion/naming decisions, fixtures and acceptance gaps.


## Final acceptance gate — 2026-10-29

[Criterion-by-criterion matrix](R10_FINAL_ACCEPTANCE.md) records implementation, automated evidence, Samsung/QA iPhone observations and exact outstanding gates. R10 remains IN PROGRESS under its unchanged DoD. User freshly edited lunch Stop and sent Check-in on QA iPhone; Samsung displayed the correct Owner image/server timestamp and updated notes, with actual fullscreen/double-tap zoom verified. Peer was opened after submission, so live arrival is not claimed. New dedicated REQUIRE_REVIEW Task was created via canonical API for Member1, without editing older Tasks or reopening completed Activity. User captured/submitted manually on Samsung after camera/system overlay conflict; API currently shows exactly1 PENDING evidence and Task TODO. Reviewer physical arrival/viewer/reject/resubmit/approve remains pending.

Two narrowly justified final-gate fixes: reproduced StopComposer coordinator/notes outline collision gets16px spacing; explicit missing DoD input for Poll→Stop gains editable `stopTitle`, optional additive API field with255-character maximum and legacy null fallback to option text. Original selected option stays in Stop notes/source link; existing idempotent targets are never renamed/recreated by retry. No schema, finance, lifecycle, media authorization, socket, Home or global style change.

New focused14 PostgreSQL PASS (0fail/error/skip),50 Flutter PASS, analyzer clean. Historical59backend/360Flutter and later scoped evidence reused separately, not summed. Backend package/restartPASS; Android debug11.4s/iOS Profile40.9s buildsPASS. New candidates built but not installed while capture/review is active; physical acceptance of new spacing/title remains pending. Logs `/tmp/wedo-r10-final-{backend,flutter,analyze,android,ios,runtime}.log`. Preserve signing/Firebase/sessions/volumes and all pre-existing dirty source. No commit/push/merge.


R10 physical continuation2026-10-29: user confirms QA iPhone live evidence arrival/fullscreen, rejection, Samsung resubmission and Owner approval, then Samsung automatic completion. Canonical API verifies2 proofs (REJECTED/APPROVED), correct Task DONE. Both new R10 candidates installed in place/launched with sessions intact. On Samsung new candidate, DONE/evidence persists after reopen and during Wi-Fi loss, then network error clears after real FPT reconnect without Retry. This closes the scoped Task review/recovery gate, not all R10 DoD. Corrected Stop form/converted Stop title, paired itinerary convergence, Check-in reconnect/explicit signed-URL recovery and remaining conversion/retry/final smoke gates remain in the [live matrix](R10_FINAL_ACCEPTANCE.md). R10 remains IN PROGRESS.


## R10 COMPLETE — final unchanged-DoD closure2026-10-29

User current QA iPhone result “lịch sử/reconnect OK; smoke OK” completes the final paired acceptance checklist. [Final matrix](R10_FINAL_ACCEPTANCE.md) is authoritative for criterion-level evidence and explicitly retained limits. Samsung held-screen reorder/status/checkin-count convergence, fresh photo/viewer, Task reviewed completion/history/recovery and user Owner participation are separately recorded; explicit Poll conversions/navigation, runtime duplicate-free retry and real private URL expiry/reissue are corroborated. Current14PostgreSQL/50Flutter PASS/analyzer clean supplement prior overlapping regressions, not a new summed total. Both final candidates installed in place; source/QA/signing preserved. No new critical R10 defect. **R10 COMPLETE; R2 IN PROGRESS; R8/R9 NOT STARTED.** Historical pending notes above are superseded only within this verified scope. No new physical negative-permission/race/forced-expiry claim or all-project acceptance.
