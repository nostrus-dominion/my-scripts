#!/usr/bin/env python3
"""ffmerge-er: the local media workshop. GPL-3.0-or-later."""

## Version: 0.4.0
## License: GPL-3.0-or-later

import argparse
from contextlib import contextmanager
from fractions import Fraction
import json
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace


# Global variables and supported formats.
VERSION = "0.4.0"
VIDEO_EXTENSIONS = set("mp4 mkv mov avi mpg mpeg m4v webm wmv ts mts m2ts 3gp".split())
AUDIO_FORMATS = {
    "mp3": ("libmp3lame", "320k"), "flac": ("flac", None),
    "wav": ("pcm_s16le", None), "m4a": ("aac", "192k"),
    "aac": ("aac", "192k"), "ogg": ("libvorbis", "192k"),
    "opus": ("libopus", "128k"),
}
PRESETS = "ultrafast superfast veryfast faster fast medium slow slower veryslow placebo".split()
CONTAINERS = ("mkv", "mp4", "mov", "webm", "avi", "ts")
TRACK_TYPES = {"video", "audio", "subtitle", "attachment", "data"}
MENU = (
    ("concat", "Concat 2 or more videos"), ("mp4", "Make MP4"),
    ("mkv", "Make MKV"), ("remux", "Remux containers"),
    ("demux", "Demux containers"), ("audio", "Audio conversion"),
    ("gif", "Make a GIF"), ("thumbnails", "Extract Thumbnail Frames"),
)
ALIASES = {"merge": "concat", "web": "mp4", "mov": "mp4",
           "mp3": "audio", "snapshots": "thumbnails"}


class WorkshopError(Exception):
    """An error that can be shown without a traceback."""


# Configuration and input validation.
def expanded_path(value):
    return Path(value).expanduser().resolve()


def number(value, minimum=0, integer=False):
    result = int(value) if integer else float(value)
    if not math.isfinite(result) or result < minimum:
        raise ValueError(f"Expected a number >= {minimum}")
    return result


def positive_float(value):
    result = number(value)
    if result == 0:
        raise ValueError("Expected a positive number")
    return result


def positive_int(value):
    return number(value, minimum=1, integer=True)


def timestamp(value):
    """Accept seconds, MM:SS, or HH:MM:SS, including fractional seconds."""
    if not re.fullmatch(r"\d+(?::\d{1,2}){0,2}(?:\.\d+)?", str(value)):
        raise ValueError("Use seconds, MM:SS, or HH:MM:SS")
    parts = [float(part) for part in str(value).split(":")]
    if any(part >= 60 for part in parts[1:]):
        raise ValueError("Minutes and seconds after a colon must be below 60")
    total = 0
    for part in parts:
        total = total * 60 + part
    return number(total)


def bitrate(value):
    if not re.fullmatch(r"[1-9][0-9]*[kKmM]?", str(value)):
        raise ValueError("Use a positive bitrate, such as 128k or 320k")
    return str(value)


def load_config():
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "my-scripts"
    directory = Path(os.environ.get("MY_SCRIPTS_CONFIG_DIR", base)).expanduser()
    filename = directory / ".env.ffmerge-er"
    values = {}
    if filename.is_file():
        for line_number, line in enumerate(filename.read_text(encoding="utf-8").splitlines(), 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            name, separator, value = line.partition("=")
            name = name.strip()
            try:
                parts = shlex.split(value, comments=True)
                if not separator or not re.fullmatch(r"[A-Za-z_]\w*", name) or len(parts) > 1:
                    raise ValueError("Expected NAME=value; quote values containing spaces")
            except ValueError as exc:
                raise WorkshopError(f"{filename}:{line_number}: {exc}") from exc
            values[name] = parts[0] if parts else ""
    values.update({key: value for key, value in os.environ.items() if key.startswith("FFMERGE_")})
    return values


def prepare_job(command, values, config):
    """Both interfaces use these defaults and checks; only CLI uses argparse."""
    original_command = command
    command = ALIASES.get(command, command)
    options = dict(output=None, output_dir=None, dry_run=False, quiet=False,
                   overwrite=False, nice=0, owner=None, file_mode=None,
                   archive_originals=None, delete_originals=False, yes=False)
    defaults = {}
    if command == "concat":
        options.update(inputs=[], extension=None, recursive=False)
    elif command in {"mp4", "mkv"}:
        defaults = {"crf": (20, "FFMERGE_CRF"),
                    "preset": ("medium", "FFMERGE_PRESET"),
                    "audio_bitrate": ("128k", "FFMERGE_AUDIO_BITRATE")}
        options["force_encode"] = original_command == "mov"
    elif command == "remux":
        options["container"] = "mkv"
    elif command == "demux":
        options["types"] = "video,audio,subtitle,attachment,data"
    elif command == "audio":
        options.update(track=0, sample_rate=None, channels=None)
        defaults = {"audio_format": ("mp3", "FFMERGE_AUDIO_FORMAT"),
                    "bitrate": (None, "FFMERGE_AUDIO_TARGET_BITRATE")}
    elif command == "gif":
        options.update(start=0, duration=5)
        defaults = {"fps": (24, "FFMERGE_GIF_FPS"),
                    "width": (720, "FFMERGE_GIF_WIDTH")}
    elif command == "thumbnails":
        options.update(every_frames=None, at=None, thumbnail_width=None, frame_offset=0, quality=6)
        # Other selection methods do not depend on the interval setting.
        if values.get("every_frames") is None and values.get("at") is None:
            defaults = {"interval": (2, "FFMERGE_SNAPSHOT_INTERVAL")}
    else:
        raise WorkshopError(f"Unknown job: {command}")
    for key, (default, variable) in defaults.items():
        options[key] = config.get(variable, default)
    options.update(values)
    # Convert interface values once, after selecting this job's defaults.
    converters = {"nice": int, "crf": int, "audio_bitrate": bitrate, "bitrate": bitrate,
                  "fps": positive_float, "width": positive_int, "interval": positive_float,
                  "start": number, "duration": positive_float, "track": int,
                  "sample_rate": positive_int, "channels": positive_int,
                  "every_frames": positive_int, "at": timestamp,
                  "thumbnail_width": positive_int, "frame_offset": int, "quality": int}
    for key, convert in converters.items():
        if options.get(key) is not None:
            try:
                options[key] = convert(options[key])
            except (ValueError, TypeError, OverflowError) as exc:
                raise WorkshopError(f"Invalid {key.replace('_', '-')}: {exc}") from exc
    if original_command == "mp3":
        options["audio_format"] = "mp3"
    if command == "audio" and options["bitrate"] is None and options["audio_format"] == "mp3":
        options["bitrate"] = bitrate(config.get("FFMERGE_MP3_BITRATE", "320k"))
    for key, choices in {"preset": PRESETS, "container": CONTAINERS,
                         "audio_format": AUDIO_FORMATS}.items():
        if key in options and options[key] not in choices:
            raise WorkshopError(f"Invalid {key}: choose {', '.join(choices)}")
    for key, low, high in (("nice", -20, 19), ("crf", 0, 51), ("quality", 2, 31)):
        if key in options and not low <= options[key] <= high:
            raise WorkshopError(f"{key} must be between {low} and {high}")
    if options.get("track", 0) < 0 or options.get("frame_offset", 0) < 0:
        raise WorkshopError("Track numbers and frame offsets cannot be negative")
    if options["archive_originals"] and options["delete_originals"]:
        raise WorkshopError("Choose archive-originals or delete-originals")
    if command == "thumbnails":
        if sum(values.get(key) is not None for key in ("interval", "every_frames", "at")) > 1:
            raise WorkshopError("Choose interval, every-frames, or at")
        if options["frame_offset"] and (options["every_frames"] or options["at"] is not None):
            raise WorkshopError("Use frame-offset only with time intervals")
    if options["file_mode"] is not None:
        try:
            mode = int(str(options["file_mode"]), 8)
        except ValueError as exc:
            raise WorkshopError("File mode must be octal, such as 644") from exc
        if not 0 <= mode <= 0o777:
            raise WorkshopError("File mode must be between 000 and 777")
    return SimpleNamespace(command=command, original_command=original_command, **options)


# FFmpeg execution, media inspection, and output protection.
def redact(message):
    return re.sub(r"([A-Za-z][A-Za-z0-9+.-]*://[^/@]*:)[^@]*(@)",
                  r"\1[redacted]\2", message)


class Runner:
    def __init__(self, args):
        self.args = args

    def log(self, message):
        if not self.args.quiet:
            print(redact(message), flush=True)

    def ffmpeg(self, arguments, duration=0, label="Processing"):
        command = ["ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y",
                   "-progress", "pipe:1", "-nostats", *map(str, arguments)]
        if self.args.nice:
            command = ["nice", "-n", str(self.args.nice), *command]
        if self.args.dry_run:
            print("DRY RUN " + redact(shlex.join(command)))
            return
        terminal = sys.stderr.isatty() and not self.args.quiet
        with tempfile.TemporaryFile() as errors:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                                       stdout=subprocess.PIPE, stderr=errors, text=True)
            try:
                for line in process.stdout:
                    key, _, value = line.strip().partition("=")
                    if terminal and key == "out_time_us" and duration > 0:
                        try:
                            percent = min(99, max(0, int(int(value) / (duration * 10000))))
                        except ValueError:
                            continue
                        print(f"\r  {label}: {percent:3d}%", end="", file=sys.stderr, flush=True)
                returncode = process.wait()
            except BaseException:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                raise
            finally:
                process.stdout.close()
                if terminal:
                    print(file=sys.stderr)
            if returncode:
                errors.seek(0)
                detail = errors.read().decode("utf-8", errors="replace")[-6000:].strip()
                raise WorkshopError(f"FFmpeg failed ({returncode}): {redact(detail)}")


def probe(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format",
         "-show_data_hash", "sha256", "-of", "json", str(path)],
        stdin=subprocess.DEVNULL, capture_output=True, text=True,
    )
    if result.returncode:
        raise WorkshopError(f"Cannot inspect {path}: {result.stderr.strip()}")
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise WorkshopError(f"Invalid ffprobe response for {path}") from exc
    if not data.get("streams"):
        raise WorkshopError(f"No media streams found: {path}")
    return data


def input_media(value):
    source = expanded_path(value)
    if not source.is_file():
        raise WorkshopError(f"Choose one input file: {source}")
    return source, probe(source)


def duration_of(data):
    try:
        duration = float(data.get("format", {}).get("duration", 0))
        return duration if math.isfinite(duration) and duration > 0 else 0
    except (ValueError, TypeError):
        return 0


def video_stream(data):
    return next((stream for stream in data["streams"] if stream.get("codec_type") == "video"
                 and not stream.get("disposition", {}).get("attached_pic")), None)


def audio_streams(data):
    return [stream for stream in data["streams"] if stream.get("codec_type") == "audio"]


def output_file(source, requested, extension):
    destination = expanded_path(requested) if requested else source.with_name(
        f"{source.name}.ffmerge-er.{extension}")
    if not destination.suffix:
        destination = destination.with_suffix("." + extension)
    if destination.suffix.lower() != "." + extension:
        raise WorkshopError(f"This job requires a .{extension} output filename")
    return destination


def validate_destination(destination, inputs, overwrite):
    if destination in inputs or any(destination.exists() and os.path.samefile(destination, source)
                                    for source in inputs):
        raise WorkshopError("Output must not replace an input file")
    if destination.exists() and not overwrite:
        raise WorkshopError(f"Output already exists: {destination}; use --overwrite to replace it")
    if destination.exists() and not destination.is_file():
        raise WorkshopError(f"Output is not a regular file: {destination}")


def apply_permissions(path, args):
    if args.owner:
        user, separator, group = args.owner.partition(":")
        shutil.chown(path, user=user or None, group=(group if separator else None))
    if args.file_mode is not None:
        path.chmod(int(str(args.file_mode), 8))


def write_media(destination, inputs, runner, arguments, duration=0):
    validate_destination(destination, inputs, runner.args.overwrite)
    if runner.args.dry_run:
        runner.ffmpeg([*arguments, str(destination)], duration)
        return False
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".ffmerge-er-output-", dir=destination.parent) as folder:
        temporary = Path(folder) / ("media" + destination.suffix)
        runner.ffmpeg([*arguments, str(temporary)], duration, destination.name)
        if not temporary.stat().st_size:
            raise WorkshopError("FFmpeg produced an empty file")
        probe(temporary)
        apply_permissions(temporary, runner.args)
        if runner.args.overwrite:
            os.replace(temporary, destination)
        else:
            # Reserve exclusively, then publish the completed output.
            with destination.open("xb") as reserved:
                reservation = os.fstat(reserved.fileno())
            try:
                os.replace(temporary, destination)
            except BaseException:
                if destination.exists():
                    current = destination.stat()
                    if (current.st_dev, current.st_ino) == (reservation.st_dev, reservation.st_ino):
                        destination.unlink()
                raise
    runner.log(f"OK   {destination}")
    return True


@contextmanager
def output_folder(source, requested, suffix, dry_run):
    """Tracks and frames share the same staging and cleanup rules."""
    destination = expanded_path(requested) if requested else source.with_name(
        f"{source.name}.ffmerge-er.{suffix}")
    if destination == source or destination in source.parents:
        raise WorkshopError("Choose a separate output directory")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise WorkshopError("Choose a new or empty output directory")
    if dry_run:
        yield destination, destination
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".ffmerge-er-output-", dir=destination.parent) as folder:
        # Keep the context manager's root in place after publishing its child.
        staging = Path(folder) / "files"
        staging.mkdir()
        yield staging, destination
        os.rename(staging, destination)


def confirm_deletion(args):
    if args.delete_originals and not args.yes and not args.dry_run:
        if not sys.stdin.isatty():
            raise WorkshopError("--delete-originals requires --yes when run unattended")
        if input("Delete originals after successful output? [y/N]: ").strip().lower() not in {"y", "yes"}:
            raise WorkshopError("Original deletion cancelled")


def finish_originals(inputs, args, runner):
    for source in inputs:
        if args.archive_originals:
            directory = expanded_path(args.archive_originals)
            destination = directory / source.name
            if source == destination:
                raise WorkshopError("Archive destination must differ from the source")
            directory.mkdir(parents=True, exist_ok=True)
            created = False
            try:
                with destination.open("xb") as output:
                    created = True
                    with source.open("rb") as original:
                        shutil.copyfileobj(original, output)
                shutil.copystat(source, destination)
                source.unlink()
            except BaseException:
                if created:
                    destination.unlink(missing_ok=True)
                raise
            runner.log(f"ARCHIVE   {source} -> {destination}")
        elif args.delete_originals:
            source.unlink()
            runner.log(f"DELETE   {source}")


# Job 1: concatenate compatible videos without re-encoding.
def concat(args, runner):
    extensions = {args.extension.lower().lstrip(".")} if args.extension else VIDEO_EXTENSIONS
    excluded = [expanded_path(args.archive_originals)] if args.archive_originals else []
    inputs = []
    for name in args.inputs:
        path = expanded_path(name)
        if path.is_dir():
            if not args.extension:
                raise WorkshopError("Choose --extension when concatenating a directory")
            candidates = path.rglob("*") if args.recursive else path.iterdir()
            selected = [p for p in candidates if p.is_file()
                        and p.suffix.lower().lstrip(".") in extensions
                        and ".ffmerge-er" not in p.name
                        and not any(part.startswith(".ffmerge-er-") for part in p.parts)
                        and not any(directory in p.parents for directory in excluded)]
            inputs.extend(sorted(selected, key=natural_key))
        elif path.is_file():
            inputs.append(path)
        else:
            raise WorkshopError(f"Input not found: {path}")
    inputs = list(dict.fromkeys(inputs))
    if len(inputs) < 2:
        raise WorkshopError("Concat needs at least two videos")
    destination = expanded_path(args.output or "concatenated.ffmerge-er.mkv")
    validate_destination(destination, inputs, args.overwrite)
    metadata = [probe(path) for path in inputs]
    if any(not video_stream(data) for data in metadata):
        raise WorkshopError("Concat requires a video stream in every input")
    if any(stream_signature(data) != stream_signature(metadata[0]) for data in metadata[1:]):
        raise WorkshopError("Concat streams differ in layout, codecs, or timing. Normalize the clips first.")
    if any("\n" in str(path) or "\r" in str(path) for path in inputs):
        raise WorkshopError("Concat lists cannot represent filenames containing line breaks")
    confirm_deletion(args)
    arguments = ["-f", "concat", "-safe", "0", "-i"]
    if args.dry_run:
        for index, path in enumerate(inputs, 1):
            print(f"CONCAT {index:03d} {path}")
        runner.ffmpeg([*arguments, "<temporary-concat-list>", "-map", "0", "-c", "copy", str(destination)])
        return
    with tempfile.TemporaryDirectory(prefix="ffmerge-er-concat-") as folder:
        listing = Path(folder) / "inputs.ffconcat"
        lines = ["ffconcat version 1.0"]
        for path in inputs:
            lines.append("file '" + str(path).replace("'", "'\\''") + "'")
        listing.write_text("\n".join(lines) + "\n", encoding="utf-8")
        write_media(destination, inputs, runner,
                    [*arguments, str(listing), "-map", "0", "-c", "copy"],
                    sum(duration_of(data) for data in metadata))
    finish_originals(inputs, args, runner)


def natural_key(path):
    return [(0, int(part)) if part.isdigit() else (1, part.casefold())
            for part in re.split(r"(\d+)", str(path))]


def stream_signature(data):
    fields = ("codec_type", "codec_name", "codec_tag_string", "time_base", "width", "height",
              "pix_fmt", "sample_aspect_ratio", "r_frame_rate", "sample_rate", "channels",
              "channel_layout", "extradata_hash")
    return [tuple(stream.get(field) for field in fields) for stream in data["streams"]]


# Jobs 2-4 and 6: video conversion, remuxing, and audio conversion.
def video_arguments(source, data, args):
    stream = video_stream(data)
    if not stream:
        raise WorkshopError(f"No video stream: {source}")
    arguments = ["-i", str(source), "-map", f"0:{stream['index']}", "-map", "0:a?",
                 "-map_metadata", "0", "-dn"]
    if args.command == "mkv":
        arguments += ["-map", "0:s?", "-map", "0:t?", "-c:s", "copy", "-c:t", "copy"]
        subtitles = [s for s in data["streams"] if s.get("codec_type") == "subtitle"]
        for index, subtitle in enumerate(subtitles):
            if subtitle.get("codec_name") == "mov_text":
                arguments += [f"-c:s:{index}", "srt"]
    else:
        arguments.append("-sn")
    if not args.force_encode and stream.get("codec_name") == "h264" and stream.get("pix_fmt") == "yuv420p":
        arguments += ["-c:v", "copy"]
    else:
        arguments += ["-c:v", "libx264", "-crf", str(args.crf), "-preset", args.preset,
                      "-pix_fmt", "yuv420p", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2"]
    for index, stream in enumerate(audio_streams(data)):
        if not args.force_encode and stream.get("codec_name") == "aac":
            arguments += [f"-c:a:{index}", "copy"]
        else:
            arguments += [f"-c:a:{index}", "aac", f"-b:a:{index}", args.audio_bitrate,
                          f"-ac:a:{index}", "2"]
    if args.command == "mp4":
        arguments += ["-movflags", "+faststart"]
    return arguments


def audio_arguments(source, data, args):
    tracks = audio_streams(data)
    if args.track >= len(tracks):
        raise WorkshopError(f"Audio track {args.track} does not exist; found {len(tracks)} track(s)")
    codec, default_bitrate = AUDIO_FORMATS[args.audio_format]
    arguments = ["-i", str(source), "-map", f"0:{tracks[args.track]['index']}", "-vn", "-sn",
                 "-dn", "-c:a", codec, "-map_metadata", "0"]
    if default_bitrate:
        arguments += ["-b:a", args.bitrate or default_bitrate]
    if args.sample_rate:
        arguments += ["-ar", str(args.sample_rate)]
    if args.channels:
        arguments += ["-ac", str(args.channels)]
    if args.audio_format == "m4a":
        arguments += ["-movflags", "+faststart"]
    return arguments


def conversion(args, runner):
    source, data = input_media(args.input)
    if args.command == "remux":
        extension = args.container
        arguments = ["-i", str(source), "-map", "0", "-c", "copy"]
        if extension in {"mp4", "mov"}:
            arguments += ["-movflags", "+faststart"]
    elif args.command == "audio":
        extension = args.audio_format
        arguments = audio_arguments(source, data, args)
    else:
        extension = args.command
        arguments = video_arguments(source, data, args)
    destination = output_file(source, args.output, extension)
    confirm_deletion(args)
    if write_media(destination, [source], runner, arguments, duration_of(data)):
        finish_originals([source], args, runner)


# Job 5: extract individual tracks and attachments without re-encoding.
def demux_format(stream):
    codec, kind = stream.get("codec_name", "unknown"), stream.get("codec_type")
    formats = {
        "video": {"h264": ("h264", "h264"), "hevc": ("h265", "hevc"),
                  "mpeg4": ("m4v", "m4v"), "mpeg1video": ("m1v", "mpeg1video"),
                  "mpeg2video": ("m2v", "mpeg2video"), "av1": ("obu", "obu"),
                  "vp8": ("ivf", "ivf"), "vp9": ("ivf", "ivf")},
        "audio": {"mp3": ("mp3", "mp3"), "aac": ("aac", "adts"), "flac": ("flac", "flac"),
                  "ac3": ("ac3", "ac3"), "eac3": ("eac3", "eac3"), "dts": ("dts", "dts"),
                  "truehd": ("thd", "truehd"), "opus": ("opus", "ogg"), "vorbis": ("ogg", "ogg")},
        "subtitle": {"subrip": ("srt", "srt"), "ass": ("ass", "ass"), "ssa": ("ass", "ass"),
                     "webvtt": ("vtt", "webvtt"), "hdmv_pgs_subtitle": ("sup", "sup"),
                     "mov_text": ("mp4", "mp4")},
    }
    if kind == "audio" and codec.startswith("pcm_"):
        return "wav", "wav"
    fallback = {"video": ("mkv", "matroska"), "audio": ("mka", "matroska"),
                "subtitle": ("mks", "matroska")}.get(kind, ("bin", "data"))
    return formats.get(kind, {}).get(codec, fallback)


def demux(args, runner):
    source, data = input_media(args.input)
    selected = {kind.strip() for kind in args.types.split(",")}
    if not selected <= TRACK_TYPES:
        raise WorkshopError("--types accepts video,audio,subtitle,attachment,data")
    streams = [stream for stream in data["streams"] if stream.get("codec_type") in selected]
    if not streams:
        raise WorkshopError("No tracks match --types")
    with output_folder(source, args.output_dir, "tracks", args.dry_run) as (folder, destination):
        manifest = []
        for stream in streams:
            index, kind = stream["index"], stream["codec_type"]
            extension, muxer = demux_format(stream)
            if kind == "attachment":
                original_name = stream.get("tags", {}).get("filename", "attachment.bin")
                suffix = Path(original_name.replace("\\", "/")).suffix
                extension = suffix.lstrip(".") if re.fullmatch(r"\.[A-Za-z0-9]{1,10}", suffix) else "bin"
            filename = f"track-{index:02d}-{kind}.{extension}"
            target = folder / filename
            if kind == "attachment":
                arguments = [f"-dump_attachment:{index}", str(target), "-i", str(source),
                             "-map", "0:v?", "-map", "0:a?", "-c", "copy", "-t", "0",
                             "-f", "null", "-"]
            else:
                arguments = ["-i", str(source), "-map", f"0:{index}", "-c", "copy",
                             "-f", muxer, str(target)]
            runner.ffmpeg(arguments, duration_of(data), filename)
            if not args.dry_run:
                if not target.is_file() or not target.stat().st_size:
                    raise WorkshopError(f"Empty extraction for track {index}")
                if kind not in {"attachment", "data"}:
                    probe(target)
                apply_permissions(target, args)
            manifest.append(dict(index=index, type=kind, codec=stream.get("codec_name"),
                                 file=filename, tags=stream.get("tags", {})))
        if not args.dry_run:
            manifest_path = folder / "tracks.json"
            manifest_path.write_text(json.dumps({"source": str(source), "tracks": manifest},
                                               indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            apply_permissions(manifest_path, args)
    runner.log(f"{'Would extract' if args.dry_run else 'OK  '} {len(streams)} tracks -> {destination}")


# Job 7: create a GIF with an optimized palette.
def make_gif(args, runner):
    source, data = input_media(args.input)
    stream = video_stream(data)
    if not stream:
        raise WorkshopError("GIF creation needs a video stream")
    if duration_of(data) and args.start >= duration_of(data):
        raise WorkshopError("GIF start time is beyond the input duration")
    filters = (f"[0:{stream['index']}]fps={args.fps},scale={args.width}:-1:flags=lanczos,"
               "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse[out]")
    arguments = ["-ss", str(args.start), "-i", str(source), "-t", str(args.duration),
                 "-filter_complex", filters, "-map", "[out]", "-an", "-loop", "0"]
    write_media(output_file(source, args.output, "gif"), [source], runner, arguments, args.duration)


# Job 8: extract JPEG frames by interval, frame number, or timestamp.
def thumbnails(args, runner):
    source, data = input_media(args.input)
    stream = video_stream(data)
    if not stream:
        raise WorkshopError("Thumbnails need a video stream")
    if args.at is not None:
        if duration_of(data) and args.at >= duration_of(data):
            raise WorkshopError("Thumbnail timestamp is beyond the input duration")
        filters = "null"
    elif args.every_frames:
        filters = f"select=not(mod(n\\,{args.every_frames}))"
    else:
        rate = Fraction(0)
        for value in (stream.get("avg_frame_rate"), stream.get("r_frame_rate")):
            try:
                candidate = Fraction(value or "0/1")
            except (ValueError, ZeroDivisionError):
                continue
            if candidate > 0:
                rate = candidate
                break
        if args.frame_offset and rate <= 0:
            raise WorkshopError("Cannot calculate the frame offset without a frame rate")
        interval = args.interval + (args.frame_offset / float(rate) if args.frame_offset else 0)
        filters = f"fps=1/{interval}"
    if args.thumbnail_width:
        filters += f",scale={args.thumbnail_width}:-1"
    arguments = (["-ss", str(args.at)] if args.at is not None else []) + [
        "-i", str(source), "-map", f"0:{stream['index']}", "-vf", filters,
        "-fps_mode", "vfr", "-q:v", str(args.quality)]
    if args.at is not None:
        arguments += ["-frames:v", "1"]
    suffix = "snapshots" if args.original_command == "snapshots" else "thumbnails"
    with output_folder(source, args.output_dir, suffix, args.dry_run) as (folder, destination):
        runner.ffmpeg([*arguments, str(folder / "snapshot-%06d.jpg")],
                      duration_of(data), "Thumbnail frames")
        if not args.dry_run:
            count = sum(1 for _ in folder.glob("*.jpg"))
            if not count:
                raise WorkshopError("No frames generated; use a shorter interval")
    if not args.dry_run:
        runner.log(f"OK   {count} thumbnail frame(s) -> {destination}")


# Command-line interface. This parser never handles menu input.
def build_parser():
    parser = argparse.ArgumentParser(prog="ffmerge-er", description="Local media workshop",
                                     epilog="Run without arguments for the eight-job menu.")
    parser.add_argument("--version", action="version", version=f"ffmerge-er {VERSION}")
    commands = parser.add_subparsers(dest="command", required=True)
    for command, label in MENU:
        aliases = [alias for alias, target in ALIASES.items() if target == command]
        item = commands.add_parser(command, aliases=aliases, help=label,
                                   argument_default=argparse.SUPPRESS)
        item.add_argument("--dry-run", action="store_true", help="print commands without writing files")
        item.add_argument("--quiet", action="store_true", help="suppress routine messages")
        item.add_argument("--overwrite", action="store_true", help="replace an existing output file")
        item.add_argument("--nice", help="FFmpeg priority adjustment, -20 to 19")
        originals = command in {"concat", "mp4", "mkv", "remux", "audio"}
        if originals:
            group = item.add_mutually_exclusive_group()
            group.add_argument("--archive-originals", metavar="DIR")
            group.add_argument("--delete-originals", action="store_true")
            item.add_argument("--yes", action="store_true", help="confirm deletion without prompting")
        if originals or command == "demux":
            item.add_argument("--owner", metavar="USER[:GROUP]")
            item.add_argument("--file-mode", metavar="OCTAL")
        if command == "concat":
            item.add_argument("inputs", nargs="+", help="videos in playback order, or a directory")
            item.add_argument("--extension", help="video extension for directory input")
            item.add_argument("--recursive", action="store_true")
        else:
            item.add_argument("input", help="one input media file")
        if command in {"demux", "thumbnails"}:
            item.add_argument("--output-dir")
        else:
            item.add_argument("-o", "--output")
        if command in {"mp4", "mkv"}:
            item.add_argument("--crf", help="H.264 quality, 0 to 51; default 20")
            item.add_argument("--preset", choices=PRESETS)
            item.add_argument("--audio-bitrate", help="encoded AAC bitrate; default 128k")
        elif command == "remux":
            item.add_argument("--container", choices=CONTAINERS)
        elif command == "audio":
            item.add_argument("--format", dest="audio_format", choices=tuple(AUDIO_FORMATS))
            item.add_argument("--bitrate", help="lossy audio bitrate")
            item.add_argument("--track", help="audio track number, starting at 0")
            item.add_argument("--sample-rate")
            item.add_argument("--channels")
        elif command == "demux":
            item.add_argument("--types", help="comma-separated track types")
        elif command == "gif":
            item.add_argument("--start", help="start in seconds; default 0")
            item.add_argument("--duration", help="length in seconds; default 5")
            item.add_argument("--fps")
            item.add_argument("--width")
        elif command == "thumbnails":
            group = item.add_mutually_exclusive_group()
            group.add_argument("--interval", help="seconds between frames; default 2")
            group.add_argument("--every-frames", help="extract every N frames")
            group.add_argument("--at", help="seconds, MM:SS, or HH:MM:SS")
            item.add_argument("--width", dest="thumbnail_width")
            item.add_argument("--frame-offset")
            item.add_argument("--quality", help="JPEG quality, 2 to 31; default 6")
    return parser


# Interactive interface. Collect values directly, without building CLI arguments.
def splash():
    color = sys.stdout.isatty() and "NO_COLOR" not in os.environ and os.environ.get("TERM") != "dumb"
    amber, reset = ("\033[38;5;208m", "\033[0m") if color else ("", "")
    print(f"\n{amber}  // THE CUTTING ROOM //  ffmerge-er  v{VERSION}{reset}")
    print("  CONCAT / CONVERT / REMUX / DEMUX / GIF / FRAMES\n")


def ask(prompt, default=None):
    return input(prompt).strip() or default


def menu_job():
    splash()
    for row in range(4):
        left = f"{row + 1}  {MENU[row][1]}"
        print(f"  {left:<32}{row + 5}  {MENU[row + 4][1]}")
    choice = ask("\n  q  Quit\n\nChoose a job: ", "")
    if choice.lower() in {"q", "quit", "exit"}:
        return None
    if not choice.isdigit() or not 1 <= int(choice) <= len(MENU):
        raise WorkshopError("Choose a job from 1 to 8 or q")
    command = MENU[int(choice) - 1][0]
    values = {}
    if command == "concat":
        selection = ask("Select files in order or a directory? [files]: ", "files").lower()
        if selection in {"directory", "dir"}:
            values["inputs"] = [ask("Directory containing videos [.]: ", ".")]
            values["extension"] = ask("Video extension [mp4]: ", "mp4")
        elif selection == "files":
            files = []
            while True:
                name = ask(f"Video {len(files) + 1} (blank to finish): ")
                if name is None:
                    break
                files.append(name)
            if len(files) < 2:
                raise WorkshopError("Concat needs two or more video files")
            values["inputs"] = files
        else:
            raise WorkshopError("Choose files or directory")
    else:
        values["input"] = ask("Input file: ")
        if values["input"] is None:
            raise WorkshopError("An input file is required")
    prompts = {
        "gif": (("start", "Start in seconds [0]: "), ("duration", "Duration in seconds [5]: ")),
        "audio": (("audio_format", "Format: mp3/flac/wav/m4a/aac/ogg/opus [configured default]: "),
                  ("track", "Audio track number [0]: "), ("bitrate", "Bitrate [format default]: ")),
        "remux": (("container", "Container: mkv/mp4/mov/webm/avi/ts [mkv]: "),),
    }
    for key, prompt in prompts.get(command, ()):
        value = ask(prompt)
        if value is not None:
            values[key] = value.lower() if key in {"container", "audio_format"} else value
    if command == "thumbnails":
        mode = ask("Selection: seconds / frames / timestamp [seconds]: ", "seconds").lower()
        selections = {"seconds": ("interval", "Seconds between frames [configured default]: "),
                      "frames": ("every_frames", "Extract every N frames [30]: "),
                      "timestamp": ("at", "Timestamp (HH:MM:SS or seconds) [0]: ")}
        if mode not in selections:
            raise WorkshopError("Choose seconds, frames, or timestamp")
        key, prompt = selections[mode]
        value = ask(prompt, {"frames": "30", "timestamp": "0"}.get(mode))
        if value is not None:
            values[key] = value
    key = "output_dir" if command in {"demux", "thumbnails"} else "output"
    value = ask("Output " + ("directory" if key == "output_dir" else "file") + " [default]: ")
    if value is not None:
        values[key] = value
    print()
    return command, values


# Shared dispatch and entry point.
HANDLERS = {"concat": concat, "mp4": conversion, "mkv": conversion, "remux": conversion,
            "audio": conversion, "demux": demux, "gif": make_gif, "thumbnails": thumbnails}


def run_job(command, values, config):
    args = prepare_job(command, values, config)
    dependencies = ["ffmpeg", "ffprobe"] + (["nice"] if args.nice else [])
    missing = [name for name in dependencies if not shutil.which(name)]
    if missing:
        raise WorkshopError("Missing dependencies: " + ", ".join(missing))
    HANDLERS[args.command](args, Runner(args))


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        if argv:
            values = vars(build_parser().parse_args(argv))
            command = values.pop("command")
            if not values.get("quiet", False):
                splash()
            run_job(command, values, load_config())
            return 0
        if not sys.stdin.isatty():
            raise WorkshopError("Choose a command; use ffmerge-er --help for unattended runs")
        config = load_config()
        while True:
            try:
                job = menu_job()
                if job is None:
                    return 0
                run_job(*job, config)
            except (WorkshopError, OSError, ValueError) as exc:
                print("ERROR   " + redact(str(exc)), file=sys.stderr)
            input("\nPress Enter to return to the menu...")
    except (WorkshopError, OSError, ValueError) as exc:
        print("ERROR   " + redact(str(exc)), file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
