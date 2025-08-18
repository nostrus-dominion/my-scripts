#!/usr/bin/python3

import requests
from collections import defaultdict

QBITTORRENT_URL = 'http://localhost:8080'  # adjust if needed
USERNAME = 'admin'
PASSWORD = 'adminadmin'

session = requests.Session()

def login():
    res = session.post(f'{QBITTORRENT_URL}/api/v2/auth/login', data={
        'username': USERNAME,
        'password': PASSWORD
    })
    if res.text != 'Ok.':
        raise Exception('Login failed')

def get_all_torrents():
    """Fetch all torrents from the client."""
    res = session.get(f'{QBITTORRENT_URL}/api/v2/torrents/info')
    return res.json()

def main():
    login()
    torrents = get_all_torrents()

    total_count = len(torrents)
    seeding_count = 0
    not_seeded_by_category = defaultdict(list)

    for torrent in torrents:
        # States that count as "actively seeding"
        if torrent['state'] in ('uploading', 'stalledUP', 'checkingUP', 'forcedUP'):
            seeding_count += 1
        else:
            not_seeded_by_category[torrent['category'] or 'Uncategorized'].append(torrent['name'])

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

if __name__ == '__main__':
    main()
