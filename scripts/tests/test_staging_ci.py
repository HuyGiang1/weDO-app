"""No Docker/network needed: exercise CI guard, redaction and WS authorization checks."""
import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "staging-container-smoke.py"
SPEC = importlib.util.spec_from_file_location("staging_ci", SCRIPT)
CI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CI)
IMAGE = "wedo-d1-ci:" + "a" * 40
ENV = {"GITHUB_ACTIONS": "true", "CI": "true", "RUNNER_ENVIRONMENT": "github-hosted"}


class FakeSocket:
    def __init__(self, response):
        self.response = response
        self.sent = b""
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass
    def sendall(self, request):
        self.sent = request
    def recv(self, size):
        result, self.response = self.response[:size], self.response[size:]
        return result


class GuardTests(unittest.TestCase):
    def test_local_machine_refused_before_commands(self):
        with patch.object(CI.sys, "argv", [str(SCRIPT), IMAGE]), patch.dict(CI.os.environ, {}, clear=True), \
                patch.object(CI.subprocess, "run") as command:
            with self.assertRaises(RuntimeError):
                CI.main()
            command.assert_not_called()

    def test_self_hosted_refused(self):
        with self.assertRaises(RuntimeError):
            CI.guard(dict(ENV, RUNNER_ENVIRONMENT="self-hosted"), IMAGE)

    def test_remote_daemon_refused(self):
        with self.assertRaises(RuntimeError):
            CI.guard(dict(ENV, DOCKER_HOST="tcp://shared.example.invalid:2376"), IMAGE)

    def test_latest_or_wrong_repository_image_refused(self):
        for image in ("wedo-d1-ci:latest", "ghcr.io/example/app:" + "a" * 40, "wedo-d1-ci:abc"):
            with self.subTest(image=image), self.assertRaises(RuntimeError):
                CI.guard(ENV, image)

    def test_valid_disposable_runner_allowed(self):
        CI.guard(ENV, IMAGE)

    def test_no_raw_process_error_is_reported(self):
        result = CI.subprocess.CompletedProcess([], 1, "synthetic-sensitive", "synthetic-sensitive")
        with patch.object(CI.subprocess, "run", return_value=result), self.assertRaises(RuntimeError) as caught:
            CI.run(["docker", "inspect"], {})
        self.assertNotIn("synthetic-sensitive", str(caught.exception))


class DiagnosticsTests(unittest.TestCase):
    def test_env_health_output_mounts_and_unknown_service_excluded(self):
        raw = [{"Config": {"Env": ["KEY=synthetic-sensitive"], "Labels": {"com.docker.compose.service": "backend"}},
                "Mounts": [{"Source": "synthetic-sensitive"}],
                "State": {"Status": "exited", "ExitCode": 1, "OOMKilled": False,
                          "Health": {"Status": "unhealthy", "Log": [{"ExitCode": 1, "Output": "synthetic-sensitive"}]}}},
               {"Config": {"Labels": {"com.docker.compose.service": "another-project"}}}]
        safe = CI.safe_state(raw)
        self.assertEqual(len(safe), 1)
        self.assertEqual(safe[0]["probeExitCodes"], [1])
        self.assertNotIn("synthetic-sensitive", json.dumps(safe))


class WebSocketTests(unittest.TestCase):
    def test_unauthorized_401_is_expected(self):
        with patch.object(CI.socket, "create_connection", return_value=FakeSocket(b"HTTP/1.1 401 Unauthorized\r\n\r\n")):
            CI.websocket(12345)

    def test_wrong_unauthorized_status_fails(self):
        with patch.object(CI.socket, "create_connection", return_value=FakeSocket(b"HTTP/1.1 500 Error\r\n\r\n")), \
                self.assertRaises(RuntimeError):
            CI.websocket(12345)

    def test_authenticated_upgrade_validates_accept_and_bearer(self):
        nonce_bytes = bytes(range(16))
        nonce = base64.b64encode(nonce_bytes).decode()
        accept = base64.b64encode(hashlib.sha1((nonce + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        connection = FakeSocket(b"HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
        with patch.object(CI.secrets, "token_bytes", return_value=nonce_bytes), \
                patch.object(CI.socket, "create_connection", return_value=connection):
            CI.websocket(12345, "synthetic-token")
        self.assertIn(b"Authorization: Bearer synthetic-token", connection.sent)

    def test_bad_accept_fails_even_with_101(self):
        with patch.object(CI.socket, "create_connection", return_value=FakeSocket(
                b"HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: wrong\r\n\r\n")), self.assertRaises(RuntimeError):
            CI.websocket(12345, "synthetic-token")


if __name__ == "__main__":
    unittest.main()
