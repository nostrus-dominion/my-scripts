#!/usr/bin/python3

import requests
import datetime
import logging
import logging.handlers
import os
import sys

# ======== CONFIGURATION ========
QBITTORRENT_HOST = "http://localhost:8080"
USERNAME = "admin"
PASSWORD = "admimadmin"
CATEGORIES_TO_CHECK = ["torrent"]  # Configure to the catagories you want to check. Use comma between catagories.
DAYS_THRESHOLD = 30

# Logging config
LOG_FILE = ".cache/torrent_purge.log"
LOG_MAX_BYTES = 1 * 1024 * 1024  # 1 MB
LOG_BACKUP_COUNT = 3
# ===============================

# ======== Setup Logging ========
logger = logging.getLogger()
logger.setLevel(logging.INFO)

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
    resp = session.post(f"{QBITTORRENT_HOST}/api/v2/auth/login", data={
        'username': USERNAME,
        'password': PASSWORD
    })
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

    session.post(f"{QBITTORRENT_HOST}/api/v2/torrents/delete", data={
        "hashes": hash_str,
        "deleteFiles": "true"
    })

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
                logger.info(f"Marked for removal: '{torrent['name']}' | Category: {category} | Added: {added_on.date()}")
                to_remove.append(torrent)

    delete_torrents(to_remove)

if __name__ == "__main__":
    main()
