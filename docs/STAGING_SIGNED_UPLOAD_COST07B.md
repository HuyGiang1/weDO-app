# D4.4-COST-07B — controlled R2 signed PUT live proof

## Result and boundary

2026-11-02: PASS. Exactly ONE owner-authorized live invocation, ONE JUnit test,
0 failures/errors/skips, Java 21.0.5 / AWS SDK 2.55.6; 5.663 seconds test time.
Separate new harness preflight: one offline/loopback test PASS before live access.
No accepted offline suites were rerun. No retry, application boot, staging enable,
production source change, Cloudflare setting change, deployment, Docker, VPS,
image publication, QA, signing, Firebase, MinIO, DB or Git mutation occurred.
Only the forked live test process read the two approved external credential files.
Product R2 remains COMPLETE. This is NOT a staging readiness/application E2E result.

## Harness and safety gates

- Isolated worktree /private/tmp/wedo-staging-media-admission,
  feat/staging-media-admission, base 4e76fb40bc8e3e1324f2f5cf907733fcac9c2bef.
- R2SignedPutLiveProofTest calls the real COST-07A Environment-aware staging
  S3ObjectStorageService, not a copied historical QA signer. Verifies exact target
  host/bucket/key, signed-header set, size, create-only condition and metadata.
- New preflight uses synthetic credentials and a loopback HTTP server to inspect
  actual HTTP/1.1 headers/body for normal, changed length, missing condition and
  modified condition requests. One Content-Length, no bearer, no contradictory
  framing, redirects disabled. BodyPublisher provides actual body length; the
  harness never injects a duplicate/restricted Content-Length header.
- Live HTTP client disables connect/method retries through JVM properties; SDK
  authenticated reads/deletes explicitly use RetryPolicy.none(). Bounded timeouts,
  maximum 20 explicit API calls, four allocated UUID keys, payloads <=32 KiB,
  aggregate PUT request-body budget <=128 KiB. Marker under backend/target prevents
  accidental repetition; never delete it to infer renewed authorization.
- Only synthetic PNGs in _wedo-storage-probe/<UUID>/. Each negative condition uses
  its own key; the replay reuses the exact successful S1 URL and key.
- Authenticated HEAD/GET/DELETE use explicitly supplied static credentials. No
  listing, public requests, bucket mutation, other objects or live video.
- SDK/framework logging OFF via test-only logback-cost07b.xml. Responses are read
  into bounded ephemeral buffers; safe XML parsing disables DTD/entities/external
  resources. Output contains static phase labels, numeric statuses, allowlisted
  codes/shapes only; arbitrary exceptions/messages/response bodies never emitted.

## Invocation (backend directory; sanitized child environment)

```text
./mvnw -o -Dtest=R2SignedPutLiveProofTest   '-DargLine=-Djdk.httpclient.disableRetryConnect=true -Djdk.httpclient.enableAllMethodRetry=false -Dlogback.configurationFile=/private/tmp/wedo-staging-media-admission/backend/src/test/resources/logback-cost07b.xml' test
```

JAVA_HOME selects Java 21. WEDO_COST07B_APPROVAL was set only for this child process
with the explicit one-run approval token (not a storage credential), removed from
its launcher afterwards and absent from the parent environment. No credential
value was passed in CLI arguments or environment. A normal suite without explicit
approval/preflight mode skips this test. Do NOT execute again without new approval.

## Measured live results

| Phase | HTTP / allowlisted error | Result / object evidence |
|---|---|---|
| S1 PUT, correct signed headers | 200 | PASS |
| S1 authenticated HEAD | 200 | Declared size, Content-Type, declared-size and original filename metadata match |
| S1 authenticated GET | 200 | Exact PNG bytes match |
| S2 changed Content-Length with correctly framed different-sized PNG | 403 SignatureDoesNotMatch, S3_XML | PASS; exact-key HEAD 404 NoSuchKey |
| S3 missing If-None-Match | 403 SignatureDoesNotMatch, S3_XML | PASS; exact-key HEAD 404 NoSuchKey |
| S3 modified If-None-Match | 403 SignatureDoesNotMatch, S3_XML | PASS; exact-key HEAD 404 NoSuchKey |
| S4 same URL/key PUT replay | 412 PreconditionFailed, S3_XML | PASS |
| S4 authenticated HEAD / GET | 200 / 200 | Original size, metadata and bytes unchanged |
| S5 four exact-key DELETEs | 204 each | Cleanup PASS independently |
| S5 four post-delete HEADs | 404 NoSuchKey each | All allocated keys absent |

Four unique keys allocated; one object successfully created; three negative keys
were absent before cleanup. Four exact-key delete attempts, four post-cleanup
absences. Five PUT attempts; aggregate attempted request-body budget 368 bytes;
20 explicit R2 API calls. All within approval. These are request/test measurements,
not billing metrics or a claim of zero cost. No orphan observed after cleanup.

## Security conclusion and limits

- Prior A1 independently proves actual SDK SigV4 binding. This live evidence now
  demonstrates R2 rejection of changed signed length and missing/modified signed
  conditional headers, plus create-only replay prevention for the tested requests.
- S2 used Content-Length equal to the actual NEW payload size, different from the
  signed original size. It proves that altered, correctly framed request was
  rejected and did not create the exact object. It does not prove universal hard
  upload-size enforcement for every transport, chunked/framing variant or client.
- Truncated connections, contradictory header/body lengths, request smuggling,
  chunked oversize payloads and malformed framing NOT TESTED. No video tested.
- Same-length content is not cryptographically bound (UNSIGNED-PAYLOAD). Existing
  issued URLs remain usable until expiry subject to their signed constraints.
  Conditional protection does not prevent all request/operation charges or new-key
  orphan creation, and does not revoke prior URLs lacking these constraints.
- Native Android/iOS real-network compatibility and pending-outcome UI/manual
  reconciliation remain separate gates. No automatic application write retries.
- Storage quota/rate limits, backup/restore consistency, retention and VPS disk/
  headroom/deployment remain pending. COST-06 staging switch stays CLOSED; existing
  GHCR image contains neither COST-06 nor COST-07A.

## Preservation and review

Production/backend, Flutter lib and infra hashes (606 paths) unchanged from before
COST-07B. QA branch/diffstat/signing diff hash unchanged; protected stash preserved.
Current task adds test harness, test logging config, this report and a handoff entry
only. No commit/stage/push/merge. Existing dirty implementation remains intact.

Sanitized evidence: /tmp/wedo-cost07b-live.log, /tmp/wedo-cost07b-preflight.log and
JUnit report in backend/target/surefire-reports. Scans found zero signed URL/query,
X-Amz-Signature/Credential values, synthetic credential values or SDK wire/debug
logging patterns; actual credentials are never read for comparison by the scanner.

Recommendation: Approach A can proceed to separately authorized Android/iOS
network compatibility verification. No additional production fix is justified by
this live result. No current evidence requires switching to bounded gateway B;
reconsider only if later transport/size safety gates fail. Do not start COST-08,
quotas, backups, another live run, upload enablement or deployment automatically.
