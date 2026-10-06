#!/usr/bin/env python3

import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

# Supported video files and extraction rate.
VIDEO_TYPES = {".mp4", ".mkv", ".avi", ".mov", ".webm", ".m4v", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".wmv", ".flv"}
FRAMES_PER_SECOND = 2


def extract_frames(video, output):
    # Leave existing frames alone when running the script again.
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError(f"Output already exists and is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)

    # Extract two frames per second, including variable-frame-rate videos.
    with TemporaryDirectory(prefix="_tmp_", dir=output) as temporary:
        temporary = Path(temporary)
        subprocess.run([
            "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
            "-n", "-i", str(video), "-map", "0:v:0",
            "-vf", f"fps={FRAMES_PER_SECOND}", "-q:v", "2",
            str(temporary / "f_%09d.jpg")
        ], check=True)

        # Group frames by minute. Folder names mark the END of each minute.
        count = 0
        for index, frame in enumerate(sorted(temporary.glob("f_*.jpg"))):
            seconds = index / FRAMES_PER_SECOND
            minute_end = index // (60 * FRAMES_PER_SECOND) + 1
            folder = output / f"{minute_end // 60:02d}-{minute_end % 60:02d}"
            folder.mkdir(exist_ok=True)
            hours, remainder = divmod(seconds, 3600)
            minutes, seconds = divmod(remainder, 60)
            frame.rename(folder / f"{int(hours):02d}h{int(minutes):02d}m{seconds:06.3f}s.jpg")
            count += 1

    if not count:
        raise ValueError("No frames were extracted.")
    print(f"Done: {count} frames -> {output}")


def main():
    # No arguments means all supported videos in the current directory.
    parser = argparse.ArgumentParser(
        description="Extract two frames per second into one-minute folders."
    )
    parser.add_argument("source", nargs="?", default=".", type=Path,
                        help="Video file or directory (default: current directory)")
    parser.add_argument("output", nargs="?", type=Path,
                        help="Output root for a directory, or output folder for one video")
    args = parser.parse_args()

    if not shutil.which("ffmpeg"):
        parser.error("ffmpeg is required but was not found in PATH.")

    if args.source.is_dir():
        videos = sorted(path for path in args.source.iterdir()
                        if path.is_file() and path.suffix.lower() in VIDEO_TYPES)
        root = args.output or args.source
        # Include extensions when two videos have the same title.
        titles = [video.stem.casefold() for video in videos]
        jobs = [(video, root / (video.name if titles.count(video.stem.casefold()) > 1
                               else video.stem)) for video in videos]
    elif args.source.is_file():
        jobs = [(args.source, args.output or args.source.with_suffix(""))]
    else:
        parser.error(f"Source does not exist: {args.source}")

    if not jobs:
        parser.error("No supported video files found in the source directory.")

    # Continue with the remaining videos if one fails.
    failed = False
    for video, output in jobs:
        print(f"Processing: {video.name}", flush=True)
        try:
            extract_frames(video, output)
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            print(f"ERROR: {video.name}: {error}", file=sys.stderr)
            failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
