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


def login():
    resp = session.post(
        f"{QBITTORRENT_HOST}/api/v2/auth/login", data={"username": USERNAME, "password": PASSWORD}
    )
    if resp.text != "Ok.":
        logger.error("Failed to log in to qBittorrent WebUI.")
        sys.exit(1)


def get_all_torrents():
    resp = session.get(f"{QBITTORRENT_HOST}/api/v2/torrents/info")
    return resp.json()


def delete_torrents(torrents):
    if not torrents:
        logger.info("No torrents to delete.")
        return

    hashes = [t["hash"] for t in torrents]
    hash_str = "|".join(hashes)

    session.post(
        f"{QBITTORRENT_HOST}/api/v2/torrents/delete",
        data={"hashes": hash_str, "deleteFiles": "true"},
    )

    for t in torrents:
        added_on = datetime.datetime.fromtimestamp(t["added_on"]).date()
        logger.info(f"Deleted: '{t['name']}' | Category: {t['category']} | Added On: {added_on}")


def main():
    login()
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

    delete_torrents(to_remove)


if __name__ == "__main__":
    main()
