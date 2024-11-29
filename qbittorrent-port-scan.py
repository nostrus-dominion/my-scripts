import sqlite3
import os
import subprocess
import platform
from plyer import notification

# Determine the correct path for the database
if os.name == 'nt':  # Windows
    db_path = os.path.join(os.path.expanduser('~'), 'Documents', 'qbit_connections.db')
else:  # Linux and other Unix-like systems
    db_path = os.path.join(os.path.expanduser('~'), 'qbit_connections.db')

# Setup SQLite database connection
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Fetch all IP addresses from the database
cursor.execute('SELECT DISTINCT ip FROM qbit_connections')
ips = cursor.fetchall()

# Function to send notifications
def send_notification(message):
    if platform.system() == 'Windows':
        notification.notify(
            title='Port Scan Alert',
            message=message,
            timeout=10
        )
    elif platform.system() == 'Darwin':  # macOS
        subprocess.run(['osascript', '-e', f'display notification "{message}" with title "Port Scan Alert"'])
    elif platform.system() == 'Linux':
        subprocess.run(['notify-send', 'Port Scan Alert', message])

# Scan each IP address for open ports
for (ip,) in ips:
    print(f"Scanning IP address: {ip}")
    try:
        # Use nmap to perform a full TCP scan on the IP
        nmap_output = subprocess.run(['nmap', '-p-', ip], capture_output=True, text=True)

        open_ports = []

        # Check for open ports in the nmap output
        for line in nmap_output.stdout.splitlines():
            if '/tcp' in line and 'open' in line:
                # Extract the port number
                port_info = line.split('/')[0].strip()
                open_ports.append(int(port_info))

        # Update the database with open ports for the IP
        for port in open_ports:
            cursor.execute('INSERT OR IGNORE INTO qbit_connections (ip, port) VALUES (?, ?)', (ip, port))
            cursor.execute('UPDATE qbit_connections SET port = ? WHERE ip = ? AND port = ?', (port, ip, port))

        # Check if ports 80 or 443 are open for notifications
        if 80 in open_ports:
            send_notification(f'Port 80 is open on {ip}.')
        if 443 in open_ports:
            send_notification(f'Port 443 is open on {ip}.')

    except Exception as e:
        print(f"Error scanning {ip}: {e}")

    print(f"Completed scanning IP address: {ip}")

# Commit updates to the database and close the connection
conn.commit()
conn.close()
