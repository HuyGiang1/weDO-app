# D3.1 — publication-only, exact validated weDO image

## Authority, scope and state

2026-11-01. PR #10 was merged **by HuyGiang1** at09:19:10UTC into dev commit
`4b598d53cd95fd24584e0153029e020f33fe8b60`. Its validated source is
`afac8aae74ae12539e94542a3beed21cda562f3a`; dev's merge tree equals that source.
D3 read-only review independently checked artifact ZIP digest, image archive hash,
image config ID/revision/platform/user, without loading Docker on the Mac.

D3.1 authorization covers code/tests/docs, feature commit/push/PR and safe checks.
**Not authorized: merge this publication PR, execute publication, create a package,
change registry visibility/credentials, change main/default branch, access VPS,
modify QA/signing/Firebase/data or any other project.**

Existing [D1](STAGING_DEPLOYMENT_D1.md) and [D2](STAGING_DEPLOYMENT_D2_REVIEW.md)
reports are historical. Their `infra/staging/ghcr-workflow.proposal.yml` remains
inactive and must **not** be copied into active workflows: it rebuilds/consumes a
same-run image, which is not the fixed existing artifact required for this release.

## Immutable inputs; no alternative image or build

| Item | Fixed value |
| --- | --- |
| Repository / numeric ID | HuyGiang1/weDO-app /1343290226 |
| Source | afac8aae74ae12539e94542a3beed21cda562f3a |
| Successful validation run |41291866605 |
| Artifact ID |13076784704 |
| Artifact name | validated-image-afac8aae74ae12539e94542a3beed21cda562f3a |
| Archive SHA256 | b6060825639ed27b2f2b2e6acee61f89aa53d9304dad4a41a35d354115922305 |
| Image config ID | sha256:5f25a50568dc9251666aa77a1eff57dd867753b0a76a7541d22cc53b540ee0ff |
| Platform / runtime UID:GID | linux/amd64 /10001:10001 |
| Target | ghcr.io/huygiang1/wedo-backend:afac8aae74ae12539e94542a3beed21cda562f3a |
| Artifact expires |2026-11-08 09:14:44UTC (16:14:44 Vietnam) |

The source SHA remains the image revision/tag even after a newer publication
workflow commit is merged. Publisher workflow SHA is recorded separately, never
misrepresented as the image's validated source. No CLI inputs or env overrides
can substitute the source/run/artifact/checksum/image/target constants.

Archive SHA256, Docker image ID (config digest), and registry manifest digest are
different identifiers. No registry digest exists for this first publication yet.
Source CI proved10Java tests, image build, fresh V0–V20/PG/Redis, REST/login/WS401/101,
backend+PG recreation/data/legacy-avatar persistence and scoped cleanup PASS.
S3 is PENDING, Firebase DISABLED, iOS push remains R9 pending. No new build/test
can silently replace the approved artifact if it expires or cannot be read.

## Supported trigger without changing main

`.github/workflows/staging-publication.yml` has:

1. **pull_request ->dev** on only its four publication paths: `safe-checks` unit
   regressions and read-only metadata audit. No package-write job can execute.
2. **push ->dev**, path **only `.github/workflows/staging-publication.yml`**:
   `safe-checks` ->read-only `preflight` ->protected `publish` job.
3. No workflow_dispatch, pull_request_target, workflow_run, caller-supplied run
   input, default-branch mutation, image build or deploy operation.

This supports the first publisher activation by separately approved merge into
dev, without registering a manual workflow on main. Editing helper/docs/tests
alone cannot trigger publication on dev. Future authorized retries can rerun a
failed run; changing the workflow to target a different image requires new review.
Publication is not authorized merely because this feature branch was pushed.

## Effective approval gate — mandatory before merge

Read-only live check in D3.1: repository PUBLIC, default branch main unchanged;
only environment `copilot` was listed. **staging-image-publication does not exist
and is not effectively protected yet.** GitHub documents required reviewers for
public repositories on current plans; YAML cannot create effective reviewer rules.

Before merging, the owner must configure and verify in Settings ->Environments:

- Create **staging-image-publication** manually.
- Required reviewers: at least one authorized User/Team with read access, enabled.
  Choose self-review/admin-bypass policy deliberately; self-review prevention
  requires a different eligible reviewer if the merger initiates the run.
- Deployment branches/tags: **Selected branches**, exactly one **branch `dev`**.
  No wildcard, tags, extra branches or "protected branches only" fallback.
- Verify the actual environment GET metadata and branch-policy listing with the
  owner. Do not merge merely because unit tests passed.

Read-only preflight checks these rules before scheduling the write-capable job,
preventing GitHub's missing-environment auto-creation from bypassing protection.
The publish job itself references that environment, so GitHub pauses it for review.
Before login/load and again before push, the helper rechecks live protection and
requires an **approved review for this run and exact environment ID/name** via
the review-history API. Missing/inaccessible gate/history or rejection blocks.
This check does not replace GitHub's own effective job approval enforcement.

If required reviewers cannot be enabled on the owner's actual plan/settings,
**STOP before merge/activation**. Safe alternative: leave this PR unmerged and
request separate approval for an owner-operated publisher on a disposable trusted
runner that performs the same fixed-artifact checks. No Mac QA/VPS publication
workaround or long-lived CI PAT is authorized.

## Permissions and publication sequence

Default permissions: contents:read. safe-checks/preflight: contents:read,
actions:read only. **Only publish** has packages:write plus those two reads.
No admin/environment-write/id-token/PAT/GitHub secret is required by the workflow.
Pinned official actions use the temporary built-in github.token. All checkouts
disable persisted Git credentials. No token is printed or passed as CLI argument.

After environment approval:

1. Recheck repository identity, source run SUCCESS/path/event/head repository and
   source SHA; exact artifact ID/name/run/origin repositories and unexpired date.
2. Download only artifact13076784704 from run41291866605 using explicit IDs, not
   latest/name discovery. `merge-multiple:true` gives the fixed archive path.
3. Hash `image.tar.gz` **before** docker load; load only that archive. Inspect the
   original CI tag and exact expected ID: linux/amd64, revision, UID10001 all match.
4. Authenticate to ghcr.io with ephemeral GITHUB_TOKEN via pinned login-action.
   Fixed GHCR token endpoint/read scope is used for authenticated manifest checks;
   HTTP401/403/429/5xx/network errors are never treated as an absent tag.
5. If target exists with another config or an image index, **TAG_CONFLICT**, no
   overwrite. If exact image exists, pull by immutable digest to validate remote
   layers/config and record ALREADY_PRESENT, without another push.
6. For absent tag, tag the loaded image, recheck collision and gate/explicit
   approval, push exact target; never docker build/rebase/commit the image.
7. Read resulting manifest, verify raw manifest SHA256 against its registry digest
   header, require expected config digest; pull by digest and reverify loaded
   image identity/platform/revision/user. Record immutable deployment reference.

One workflow concurrency group serializes this target. **GHCR does not provide a
compare-and-set create-only tag in this implementation**: checks immediately
before push do not eliminate an external concurrent writer. Owner must restrict
publishing to this approved path/no competing writers; never describe SHA tags as
globally immutable. Deploy only by recorded registry digest. Do not rerun an
older publisher to overwrite an existing conflicting SHA tag.

## Package visibility/access — separate owner settings

No visibility-setting API exists in this workflow. D3 package metadata query
returned404 under available read access; that is not proof a private/inaccessible
package cannot exist. Before first publication, owner checks `wedo-backend`
namespace/package collision and workflow/repository write access in GHCR.

New GHCR package defaults PRIVATE per GitHub. Keep it private unless public
visibility is separately approved. If an existing package is public or not linked
to this repository, resolve visibility/access policy with owner before approval.
Package/repository access inheritance and visibility are separate controls; a
PUBLIC source repository is not an approval to make the image public.

Future private VPS pull: approved deployment account, read:packages-only credential
and explicit package read access; use credential helper or protected external
DOCKER_CONFIG, password-stdin, no token in Git/shell history/logs. Docker config
base64 is not encryption. Public image needs no pull credential only after owner
approves that visibility. No credential creation or VPS access in D3.1.

## Evidence, failure recovery and validation limits

Sanitized JSON records fixed provenance/checksum/image ID, publisher SHA, outcome,
remote manifest digest/pinned reference, or fixed failure reason. No raw provider
response, HTTP authorization, token, env dump or Docker stdout/stderr is archived.
Evidence retention30days; source image artifact expires on the fixed date above.
Current build provenance is checksum/CI metadata, not a new signed attestation.

Corruption/provenance mismatch/missing approval/conflict: fail before push.
Registry auth/network denial: fail, no assume-success/visibility change. If push
succeeded but verification failed, keep the failed status, review remotely before
retry. Same exact remote image returns ALREADY_PRESENT; different image blocks.
Do not delete package versions, change visibility or rebuild to recover. Preserve
known-good digests for later rollout rollback; no VPS is deployed by this job.

Local tests mock network/Docker/approval; they prove guards and error paths, **not
actual GHCR login/push**. Static YAML/bash validation and PR safe-checks can run
without any registry write. Do not mark publication complete until a separately
approved protected job publishes and remote verification succeeds.

## Exact remaining approval boundary

Feature implementation/commit/push/PR and safe validation are authorized.
Owner must still verify environment and package access/visibility, review the PR,
**explicitly approve its merge**, and **approve the protected publication job**.
Do not change main/default branch. No VPS build/pull/deploy, Nginx/Certbot/DNS,
domain purchase, S3 provisioning, DB/media migration or Breast Cancer action.

References:
[Environment reviewers](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments),
[Environment metadata](https://docs.github.com/en/rest/deployments/environments),
[Branch policies](https://docs.github.com/en/rest/deployments/branch-policies),
[Run review history](https://docs.github.com/en/rest/actions/workflow-runs#get-the-review-history-for-a-workflow-run),
[Artifact download](https://github.com/actions/download-artifact/blob/v4/README.md),
[GHCR permissions/visibility](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
