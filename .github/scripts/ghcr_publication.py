#!/usr/bin/env python3
"""One fixed, previously validated image. No build, arbitrary inputs or visibility changes."""
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

REPO = "HuyGiang1/weDO-app"
REPO_ID = 1343290226
SOURCE = "afac8aae74ae12539e94542a3beed21cda562f3a"
VALIDATION_RUN = 41291866605
ARTIFACT = 13076784704
ARCHIVE_SHA = "b6060825639ed27b2f2b2e6acee61f89aa53d9304dad4a41a35d354115922305"
IMAGE_ID = "sha256:5f25a50568dc9251666aa77a1eff57dd867753b0a76a7541d22cc53b540ee0ff"
IMAGE = "ghcr.io/huygiang1/wedo-backend"
TARGET = IMAGE + ":" + SOURCE
ENVIRONMENT = "staging-image-publication"
MANIFEST_TYPES = ("application/vnd.oci.image.manifest.v1+json", "application/vnd.docker.distribution.manifest.v2+json")


class Blocked(Exception):
    """Message is a fixed, non-sensitive diagnostic code, never raw provider output."""


def need(condition, code):
    if not condition:
        raise Blocked(code)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def get(url, headers):
    """GET only, fixed HTTPS hosts, no redirects/proxies or credentials in errors."""
    parsed = urllib.parse.urlsplit(url)
    need(parsed.scheme == "https" and parsed.netloc in ("api.github.com", "ghcr.io"), "UNTRUSTED_ENDPOINT")
    request = urllib.request.Request(url, headers=headers)
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        response = opener.open(request, timeout=30)
    except urllib.error.HTTPError as failure:
        response = failure
    except OSError:
        raise Blocked("READ_NETWORK_FAILED") from None
    with response:
        body = response.read(4 * 1024 * 1024 + 1)
        need(len(body) <= 4 * 1024 * 1024, "RESPONSE_TOO_LARGE")
        return response.code, {k.lower(): v for k, v in response.headers.items()}, body


def github(path, missing=False):
    token = os.environ.get("GH_TOKEN", "")
    need(token, "MISSING_EPHEMERAL_TOKEN")
    status, _, body = get("https://api.github.com/repos/" + REPO + path,
                          {"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json"})
    if missing and status == 404:
        return None
    need(status == 200, "GITHUB_READ_FAILED")
    return json.loads(body)


def context(write=False):
    need(os.environ.get("GITHUB_ACTIONS") == "true" and os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted", "HOSTED_RUNNER_REQUIRED")
    need(os.environ.get("GITHUB_REPOSITORY") == REPO and os.environ.get("GITHUB_REPOSITORY_ID") == str(REPO_ID), "REPOSITORY_MISMATCH")
    need(os.environ.get("GITHUB_EVENT_NAME") in ("push", "pull_request"), "EVENT_NOT_ALLOWED")
    if write:
        need(os.environ.get("GITHUB_EVENT_NAME") == "push" and os.environ.get("GITHUB_REF") == "refs/heads/dev", "DEV_PUSH_REQUIRED")


def provenance(run, artifact, now=None):
    now = now or datetime.now(timezone.utc)
    need(run.get("id") == VALIDATION_RUN and run.get("status") == "completed" and run.get("conclusion") == "success", "VALIDATION_NOT_SUCCESSFUL")
    need(run.get("head_sha") == SOURCE and run.get("event") == "pull_request"
         and run.get("path") == ".github/workflows/staging-validation.yml", "VALIDATION_SOURCE_MISMATCH")
    need(run.get("repository", {}).get("id") == REPO_ID and run.get("repository", {}).get("full_name") == REPO
         and run.get("head_repository", {}).get("id") == REPO_ID, "VALIDATION_REPOSITORY_MISMATCH")
    need(artifact.get("id") == ARTIFACT and artifact.get("name") == "validated-image-" + SOURCE, "ARTIFACT_MISMATCH")
    need(artifact.get("expired") is False and datetime.fromisoformat(artifact["expires_at"].replace("Z", "+00:00")) > now, "ARTIFACT_EXPIRED")
    origin = artifact.get("workflow_run", {})
    need(origin.get("id") == VALIDATION_RUN and origin.get("head_sha") == SOURCE
         and origin.get("repository_id") == REPO_ID and origin.get("head_repository_id") == REPO_ID, "ARTIFACT_PROVENANCE_MISMATCH")


def audit():
    context()
    provenance(github(f"/actions/runs/{VALIDATION_RUN}"), github(f"/actions/artifacts/{ARTIFACT}"))


def gate_configuration(environment, branches):
    need(environment and environment.get("name") == ENVIRONMENT and isinstance(environment.get("id"), int), "ENVIRONMENT_MISSING")
    rules = [r for r in environment.get("protection_rules", []) if r.get("type") == "required_reviewers"]
    need(len(rules) == 1 and rules[0].get("reviewers") and all(
        r.get("type") in ("User", "Team") and r.get("reviewer", {}).get("id", 0) > 0 for r in rules[0]["reviewers"]), "REVIEWER_GATE_REQUIRED")
    policy = environment.get("deployment_branch_policy") or {}
    need(policy.get("custom_branch_policies") is True and policy.get("protected_branches") is False, "EXPLICIT_DEV_POLICY_REQUIRED")
    entries = branches.get("branch_policies", [])
    need(branches.get("total_count") == 1 and len(entries) == 1
         and entries[0].get("name") == "dev" and entries[0].get("type", "branch") == "branch", "DEV_ONLY_POLICY_REQUIRED")
    return environment["id"]


def gate():
    context(write=True)
    audit()
    environment = github("/environments/" + ENVIRONMENT, missing=True)
    need(environment is not None, "ENVIRONMENT_MISSING")
    return gate_configuration(environment, github("/environments/" + ENVIRONMENT + "/deployment-branch-policies"))


def approval(history, environment_id):
    relevant = [r for r in history if any(e.get("id") == environment_id and e.get("name") == ENVIRONMENT for e in r.get("environments", []))]
    need(not any(r.get("state") == "rejected" for r in relevant)
         and any(r.get("state") == "approved" and r.get("user", {}).get("id", 0) > 0 for r in relevant), "EXPLICIT_APPROVAL_REQUIRED")


def approved():
    environment_id = gate()  # Recheck after the environment job starts; missing protection fails closed.
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    need(re.fullmatch(r"[0-9]+", run_id), "CURRENT_RUN_REQUIRED")
    approval(github(f"/actions/runs/{run_id}/approvals"), environment_id)


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=360)
    except (OSError, subprocess.TimeoutExpired):
        raise Blocked("DOCKER_COMMAND_FAILED") from None
    need(result.returncode == 0, "DOCKER_COMMAND_FAILED")
    return result.stdout


def archive_check(path):
    need(path.is_file() and not path.is_symlink(), "ARCHIVE_REQUIRED")
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    need(digest.hexdigest() == ARCHIVE_SHA, "ARCHIVE_CHECKSUM_MISMATCH")


def image_metadata(info):
    need(info.get("Id") == IMAGE_ID, "IMAGE_ID_MISMATCH")
    need(info.get("Os") == "linux" and info.get("Architecture") == "amd64", "IMAGE_PLATFORM_MISMATCH")
    config = info.get("Config", {})
    need(config.get("User") == "10001:10001" and config.get("Labels", {}).get("org.opencontainers.image.revision") == SOURCE, "IMAGE_CONFIG_MISMATCH")


def inspect(reference):
    images = json.loads(command("docker", "image", "inspect", reference))
    need(len(images) == 1, "SINGLE_IMAGE_REQUIRED")
    image_metadata(images[0])
    return images[0]


def load(path):
    archive_check(path)  # Always BEFORE docker load.
    command("docker", "load", "--input", str(path))
    inspect("wedo-d1-ci:" + SOURCE)
    return inspect(IMAGE_ID)


class Registry:
    def __init__(self):
        token, actor = os.environ.get("GH_TOKEN", ""), os.environ.get("GITHUB_ACTOR", "")
        need(token and actor, "REGISTRY_AUTH_REQUIRED")
        basic = base64.b64encode((actor + ":" + token).encode()).decode()
        status, _, body = get("https://ghcr.io/token?service=ghcr.io&scope=repository:huygiang1/wedo-backend:pull", {"Authorization": "Basic " + basic})
        need(status == 200, "REGISTRY_READ_AUTH_FAILED")
        payload = json.loads(body)
        self.token = payload.get("token") or payload.get("access_token")
        need(self.token, "REGISTRY_READ_AUTH_FAILED")

    def manifest(self, reference):
        need(reference == SOURCE or re.fullmatch(r"sha256:[a-f0-9]{64}", reference), "REGISTRY_REFERENCE_NOT_ALLOWED")
        status, headers, body = get("https://ghcr.io/v2/huygiang1/wedo-backend/manifests/" + reference,
                                    {"Authorization": "Bearer " + self.token, "Accept": ", ".join(MANIFEST_TYPES)})
        if status == 404:
            codes = {e.get("code") for e in json.loads(body).get("errors", [])}
            need(codes and codes <= {"MANIFEST_UNKNOWN", "NAME_UNKNOWN"}, "REGISTRY_AMBIGUOUS_NOT_FOUND")
            return None
        need(status == 200, "REGISTRY_MANIFEST_READ_FAILED")  # 401/403/5xx are never absence.
        digest = headers.get("docker-content-digest", "")
        need(re.fullmatch(r"sha256:[a-f0-9]{64}", digest)
             and digest == "sha256:" + hashlib.sha256(body).hexdigest(), "REGISTRY_DIGEST_MISMATCH")
        return digest, json.loads(body)


def remote_identity(found):
    need(found is not None, "REGISTRY_MANIFEST_MISSING")
    digest, manifest = found
    need(manifest.get("schemaVersion") == 2 and manifest.get("mediaType") in MANIFEST_TYPES
         and manifest.get("config", {}).get("digest") == IMAGE_ID, "TAG_CONFLICT")
    # Pull by immutable digest also validates layer content, not merely the config pointer.
    command("docker", "pull", IMAGE + "@" + digest)
    inspect(IMAGE + "@" + digest)
    return digest


def publish(registry):
    inspect(IMAGE_ID)
    found = registry.manifest(SOURCE)
    if found is not None:
        return "ALREADY_PRESENT", remote_identity(found)
    command("docker", "tag", IMAGE_ID, TARGET)
    found = registry.manifest(SOURCE)  # Recheck immediately before push, serialize workflow runs too.
    if found is not None:
        return "ALREADY_PRESENT", remote_identity(found)
    approved()  # Protection/explicit approval rechecked immediately before the only registry write.
    command("docker", "push", TARGET)
    return "PUBLISHED", remote_identity(registry.manifest(SOURCE))


def evidence(status, **extra):
    report = dict(status=status, repository=REPO, sourceSha=SOURCE, validationRun=VALIDATION_RUN,
                  artifactId=ARTIFACT, archiveSha256=ARCHIVE_SHA, imageId=IMAGE_ID, target=TARGET,
                  platform="linux/amd64", publisherSha=os.environ.get("GITHUB_SHA", ""), **extra)
    folder = Path(os.environ["RUNNER_TEMP"]) / "wedo-publication-evidence"
    folder.mkdir(exist_ok=True)
    (folder / "publication.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report))


def main(mode):
    if mode == "audit":
        audit()
        print("PASS: exact validated artifact provenance; no registry access")
        return
    if mode == "gate":
        gate()
        print("PASS: environment reviewer gate and dev-only policy configured")
        return
    approved()
    if mode == "approved":
        print("PASS: explicit review recorded for this run/environment")
        return
    archive = Path(os.environ["RUNNER_TEMP"]) / "wedo-validated-image" / "image.tar.gz"
    if mode == "image":
        info = load(archive)
        evidence("VERIFIED", imageSizeBytes=info["Size"])
        return
    need(mode == "publish", "MODE_NOT_ALLOWED")
    archive_check(archive)
    outcome, digest = publish(Registry())
    evidence(outcome, manifestDigest=digest, pinnedReference=IMAGE + "@" + digest)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as destination:
            destination.write(f"{outcome}: `{IMAGE}@{digest}`\nSource: `{SOURCE}`\nNo deployment performed.\n")


if __name__ == "__main__":
    try:
        need(len(sys.argv) == 2 and sys.argv[1] in ("audit", "gate", "approved", "image", "publish"), "MODE_NOT_ALLOWED")
        main(sys.argv[1])
    except Exception as failure:
        code = str(failure) if isinstance(failure, Blocked) else "UNEXPECTED_FAILURE"
        if os.environ.get("RUNNER_TEMP"):
            evidence("FAILED", reason=code)
        raise SystemExit("Publication blocked: " + code) from None
