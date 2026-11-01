"""Offline only: network, Docker load/pull/push and approvals are mocked."""
import contextlib
from datetime import datetime, timezone
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("publication", ROOT / ".github/scripts/ghcr_publication.py")
P = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(P)
NOW = datetime(2026, 11, 1, tzinfo=timezone.utc)


def validation():
    return dict(id=P.VALIDATION_RUN, status="completed", conclusion="success", head_sha=P.SOURCE,
                event="pull_request", path=".github/workflows/staging-validation.yml",
                repository=dict(id=P.REPO_ID, full_name=P.REPO), head_repository=dict(id=P.REPO_ID))


def artifact():
    return dict(id=P.ARTIFACT, name="validated-image-" + P.SOURCE, expired=False,
                expires_at="2026-11-08T09:14:44Z", workflow_run=dict(id=P.VALIDATION_RUN,
                head_sha=P.SOURCE, repository_id=P.REPO_ID, head_repository_id=P.REPO_ID))


def environment():
    return dict(id=123, name=P.ENVIRONMENT,
                protection_rules=[dict(type="required_reviewers", reviewers=[dict(type="User", reviewer=dict(id=42))])],
                deployment_branch_policy=dict(custom_branch_policies=True, protected_branches=False))


def branches():
    return dict(total_count=1, branch_policies=[dict(name="dev", type="branch")])


def metadata():
    return dict(Id=P.IMAGE_ID, Os="linux", Architecture="amd64", Size=442034821,
                Config=dict(User="10001:10001", Labels={"org.opencontainers.image.revision": P.SOURCE}))


def manifest(config=None):
    return ("sha256:" + "a" * 64, dict(schemaVersion=2, mediaType=P.MANIFEST_TYPES[0],
                                      config=dict(digest=config or P.IMAGE_ID)))


class ProvenanceTests(unittest.TestCase):
    def test_fixed_validated_provenance(self):
        P.provenance(validation(), artifact(), NOW)

    def test_failed_ci_and_wrong_run_or_source_are_rejected(self):
        for key, value in (("id", 1), ("head_sha", "bad"), ("conclusion", "failure"),
                           ("status", "in_progress"), ("event", "push"), ("path", "different.yml")):
            with self.subTest(key=key), self.assertRaises(P.Blocked):
                run = validation(); run[key] = value
                P.provenance(run, artifact(), NOW)

    def test_repository_and_fork_substitution_rejected(self):
        for key in ("repository", "head_repository"):
            run = validation(); run[key]["id"] = 2
            with self.subTest(key=key), self.assertRaises(P.Blocked):
                P.provenance(run, artifact(), NOW)

    def test_artifact_id_name_origin_and_expiry_are_binding(self):
        cases = []
        for key, value in (("id", 1), ("name", "latest"), ("expired", True), ("expires_at", "2026-10-01T00:00:00Z")):
            item = artifact(); item[key] = value; cases.append(item)
        for key in ("id", "head_sha", "repository_id", "head_repository_id"):
            item = artifact(); item["workflow_run"][key] = "wrong"; cases.append(item)
        for item in cases:
            with self.subTest(item=item), self.assertRaises(P.Blocked):
                P.provenance(validation(), item, NOW)


class GateTests(unittest.TestCase):
    def test_effective_required_reviewers_and_dev_policy(self):
        self.assertEqual(P.gate_configuration(environment(), branches()), 123)

    def test_missing_auto_created_or_empty_gate_rejected(self):
        for item in (None, dict(id=123, name=P.ENVIRONMENT), dict(environment(), protection_rules=[])):
            with self.subTest(item=item), self.assertRaises(P.Blocked):
                P.gate_configuration(item, branches())
        item = environment(); item["protection_rules"][0]["reviewers"] = []
        with self.assertRaises(P.Blocked):
            P.gate_configuration(item, branches())

    def test_wildcard_tag_or_extra_branch_policy_rejected(self):
        for item in (dict(total_count=1, branch_policies=[dict(name="*", type="branch")]),
                     dict(total_count=1, branch_policies=[dict(name="dev", type="tag")]),
                     dict(total_count=2, branch_policies=branches()["branch_policies"]),
                     dict(total_count=1, branch_policies=[])):
            with self.subTest(item=item), self.assertRaises(P.Blocked):
                P.gate_configuration(environment(), item)

    def test_broad_or_protected_branches_only_policy_rejected(self):
        for value in (None, dict(protected_branches=True, custom_branch_policies=False)):
            item = environment(); item["deployment_branch_policy"] = value
            with self.assertRaises(P.Blocked):
                P.gate_configuration(item, branches())

    def test_real_approval_for_exact_environment_required(self):
        review = dict(state="approved", user=dict(id=42), environments=[dict(id=123, name=P.ENVIRONMENT)])
        P.approval([review], 123)
        for history in ([], [dict(review, state="rejected")], [dict(review, environments=[dict(id=999, name=P.ENVIRONMENT)])],
                        [dict(review, user={})]):
            with self.subTest(history=history), self.assertRaises(P.Blocked):
                P.approval(history, 123)

    def test_pr_can_never_enter_write_path(self):
        env = dict(GITHUB_ACTIONS="true", RUNNER_ENVIRONMENT="github-hosted", GITHUB_REPOSITORY=P.REPO,
                   GITHUB_REPOSITORY_ID=str(P.REPO_ID), GITHUB_EVENT_NAME="pull_request", GITHUB_REF="refs/pull/11/merge")
        with patch.dict(os.environ, env, clear=True), patch.object(P, "github") as network, \
                patch.object(P, "Registry") as registry, patch.object(P, "command") as docker:
            with self.assertRaisesRegex(P.Blocked, "DEV_PUSH_REQUIRED"):
                P.main("publish")
            network.assert_not_called(); registry.assert_not_called(); docker.assert_not_called()

    def test_wrong_repo_main_and_self_hosted_runner_cannot_write(self):
        base = dict(GITHUB_ACTIONS="true", RUNNER_ENVIRONMENT="github-hosted", GITHUB_REPOSITORY=P.REPO,
                    GITHUB_REPOSITORY_ID=str(P.REPO_ID), GITHUB_EVENT_NAME="push", GITHUB_REF="refs/heads/dev")
        for key, value in (("GITHUB_REPOSITORY_ID", "2"), ("GITHUB_REF", "refs/heads/main"),
                           ("RUNNER_ENVIRONMENT", "self-hosted")):
            with patch.dict(os.environ, dict(base, **{key: value}), clear=True), self.assertRaises(P.Blocked):
                P.context(write=True)

    def test_preflight_missing_environment_cannot_schedule_registry_work(self):
        with patch.object(P, 'context'), patch.object(P, 'audit'), patch.object(P, 'github', return_value=None), \
                patch.object(P, 'Registry') as registry, self.assertRaisesRegex(P.Blocked, 'ENVIRONMENT_MISSING'):
            P.gate()
        registry.assert_not_called()


class ImageTests(unittest.TestCase):
    def test_platform_user_revision_and_id_are_checked(self):
        P.image_metadata(metadata())
        for key, value in (("Id", "wrong"), ("Os", "windows"), ("Architecture", "arm64")):
            item = metadata(); item[key] = value
            with self.assertRaises(P.Blocked): P.image_metadata(item)
        for key, value in (("User", "root"), ("Labels", {"org.opencontainers.image.revision": "wrong"})):
            item = metadata(); item["Config"][key] = value
            with self.assertRaises(P.Blocked): P.image_metadata(item)

    def test_corrupt_archive_is_rejected_before_docker_load(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(P, "command") as docker:
            path = Path(folder) / "image.tar.gz"; path.write_bytes(b"not-the-validated-image")
            with self.assertRaisesRegex(P.Blocked, "ARCHIVE_CHECKSUM_MISMATCH"): P.load(path)
            docker.assert_not_called()

    def test_valid_test_checksum_passes_without_loading(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture"; path.write_bytes(b"synthetic fixture")
            with patch.object(P, "ARCHIVE_SHA", hashlib.sha256(path.read_bytes()).hexdigest()):
                P.archive_check(path)

    def test_symlink_archive_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "target"; target.write_bytes(b"fixture")
            link = Path(folder) / "link"; link.symlink_to(target)
            with self.assertRaises(P.Blocked): P.archive_check(link)


class RegistryTests(unittest.TestCase):
    def test_missing_manifest_only_for_explicit_not_found(self):
        reg = P.Registry.__new__(P.Registry); reg.token = "synthetic-token"
        with patch.object(P, "get", return_value=(404, {}, b'{"errors":[{"code":"MANIFEST_UNKNOWN"}]}')):
            self.assertIsNone(reg.manifest(P.SOURCE))
        for status in (401, 403, 429, 500, 503):
            with patch.object(P, "get", return_value=(status, {}, b'{}')), self.assertRaises(P.Blocked):
                reg.manifest(P.SOURCE)
        with patch.object(P, "get", return_value=(404, {}, b'{}')), self.assertRaises(P.Blocked):
            reg.manifest(P.SOURCE)

    def test_registry_digest_is_manifest_hash_not_image_id(self):
        reg = P.Registry.__new__(P.Registry); reg.token = "synthetic-token"
        body = json.dumps(manifest()[1]).encode(); digest = "sha256:" + hashlib.sha256(body).hexdigest()
        with patch.object(P, "get", return_value=(200, {"docker-content-digest": digest}, body)):
            self.assertEqual(reg.manifest(P.SOURCE)[0], digest)
            self.assertNotEqual(digest, P.IMAGE_ID)
        with patch.object(P, "get", return_value=(200, {"docker-content-digest": P.IMAGE_ID}, body)), self.assertRaises(P.Blocked):
            reg.manifest(P.SOURCE)

    def test_conflict_never_pushes_or_pulls(self):
        reg = Mock(); reg.manifest.return_value = manifest("sha256:" + "b" * 64)
        with patch.object(P, "inspect"), patch.object(P, "command") as docker, self.assertRaisesRegex(P.Blocked, "TAG_CONFLICT"):
            P.publish(reg)
        docker.assert_not_called()

    def test_existing_exact_image_is_idempotent_and_remote_layers_checked(self):
        reg = Mock(); reg.manifest.return_value = manifest()
        with patch.object(P, "inspect"), patch.object(P, "command") as docker:
            outcome, digest = P.publish(reg)
            self.assertEqual(outcome, "ALREADY_PRESENT")
            docker.assert_called_once_with("docker", "pull", P.IMAGE + "@" + digest)

    def test_new_push_requires_approval_and_verifies_remote_identity(self):
        reg = Mock(); reg.manifest.side_effect = [None, None, manifest()]
        calls = []
        with patch.object(P, "inspect"), patch.object(P, "command", side_effect=lambda *args: calls.append(args)), \
                patch.object(P, "approved", side_effect=lambda: calls.append(("approved",))):
            self.assertEqual(P.publish(reg)[0], "PUBLISHED")
        self.assertLess(calls.index(("approved",)), calls.index(("docker", "push", P.TARGET)))
        self.assertFalse(any("build" in arg for call in calls for arg in call))

    def test_racing_conflict_and_failed_approval_never_push(self):
        for sequence in ([None, manifest("sha256:" + "b" * 64)], [None, None]):
            reg = Mock(); reg.manifest.side_effect = sequence
            with patch.object(P, "inspect"), patch.object(P, "command") as docker, \
                    patch.object(P, "approved", side_effect=P.Blocked("EXPLICIT_APPROVAL_REQUIRED")), self.assertRaises(P.Blocked):
                P.publish(reg)
            self.assertFalse(any(call.args[:2] == ("docker", "push") for call in docker.call_args_list))

    def test_failed_push_cannot_produce_success(self):
        reg = Mock(); reg.manifest.side_effect = [None, None]
        def docker(*args):
            if args[:2] == ("docker", "push"): raise P.Blocked("DOCKER_COMMAND_FAILED")
        with patch.object(P, "inspect"), patch.object(P, "command", side_effect=docker), \
                patch.object(P, "approved"), self.assertRaises(P.Blocked):
            P.publish(reg)

    def test_changed_remote_identity_after_push_is_failure(self):
        reg = Mock(); reg.manifest.side_effect = [None, None, manifest('sha256:' + 'b' * 64)]
        with patch.object(P, 'inspect'), patch.object(P, 'command'), patch.object(P, 'approved'), \
                self.assertRaisesRegex(P.Blocked, 'TAG_CONFLICT'):
            P.publish(reg)

    def test_multi_arch_index_is_not_the_validated_single_image(self):
        item = manifest(); item[1]['mediaType'] = 'application/vnd.oci.image.index.v1+json'
        with patch.object(P, 'command') as docker, self.assertRaisesRegex(P.Blocked, 'TAG_CONFLICT'):
            P.remote_identity(item)
        docker.assert_not_called()


class SafetyTests(unittest.TestCase):
    def test_process_error_and_evidence_never_echo_token_or_raw_output(self):
        raw = "synthetic-sensitive-token"
        result = subprocess.CompletedProcess([], 1, raw, raw)
        with patch.object(P.subprocess, "run", return_value=result), self.assertRaises(P.Blocked) as failure:
            P.command("docker", "push", P.TARGET)
        self.assertNotIn(raw, str(failure.exception))
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, dict(RUNNER_TEMP=folder, GH_TOKEN=raw, GITHUB_SHA="a" * 40)):
            with contextlib.redirect_stdout(io.StringIO()) as stream: P.evidence("FAILED", reason="DOCKER_COMMAND_FAILED")
            self.assertNotIn(raw, stream.getvalue())
            self.assertNotIn(raw, (Path(folder) / 'wedo-publication-evidence/publication.json').read_text())

    def test_redirects_and_unknown_hosts_refused(self):
        self.assertIsNone(P.NoRedirect().redirect_request(None, None, None, None, None, None))
        with self.assertRaisesRegex(P.Blocked, "UNTRUSTED_ENDPOINT"):
            P.get("https://other.example.invalid", {"Authorization": "synthetic-sensitive-token"})

    def test_workflow_keeps_all_write_capability_in_protected_push_job(self):
        text = (ROOT / '.github/workflows/staging-publication.yml').read_text()
        self.assertNotIn('workflow_dispatch:', text)
        self.assertNotIn('pull_request_target:', text)
        self.assertEqual(text.count('packages: write'), 1)
        before, write_job = text.split('  publish:\n', 1)
        self.assertNotIn('packages: write', before)
        self.assertIn('needs: preflight', write_job)
        self.assertIn('environment: staging-image-publication', write_job)
        self.assertIn("github.event_name == 'push'", write_job)
        self.assertIn("github.ref == 'refs/heads/dev'", write_job)
        self.assertIn("artifact-ids: '13076784704'", write_job)
        self.assertIn("run-id: '41291866605'", write_job)
        self.assertNotIn('build-push-action', text)
        self.assertNotIn('docker build', text)
        push_trigger = text.split('  push:\n', 1)[1].split('# No dispatch', 1)[0]
        self.assertIn('branches: [dev]', push_trigger)
        self.assertEqual(push_trigger.count('- '), 1)
        self.assertIn("- '.github/workflows/staging-publication.yml'", push_trigger)


if __name__ == '__main__':
    unittest.main()
