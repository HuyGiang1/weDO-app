# D6 backend-first staging media enablement

## Status (2026-11-03)

LOCAL backend implementation verified, not yet released or enabled. Dedicated
worktree /private/tmp/wedo-d6-demo-media, feat/d6-demo-media-guards from dev1d0c2df.
Existing VPS image61f46cbaeef07f0f7ac20559b54ef7e599844df8bda869b808acdb0b986a488e
and runtime CLOSED unchanged. No R2 request/deploy/password rotation/native rebuild.
Installed Android/iOS staging candidates remain the first clients to test after
server acceptance. Simulator DEFERRED, pushDISABLED. No full-parity claim.

## Server contract

Staging-only allowlist maximum3canonicalUUIDs, no embedded identities. Coarse env
switch false by default; malformed/missing cohort or unsafe numeric/boolean settings
fails CLOSED. Ceilings may be lowered but not raised beyond approved demo policy:
images5MiB, MP4video20MiB, cumulative150MiB,5admissions/user/sliding600seconds.
Video requires explicit separate opt-in. Existing per-module authorization/MIME/
filename checks remain before budget reservation and presigning. SDK continues to
sign exact Content-Length,If-None-Match*,Content-Type/metadata; requiredHeaders
come from actual signed request. No frontend-only quota, custom object key or
separate socket/financial rule introduced.

V21 adds two infrastructure tables, V0–V20 unchanged:
- staging_media_upload_control singleton id1, enabledfalse. Operator-only DB latch,
  no HTTP administration endpoint or new secret. Settingfalse atomically prevents
  new reservations without restarting backend or interrupting text Chat.
- staging_media_upload_reservations UUID/UserFK/uniquekey/positivebytes/serverclock,
  index(userId,createdAt). FORUPDATE oncontrol serializes quota/rate decisions across
  processes; REQUIRES_NEW commits a reservation before URL can escape. Active and
  abandoned/unknown/failed admissions all remain charged. Rate window expires,
  cumulative quota does NOT. Closing/reopening/restarting never resets accounting.
  No automatic refund/GC/delete. This bounds potentially uploaded new bytes even
  when confirmation never arrives; orphan objects remain accounted, not unbounded.

Legacy multipart filesystem avatar is always rejected in staging, even when media
admission is open. Current Flutter already uses authorized R2 AVATAR/GROUP_AVATAR
presign routes. Non-staging legacy/product behavior and size policy unchanged.
Disabled/nonallowlisted/oversized/rate/quota/presignrequired have distinct safe HTTP
codes; no ID, bucket credentials or signed URL in error responses.

## Limits that are NOT a Cloudflare spending cap

5/10min is the admission/presign request rate, not every network packet to R2.
Issued URLs cannot be instantly revoked by the app latch and retain existing10min
TTL; signed GET remains5min. Replayed writes are rejected by If-None-Match but R2
operation usage, repeated reads and denied requests may still incur provider costs.
No claim of $0 or absolute spending cap. Private bucket/authorized application reads
remain; not enabling public domain/write or changing R2 tokens/settings. No object
listing/deletion required for this conservative slice. Actual cumulative ledger
usage and provider metrics are separate evidence, never estimated $0.

## Focused verification

Final latest10+1 testclasses:114PASS/0FAIL/0ERROR/0SKIP on local isolated tests.
Covers PostgreSQL17 concurrentquota/rate, per-userwindow, permanentbudget, repeatkey,
restart/newinstance, outerrollback retention, runtime latch close/reopen;
actual authenticated MockMvc admission/rejection/legacybypass/coreprofile reads;
size/config caps/videoauthorization; SDK signature constraints; ordinarynonstaging
uploadauthorization; fresh fullschema22migrations/Redis/stagingbootstrap. Flyway
using oldV0–V20 resource set validates database with additiveV21 (not an actual old
container rollback smoke). Static Compose/isolationPASS,18CI-helperPASS,
36publisher/provenance/permission testsPASS. No realR2/nativePASS from these tests.

History:initial89had1failure because old staging10MiBtest intentionally conflicts
with newly approved5MiBlimit; updated exactboundary then31pathsPASS. One newAPItest
attempt could not access Docker from sandbox; six initializationerrors, no cases
executed; rerun with approved Docker access7APIcasesPASS. Historical failures not
relabeled as successful runs. No assertions skipped/expanded to make tests green.

## Release and activation gates

1. Review/explicitGit authorization; stage backend/config/schema/docs/CI ONLY.
   Exclude uncommitted preliminary Flutter drafts, volatilelocalhandoff and all
   generated __pycache__/pyc/build/liveproof/secret files. No MacQA changes.
2. PR exact-source CI builds linuxamd64 image and CLOSED default runtime smoke,
  22migrations, REST/WS/persistence. publication-candidate remainsPENDING_VALIDATION
   until actual CI artifactID/archiveSHA/configID/source revision verified.
3. Merge only reviewed passing source under branchrules; metadata-only provenance
   record from verified artifact. Protected GHCR environment approval by OWNER UI,
   no bypass, no rebuild/tagoverwrite. Verify remote immutablemanifestdigest.
4. Fresh ownVPScapacity check, verify Reader, actual encrypted predeploy PGbackup
   offhost; retain prior independently verified PG17restore evidence. Pullnewdigest
   only with dedicated Readerconfig; capture ownbackend/PG/Redis/volumes+other
   workload metadata. Do not access other apps' credentials/data.
5. Copy ONLY own Compose/env updates; own backend recreate ONLY, SAME PG/Redis/
   volumes/port18280; Flyway applies V21. Deploy env uploadfalse and DB latchfalse.
   Verify22migrations/coreREST/textWS/existing data before opening.
6. Configure exactly3verifiedsyntheticUUIDs externally (accounts.json IDs only),
   image5MiB/video20MiB/quota150MiB/rate5/600, videooptiniftested. Coarseenabletrue
   requires ownbackend environment restart once; DB latch stillfalse. Only after
   positive server gates set ownDBcontrol enabledtrue. No userpassword change.
7. Actual tiny synthetic native/API E2E respecting quota/rate; no broad testobject
   cleanup. Current apps FIRST. NoFlutterbuildifhappy paths work. Record unsupported
   policy/unknown-outcome UI as actualclientdefect before completing/publishingdraft.

Emergency immediateclose (operator on dedicated ownPG only):
UPDATE staging_media_upload_control SET enabled=false WHERE id=1;
This is not a public API and does not reset reservations/revoke already-issuedURLs.
After demo close latch, verify newpresign403/textChatworks; also restoreenvfalse
on next approved ownbackendcycle. Reopening requires operator decision, noautotimer.

Rollback:close DB latch, set envuploadfalse, use PREVIOUSimmutableimage explicitly,
recreateONLYownbackend. Retain newtables/reservations/PG/Redis/media volumes; no
migrationundo/reset/objectdeletion. Verifyhealth/403/coreREST/authWS/data. Preserve
Nginx/DNS/certs/otherprojects. Fail closed and stop on identity/schema/data/health
failure. Newimage not published/deployed yet; actualrollback image gate pending.

## Client observation / drafts held

Reported iPhone “Không thể kết nối” is consistent with verified source defect:
MediaUploadService.uploadImage catches everyDioException asnetwork_failure, including
403policy; ChatRepository renders genericnetwork. No exactiPhoneHTTPtrace captured
thisphase, so do not assert a new physicalreproduction. Existing uploadunknownoutcome
exception prevents automaticPUTretry but draftmanualSend could presign again;
preliminary isolatedFlutterpatches are UNFINISHED/UNTESTED and EXCLUDED frombackend
checkpoint. Installedcandidates/source are unchanged. Backend-firstownersteering
requires test existingapps first, rebuild only for confirmedclientproblem.

Remaining:Git/PR/CI/image/guardedliveactivation, realR2nativeimage/videoauthorization,
all pairedE2E/nativecoverage, simulatorlater, backup/renewalautomation. CurrentNO-GO
for media/fullparity until actual evidence. No real financialtransactions allowed.
