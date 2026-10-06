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

import os
import shlex
from pathlib import Path

import requests
from collections import defaultdict


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


load_env_file("qbittorrent-cat-scan")


def required(name):
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Required setting is empty: {name}")
    return value


QBITTORRENT_URL = required("QBITTORRENT_URL").rstrip("/")
USERNAME = required("QBITTORRENT_USERNAME")
PASSWORD = required("QBITTORRENT_PASSWORD")

session = requests.Session()


def login():
    res = session.post(
        f"{QBITTORRENT_URL}/api/v2/auth/login", data={"username": USERNAME, "password": PASSWORD}
    )
    if res.text != "Ok.":
        raise Exception("Login failed")


def get_all_torrents():
    """Fetch all torrents from the client."""
    res = session.get(f"{QBITTORRENT_URL}/api/v2/torrents/info")
    return res.json()


def main():
    login()
    torrents = get_all_torrents()

    total_count = len(torrents)
    seeding_count = 0
    not_seeded_by_category = defaultdict(list)

    for torrent in torrents:
        # States that count as "actively seeding"
        if torrent["state"] in ("uploading", "stalledUP", "checkingUP", "forcedUP"):
            seeding_count += 1
        else:
            not_seeded_by_category[torrent["category"] or "Uncategorized"].append(torrent["name"])

    # Summary
    print("=== Torrent Summary ===")
    print(f"Total torrents: {total_count}")
    print(f"Seeding torrents: {seeding_count}")
    print(f"Not seeding: {total_count - seeding_count}")

    # Breakdown
    print("\n=== Torrents NOT being seeded, grouped by category ===")
    if not not_seeded_by_category:
        print("✅ All torrents are actively seeding.")
        return

    for category, items in sorted(not_seeded_by_category.items()):
        print(f"\nCategory: {category} ({len(items)} not seeding)")
        for item in sorted(items):
            print(f" - {item}")


if __name__ == "__main__":
    main()
