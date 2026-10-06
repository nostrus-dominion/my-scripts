# ffmerge-er

`ffmerge-er` is a local media command with a matching splash and an eight-job
menu. It uses Python 3's standard library, FFmpeg and ffprobe; no Python packages
are required.

```bash
./ffmerge-er
./ffmerge-er --help
./ffmerge-er concat --help
```

Run without arguments for the menu. Jobs return to the menu after Enter.
Command-line runs require a command, with options after its name.

## Menu

| Number | Job | Command |
| --- | --- | --- |
| 1 | Concat 2 or more videos | `concat` |
| 2 | Make MP4 | `mp4` |
| 3 | Make MKV | `mkv` |
| 4 | Remux containers | `remux` |
| 5 | Demux containers | `demux` |
| 6 | Audio conversion | `audio` |
| 7 | Make a GIF | `gif` |
| 8 | Extract Thumbnail Frames | `thumbnails` |
| q | Quit | |

The menu uses two columns: 1–4 on the left, 5–8 on the right. Trimming, batch
conversion, video/playlist downloads, playback and stream recording are removed
from this command. They are intended for separate scripts. Their old command
names and scheduling/network settings are no longer accepted here, including
the old camera playback command. No new standalone scripts are included in this
update.

## Video concat

```bash
# Explicit playback order, preserving every compatible stream.
./ffmerge-er concat 'part 1.mp4' 'part 2.mp4' -o combined.mkv
# Directory selection uses natural order: part 2 before part 10.
./ffmerge-er concat ./clips --extension mp4 -o combined.mp4
```

Choose two or more videos, or a directory and video extension. The menu supports
both input methods. `--recursive` selects videos in subdirectories. Generated
`.ffmerge-er` files and the selected archive directory are excluded from scans.
Duplicate paths are removed. Each input must contain a video stream.

Concat copies compressed streams without re-encoding. Stream layouts, codecs,
dimensions, frame rates, audio parameters, time bases and codec initialization
data must match. Normalize incompatible clips first. Conversion does not
automatically equalize different resolutions or frame rates. Names with spaces,
apostrophes, Unicode and backslashes are retained; concat lists cannot represent
filenames containing line breaks. The default output is
`concatenated.ffmerge-er.mkv` in the current directory.

## MP4, MKV and remux

```bash
./ffmerge-er mp4 input.mov -o output.mp4
./ffmerge-er mkv input.mov -o output.mkv
./ffmerge-er remux input.mp4 --container mkv -o output.mkv
```

Each conversion takes one file. Directory input, multiple inputs, recursive
conversion and scheduling belong in the separate batch script.

MP4 uses H.264 video and AAC audio with fast-start metadata. Compatible H.264
`yuv420p` and AAC streams are copied; other streams are encoded. MKV uses the
same video/audio profile and retains compatible subtitles and attachments;
MOV text subtitles are converted to SRT. Both conversions select the main video
and all audio tracks. MP4 omits subtitles, attachments and data. Encoded video
defaults to CRF 20 and preset `medium`; encoded AAC defaults to stereo at 128k.
Copied AAC retains its channel count.

Remux copies every stream without converting codecs. Container choices are
MKV, MP4, MOV, WebM, AVI and TS. Unsupported codec/container combinations fail
without changing the source or replacing an existing output.

## Demux

```bash
./ffmerge-er demux input.mkv --output-dir ./tracks
./ffmerge-er demux input.mkv --types audio,subtitle --output-dir ./audio-and-subs
```

Demux extracts individual tracks, subtitles, attachments and data without
re-encoding. Common codecs use native files (H.264, HEVC, AAC, MP3, FLAC, SRT,
ASS, and others). Other codecs use single-track Matroska containers; MOV text
retains its native MP4 container. Attachments retain their bytes and a safe
extension. `tracks.json` records source track indices, codecs, filenames and
metadata. `--types` selects video, audio, subtitle, attachment or data.

The output directory must be new or empty. It is published after all selected
tracks are extracted successfully. Demux always keeps the source.

## Audio conversion

```bash
./ffmerge-er audio recording.m4a --format mp3 -o recording.mp3 --bitrate 192k
./ffmerge-er audio concert.mkv --format flac --track 1 -o second-track.flac
./ffmerge-er audio recording.flac --format wav --sample-rate 44100 --channels 2
```

Formats are MP3, FLAC, WAV (16-bit PCM), M4A, AAC, OGG (Vorbis) and Opus.
Track numbers start at zero; `--track 0` is the default. Sample rate and channel
count are retained where the target codec supports them unless explicitly
changed. Default lossy bitrates are 320k MP3, 192k AAC/M4A/Vorbis and 128k Opus.
`--bitrate` changes the target; FLAC and WAV ignore bitrate. Converting lossy
audio to FLAC/WAV does not restore quality lost earlier.

## GIFs and thumbnail frames

```bash
./ffmerge-er gif input.mp4 --start 12.5 --duration 4 --fps 20 --width 720 -o clip.gif
./ffmerge-er thumbnails input.mp4 --interval 2 --output-dir ./frames
./ffmerge-er thumbnails input.mp4 --every-frames 5 --output-dir ./every-fifth-frame
./ffmerge-er thumbnails input.mp4 --interval 2 --frame-offset 15
./ffmerge-er thumbnails input.mp4 --at 00:01:30 --width 320 --output-dir ./one-frame
```

GIFs use an optimized palette and loop indefinitely. Defaults are start 0,
duration 5 seconds, width 720 and 24 fps. Start/duration select the GIF segment;
they do not provide the removed video-trimming command.

Thumbnail selection uses seconds, exact frame indices, or one timestamp.
`--at` accepts seconds, `MM:SS` or `HH:MM:SS`, optionally with decimal seconds.
Selection methods are mutually exclusive. A frame offset adds frame periods to
a time interval. JPEG quality defaults to 6, adjustable from 2 to 31; lower is
better. `--width` resizes frames. Output requires a new or empty directory,
published after successful generation.

## Originals, outputs and configuration

```bash
./ffmerge-er mp4 input.mov --dry-run
./ffmerge-er remux input.mp4 --container mkv --archive-originals ./processed
./ffmerge-er audio input.flac --format mp3 --delete-originals --yes
./ffmerge-er remux input.mp4 --container mkv --owner plex:plex --file-mode 644
```

Originals are kept by default. Single-file conversions default to a name such
as `original.ext.ffmerge-er.mp4` alongside the input. Missing output extensions
are appended; extensions must match the selected format. Existing outputs
require `--overwrite`; an input can never be overwritten. FFmpeg writes into a
private staging directory, then publishes a nonempty, readable media file after
successful processing. Failures clean up staging and preserve prior outputs.

Archive/delete options apply to concat and single-file conversion only, after
verified output. They are mutually exclusive. Archives never replace existing
files. Unattended deletion requires `--yes`. Ownership and permissions affect
new outputs only and require appropriate OS privileges. Dry runs inspect media
and print commands without changing files. `--nice` adjusts FFmpeg priority.

The optional template `.config/.env.ffmerge-er.example` contains local media
defaults. See [CONFIGURATION.md](CONFIGURATION.md) for private file installation.
Python reads literal assignments without executing shell code. Command-line
options override environment variables, which override the file.

Compatibility aliases are `merge` for `concat`, `web` for `mp4`, `mp3` for MP3
audio conversion, and `snapshots` for `thumbnails`. `mov` accepts one input file
and forces H.264/AAC encoding to MP4.

## Previous local helper mapping

| Previous script | Replacement |
| --- | --- |
| `ffmerge-files.sh` | `ffmerge-er concat` |
| `ffmpeg-web-convert.bash` | `ffmerge-er mp4` |
| `mov.sh` | `ffmerge-er mov` |
| `ffmpeg-mp4-to-mkv.bash` | `ffmerge-er remux --container mkv` |
| `ffmpeg-m4a.sh` | `ffmerge-er audio --format mp3` |
| `ffmpeg-flac.sh` | `ffmerge-er audio --format mp3` |
| `make-a-gif.sh` | `ffmerge-er gif --fps 20` |
| `create-a-gif.sh` | `ffmerge-er gif --fps 24` |
| `snapshot.sh` | `ffmerge-er thumbnails` |

The retired local helpers are removed from the active bundle. Previous
batch/cron, camera and downloader helpers are outside the revised scope.
Validation uses real FFmpeg-generated media and checks both the retained jobs
and rejection of removed jobs. See [FORMATTING.md](FORMATTING.md).

References: [FFmpeg options](https://ffmpeg.org/ffmpeg.html) and
[concat demuxer](https://ffmpeg.org/ffmpeg-formats.html#concat).
