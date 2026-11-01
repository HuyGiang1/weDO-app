#!/usr/bin/env python3
"""Offline Compose/schema and isolation checks. Never starts or contacts containers."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def validate():
    # Do not inherit QA WEDO/COMPOSE settings or read a local .env file.
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("WEDO_", "COMPOSE_"))}
    env.update({
        "WEDO_BACKEND_IMAGE": "example.invalid/wedo@sha256:" + "0" * 64,
        "WEDO_PUBLIC_API_ORIGIN": "https://api.staging.example.invalid",
        "WEDO_MEDIA_S3_ENDPOINT": "https://s3.staging.example.invalid",
        "WEDO_MEDIA_PUBLIC_ENDPOINT": "https://s3.staging.example.invalid",
        "WEDO_MEDIA_BUCKET": "synthetic-staging",
        "WEDO_MEDIA_REGION": "us-east-1",
        "WEDO_STAGING_SECRET_DIR": "/synthetic-not-provisioned/wedo-secrets",
    })
    command = ["docker", "compose", "--env-file", os.devnull,
               "-f", str(ROOT / "infra/compose.staging.yml"), "config", "--format", "json"]
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("Compose configuration validation failed; no services were started")
    data = json.loads(result.stdout)
    assert data["name"] == "wedo-staging"
    services = data["services"]
    assert set(services) == {"backend", "postgres", "redis"}
    for service in services.values():
        assert service["platform"] == "linux/amd64"
        assert "build" not in service and "container_name" not in service
        assert service["restart"] == "unless-stopped"
        assert int(service["mem_limit"]) > 0 and float(service["cpus"]) > 0
        assert service["logging"]["options"] == {"max-file": "3", "max-size": "10m"}
        assert "no-new-privileges:true" in service["security_opt"]
    for name in ("postgres", "redis"):
        assert not services[name].get("ports")
        assert set(services[name]["networks"]) == {"data"}
        assert services[name]["healthcheck"]["test"]
        assert "@sha256:" in services[name]["image"]
    backend = services["backend"]
    assert backend["user"] == "10001:10001" and backend["read_only"]
    assert backend["ports"][0]["host_ip"] == "127.0.0.1"
    assert str(backend["ports"][0]["published"]) == "18280"
    assert len(backend["ports"]) == 1
    assert backend["environment"]["SPRING_PROFILES_ACTIVE"] == "staging"
    assert backend["environment"]["WEDO_PUSH_ENABLED"] == "false"
    assert "GOOGLE_APPLICATION_CREDENTIALS" not in backend["environment"]
    assert all(v["condition"] == "service_healthy" for v in backend["depends_on"].values())
    assert data["networks"]["data"]["internal"]
    assert set(data["volumes"]) == {"postgres_data", "redis_data", "legacy_media"}
    for section in ("volumes", "networks"):
        for value in data[section].values():
            assert not value.get("external")
            assert value["name"].startswith("wedo-staging_")
    assert len(data["secrets"]) == 6 and len(backend["secrets"]) == 6
    for secret in data["secrets"].values():
        assert secret["file"].startswith("/synthetic-not-provisioned/wedo-secrets/")
    for service in services.values():
        assert all(v["type"] == "volume" for v in service.get("volumes", []))
    migrations = list((ROOT / "backend/src/main/resources/db/migration").glob("V*__*.sql"))
    assert sorted(int(p.name.split("__")[0][1:]) for p in migrations) == list(range(21))
    ignore = (ROOT / "backend/.dockerignore").read_text()
    assert ignore.splitlines()[1] == "**"
    for required in ("!src/main/java/**", "!src/main/resources/db/migration/*.sql",
                     "!src/main/resources/application.yml", "!src/main/resources/application-staging.yml",
                     "**/*.p8", "**/*.key", "**/.env*"):
        assert required in ignore
    assert "!src/main/resources/application*.yml" not in ignore
    print("PASS: Compose schema/isolation, six external secret references, V0-V20, context allow-list guards")
    print("No Docker daemon, build, secret files or existing services accessed. Context packaging still requires CI build.")


if __name__ == "__main__":
    validate()
