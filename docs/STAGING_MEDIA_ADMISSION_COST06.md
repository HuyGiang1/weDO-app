# D4.4-COST-06 — Staging media upload admission guard

2026-11-02. LOCAL implementation/offline evidence only; not enabled or deployed.
Isolated worktree `/private/tmp/wedo-staging-media-admission`, branch
`feat/staging-media-admission`, baseline freshly fetched origin/dev
`4e76fb40bc8e3e1324f2f5cf907733fcac9c2bef`. Dirty Mac QA checkout remains untouched.
The previously published GHCR image DOES NOT contain this uncommitted guard.

## Contract

Guard applies if `staging` is accepted by Spring Environment, including mixed
`local,staging` or a staging default profile. It is a no-op on other profiles;
it does not inspect staging properties in local/test/teammate/production-only mode.
Active-user check remains first; admission then runs before signing/local writing.
All existing category/context/MIME/size/role/membership checks remain in place.

| Environment | Spring property | Default / valid syntax |
| --- | --- | --- |
| WEDO_STAGING_MEDIA_UPLOAD_ENABLED |wedo.staging.media-upload.enabled |`false` (CLOSED); exact lowercase `true`/`false` only |
| WEDO_STAGING_MEDIA_UPLOAD_ALLOWED_USER_IDS |wedo.staging.media-upload.allowed-user-ids |empty; comma-separated1–10 distinct canonical UUIDs |

Allowlist is operator-provided, never hardcoded. Surrounding whitespace per CSV
entry is trimmed; UUID hex case accepted. Wildcard/names/emails/short UUIDs,
duplicate entries/empty entries/>10 entries are invalid. Missing/invalid settings
deny all upload admission with existing403 ACCESS_DENIED and generic message;
they do not need to crash the backend to be fail-closed. CLOSED works with empty
allowlist, allowing normal read-only staging startup. Errors do not disclose IDs.

application-staging.yml maps the two variables; staging Compose forwards them with
CLOSED/empty defaults and staging.env.example remains false/empty. No actual IDs,
external env files or existing QA configuration were created/changed. Operator
must separately approve enabling and supply actual UUIDs out of Git.

Configuration is a startup snapshot, not a hot-reload/admin API. A future change
requires owner-approved staging backend restart/recreation; closing does not
invalidate URLs already issued. Multi-instance operators must change every instance.
This phase did not restart anything or set the switch ON in any runtime.

## Coverage and intentional limits

Guarded service entry points (constructor-injected mandatory guard):

- POST `/api/v1/uploads/presign`, all10 UploadCategory values: AVATAR, GROUP_AVATAR,
  CHAT_IMAGE, MOMENT_IMAGE, MOMENT_VIDEO, COMMUNITY_IMAGE, EXPENSE_RECEIPT,
  FUND_CONTRIBUTION_PROOF, FUND_EXPENSE_RECEIPT, FUND_REIMBURSEMENT_RECEIPT.
- Task proof and Journey check-in use MOMENT_IMAGE through the same presign path;
  Album reuses Moment media references, no separate upload/signer bypass found.
- POST `/api/v1/media/avatar` legacy multipart is ALSO guarded before file bytes
  are read/stored by MediaService. This prevents persistent local avatar writes;
  Spring multipart parsing may still accept/spool incoming bytes before the service
  check. This is not a request-body/network ingress limit.

Intentionally not revoked/blocked by admission:

- Direct R2 PUT using an already-issued signed URL, raw S3 credentials/operator
  scripts: do not traverse backend guard. URL TTL/replay/oversize risks remain.
- Existing media access GETs/signed GETs, local legacy avatar reads, attach/confirm
  business mutations and HEAD verification retain existing authorization. No read
  spending cap; closing admission does not prevent finishing earlier valid uploads.
- No cumulative bytes/files quota, upload intent/reservation, throttle, deletion,
  cleanup scheduler, Cloudflare budget cap or schema/migration in this slice.

## Focused offline verification

Java21.0.5/Maven offline, no DB/Docker/network/R2 or real credentials.
Initial plain run encountered Mockito self-attachment restriction in sandbox;
rerun used existing local Mockito5.23.0 JAR as `-javaagent` via command argLine only,
without changing POM/tooling globally. Final **61PASS/0fail/error/skip**:

- MediaUploadAdmissionGuardTest21: missing/invalid/open/closed/allowlist bounds,
  duplicate/malformed IDs, mixed and non-staging profiles, startup snapshot.
- MediaUploadAdmissionPathsTest27: allcategories closed/nonallowlisted, allowed
  avatar sign, active-user/Group/Chat permission checks, legacy write bypass blocked,
  non-staging local writer preserved, real Spring constructor injection closed.
- Existing affected UploadServiceTest5 + MediaServiceLegacyAccessTest1.
- StagingProfileTest7: real YAML/env mapping/default closed and explicit allowlist,
  with synthetic temp secret fixtures only; existing staging config evidence retained.

No live/offline R2 probe or unrelated full suite rerun. No Compose daemon/config
execution; local Compose forwarding defaults reviewed in source, not VPS-validated.

## Remaining gates / COST-07 proposal only

READY for Technical Lead code review, not deployment or enabling. Owner must
separately approve actual allowlist/opening and commit/push/build/publication when
appropriate. Published digest is unchanged; it cannot gain this behavior by env alone.
Quota/rate-limits/transport byte enforcement/presign replay/orphan/backup consistency
remain COST-07 decisions, not automatic next work. Native app/media authorization/
video/backup restore/VPS disk headroom remain independent pending gates.
Product R2 status and historical LIVE-03 Maven FAIL are unchanged.
