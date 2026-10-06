#!/bin/bash

# Fix directory and file permissions under a root directory.
# Optionally change the owner and group as well.
# Uses GNU/Linux commands.

#######################
## ALL THE BORING STUFF
#######################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Dependency check.
dependencies=("cat" "realpath" "getent" "mktemp" "find" "stat" "chown" "chmod" "rm")
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

# Stop on unset variables and report failures in pipelines.
set -u
set -o pipefail

# Default ownership and permissions.
owner=''
group=''
dir_mode=775
file_mode=664

# Directory, exclusions, and dry-run settings.
target=''
excludes=()
dry_run=0

#######################
## FUNCTIONS
#######################

# Display the help section.
usage() {
  cat << 'HELP'
Usage:
  perms-fixer.sh DIRECTORY [OPTIONS]

Options:
  --owner USER       Set owner; omitted means preserve existing owners
  --group GROUP      Set group; omitted means preserve existing groups
  --dir-mode MODE    Octal directory mode (default: 775)
  --file-mode MODE   Octal file mode (default: 664; removes executable bits)
  --exclude PATH     Skip relative subtree or absolute path; repeatable
  --dry-run          Preview without changing anything
  -h, --help         Show help

Examples:
  sudo perms-fixer.sh /mnt/plex --owner plex --group plex
  sudo perms-fixer.sh /mnt/thevault --owner pmusselman --group pmusselman
  perms-fixer.sh . --exclude .git --dry-run

Includes the target directory. Symlinks and special files are skipped.
Exclusions are literal paths relative to DIRECTORY, not glob patterns.
Run with sudo when necessary; the script never invokes sudo itself.
HELP
}

# Display an error and stop the script.
die() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
}

#######################
## START OF SCRIPT
#######################

# Read the directory and options from the command line.
while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --owner|--group|--dir-mode|--file-mode|--exclude)
      if (($# < 2)); then
        die "$1 requires a value"
      fi
      if [[ -z $2 ]]; then
        die "$1 requires a nonempty value"
      fi

      case "$1" in
        --owner)
          owner=$2
          ;;
        --group)
          group=$2
          ;;
        --dir-mode)
          dir_mode=$2
          ;;
        --file-mode)
          file_mode=$2
          ;;
        --exclude)
          excludes+=("$2")
          ;;
      esac
      shift 2
      ;;
    --)
      shift
      if (($# != 1)) || [[ -n $target ]]; then
        die 'Expected one directory after --'
      fi
      target=$1
      shift
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      if [[ -n $target ]]; then
        die 'Specify only one directory'
      fi
      target=$1
      shift
      ;;
  esac
done

# Show help if no directory was provided.
if [[ -z $target ]]; then
  usage >&2
  exit 2
fi

# Make sure the requested permissions are valid octal modes.
for mode in "$dir_mode" "$file_mode"; do
  if [[ ! $mode =~ ^[0-7]{3,4}$ ]]; then
    die "Invalid octal mode: $mode"
  fi
done

# Check the target directory before making any changes.
if [[ -L $target ]]; then
  die 'Target must not be a symlink'
fi
if [[ ! -d $target ]]; then
  die "Not a directory: $target"
fi

target=$(realpath -e -- "$target") || die 'Cannot resolve directory'

if [[ $target == / ]]; then
  die 'Refusing to operate on the filesystem root'
fi

# Look up the requested owner and group IDs.
# Empty values mean keep the current owner or group.
uid=''
gid=''

if [[ -n $owner ]]; then
  entry=$(getent passwd "$owner") || die "Unknown owner: $owner"
  IFS=: read -r _ _ uid _ <<< "$entry"
fi

if [[ -n $group ]]; then
  entry=$(getent group "$group") || die "Unknown group: $group"
  IFS=: read -r _ _ gid _ <<< "$entry"
fi

# Resolve each exclusion to a full path beneath the target directory.
excluded_paths=()
for path in "${excludes[@]}"; do
  if [[ $path != /* ]]; then
    path="$target/$path"
  fi
  path=$(realpath -ms -- "$path") || die 'Cannot resolve exclusion'
  if [[ $path != "$target/"* ]]; then
    die "Exclusion must be beneath target: $path"
  fi
  excluded_paths+=("$path")
done

# Build the directory search and skip excluded paths.
find_args=("$target")
if ((${#excluded_paths[@]})); then
  find_args+=( '(' )
  first=1

  for path in "${excluded_paths[@]}"; do
    # Escape wildcard characters so exclusions match literal path names.
    pattern=${path//\\/\\\\}
    pattern=${pattern//\*/\\*}
    pattern=${pattern//\?/\\?}
    pattern=${pattern//\[/\\[}

    if ((! first)); then
      find_args+=( -o )
    fi
    first=0
    find_args+=( -path "$pattern" )
  done

  find_args+=( ')' -prune -o )
fi
find_args+=( '(' -type d -o -type f ')' -print0 )

# Finish the directory search before changing permissions.
# Stop if the search fails, and remove the temporary list when finished.
listing=$(mktemp) || die 'Cannot create temporary listing'
trap 'rm -f -- "$listing"' EXIT
find "${find_args[@]}" > "$listing" || die 'Directory traversal failed; no changes applied'

# Keep track of the results.
scanned=0
changed=0
unchanged=0
failed=0

# Process each directory and regular file from the list.
while IFS= read -r -d '' path; do
  ((scanned+=1))

  # Recheck the entry in case its type changed after the search.
  if [[ -L $path || (! -f $path && ! -d $path) ]]; then
    printf 'Skipped changed entry: %q\n' "$path" >&2
    ((failed+=1))
    continue
  fi

  # Read the current permissions, owner, and group.
  if ! metadata=$(stat -c '%a %u %g' -- "$path"); then
    ((failed+=1))
    continue
  fi
  read -r current_mode current_uid current_gid <<< "$metadata"

  # Use the appropriate permissions for directories and files.
  if [[ -d $path ]]; then
    desired=$dir_mode
  else
    desired=$file_mode
  fi

  # Check whether the owner or group needs to change.
  needs_owner=0
  if [[ -n $uid && $uid != "$current_uid" ]]; then
    needs_owner=1
  fi
  if [[ -n $gid && $gid != "$current_gid" ]]; then
    needs_owner=1
  fi

  # Skip entries that already have the requested ownership and permissions.
  if (( ! needs_owner && 8#$current_mode == 8#$desired )); then
    ((unchanged+=1))
    continue
  fi

  # Show the proposed changes without applying them during a dry run.
  if ((dry_run)); then
    printf 'Would fix: %q (mode %s -> %s, owner %s -> %s, group %s -> %s)\n' \
      "$path" "$current_mode" "$desired" "$current_uid" "${uid:-$current_uid}" "$current_gid" "${gid:-$current_gid}"
    ((changed+=1))
    continue
  fi

  # Change ownership if an owner or group was provided and needs updating.
  ok=1
  if ((needs_owner)); then
    ownership=${uid:-$current_uid}:${gid:-$current_gid}
    chown --no-dereference -- "$ownership" "$path" || ok=0
  fi

  # Apply permissions after ownership, which can clear special mode bits.
  if ((ok)); then
    chmod -- "$desired" "$path" || ok=0
  fi

  # Record whether the changes succeeded.
  if ((ok)); then
    printf 'Fixed: %q\n' "$path"
    ((changed+=1))
  else
    ((failed+=1))
  fi
done < "$listing"

# Display the final results.
if ((dry_run)); then
  label='Would change'
else
  label='Changed'
fi

printf 'Scanned: %d | %s: %d | Unchanged: %d | Failed: %d\n' "$scanned" "$label" "$changed" "$unchanged" "$failed"

# Return a failure status if any entry could not be fixed.
((failed == 0))
