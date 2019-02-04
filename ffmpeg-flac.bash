#/bin/sh
for f in *.flac; do sudo ffmpeg -i "$f" -acodec libmp3lame -ab 320k "${f%.flac}.mp3"; done && sudo chown plex:plex * && sudo chmod 644 * && find . -name "*.flac" -exec rm -rf {} \;

