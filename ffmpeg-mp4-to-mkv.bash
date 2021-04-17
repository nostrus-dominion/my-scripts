for f in *.mp4; do sudo ffmpeg -i "$f" -c copy "${f%.mp4}.mkv"; done && sudo chown plex:plex * && sudo chmod 644 * && sudo rm *.mp4
