# D4.4-COST-07A — signed upload constraints (local only)

## Scope and status

2026-11-02: A1 PASS, A2 implemented, A3 focused offline PASS; READY for Technical
Lead review, NOT evidence of provider-enforced hard upload size. Worktree:
`/private/tmp/wedo-staging-media-admission`, `feat/staging-media-admission`,
base `4e76fb40bc8e3e1324f2f5cf907733fcac9c2bef`. COST-06 changes remain uncommitted
and preserved. No commits, push, deployment, image build, real credential access,
R2 calls or device changes. Published image still lacks COST-06/COST-07A.

## A1: real SDK proof, not request-builder inspection alone

AWS SDK 2.55.6, Java 21.0.5, real S3Presigner, explicitly synthetic static
credentials and an `.invalid` endpoint. The signed request includes content-length,
if-none-match, content-type and declared-size metadata. An independent SigV4 HMAC
implementation reconstructs the canonical PUT/query/headers/UNSIGNED-PAYLOAD and
verifies the actual signature. Removing OR modifying each of content-length and
if-none-match independently fails signature verification. No endpoint is contacted.
The test uses static assertion labels, never prints URLs or signature material.

## Staging implementation contract

- Spring staging profile (including mixed profiles) applies exact declared length
  and If-None-Match `*` to every S3 presigned PUT. Existing unique keys, metadata,
  ten-minute expiry, module permission checks, HEAD/confirmation remain unchanged.
- REST shape is unchanged: requiredHeaders is extracted from actual SDK signed
  headers; Host is transport-supplied. Missing required fields, multiple values,
  case-duplicate names, wrong length/condition, CR/LF or authorization fail closed
  with a static message and no request/cause in the constraint exception.
- Non-staging keeps the previous presign headers and permits its existing video
  path. Seven-argument direct construction remains a non-staging compatibility
  entry point; Spring uses the required Environment-aware constructor.
- Staging rejects MOMENT_VIDEO even with spoofed image MIME, plus non-image MIME,
  before signing. Storage layer also rejects non-image staging presigns. This is
  category/MIME admission, not magic-byte validation or a content scanning service.
- COST-06 allowlist (maximum ten IDs), startup configuration validation and CLOSED
  default are unchanged. No upload setting was enabled or configured in a runtime.
- Legacy multipart avatar remains protected by COST-06 and its existing size/MIME
  checks, but does not use an S3 presigned PUT; signed headers do not cover that
  ingress/spooling path. No new quota, rate limiter, migration, cleanup or deletion.

## Flutter and ambiguous outcomes

- Required header names are handled case-insensitively. Duplicate names and any
  required Authorization are rejected. A separate direct client carries no backend
  bearer; an accidentally configured default Authorization is explicitly removed.
- Actual Uint8List length must equal any supplied Content-Length. Constrained
  targets must carry both matching length and `*`, and both names must appear in
  the URL's signed-header declaration. Dio receives one normalized length header.
- Streams count chunks without buffering the file: overflow chunks are not emitted;
  early EOF fails. Native transport can already have transmitted preceding bytes,
  so a stream/transport error does not prove the R2 object is absent.
- Constrained PUT redirects are disabled. There are no automatic PUT retries or
  automatic HEAD/confirmation requests. HTTP 412 yields `upload_conflict`; other
  ambiguous PUT failures yield `upload_outcome_unknown`, both with a retained key
  in MediaUploadPendingException, without raw Dio cause/URL/body. A 412 may mean
  that an earlier write succeeded. A missing/failed HEAD is not conclusive failure.
- Callers must reconcile a pending key through authorized confirmation/manual
  review; no new UI reconciliation workflow is implemented. User-initiated retries
  that obtain new keys can still leave orphans. Existing UI shows its generic
  failure state; do not infer safe automated retry or orphan prevention.
- Non-constrained existing uploads retain their error/redirect behavior. Android
  and iOS wire-level framing, platform headers and provider behavior are UNVERIFIED.

## Focused offline evidence

- Backend: 79 unique tests PASS, zero failure/error/skip across real signing proof,
  staging signed-header tests, admission guard/paths, existing upload/legacy avatar
  and staging profile tests. Includes 5 MiB avatar and 10 MiB image boundaries,
  staging video rejection, existing auth and CLOSED/missing config protections.
  Initial 78 run, then affected path/config checks (38) and signed-header checks
  (13) after added assertions: counts overlap and must not be summed.
- Flutter: 26 new constraints + 2 existing upload + 1 existing Moments stream test
  PASS (29 total). Adapter-only, no sockets. Focused analysis: no issues.
- Maven offline; sanitized process environment; synthetic credentials only. No
  debug/wire logging, raw URL/credential diagnostics or external secrets read.
  Reports checked for signed URL/signature patterns and synthetic credential leakage.
- No full suites, backend runtime restart, Docker, QA change or physical app build.

## Separate future live approval proposal (not executed)

One bounded synthetic PNG scenario with fresh UUID keys for independent negative
cases: exact-size PUT/HEAD/GET; missing/modified signed length or condition rejection;
controlled HTTP framing/short/long-body checks agreed with the Technical Lead;
replay of successful create-only PUT expected 412 with bytes unchanged; exact-key
cleanup of only scenario-owned keys. Never list/delete unrelated objects. Sanitized
status/phase diagnostics only; no automatic retry. Existing D4.4 live evidence does
not prove these NEW constraints. Android/iOS transport verification is separate.

## Remaining limits

Same-length content is not cryptographically bound (UNSIGNED-PAYLOAD). Previously
issued URLs remain valid until expiry. Conditional overwrite prevention on R2 and
exact-size provider enforcement require live evidence. Unlimited distinct keys,
URL replay attempts, orphan growth, GET traffic, operation charges, legacy ingress,
quota, rate limiting, retention, backup/restore and VPS headroom remain unsolved.
A kill switch cannot revoke issued URLs or create a Cloudflare spending cap.
Product R2 remains COMPLETE; historical LIVE-03 Maven FAIL is not rewritten.
No COST-08/09/10 implementation or automatic continuation is authorized.
