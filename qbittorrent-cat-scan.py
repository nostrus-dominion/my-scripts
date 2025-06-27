#!/usr/bin/python3

import requests
import os

QBITTORRENT_URL = 'http://localhost:8080' # change all this for the setup
USERNAME = 'admin'
PASSWORD = 'adminadmin'
BASE_PATH = '/mnt/dump'

session = requests.Session()

def login():
    res = session.post(f'{QBITTORRENT_URL}/api/v2/auth/login', data={
        'username': USERNAME,
        'password': PASSWORD
    })
    if res.text != 'Ok.':
        raise Exception('Login failed')

def get_categories():
    res = session.get(f'{QBITTORRENT_URL}/api/v2/torrents/categories')
    return list(res.json().keys())

def get_category_torrents(category):
    res = session.get(f'{QBITTORRENT_URL}/api/v2/torrents/info', params={
        'category': category
    })
    return res.json()

def list_downloaded_items(directory):
    try:
        return set(os.listdir(directory))
    except FileNotFoundError:
        print(f"Directory '{directory}' does not exist.")
        return set()

def main():
    login()
    categories = get_categories()

    if not categories:
        print("No categories found.")
        return

    print("Available categories:")
    for i, cat in enumerate(categories):
        print(f"{i + 1}. {cat}")

    choice = input("Enter the number of the category to check: ")

    try:
        index = int(choice) - 1
        if index < 0 or index >= len(categories):
            raise ValueError
        category = categories[index]
    except ValueError:
        print("Invalid selection.")
        return

    folder = os.path.join(BASE_PATH, category)
    print(f"Checking local folder: {folder}")

    torrents = get_category_torrents(category)
    seeded_items = set()

    for torrent in torrents:
        content_path = os.path.join(torrent['save_path'], torrent['name'])
        seeded_items.add(os.path.basename(content_path))

    on_disk_items = list_downloaded_items(folder)

    not_seeded = on_disk_items - seeded_items

    print(f"\n=== Results for Category: {category} ===")
    if not_seeded:
        print("Items on disk NOT being seeded:")
        for item in sorted(not_seeded):
            print(f" - {item}")
    else:
        print("All items in the directory are being seeded.")

if __name__ == '__main__':
    main()
