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
import sqlite3
import os
import shlex
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


load_env_file("qbittorrent-connections")


def required(name):
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Required setting is empty: {name}")
    return value


qb_url = required("QBITTORRENT_URL").rstrip("/") + "/api/v2"
qb_username = required("QBITTORRENT_USERNAME")
qb_password = required("QBITTORRENT_PASSWORD")

# Determine the correct path for the database
if "QBITTORRENT_DATABASE" in os.environ:
    db_path = os.path.expanduser(os.environ["QBITTORRENT_DATABASE"])
elif os.name == "nt":  # Windows
    db_path = os.path.join(os.path.expanduser("~"), "Documents", "qbit_connections.db")
else:  # Linux and other Unix-like systems
    db_path = os.path.join(os.path.expanduser("~"), "qbit_connections.db")

# Setup SQLite database
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("""
CREATE TABLE IF NOT EXISTS qbit_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT NOT NULL,
    port INTEGER NOT NULL,
    port_open INTEGER,
    UNIQUE(ip, port)
)
""")


# Login to qBittorrent
session = requests.Session()
login_data = {"username": qb_username, "password": qb_password}
session.post(f"{qb_url}/auth/login", data=login_data)

# Get the list of torrents
torrents = session.get(f"{qb_url}/torrents/info").json()

# Fetch peers for each torrent and store in database
for torrent in torrents:
    hash = torrent["hash"]
    peers = session.get(f"{qb_url}/sync/torrentPeers", params={"hash": hash}).json()
    for peer_id, peer_info in peers["peers"].items():
        ip_port = (peer_info["ip"], peer_info["port"])
        try:
            cursor.execute("INSERT INTO qbit_connections (ip, port) VALUES (?, ?)", ip_port)
        except sqlite3.IntegrityError:
            # Ignore duplicates
            pass

# Commit and close the database connection
conn.commit()
conn.close()

# Logout
session.post(f"{qb_url}/auth/logout")
