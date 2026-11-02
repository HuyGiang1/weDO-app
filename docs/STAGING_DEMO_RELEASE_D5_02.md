# D5-DEMO-02 — staging demo release candidate, LOCAL preparation

2026-11-02. READY for owner to review/authorize a selective commit, push and PR;
NOT READY to merge/publish/deploy without the gates below. No new release SHA,
CI run/artifact or registry digest exists yet. No secrets were accessed and no
network, Docker, Maven, Flutter, VPS or deployment command was executed here.
Product R2 remains COMPLETE. Domain wedoapp.site ACTIVE is owner-reported; no DNS,
TLS or API hostname readiness is implied.

## Source integrity and isolation

Worktree `/private/tmp/wedo-staging-media-admission`, branch
`feat/staging-media-admission`, base HEAD `4e76fb40bc8e3e1324f2f5cf907733fcac9c2bef`.
Remote refs are cached; no fetch was performed. Mac QA and its untracked D4.3/D4.4,
local signing, app candidates, runtime, data and protected stash were untouched.
No changes to Java/Flutter production behavior in D5. Earlier COST-06/07A production
changes remain present and hash-identical to the start of this task.

- Presign POST /api/v1/uploads/presign checks active user then mandatory admission
  BEFORE all ten category paths can issue PUT URLs. Task/Journey share MOMENT_IMAGE.
- Legacy multipart POST /api/v1/media/avatar checks admission before reading bytes
  or storing local avatar. Multipart ingress/spooling is still not a spending or
  network byte cap; later approved proxy/body-size controls remain separate.
- Staging default false/empty allowlist, missing/invalid configuration fail closed.
  Non-staging no-op, module permissions and core read paths unchanged.
- V0-V20: exactly 21 migrations, byte-identical to HEAD, no DB/schema change.
- Closed admission does not revoke prior PUT URLs, disable authorized reads or
  prevent charges on direct R2 requests. Existing GHCR image cannot gain the guard
  from env flags. Do not deploy its historical digest as the CLOSED candidate.

## Smallest publisher correction: reviewed fixed record, no latest selection

Removed executable historical SOURCE/run/artifact/checksum/image-ID constants.
No workflow_dispatch, auto-latest lookup, arbitrary registry/repository input,
new token, new permission or weakened environment gate was introduced.

`infra/staging/publication-candidate.json` contract:

- schemaVersion=1, platform=linux/amd64, mediaUploadPolicy=CLOSED.
- PENDING_VALIDATION: sourceSha, validationRunId, validationRunAttempt, artifactId,
  archiveSha256, imageId are ALL null. Safe checks pass offline; preflight/publish
  jobs are not scheduled. Invalid/partial/duplicate/unknown fields fail closed.
- VALIDATED: full lowercase 40-hex source SHA, positive integer run/attempt/artifact
  IDs, 64-hex archive SHA256 and sha256-prefixed image config ID. Values must come
  from actual reviewed CI evidence, never example values or environment overrides.
- selection exports only type-validated record values. New immutable tag stays
  `ghcr.io/huygiang1/wedo-backend:<full-source-SHA>`, never latest or mutable rc.

Publisher rechecks hosted runner, correct repository, successful exact PR workflow
run + attempt, exact same-repository source/artifact origin/name/not-expired status.
Full checkout history proves validated source is an ancestor; backend/mobile/scripts,
Compose/env and validation-workflow trees must be unchanged at publisher checkout.
A record-only publication commit/merge can differ from the compiled source SHA;
a runtime/CI-code change requires a NEW validation, not metadata relabeling.

The SAME artifact contains image.tar.gz and validation.json. Metadata binds source,
run/attempt, archive SHA, image config ID, linux/amd64 and actual uploadClosedSmoke
PASS. SHA256 and bounded/type-checked evidence are verified BEFORE Docker load;
platform/UID10001/revision/config-ID verified afterwards. Publisher never builds.
Registry collision rejection, environment review, final pre-push approval recheck,
remote manifest SHA256/config identity and digest pull/layer verification retained.
The extra metadata is not a new independent cryptographic attestation: trust still
requires reviewed source/CI, GitHub artifact provenance and protected publication.

## CI additions (prepared, NOT executed against an image locally)

- Validation selects existing guard/path/profile/S3 signing focused tests; no live
  R2 probe class is selected. No credentials or QA fixtures in image context.
- Disposable hosted-runner actual-image smoke logs in its own synthetic active
  user and requires HTTP403 for ALL ten presign categories plus a valid multipart
  legacy avatar POST. 401, validation400 and success are FAIL, not CLOSED evidence.
- Legacy media file list must remain unchanged after the rejected upload. Then
  existing login/me/groups/WS401/101, app/PG recreation and persistence checks run.
- Only after the full smoke succeeds is validation.json created alongside the
  exact archived image. Artifact retention remains7days; publication evidence30days.
- Compose static validation now asserts false/empty effective guard environment.
  No server build; private external S3 remains configuration-only for CLOSED demo.

## Focused LOCAL verification

- Publisher:36 offline tests PASS,0fail/error/skip, including new reviewed record,
  pending-no-network path, safe outputs, source ancestry/tree mismatch, run attempt,
  sidecar failure boundaries; retained approval/permissions/collision/redaction.
- CI helper:18 offline tests PASS,0fail/error/skip. Ten-category Java enum parity,
  all11routes must403, raw multipart/JSON transport, wrong-status rejection,
  Compose/profile/env defaults and CI evidence contract plus existing helpers.
- Both workflow YAML files, Compose and staging profile parse offline. Real
  selection on the actual pending record prints publication disabled. Diff check
  clean. No Docker daemon/config invocation, image test or registry request locally.
- COST-06 accepted61 / COST-07A79backend+29Flutter / COST-07B live PASS retained,
  NOT rerun or summed into54 new/affected Python tests. Core REST actual-image
  proof for THIS candidate remains a future CI gate, not an offline PASS claim.

## Reviewed inclusion/exclusion for future selective staging

INCLUDE all current legitimate production changes: MediaUploadAdmissionGuard,
UploadService, MediaService, S3ObjectStorageService, Flutter media_upload_service;
COST config/profile/Compose/env template; all associated safe unit/regression tests;
CI publisher/workflows/helpers/tests/record and current delivery/handoff docs.

PRESERVE LOCAL / EXCLUDE from checkpoint: R2SignedPutLiveProofTest.java and
logback-cost07b.xml (Mac/account-specific live probe harness). Existing live-run
markers, logs, target/build caches, image archives, external secrets, QA artifacts
and iOS signing are not release inputs. Never stage all files blindly.

Synthetic credentials/identities exist ONLY in intentional test fixtures and
throwaway CI data, not production configuration or VALIDATED release identity.
Pending identity fields are null, not fake SHA/run/artifact values. Pattern scan
found no private keys, JWTs, GitHub tokens or service-account private key material
in pending source. No binary/generated build artifact or accidental deletion found.
This targeted scan is not a mathematical guarantee; review staged diff again after
owner approval, without reading real secret files. Preserve all excluded files.

## Exact next approval and release sequence

1. Owner authorizes selective commit AND push/PR separately; refresh origin/dev
   without switching/resetting QA, check actual divergence, review full staged diff.
2. Commit reviewed source with record PENDING; push feature, PR ->dev. Run the
   prepared staging-validation CI against exact source S. Actual built-image CLOSED
   smoke, core REST/WS,21migrations/persistence must PASS. Record CI run/attempt,
   artifact ID, archive SHA and image ID. No publication at this stage.
3. Owner reviews S and evidence. In a separately reviewed metadata update, fill the
   record VALIDATED from those real values only. Prefer a second PR after RC merge;
   no cherry-picking/rebasing/squashing away source ancestry. If S is not retained
   as ancestor, run new validation on the appropriate retained source instead.
4. PR metadata/publisher audit must PASS; runtime/CI trees unchanged from S. Owner
   separately approves merging the publication record into dev. Main untouched.
5. Expected dev-push workflow passes read-only safe checks/preflight, then publish
   WAITING in staging-image-publication. Reverify effective reviewer/dev-only rules,
   package Private and Actions access. No approval is implied by commit/merge.
6. Only separate environment approval permits packages:write job. Download exact
   artifact IDs, verify hash/sidecar/image identity, collision-check SHA tag, push
   unchanged image, record verified remote manifest digest and pulled image identity.
   Staging uses `ghcr.io/huygiang1/wedo-backend@sha256:<new-verified-manifest-digest>`.
7. Any failed/missing evidence, expired artifact, ancestor/tree mismatch or tag
   collision => STOP; do not rebuild in publisher, relax checks, overwrite tag or
   fall back to the old image. New validation/record review needed as applicable.

## Final image acceptance and remaining non-Git gates

Before publication: actual image staging profile, CLOSED+empty allowlist, all10
presign403/noURL, legacy avatar403/no new file; auth/me/groups/WS work, PG/Redis
healthy,21migrations and persistence PASS; linux/amd64/nonroot/revision/hash match.
No Firebase credentials required while push=false. Missing/invalid staging settings
reuse accepted fail-closed unit evidence; do not enable upload to prove CLOSED.

Blocking merge/publication NOW: no committed release S, no fresh PR CI/image/sidecar,
record intentionally pending, no new artifact/digest and no Git/environment approval.
No architectural shortcut is required. READY only for owner Git review/approval.

VPS deployment remains NO-GO until separate capacity/headroom, GHCR Reader, six
staging secrets, independently tested off-host restore/rollback, reserved isolated
paths/port and HTTPS/WSS approvals. wedoapp.site ownership is not TLS readiness.
Do not deploy, create DNS/Nginx or expand COST-08+ automatically.
