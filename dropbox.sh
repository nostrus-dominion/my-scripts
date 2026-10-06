#!/bin/bash

## Version 0.6
## License: Open Source GPL
## Copyright: (c) 2023

#######################
## ALL THE BORING STUFF
#######################

# Global variables for ANSI color.
color_file="${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf"
if [ -r "$color_file" ]; then
  # shellcheck source=/dev/null
  source "$color_file" || exit 1
fi

# Default download directory and Dropbox upload location.
downdir="${DROPBOX_DOWNLOAD_DIR:-$HOME/Dropbox Downloads}"
dropbox_remote="${DROPBOX_REMOTE:-dropbox}"
dropbox_remote="${dropbox_remote%:}"
inbox="$dropbox_remote:00 Inbox"
workdir=''

# Allow an empty download directory listing, including hidden filenames.
shopt -s nullglob dotglob

#######################
## FUNCTIONS
#######################

# Display the help section.
show_help() {
  cat << 'HELP'
Usage:
  dropbox.sh                         Prompt for a Dropbox download link
  dropbox.sh 'https://www.dropbox.com/...'
                                     Download the supplied link
  dropbox.sh foo.ext                 Upload a file to Dropbox's 00 Inbox
  dropbox.sh foo.ext bar.ext         Upload multiple files to 00 Inbox
  dropbox.sh -- '-filename.ext'      Upload a filename starting with a dash
  dropbox.sh -h, --help              Show help

Downloads go to ~/Dropbox Downloads. ZIP downloads are extracted there;
other downloads keep their filenames. Existing files are not overwritten.
If extraction fails, the downloaded archive is kept.

Uploads keep the local filename and leave the local file in place.
Identical remote files are skipped; different files with the same name
cause an error instead of being overwritten. Directories are not uploaded.

Upload setup:
  Install rclone, then run: rclone config
  Create a remote named dropbox, select Dropbox, and authorize your account.
  Run this script as the same user who configured rclone.

Optional settings:
  DROPBOX_REMOTE        rclone remote name (default: dropbox)
  DROPBOX_DOWNLOAD_DIR  Download directory (default: ~/Dropbox Downloads)

Download dependencies: curl, mkdir, mktemp, mv, rm; 7z for ZIP extraction.
Upload dependencies: rclone, realpath.
HELP
}

# Display an error using the shared color configuration, if available.
error() {
  printf '%bERROR: %s%b\n' "$red" "$*" "$reset" >&2
}

# Check only the dependencies needed for the selected mode.
check_dependencies() {
  local dependency
  local missing_dependencies=()

  for dependency in "$@"; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      missing_dependencies+=("$dependency")
    fi
  done

  if ((${#missing_dependencies[@]})); then
    for dependency in "${missing_dependencies[@]}"; do
      error "Required command '$dependency' is not installed or not in PATH."
    done
    return 1
  fi
}

# Remove temporary download files when the script finishes or is interrupted.
cleanup() {
  if [ -n "$workdir" ] && [ -d "$workdir" ]; then
    rm -rf -- "$workdir"
  fi
}

# Force the shared link to download while keeping its other query parameters.
download_link() {
  local url="${1%%#*}"
  local base="${url%%\?*}"
  local query=''
  local parameter
  local parameters=()

  if [[ "$url" == *\?* ]]; then
    query="${url#*\?}"
  fi
  IFS='&' read -r -a parameters <<< "$query"

  url="$base?dl=1"
  for parameter in "${parameters[@]}"; do
    case "$parameter" in
      ''|dl=*|raw=*)
        continue
        ;;
      *)
        url+="&$parameter"
        ;;
    esac
  done

  printf '%s\n' "$url"
}

# Download a shared Dropbox file or folder.
download_files() {
  local url="${1:-}"
  local downloaded_files=()
  local downloaded_file name saved_file
  local number=1

  check_dependencies curl mkdir mktemp mv rm || return 1

  # Prompt for a link when the script was called without arguments.
  if [ -z "$url" ]; then
    read -rp "Paste Dropbox Link: " url || return 1
  fi

  if [[ ! "$url" =~ ^https://(www\.)?dropbox\.com/[^[:space:]]+$ ]]; then
    error 'Please provide a valid HTTPS Dropbox link.'
    return 1
  fi
  url="$(download_link "$url")"

  # Download into a separate temporary directory before saving the result.
  mkdir -p -- "$downdir" || return 1
  downdir="$(cd -- "$downdir" && pwd -P)" || return 1
  workdir="$(mktemp -d "$downdir/.dropbox-download.XXXXXXXX")" || return 1

  echo 'Downloading from Dropbox...'
  if ! (
    cd -- "$workdir" || exit 1
    curl --fail --location --show-error --limit-rate 5M \
      --proto '=https' --proto-redir '=https' \
      --remote-name --remote-header-name -- "$url"
  ); then
    error 'Download failed.'
    return 1
  fi

  # Use the filename supplied by Dropbox instead of calling every file a ZIP.
  downloaded_files=("$workdir"/*)
  if ((${#downloaded_files[@]} != 1)) || [ ! -f "${downloaded_files[0]:-}" ]; then
    error 'Could not locate the downloaded file.'
    return 1
  fi
  downloaded_file="${downloaded_files[0]}"
  name="${downloaded_file##*/}"
  saved_file="$downdir/$name"

  # Keep existing downloads by adding a number if the filename is already used.
  while [ -e "$saved_file" ] || [ -L "$saved_file" ]; do
    saved_file="$downdir/$name.$number"
    ((number++))
  done
  if ! mv -nT -- "$downloaded_file" "$saved_file" || [ -e "$downloaded_file" ]; then
    error 'Could not save the downloaded file.'
    return 1
  fi

  # Extract ZIP downloads, and remove the archive only after successful extraction.
  if [[ "$name" == *.[zZ][iI][pP] ]]; then
    if ! check_dependencies 7z; then
      echo "Archive saved to $saved_file"
      return 1
    fi

    echo 'Extracting downloaded ZIP...'
    if ! 7z x "$saved_file" "-o$downdir" -aos; then
      error "Extraction failed. Archive kept at: $saved_file"
      return 1
    fi
    rm -f -- "$saved_file" || return 1
    echo "Files saved to $downdir"
  else
    echo "File saved to $saved_file"
  fi

  echo 'DONE!'
}

# Upload local files to the 00 Inbox folder in Dropbox.
upload_files() {
  local file name source_file remote
  local remotes
  local configured=0
  local failed=0

  check_dependencies rclone realpath || return 1

  # Validate every supplied file before starting an upload.
  for file in "$@"; do
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
      error "Not a readable file: $file"
      return 1
    fi
  done

  # Check that the requested rclone remote has been configured.
  remotes="$(rclone listremotes)" || return 1
  while IFS= read -r remote; do
    if [ "$remote" = "$dropbox_remote:" ]; then
      configured=1
    fi
  done <<< "$remotes"

  if (( ! configured )); then
    error "rclone remote '$dropbox_remote' is not configured. Run 'rclone config' first."
    return 1
  fi

  for file in "$@"; do
    name="${file##*/}"

    # A full local path avoids confusing filenames containing ':' with remotes.
    if ! source_file="$(realpath -e -- "$file")"; then
      error "Cannot resolve file: $file"
      failed=1
      continue
    fi

    echo "Uploading $file to 00 Inbox..."
    if rclone copyto --progress --checksum --immutable -- "$source_file" "$inbox/$name"; then
      echo "Available in Dropbox: 00 Inbox/$name"
    else
      error "Upload failed: $file"
      failed=1
    fi
  done

  return "$failed"
}

#######################
## BEGINNING OF SCRIPT
#######################

# Show help without starting a transfer.
if [ "${1:-}" = '--help' ] || [ "${1:-}" = '-h' ]; then
  check_dependencies cat || exit 1
  show_help
  exit 0
fi

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# No arguments means download mode, just like the original script.
if (($# == 0)); then
  download_files
  exit $?
fi

# A supplied Dropbox link also selects download mode.
if [[ "$1" == https://* ]]; then
  if (($# != 1)); then
    error 'Supply one Dropbox download link at a time.'
    exit 1
  fi
  download_files "$1"
  exit $?
fi

# Everything else is a local file to upload. Allow -- before dashed filenames.
if [ "$1" = '--' ]; then
  shift
fi
if (($# == 0)); then
  error 'Supply at least one file after --.'
  exit 1
fi

upload_files "$@"
exit $?
