# R4 — private group Moments / Album delivery

Current milestone: **COMPLETE**, closed2026-10-27. R1 COMPLETE; R2 IN PROGRESS;
R3 COMPLETE; R5 IN PROGRESS; R6–R9 NOT STARTED. Implementation is additive to the existing dirty
worktree, not a claim of ownership over every changed file.

## Final closure — 2026-10-27 (supersedes pending checkpoints below)

User replied explicitly **“Album OK, chat OK, Poll OK, RSVP Ok.”** to the requested
QA iPhone same “R4 QA Member Album” logo+video opening and brief current-candidate
Chat old-image/Poll/RSVP list-read gate. This is user-reported physical evidence,
not agent-operated iOS automation. User also states they are controlling Samsung;
automatic Samsung taps were stopped to avoid conflicting actions. Do not infer
additional unreported mutation/deadline/security scenarios from these words.

The unchanged R4 Definition of Done is now supported: group feed/Album/photo/video/
Activity link/reaction/comment journeys have the previous scoped device evidence,
including user video play/seek and Samsung automatic offline recovery; remaining
same-Album and adjacent smoke gate explicitly confirmed. Required authorization
has existing isolated PostgreSQL group isolation/revocation/media tests78PASS
and Flutter stale/access-loss regressions295PASS. Current runtime anonymous GET
of the retained QA Moment returns401. That401 is a real REST check, not a physical
removed-user test. No main group member removal or R4 suite repeat was performed.
No critical known R4 regression; no definition weakened to close it.

Network changed from<QA_HOTSPOT_IP> to<QA_LAN_IP>. The tested R5 candidate retains R4
source and supplies current LAN endpoint; both platforms installed in place,
signing/sessions/data preserved. Current smoke is reported on this candidate,
not falsely attributed to an old<QA_HOTSPOT_IP> build. R5 tests do not replace old R4
evidence. Optional physical camera/multi-photo/moderation edge cases and wider
product regression remain R7/R9 follow-up; Community is R5, R2 parity separate.

## R3 closure and inventory

The R4 request explicitly reports user-operated QA iPhone Choice One/peer voting,
participant list, anonymous privacy and Chat image/scroll stability PASS.
These close the remaining R3 physical gate together with the existing55 backend,
198 Flutter, analyzer and candidate evidence. No new R3 physical observations
are inferred from the R4 tests.

Inventory found no existing Moments/Album schema or implementation. Reused
authenticated group membership, Activity references, shared reliable reads,
upload signing/object storage, AFTER_COMMIT publication, Redis fan-out and the
single app WebSocket. Chat remains the communication surface; Memories has its
own group and Activity navigation entry. No Community/Recruitment implementation.

## Persistence and retention

V15 `group_moments_albums` adds `group_moments`, `moment_media`,
`moment_reactions`, `moment_comments`, `group_albums`, `album_items`.
Canonical ownership is always the group. Activity is optional and must belong
to that group, enforced in service and SQL triggers. No implicit Activity.
Cursor feeds use `(created_at,id)`; media has stable UUID/order and unique key.
One reaction per user/post. Album associations reuse media IDs and object bytes.

Moments, comments and albums use soft deletion/audit. Deleting an album does not
delete its Moments or objects. Deleted Moments disappear from albums; existing
object bytes are retained. Unfinalized uploads can leave private orphan objects;
no automatic object deletion/garbage collection is introduced. Failed writes
never commit dangling database references. The composer retains uploaded keys
and command UUID for bounded user retries. Moment creation and optional album
attachment are separate transactions; failed attachment retries the association.

V15 passed isolated PostgreSQL integration before QA deployment. QA Flyway V15
is now applied successfully: **do not rewrite V13–V15**. Pre-migration custom
backup `/tmp/wedo-r4-before-v15.dump` is mode0600. Existing users5/polls11/
messages95/ballots14 remained unchanged across migration. New labeled R4 QA
records are separate additive acceptance fixtures, not reset data.

## API and permission contract

All endpoints require normal bearer authentication, under `/api/v1`:

| Method | Path | Behavior |
|---|---|---|
| GET/POST | `/groups/{group}/moments` | Cursor feed / idempotent UUID creation |
| GET/PATCH/DELETE | `/moments/{id}` | Detail / caption and Activity / soft delete |
| PUT | `/moments/{id}/reaction` | Set one supported emoji or null to remove |
| GET/POST | `/moments/{id}/comments` | Cursor comments / UUID-idempotent comment |
| DELETE | `/moments/{id}/comments/{comment}` | Authorized soft delete |
| GET/POST/PATCH | `/groups/{group}/albums` | Cursor list / create / edit by request UUID |
| GET/DELETE | `/albums/{id}` | Detail / soft delete |
| GET/PUT | `/albums/{id}/media` | Cursor grid / add authorized existing media IDs |
| DELETE | `/albums/{id}/media/{media}` | Remove association only |
| GET | `/moment-media/{id}/access` | Membership-authorized60-second signed GET |

Feed/album reads accept optional `activityId`; cursor parameter is `before` UUID.
Page DTO: `items,nextBefore,hasMore,canCreate`. Default REST success status is200,
including creation/deletion; no undocumented201 contract is assumed.
Create Moment: `clientRequestId,activityId,caption,mediaKeys`; edit:
`caption,activityId`; comment: `clientRequestId,content`; album:
`clientRequestId,activityId,name,description`; album add: `mediaIds`.

| Operation | Rule |
|---|---|
| Read, obtain media URL | Current active user and readable group membership |
| Create, react, comment | Mutable membership; archived groups are read-only |
| Edit/delete Moment or Album, manage album items | Creator or current Owner/Admin |
| Delete comment | Comment creator or current Owner/Admin |
| Link Activity or media | Same group, plus current access; no RSVP requirement |

IDs do not bypass membership. New upload keys must belong to the uploading user
and group. Read media DTOs expose ID/type/basename/size/order, never raw storage
keys. Signed URLs necessarily contain temporary object/signature material and
are used only in memory for rendering, not persisted/logged by the new UI.
Already issued URLs remain usable for at most60 seconds after revocation;
subsequent access is denied. This is the existing presigned-access model, not
instant cryptographic revocation of a previously issued URL. Confirmed scope
loss clears reads, composer/editor content and fullscreen media; generation
guards prevent old responses restoring it. Transient failures retain valid
read-only cached state with retry feedback rather than impersonating empty data.

## Media and UI

Upload categories `MOMENT_IMAGE` / `MOMENT_VIDEO` reuse the existing presign PUT
endpoint. Config: `media.moments.max-image-bytes` defaults10MiB;
`media.moments.max-video-bytes` defaults50MiB. Maximum8 attachments/post.
Images: JPEG/JPG, PNG, WEBP with matching MIME/extension. Video: MP4/video/mp4;
use H.264/AAC for Android/iOS interoperability. No transcoding, codec probing,
HLS or permanent public URL. Server validates signed metadata, actual object
size, declared MIME/extension and upload ownership; it does not decode file
content to establish the actual codec or inspect magic bytes.

Flutter provides feed/pagination, caption composer, gallery multi-photo/camera,
MP4 picker, progress/retry, detail/comments, reactions, album editor/grid,
existing/new media associations, Activity selector and Activity-filtered entry.
Caption editing preserves attachment identity; post attachment replacement is
not implemented. Streaming uploads avoid whole-video Dart buffers. Photo viewer
uses stable cached identity and renewed signed access on failure. Native
`video_player` renders an initialized first frame, play/pause and scrubbing;
controllers pause on background and are disposed with their widget.

## Realtime and reliability

Group-scoped `MOMENT_CREATED/UPDATED/DELETED`, `MOMENT_REACTION_CHANGED`,
`MOMENT_COMMENT_CHANGED`, `ALBUM_CREATED/UPDATED/DELETED` use existing
`DOMAIN_CHANGED` envelope/eventId and aggregate UUID. Payload empty/actor null;
only authoritative REST responses contain content. AFTER_COMMIT only, no
rollback events, same Redis/shared socket, no manufactured version/polling.
Visible resource cards refetch only their aggregate; reactions do not refetch
the entire group/feed. Reconnect subscription/resync refetches current state.
While reading older feed content, new posts show “Có bài mới” instead of jumping.
Album updates invalidate its list/detail and affected associations. Publication
remains best effort under existing R1 delivery; no new durable event outbox.

## Completed automated verification

- Backend78/78 PASS,0 failure/error/skip: MomentIntegrationTest12,
  M8MultiAccount28, ChatService14, ChatRealtime5, ChatController1,
  DomainRealtimeCoordinator6, PollService1, UploadController4,
  MediaReference2, UploadService5. Log `/tmp/wedo-r4-backend-regression.log`.
  Isolated PostgreSQL/Flyway is real; object storage is mocked in these tests,
  so this is not physical MinIO upload or device playback evidence.
- Flutter295 PASS,0FAIL: Moments16 plus affected Chat/Poll/realtime/routes/group/
  Activity regressions. Final log `/tmp/wedo-r4-final-tests.log` includes the
  reaction-change chooser regression (same test extended, count unchanged).
- Analyzer clean3.0s: `/tmp/wedo-r4-final-analyze.log`.
- Covers targeted reads, failed upload/POST retry, command/media identity,
  pagination, offline/reconnect, membership loss, stale/disposed replies,
  native-controller initialization/play and disposal request. Mock tests do
  not prove native decoder behavior on physical devices.
- Backend package PASS4.903s and deployed. Final iOS release43.3s/install/launch
  QA iPhone PASS (`/tmp/wedo-r4-ios-delivery.log`, `ios-final-install.log`); unchanged
  pbxproj/Info.plist hashes. Runner SHA256
  `0391a269f7e2c6568eb5fa635bbf566d598040daa6c3dc400b6a9cf72748d69f`.
- Android actual native playback first reproduced `Cleartext HTTP traffic to
  <QA_HOTSPOT_IP> not permitted`. Dart HTTP/images working did not prove ExoPlayer
  connectivity. Corrected only `src/debug/AndroidManifest.xml` with local QA
  HTTP permission, verified merged manifest; main/release policy unchanged.
  [Official Android explanation](https://developer.android.com/media/media3/exoplayer/troubleshooting#fixing-cleartext-http-traffic-not-permitted-errors).
  Debug rebuild4.3s PASS (`/tmp/wedo-r4-android-native-fix.log`). No iOS/source/
  backend rebuild needed for this Android-only configuration correction.
  No unrelated full suite.

## Environment and physical acceptance checkpoint

Mac en0 `<QA_HOTSPOT_IP>`, Samsung `<QA_HOTSPOT_IP>`, QA iPhone hotspot `<QA_HOTSPOT_IP>`.
Backend local/LAN UP; PostgreSQL ready, Redis PONG, MinIO local/LAN ready.
Existing containers/volumes preserved. Backend runtime `/tmp/wedo-r4-runtime.log`;
LAN MinIO relay `/tmp/wedo-r4-media.py` allows only current Mac/these two devices
and forwards to existing localhost9000 without altering S3 authorization.
Disk about11GiB; no cleanup performed. Leave QA runtime running.

Actual Samsung Home → QA group → feed/composer; selected only explicitly copied
`wedo-r4-qa.png` logo and published photo Moment linked to existing R2A QA25-10.
User created photo Moment on QA iPhone (reports “Đã đăng”). Samsung observed that
authorized photo, reacted and commented `R4 QA Member comment`; user confirms
QA iPhone automatically saw1 reaction/1 comment, could view the logo fullscreen, and
reacted/commented back. These are scoped real device observations, not a full
R4 acceptance claim. No personal-media selection was automated on either phone.

Samsung unexpectedly switched from hotspot<QA_HOTSPOT_IP> to UTT_Free10.40.24.217,
causing expected offline banners/failed requests. User rejoined QA iPhone hotspot;
retained composer successfully retried the same command/video. This is not an
application upload failure. Video committed once; native player policy issue
above then reproduced and corrected. Remaining video/album/reconnect device
checks are separate below. iPhone runner unsupported; no repeated initialization.

Safe additive fixtures (no old record deletion): Owner photo
`497ea29f-adbb-4872-860f-d0ed24dea157`; Member linked logo
`8e571002-5221-4eae-bd8f-40acc8289ffd`; Member video
`6aafbcb3-fdd3-4449-8340-377930fd4fbc`; Owner-created album
`35c573d6-aa3c-4c93-80cc-31634942ed65` (`R4 QA Owner`).
Own logo caption contains literal `%20` from an ADB entry mistake; this is a QA
fixture entry artifact, not app text encoding; later normal-space comment/video
caption rendered correctly. Keep data; no corrective SQL rewrite.

Required remaining paired gate:

1. Nhóm74DCTT23 → Khoảnh khắc & Album; create labeled R4 QA photo/caption.
2. Observe Samsung arrival without refresh; react/comment there, observe QA iPhone.
3. Samsung upload QA MP4; play on QA iPhone, then add media to R4 QA Album.
4. Open same album on both devices; link existing R2A QA Activity and verify entry.
5. Disconnect/reconnect, verify convergence without duplicate posts/comments.
6. Check Chat old image/scroll, Poll and RSVP remain stable. No financial writes.

Physical access revocation is not exercised by removing real group members;
server isolation/revocation and client stale-response tests are separate evidence.
The historical pending evidence below was superseded by the final closure above.

### Final observed device outcomes

| Journey | Evidence and scope |
|---|---|
| Owner photo → Samsung | PASS: user created on QA iPhone; actual Samsung image rendered |
| Member logo → QA iPhone | PASS: user confirms fullscreen image and own reaction/comment |
| Reactions/comments | PASS: Samsung writes through UI; user observes automatic1/1 on QA iPhone; Samsung later reads reverse1/1 on its linked post |
| Video upload/retry | PASS Samsung: retained composer retries after wrong-Wi-Fi failure; exactly one committed post |
| Video playback | PASS Samsung final APK: native first frame, play to100%, fullscreen; no current-process native errors at final capture |
| iPhone video | PASS user-reported: “video chạy, seek được, tua nhanh được...” on installed R4 candidate; not inferred from earlier “đã thấy” |
| Album create/link/add/grid | PASS Samsung: new Member album linked to R2A QA25-10, existing logo+video2media; no copied object bytes |
| Album offline/reconnect | PASS Samsung: disable Wi-Fi retains2media, error banner and disabled writes; enabling restores `.4`, banner clears/buttons reenable automatically without Retry/navigation |
| Activity entry | PASS Samsung: existing QA detail → Khoảnh khắc hoạt động shows only linked logo; Album tab shows only linked Member album, omits unlinked Owner album/video post |
| QA iPhone Album/reopen persistence | PASS user-reported “Vẫn còn” to the Album/reopen question; no separate claim that both media were played from inside that Album or that this was an offline reconnect test |
| Physical negative access/moderation | PENDING; automated membership/isolation/stale-response evidence passed, no real member removal |
| Current R4 Chat/RSVP/Poll UI smoke | PENDING new physical pass; affected automated Chat/Poll/Activity regressions295PASS, previous R3 physical passes retained separately |

Final APK SHA256 `aa76a53f2c80f1dc9053ca1f43f351817ff759208826588169ae93996ae3d434`;
iOS Runner hash above. Both installed in place, sessions preserved; only QA iPhone
and Samsung operated. Disk about10GiB. `git diff --check` scoped R4 clean;
whole-worktree warnings remain two pre-existing blank EOFs in group/profile tests,
untouched. Index empty, branch/HEAD/stash unchanged. No Git mutation/commit/push.

### Changed-path inventory

New backend: `moment/{MomentController,MomentService,MomentDtos}.java`,
`media/service/MomentMediaPolicy.java`, V15, `MomentIntegrationTest.java`.
Extended existing media `UploadCategory`, `UploadService`, `MediaReferenceService`.
New Flutter: `features/moments/data/{moment_models,moments_api}.dart`,
`presentation/{memories_screen,memory_media}.dart`, focused `moments_test.dart`.
Extended existing streaming `media_upload_service`, app routes, GroupInfo and
Activity detail navigation, route test, pubspec/lock. Added native player generated
macOS registration and debug-only Android HTTP policy; no signing/Firebase edit.
Updated R3 delivery closure, official roadmap/current handoff/API/ERD/class diagram/
stable decision log and this report. These are R4 paths, not a claim that all
pre-existing dirty files originated here.

### Limits and exact next acceptance

No known remaining critical automated R4 defect. Complete exact remaining
same-Album media-open and current R4 Chat/RSVP/Poll smoke scope; QA iPhone reopen
persistence is now user-reported PASS. Keep R4 IN PROGRESS until accepted.
Physical multiple-photo/camera, moderation and interruption during playback have
not been claimed from the single-photo/video tests. Attachment replacement,
transcoding, original-byte content sniffing, durable event outbox and orphan
object cleanup are not implemented; conservative format/retention policy above
is explicit rather than a fake completion claim. Reactions support six choices
plus removal; simple feed icon remains a generic favorite indicator.

R2 remains IN PROGRESS: broad module/list/read-model parity, Task peer/iOS edge
paths, live picker snapshots, Finance/Fund/Notification and aggregate parity remain
scoped follow-ups in the official roadmap. No R2 expansion or R5–R9 start here.
