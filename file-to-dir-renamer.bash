#!/bin/bash
shopt -s nullglob

root="$1"

if [ -z "$root" ]; then
  echo "Usage: $0 <root-directory>"
  exit 1
fi

if [ ! -d "$root" ]; then
  echo "Error: '$root' is not a directory"
  exit 1
fi

find "$root" -type d | while IFS= read -r dir; do
  cd "$dir" || continue

  parent="$(basename "$dir")"

  # Build list of extensions in this directory
  declare -A ext_counts=()

  for f in *.*; do
    [ -f "$f" ] || continue
    ext="${f##*.}"
    ((ext_counts["$ext"]++))
  done

  # Process each extension group
  for ext in "${!ext_counts[@]}"; do
    count="${ext_counts[$ext]}"
    files=( *."$ext" )

    if [ "$count" -eq 1 ]; then
      src="${files[0]}"
      dest="${parent}.${ext}"

      if [ "$src" != "$dest" ]; then
        echo "Renaming: $src -> $dest"
        mv -n -- "$src" "$dest"
      fi
    else
      i=1
      for src in "${files[@]}"; do
        printf -v num "%03d" "$i"
        dest="${parent}-${num}.${ext}"

        echo "Renaming: $src -> $dest"
        mv -n -- "$src" "$dest"
        ((i++))
      done
    fi
  done

done
