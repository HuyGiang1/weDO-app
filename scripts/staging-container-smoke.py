#!/usr/bin/env python3
"""Disposable GitHub-hosted CI smoke only; no QA/VPS use or external S3 assertions."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
SECRET_NAMES = ("WEDO_DB_PASSWORD", "WEDO_JWT_SECRET_BASE64", "WEDO_AUTH_TOKEN_PEPPER_BASE64",
                "WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64", "WEDO_MEDIA_ACCESS_KEY", "WEDO_MEDIA_SECRET_KEY")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def guard(env, image):
    require(env.get("GITHUB_ACTIONS") == "true" and env.get("CI") == "true"
            and env.get("RUNNER_ENVIRONMENT") == "github-hosted",
            "Refused: disposable GitHub-hosted runner required; never run on Mac QA/VPS")
    require(re.fullmatch(r"wedo-d1-ci:[0-9a-f]{40}", image), "Refused: exact commit-tagged CI image required")
    require(not env.get("DOCKER_HOST") or env["DOCKER_HOST"].startswith("unix://"), "Refused: remote Docker host")


def run(command, env):
    result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=360)
    require(result.returncode == 0, "Disposable CI command failed (raw output withheld)")
    return result.stdout.strip()


def http(base, path, expected, payload=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(base + path, data=data, headers=headers)
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=10) as response:
            status, body = response.status, response.read(1024 * 1024)
    except urllib.error.HTTPError as failure:
        status, body = failure.code, b"{}"
        failure.close()
    require(status == expected, "REST smoke returned unexpected status")
    return json.loads(body) if body else {}


def websocket(port, token=None):
    nonce = base64.b64encode(secrets.token_bytes(16)).decode()
    lines = ["GET /ws HTTP/1.1", f"Host: 127.0.0.1:{port}", "Upgrade: websocket",
             "Connection: Upgrade", "Sec-WebSocket-Version: 13", "Sec-WebSocket-Key: " + nonce]
    if token:
        lines.append("Authorization: Bearer " + token)
    with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
        connection.sendall(("\r\n".join(lines) + "\r\n\r\n").encode())
        header = b""
        while b"\r\n\r\n" not in header:
            chunk = connection.recv(4096)
            require(chunk and len(header) < 16384, "Incomplete WebSocket response")
            header += chunk
    lines = header.split(b"\r\n\r\n", 1)[0].decode("latin-1").split("\r\n")
    require(lines[0].split()[1] == ("101" if token else "401"), "Unexpected WebSocket authorization status")
    if token:
        expected = base64.b64encode(hashlib.sha1((nonce + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        # Header names are case-insensitive; values such as Accept are case-sensitive.
        fields = dict((key.lower(), value.strip()) for key, value in
                      (line.split(":", 1) for line in lines[1:] if ":" in line))
        require(fields.get("sec-websocket-accept") == expected, "Invalid WebSocket accept value")


def safe_state(inspections):
    """Allow-list only. Never include Config.Env, mounts, raw health output or logs."""
    result = []
    for item in inspections:
        state = item.get("State", {})
        service = item.get("Config", {}).get("Labels", {}).get("com.docker.compose.service")
        if service not in ("backend", "postgres", "redis"):
            continue
        result.append({"service": service, "status": state.get("Status"),
                       "exitCode": state.get("ExitCode"), "oomKilled": state.get("OOMKilled"),
                       "health": state.get("Health", {}).get("Status"),
                       "probeExitCodes": [entry.get("ExitCode") for entry in state.get("Health", {}).get("Log", [])]})
    return result


def main():
    require(len(sys.argv) == 2, "Require exactly one CI image reference")
    guard(os.environ, sys.argv[1])
    require(shutil.disk_usage(ROOT).free >= 10 * 1024**3, "Blocked: need 10 GiB free for isolated containers")
    env = {k: v for k, v in os.environ.items() if not k.startswith(("WEDO_", "COMPOSE_"))}
    endpoint = json.loads(run(["docker", "context", "inspect"], env))[0]["Endpoints"]["docker"]["Host"]
    require(endpoint.startswith("unix://"), "Refused: remote Docker context")
    require(run(["docker", "info", "--format", "{{.OSType}}/{{.Architecture}}"], env)
            in ("linux/x86_64", "linux/amd64"), "Refused: amd64 Linux daemon required")
    image = json.loads(run(["docker", "image", "inspect", sys.argv[1]], env))[0]
    require(image["Os"] == "linux" and image["Architecture"] == "amd64", "Image architecture mismatch")
    require(image["Config"].get("User") == "10001:10001", "Image must run non-root")
    project = "wedo-d2-ci-" + uuid.uuid4().hex
    for resource, subcommand in (("container", "ps"), ("volume", "ls"), ("network", "ls")):
        command = ["docker", subcommand, "-aq"] if resource == "container" else ["docker", resource, subcommand, "-q"]
        require(not run(command + ["--filter", "label=com.docker.compose.project=" + project], env), "Project collision")
    with tempfile.TemporaryDirectory(prefix="wedo-d2-ci-") as folder:
        Path(folder).chmod(0o755)
        for name in SECRET_NAMES:
            path = Path(folder) / name
            path.write_text(base64.b64encode(secrets.token_bytes(32)).decode())
            path.chmod(0o444)  # Disposable CI synthetic keys only; never production secret permissions.
        env.update(WEDO_BACKEND_IMAGE=sys.argv[1], WEDO_STAGING_SECRET_DIR=folder,
                   WEDO_HTTP_PORT="0", WEDO_PUBLIC_API_ORIGIN="https://api.staging.example.invalid",
                   WEDO_MEDIA_S3_ENDPOINT="https://s3.staging.example.invalid",
                   WEDO_MEDIA_PUBLIC_ENDPOINT="https://s3.staging.example.invalid",
                   WEDO_MEDIA_BUCKET="synthetic-staging", WEDO_MEDIA_REGION="us-east-1")
        command = ["docker", "compose", "--env-file", os.devnull, "-p", project,
                   "-f", str(ROOT / "infra/compose.staging.yml")]
        def compose(*args):
            return run(command + list(args), env)
        def sql(statement):
            return compose("exec", "-T", "postgres", "psql", "-U", "wedo_staging", "-d",
                           "wedo_staging", "-At", "-v", "ON_ERROR_STOP=1", "-c", statement)
        config = json.loads(compose("config", "--format", "json"))
        require(config["name"] == project and set(config["services"]) == {"backend", "postgres", "redis"}, "Unexpected project plan")
        for section in ("volumes", "networks"):
            require(all(not v.get("external") and v["name"].startswith(project + "_")
                        for v in config[section].values()), "Shared resource refused")
        require(all(v["type"] == "volume" for s in config["services"].values()
                    for v in s.get("volumes", [])), "Non-secret bind mount refused")
        report = {"status": "FAIL", "checks": [], "externalS3": "PENDING", "firebasePush": "DISABLED"}
        def login(base):
            result = http(base, "/api/v1/auth/login", 200, {"email": email, "password": password})
            require(result.get("accessToken"), "No access token issued")
            return result["accessToken"]
        def base_url():
            address = compose("port", "backend", "8080")
            require(re.fullmatch(r"127\.0\.0\.1:[0-9]+", address), "Non-loopback binding refused")
            return "http://" + address, int(address.split(":")[1])
        try:
            compose("up", "-d", "--wait", "--wait-timeout", "240")
            base, port = base_url()
            health = http(base, "/actuator/health", 200)
            require(health.get("status") == "UP" and "components" not in health, "Readiness/details mismatch")
            http(base, "/api/v1/me", 401)
            require(sql("SELECT count(*) FROM flyway_schema_history WHERE success") == "21", "Flyway migration mismatch")
            require(sql("SELECT count(*) FROM users") == "0", "Unexpected seeded users")
            require(compose("exec", "-T", "redis", "redis-cli", "ping") == "PONG", "Redis unavailable")
            report["checks"].extend(["amd64/non-root", "fresh-V0-V20", "health/PG/Redis", "no-QA-seed"])
            email, password = "d2-smoke@example.invalid", secrets.token_urlsafe(32)
            http(base, "/api/v1/auth/register", 201, {"email": email, "password": password})
            # Only new disposable CI database: no mail provider and no production verification bypass.
            sql("UPDATE users SET status='ACTIVE', username='d2_smoke', display_name='CI synthetic', email_verified_at=now() WHERE email='d2-smoke@example.invalid'")
            token = login(base)
            for path in ("/api/v1/me", "/api/v1/groups"):
                http(base, path, 200, token=token)
            websocket(port)
            websocket(port, token)
            report["checks"].append("built-image-REST-login/me/groups-WS401/101")
            compose("exec", "-T", "backend", "sh", "-c", "printf ci-only > /opt/wedo/.local-media/d2-persistence-probe")
            before = compose("ps", "-q", "backend")
            compose("up", "-d", "--no-deps", "--force-recreate", "--wait", "--wait-timeout", "240", "backend")
            require(compose("ps", "-q", "backend") != before, "Application was not recreated")
            base, port = base_url()
            token = login(base)
            http(base, "/api/v1/me", 200, token=token)
            require(sql("SELECT count(*) FROM users WHERE email='d2-smoke@example.invalid'") == "1", "User lost after application recreation")
            require(compose("exec", "-T", "backend", "cat", "/opt/wedo/.local-media/d2-persistence-probe") == "ci-only", "Avatar volume lost")
            report["checks"].append("application-recreation-DB/login/legacy-volume-persistence")
            compose("up", "-d", "--no-deps", "--force-recreate", "--wait", "--wait-timeout", "120", "postgres")
            require(sql("SELECT count(*) FROM users WHERE email='d2-smoke@example.invalid'") == "1", "Database volume lost")
            for attempt in range(30):
                try:
                    if http(base, "/actuator/health", 200).get("status") == "UP":
                        break
                except (OSError, RuntimeError, ValueError):
                    pass
                time.sleep(2)
            else:
                raise RuntimeError("Bounded readiness recovery timed out")
            http(base, "/api/v1/me", 200, token=login(base))
            report["checks"].append("postgres-recreation-volume/recovery")
            report["status"] = "PASS"
        finally:
            # Metadata only; never archive raw logs, inspect JSON, envs, secrets or REST bodies.
            try:
                ids = compose("ps", "-aq").split()
                report["containers"] = safe_state(json.loads(run(["docker", "inspect"] + ids, env))) if ids else []
            except (RuntimeError, ValueError, subprocess.TimeoutExpired):
                report["diagnostics"] = "metadata unavailable"
            try:
                compose("down", "--volumes", "--timeout", "30")  # Only random, collision-checked new CI project.
                report["cleanup"] = "PASS"
            except (RuntimeError, subprocess.TimeoutExpired):
                report["cleanup"] = "FAIL"
            output = Path(os.environ["RUNNER_TEMP"]) / "wedo-d2-diagnostics"
            output.mkdir(exist_ok=True)
            (output / "smoke.json").write_text(json.dumps(report, indent=2))
            print(json.dumps(report))
            require(report.get("cleanup") == "PASS", "Disposable project cleanup failed")
        require(report["status"] == "PASS", "Smoke failed")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError):
        raise SystemExit("CI smoke FAILED; inspect sanitized metadata artifact, never raw secrets/logs")
