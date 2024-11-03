import requests
import sqlite3
import os

# qBittorrent Web UI credentials and URL
qb_url = 'http://10.1.10.30:8080/api/v2'
qb_username = 'admin'
qb_password = 'StackAccess11#'

# Determine the correct path for the database
if os.name == 'nt':  # Windows
    db_path = os.path.join(os.path.expanduser('~'), 'Documents', 'qbit_connections.db')
else:  # Linux and other Unix-like systems
    db_path = os.path.join(os.path.expanduser('~'), 'qbit_connections.db')

# Setup SQLite database
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute('''
CREATE TABLE IF NOT EXISTS qbit_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT NOT NULL,
    port INTEGER NOT NULL,
    UNIQUE(ip, port)
)
''')

# Login to qBittorrent
session = requests.Session()
login_data = {'username': qb_username, 'password': qb_password}
session.post(f'{qb_url}/auth/login', data=login_data)

# Get the list of torrents
torrents = session.get(f'{qb_url}/torrents/info').json()

# Fetch peers for each torrent and store in database
for torrent in torrents:
    hash = torrent['hash']
    peers = session.get(f'{qb_url}/sync/torrentPeers', params={'hash': hash}).json()
    for peer_id, peer_info in peers['peers'].items():
        ip_port = (peer_info['ip'], peer_info['port'])
        try:
            cursor.execute('INSERT INTO qbit_connections (ip, port) VALUES (?, ?)', ip_port)
        except sqlite3.IntegrityError:
            # Ignore duplicates
            pass

# Commit and close the database connection
conn.commit()
conn.close()

# Logout
session.post(f'{qb_url}/auth/logout')
