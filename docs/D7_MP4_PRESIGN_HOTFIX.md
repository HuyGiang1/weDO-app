# D7 staging MP4 presign hotfix

## Verified defect and exact scope

D6 source8726b182, deployed digestfd201c45...651fc24, admits opt-in MOMENT_VIDEO
at the admission layer, but S3ObjectStorageService.presignPut still rejects every
non-image MIME in its staging branch. This residual COST-07A restriction produces
ObjectStorageException/HTTP500 at line118, before any presigned URL is returned.
The D6 budget test mocks storage and missed this transport mismatch; the older
storage test explicitly expected MP4 rejection while video was disabled.

Actual D7 synthetic MP4 request (16645 bytes, locally generated H264/3seconds)
returned500. Sanitized own-backend frames confirm the exact exception/line. No
video PUT/HEAD/GET happened; no provider failure or client defect is inferred.
The durable reservation remains charged conservatively despite presign failure.
Images/avatars/Community/native photo sends continue working under existing caps.

## Minimal correction

Permit exactly video/mp4 alongside the previous image MIME check at the S3 signing
boundary. The authenticated admission layer still enforces explicit video opt-in,
20MiB ceiling, three-user allowlist, cumulative150MiB reservation budget and5/600s
rate. No new upload route, identity, schema, timeout, TTL or API contract.
Exact Content-Length and If-None-Match remain cryptographically signed; all actual
SDK signed non-host headers still form requiredHeaders. Arbitrary binary types
remain refused. Non-staging paths are unchanged.

Tests exercise real S3Presigner with synthetic offline credentials: MP4 returned
headers/signature consistency, PNG+MP4 independent SigV4 recomputation, removed/
modified length/conditional/content-type headers rejected, default video disabled,
size bounds/permission-before-reservation and budget rejection preserved.

## Evidence

- Added real-transport MP4 regression first: RED1test/1ObjectStorageException.
- After correction:32focused offline tests PASS,0failure/error/skip:
  StagingSignedUploadTest14, SignedUploadConstraintsProofTest2,
  StagingMediaBudgetPolicyTest16.
- One sandboxed verification attempt had3Mockito attach initialization errors;
  the14storage+1priorproof checks passed, then rerun with permitted JVM attach
  completed all32. No source assertion changed to hide the sandbox problem.
- No live video retry, R2 credentials read, full regression, Docker image build,
  Flutter changes/rebuild, VPS patch, signing change or QA modification.

## Release gate

publication-candidate.json is reset to PENDING_VALIDATION so no old image identity
is selected for this changed backend. Commit/push/PR/merge need owner Git approval.
Only a newly validated exact-source CI artifact may become the new publication
record; protected GHCR approval stays OWNER UI. Never use a metadata commit SHA
as the image source, rebuild the approved artifact, or substitute the D6 image.

Before deploying a new immutable digest: fresh own-resource/capacity/backup gates,
preserve all staging records, V0–V21 and reservation accounting. Replace only own
backend and retain prior digest for rollback; do not reset reservations. Follow
CLOSED/latch verification gates before controlled synthetic MP4 PUT/confirm/GET/
range and existing native player tests. No Flutter build unless a separate actual
client defect requires it. Keep push disabled and all brother resources untouched.

Current video staging status: BLOCKED ON BACKEND HOTFIX RELEASE. Local fix is
READY FOR REVIEW, not yet committed/published/deployed or physically video PASS.
