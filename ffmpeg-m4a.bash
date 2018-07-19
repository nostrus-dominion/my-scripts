## FOR CORUSCANT
for f in *.m4a; do sudo ffmpeg -i "$f" -acodec libmp3lame -ab 256k "${f%.m4a}.mp3"; done && sudo chown plex:plex * && sudo chmod 644 * && find . -name "*.m4a" -exec rm -rf {} \;

## FOR TORRENT-SERV
for f in *.m4a; do sudo ffmpeg -i "$f" -acodec libmp3lame -ab 256k "${f%.m4a}.mp3"; done && find . -name "*.m4a" -exec rm -rf {} \;