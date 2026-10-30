"""Generate private local development values, never print or overwrite them."""
import argparse
import base64
import os
from pathlib import Path
import secrets

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=Path(".env.local"))
args = parser.parse_args()
values = {
    key: base64.b64encode(secrets.token_bytes(32)).decode("ascii")
    for key in (
        "WEDO_JWT_SECRET_BASE64",
        "WEDO_AUTH_TOKEN_PEPPER_BASE64",
        "WEDO_PROFILE_COMPLETION_TOKEN_SECRET_BASE64",
        "WEDO_DB_PASSWORD",
        "WEDO_MEDIA_SECRET_KEY",
    )
}
values["WEDO_MEDIA_ACCESS_KEY"] = secrets.token_urlsafe(16)
values["WEDO_LOCAL_TEST_PASSWORD"] = "Dev!" + secrets.token_urlsafe(24)
try:
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    parser.exit(1, "Existing file preserved; no secret rotation performed.\n")
with os.fdopen(fd, "w", encoding="utf-8") as stream:
    stream.write("# Private local values; load explicitly, never commit.\n")
    stream.writelines(f"{key}={value}\n" for key, value in values.items())
print("Private local values generated. No values printed; keep this file out of Git.")
