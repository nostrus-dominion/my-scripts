# Check all external dependencies before importing them or starting work.
import importlib as _dependency_importlib
import shutil as _dependency_shutil
import sys as _dependency_sys
import platform as _dependency_platform
_dependency_missing = []
_dependency_modules = ['plyer']
_dependency_commands = []
_dependency_commands.append('nmap')
if _dependency_platform.system() == 'Linux':
    _dependency_commands.append('notify-send')
elif _dependency_platform.system() == 'Darwin':
    _dependency_commands.append('osascript')
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

import sqlite3
import os
import shlex
import subprocess
import platform
from pathlib import Path
from plyer import notification


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


load_env_file("qbittorrent-port-scan")
db_path = os.path.expanduser(os.environ.get("QBITTORRENT_DATABASE", "~/qbit_connections.db"))

# Setup SQLite database connection
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Fetch all IP addresses from the database
cursor.execute("SELECT DISTINCT ip FROM qbit_connections")
ips = cursor.fetchall()


# Function to send notifications
def send_notification(message):
    if platform.system() == "Windows":
        notification.notify(title="Port Scan Alert", message=message, timeout=10)
    elif platform.system() == "Darwin":  # macOS
        subprocess.run(
            ["osascript", "-e", f'display notification "{message}" with title "Port Scan Alert"']
        )
    elif platform.system() == "Linux":
        subprocess.run(["notify-send", "Port Scan Alert", message])


# Scan each IP address for open ports
for (ip,) in ips:
    print(f"Scanning IP address: {ip}")
    try:
        # Use nmap to perform a full TCP scan on the IP
        nmap_output = subprocess.run(["nmap", "-p-", ip], capture_output=True, text=True)

        open_ports = []

        # Check for open ports in the nmap output
        for line in nmap_output.stdout.splitlines():
            if "/tcp" in line and "open" in line:
                # Extract the port number
                port_info = line.split("/")[0].strip()
                open_ports.append(int(port_info))

        # Update the database with open ports for the IP
        for port in open_ports:
            cursor.execute(
                "INSERT OR IGNORE INTO qbit_connections (ip, port) VALUES (?, ?)", (ip, port)
            )
            cursor.execute(
                "UPDATE qbit_connections SET port = ? WHERE ip = ? AND port = ?", (port, ip, port)
            )

        # Check if ports 80 or 443 are open for notifications
        if 80 in open_ports:
            send_notification(f"Port 80 is open on {ip}.")
        if 443 in open_ports:
            send_notification(f"Port 443 is open on {ip}.")

    except Exception as e:
        print(f"Error scanning {ip}: {e}")

    print(f"Completed scanning IP address: {ip}")

# Commit updates to the database and close the connection
conn.commit()
conn.close()
