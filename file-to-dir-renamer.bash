#!/bin/bash

# Rename files using the name of the directory they are in.
# One file per extension gets the directory name.
# Multiple files per extension get the directory name and a number.

#######################
## ALL THE BORING STUFF
#######################

# Dependency check.
dependencies=("find" "basename" "mv" "cat")
missing_dependencies=()
for dependency in "${dependencies[@]}"; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    missing_dependencies+=("$dependency")
  fi
done
if ((${#missing_dependencies[@]})); then
  for dependency in "${missing_dependencies[@]}"; do
    printf 'ERROR: Required command "%s" is not installed or not in PATH.\n' "$dependency" >&2
  done
  exit 1
fi

# Leave an unmatched file pattern empty instead of using it as a filename.
shopt -s nullglob

############
## FUNCTIONS
############

# Display the help section.
show_help() {
  cat << 'HELP'
Usage:
  file-to-dir-renamer.bash <root-directory>

Rename files in the root directory and its subdirectories using the name
of the directory they are in. Each file keeps its original extension.

One file of an extension:
  photo.jpg -> Vacation.jpg

Multiple files of an extension:
  photo.jpg -> Vacation-001.jpg
  other.jpg -> Vacation-002.jpg

Hidden files and files without an extension are skipped.
Existing destination files are not overwritten.

Example:
  file-to-dir-renamer.bash '/path/to/files'
HELP
}

##################
## START OF SCRIPT
##################

# Read the root directory from the first argument.
root="$1"

# Show help if no directory was provided or help was requested.
if [ -z "$root" ]; then
  show_help
  exit 1
fi

if [ "$root" = "--help" ] || [ "$root" = "-h" ]; then
  show_help
  exit 0
fi

# Make sure the root directory exists.
if [ ! -d "$root" ]; then
  echo "Error: '$root' is not a directory"
  exit 1
fi

# Use a full path so changing directories does not break relative paths.
root="$(cd -- "$root" && pwd -P)" || exit 1

# Go through the root directory and all its subdirectories.
# Use null separators so spaces and newlines in directory names are handled.
find "$root" -type d -print0 | while IFS= read -r -d '' dir; do
  cd -- "$dir" || continue

  # Use the current directory name as the new filename.
  parent="$(basename -- "$dir")"

  # Count the files for each extension in this directory.
  declare -A ext_counts=()

  for f in *.*; do
    [ -f "$f" ] || continue
    ext="${f##*.}"
    [ -n "$ext" ] || continue
    ((ext_counts["$ext"]++))
  done

  # Rename each extension group separately.
  for ext in "${!ext_counts[@]}"; do
    count="${ext_counts[$ext]}"
    files=()

    # Keep directories out of the list of files to rename.
    for f in *."$ext"; do
      [ -f "$f" ] || continue
      files+=("$f")
    done

    if [ "$count" -eq 1 ]; then
      # One file gets the directory name without a number.
      src="${files[0]}"
      dest="${parent}.${ext}"

      if [ "$src" != "$dest" ]; then
        echo "Renaming: $src -> $dest"
        # Treat the destination as a filename, not a directory to move into.
        mv -nT -- "$src" "$dest"
      fi
    else
      # Multiple files get a three-digit number starting at 001.
      i=1
      for src in "${files[@]}"; do
        printf -v num "%03d" "$i"
        dest="${parent}-${num}.${ext}"

        echo "Renaming: $src -> $dest"
        # Treat the destination as a filename, not a directory to move into.
        mv -nT -- "$src" "$dest"
        ((i++))
      done
    fi
  done
done
