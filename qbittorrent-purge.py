#!/usr/bin/python3

# Check all external dependencies before importing them or starting work.
import importlib as _dependency_importlib
import shutil as _dependency_shutil
import sys as _dependency_sys
import platform as _dependency_platform
_dependency_missing = []
_dependency_modules = ['requests']
_dependency_commands = []
for _dependency_module in _dependency_modules:
    try:
        _dependency_importlib.import_module(_dependency_module)
    except ImportError as _dependency_error:
        _dependency_missing.append('Python module "{}": {}'.format(_dependency_module, _dependency_error))
for _dependency_command in _dependency_commands:
    if not _dependency_shutil.which(_dependency_command):
        _dependency_missing.append('command "{}" is not installed or not in PATH'.format(_dependency_command))
if _dependency_missing:
    for _dependency_message in _dependency_missing:
        print('ERROR: ' + _dependency_message, file=_dependency_sys.stderr)
    raise SystemExit(1)

import requests
import datetime
import argparse
from urllib.parse import urlsplit
import logging
import logging.handlers
import os
import shlex
import sys
from pathlib import Path


def load_env_file(script_name):
    config_dir = Path(
        os.environ.get(
            "MY_SCRIPTS_CONFIG_DIR",
            Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "my-scripts",
        )
    )
    env_file = config_dir / f".env.{script_name}"
    if not env_file.is_file():
        raise SystemExit(f"Configuration file not found: {env_file}")
    for number, raw_line in enumerate(env_file.read_text().splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise SystemExit(f"Invalid configuration at {env_file}:{number}")
        name, value = line.split("=", 1)
        values = shlex.split(value, comments=False, posix=True)
        if len(values) != 1:
            raise SystemExit(f"Invalid value at {env_file}:{number}")
        os.environ.setdefault(name.strip(), values[0])


load_env_file("qbittorrent-purge")


def required(name):
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Required setting is empty: {name}")
    return value


QBITTORRENT_HOST = required("QBITTORRENT_URL").rstrip("/")
USERNAME = required("QBITTORRENT_USERNAME")
PASSWORD = required("QBITTORRENT_PASSWORD")
CATEGORIES_TO_CHECK = [
    category.strip().lower()
    for category in os.environ.get("QBITTORRENT_CATEGORIES", "torrent").split(",")
    if category.strip()
]
DAYS_THRESHOLD = int(os.environ.get("QBITTORRENT_DAYS_THRESHOLD", "30"))

# Logging config
LOG_FILE = os.path.expanduser(
    os.environ.get(
        "QBITTORRENT_PURGE_LOG",
        "~/.local/state/my-scripts/qbittorrent-purge.log",
    )
)
LOG_MAX_BYTES = 1 * 1024 * 1024  # 1 MB
LOG_BACKUP_COUNT = 3
# ===============================

# ======== Setup Logging ========
logger = logging.getLogger()
logger.setLevel(logging.INFO)
Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)

try:
    handler = logging.handlers.RotatingFileHandler(
        LOG_FILE, maxBytes=LOG_MAX_BYTES, backupCount=LOG_BACKUP_COUNT
    )
except PermissionError:
    print(f"Permission denied writing to log file: {LOG_FILE}")
    sys.exit(1)

formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

console = logging.StreamHandler()
console.setFormatter(logging.Formatter("%(asctime)s - %(message)s", "%H:%M:%S"))
logger.addHandler(console)
# ===============================

session = requests.Session()
# qBittorrent requires a matching Origin/Referer when WebUI CSRF protection is active.
_parts = urlsplit(QBITTORRENT_HOST)
if _parts.scheme not in ("http", "https") or not _parts.netloc:
    raise SystemExit("QBITTORRENT_URL must be a full http:// or https:// URL")
_origin = f"{_parts.scheme}://{_parts.netloc}"
session.headers.update({"Origin": _origin, "Referer": QBITTORRENT_HOST + "/"})
REQUEST_TIMEOUT = 15


def login():
    endpoint = f"{QBITTORRENT_HOST}/api/v2/auth/login"
    try:
        resp = session.post(
            endpoint,
            data={"username": USERNAME, "password": PASSWORD},
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as exc:
        logger.error("Could not connect to qBittorrent WebUI: %s", exc)
        raise SystemExit(1)

    # qBittorrent 5.2.0+ returns 204 No Content after a successful login.
    # Older versions return 200 with the literal body 'Ok.'.
    # Reject anything else rather than blindly accepting all 2xx responses.
    if not (
        resp.status_code == 204
        or (resp.status_code == 200 and resp.text.strip() == "Ok.")
    ):
        logger.error(
            "qBittorrent WebUI login failed: HTTP %s; response=%r; URL=%s",
            resp.status_code,
            resp.text.strip()[:200],
            resp.url,
        )
        if resp.status_code == 403:
            logger.error("HTTP 403: possible IP login ban, CSRF protection, or Host validation failure.")
        elif resp.text.strip() == "Fails.":
            logger.error("qBittorrent reported invalid credentials. Check WebUI username/password.")
        elif resp.status_code in (301, 302, 307, 308) or "html" in resp.headers.get("Content-Type", "").lower():
            logger.error("Received redirect/HTML instead of the API response. Check QBITTORRENT_URL and proxy configuration.")
        raise SystemExit(1)
    logger.info("qBittorrent WebUI login succeeded.")

def get_all_torrents():
    try:
        resp = session.get(f"{QBITTORRENT_HOST}/api/v2/torrents/info", timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        if not isinstance(data, list):
            raise ValueError("Expected a JSON list of torrents")
        return data
    except (requests.RequestException, ValueError) as exc:
        logger.error("Failed to retrieve torrents: %s", exc)
        raise SystemExit(1)

def delete_torrents(torrents):
    if not torrents:
        logger.info("No torrents to delete.")
        return

    hashes = [t["hash"] for t in torrents]
    hash_str = "|".join(hashes)

    try:
        resp = session.post(
            f"{QBITTORRENT_HOST}/api/v2/torrents/delete",
            data={"hashes": hash_str, "deleteFiles": "true"},
            timeout=REQUEST_TIMEOUT,
        )
        resp.raise_for_status()
    except requests.RequestException as exc:
        logger.error("Torrent deletion request failed: %s", exc)
        raise SystemExit(1)

    for t in torrents:
        added_on = datetime.datetime.fromtimestamp(t["added_on"]).date()
        logger.info(f"Deleted: '{t['name']}' | Category: {t['category']} | Added On: {added_on}")


def main():
    parser = argparse.ArgumentParser(description="Purge old torrents from selected qBittorrent categories.")
    parser.add_argument("--check-login", action="store_true", help="Test authentication only (does not delete anything).")
    parser.add_argument("--dry-run", action="store_true", help="Show matching torrents without deleting anything.")
    args = parser.parse_args()

    login()
    if args.check_login:
        logger.info("Login-only check complete; no torrents were touched.")
        return
    all_torrents = get_all_torrents()
    now = datetime.datetime.now()
    cutoff = now - datetime.timedelta(days=DAYS_THRESHOLD)

    to_remove = []

    for torrent in all_torrents:
        category = torrent.get("category", "").lower()
        if category in CATEGORIES_TO_CHECK:
            added_on = datetime.datetime.fromtimestamp(torrent.get("added_on", 0))
            if added_on < cutoff:
                logger.info(
                    f"Marked for removal: '{torrent['name']}' | Category: {category} | Added: {added_on.date()}"
                )
                to_remove.append(torrent)

    if args.dry_run:
        logger.info("Dry run: %d torrents would be deleted; nothing was deleted.", len(to_remove))
        return

    delete_torrents(to_remove)


if __name__ == "__main__":
    main()

