#!/bin/bash
# snapshot.sh — Extract snapshots from a video at set intervals (seconds or frames)

## Verision 0.5
## License: Open Source GPL
## Copyright: (c) 2024

# Usage:
#   ./snapshot.sh [video filename] [seconds] [frames]
# Examples:
#   ./snapshot.sh video.mp4             -> every 2 seconds (default)
#   ./snapshot.sh video.mp4 2 15        -> every 2 seconds + 15 frames
#   ./snapshot.sh video.mp4 0 5         -> every 5 frames

# Define colors
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
dim=$(tput dim)
reset=$(tput sgr0) # No Color

#  Dependency check
checkDependencies() {
  if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed or not in PATH."
    echo "Please install it first. (e.g., sudo apt install ffmpeg)"
    exit 1
  fi

  if ! command -v ffprobe &> /dev/null; then
    echo "Error: ffprobe is not installed or not in PATH."
    echo "Please install it first. (e.g., sudo apt install ffmpeg)"
    exit 1
  fi
}

#  Progress bar
showProgressBar() {
  local current=$1
  local total=$2
  local width=40
  local progress=$((current * width / total))
  local percent=$((current * 100 / total))

  printf "\r["
  for ((i=0; i<width; i++)); do
    if [ "$i" -lt "$progress" ]; then
      printf "#"
    else
      printf "-"
    fi
  done
  printf "] %d%% (%d/%d)" "$percent" "$current" "$total"
}

#  Main snapshot extraction
extractSnapshots() {
  local input="$1"
  local secondsInterval="$2"
  local framesOffset="$3"

  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local outDir="snapshots-${timestamp}"
  local outputPattern="${outDir}/snapshot-${timestamp}_%04d.jpg"

  mkdir -p "$outDir"

  # Get FPS and total frames
  local fps
  fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
    -of default=noprint_wrappers=1:nokey=1 "$input" | awk -F'/' '{printf "%.2f", $1/$2}')

  local totalFrames
  totalFrames=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames \
    -of default=noprint_wrappers=1:nokey=1 "$input")

  local filter
  if [ "$secondsInterval" -eq 0 ]; then
    filter="select=not(mod(n\\,$framesOffset))"
    echo "Extracting every $framesOffset frames (video FPS: $fps)"
  else
    local frameTime
    frameTime=$(echo "scale=6; $secondsInterval + ($framesOffset / $fps)" | bc)
    filter="fps=1/${frameTime}"
    echo "Extracting every ${secondsInterval}s + ${framesOffset}f (~${frameTime}s)"
  fi

  echo "Input file: $input"
  echo "Output folder: $outDir"
  echo "JPEG quality: 6"
  echo "--"

  # Run ffmpeg with progress tracking
  local tmpFile
  tmpFile=$(mktemp)

  ffmpeg -hide_banner -loglevel error -i "$input" -vf "$filter" -q:v 6 -f image2 "$outputPattern" -progress "$tmpFile" &

  local pid=$!
  local current=0

  while kill -0 $pid 2> /dev/null; do
    if grep -q "frame=" "$tmpFile"; then
      current=$(grep "frame=" "$tmpFile" | tail -1 | cut -d= -f2)
      showProgressBar "$current" "$totalFrames"
    fi
    sleep 0.2
  done

  wait $pid
  showProgressBar "$totalFrames" "$totalFrames"
  echo ""
  echo "--"

  local count
  count=$(ls "$outDir" | wc -l)
  echo "Done. Saved $count snapshots to '$outDir/'."

  rm -f "$tmpFile"
}

#  Main execution
checkDependencies

if [ -z "$1" ]; then
  echo "Usage: $0 [video filename] [seconds] [frames]"
  echo "Example: $0 input.mp4 2 15"
  echo "Example: $0 input.mp4 0 5   # every 5 frames"
  exit 1
fi

input="$1"
secondsInterval=${2:-2}
framesOffset=${3:-0}

if [ ! -f "$input" ]; then
  echo "Error: File '$input' not found."
  exit 1
fi

extractSnapshots "$input" "$secondsInterval" "$framesOffset"
