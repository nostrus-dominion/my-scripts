#!/bin/bash

## Version 3.0
## License: Open Source GPL
## Copyright: (c) 2023

#######################
## ALL THE BORING STUFF
#######################

# Stop the script if a command fails or a variable is missing
set -euo pipefail

# Use the same locale and timestamps for every scan
export LC_ALL=C
export TZ=UTC0
umask 077

# Check the Bash version.
if ! ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
  show_error 'Bash 4.4 or newer is required.'
fi

if ! (($#)); then
  interactive=1
fi

# Global Variables for ANSI color
orange=""
red=""
reset=""
color_file="${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf"
if [[ -r $color_file ]]; then
  # shellcheck source=/dev/null
  if ! source "$color_file"; then
    show_error 'Could not load the color configuration.'
  fi
fi

# Dependency check
dependencies=("sqlite3" "find" "md5sum" "nproc" "stat" "cmp" "mktemp" "cat" "rm" "mkdir" "realpath" "flock" "date" "chmod")
if [[ -z $delete_report ]]; then
  dependencies+=(parallel)
fi
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

# Variables for the directory, report, and database
directory=""
num_threads=""
report_path=""
delete_report=""
root_key=""
db_path="${XDG_CACHE_HOME:-$HOME/.cache}/de-duper/hashes.sqlite3"
delete_requested=0
dry_run=0
rehash=0
interactive=0

#######################
## FUNCTIONS
#######################

# Function to display an error and exit the script
show_error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Function to validate if the provided path is a directory
validate_directory() {
  local dir=$1

  if [[ ! -d "$dir" ]]; then
    show_error "Not a directory: $dir"
  fi
}

# Function to get the number of threads for parallel processing
get_num_threads() {
  local available_threads

  if ! available_threads=$(nproc); then
    show_error 'Could not determine the available CPU threads.'
  fi
  if [[ -z $num_threads ]]; then
    if ((interactive)); then
      echo ""
      echo -e "Number of available threads on this system: ${red}$available_threads${reset}"
      echo ""
      if ! read -rp "Enter the number of threads for parallel processing (default is 1, maximum is $available_threads): " num_threads; then
        show_error 'Canceled.'
      fi
    fi
    num_threads=${num_threads:-1}
  fi
  if ! [[ $num_threads =~ ^[1-9][0-9]*$ ]] || ! ((${#num_threads} <= ${#available_threads} && num_threads <= available_threads)); then
    if ((interactive)); then
      echo -e "Invalid input. Using default value (1 thread). ${red}You go slow because you were being cute.${reset}"
      num_threads=1
    else
      show_error "Threads must be between 1 and $available_threads."
    fi
  fi
  echo "Selected number of threads: $num_threads"
}

# Function to display the help menu
usage() {
  cat << 'HELP'
Usage:
  de-duper [directory] [--threads N] [--db FILE] [--rehash]
  de-duper [directory] --report FILE [--threads N] [--db FILE] [--rehash]
  de-duper [directory] --delete [--report FILE] [--threads N] [--db FILE]
  de-duper --delete-report FILE [--dry-run] [--db FILE]

With no arguments, use the original directory/thread/menu prompts.
  --report FILE       Save a KEEP/REMOVE report; no deletion unless --delete.
  --delete            Scan, save the report, then ask you to type DELETE.
  --delete-report FILE
                      Delete unique REMOVE entries from a previous report.
                      Each entry requires a KEEP in the same duplicate group.
                      Original and directory-regrouped reports both work.
  --dry-run           Show the proposed removals without deleting anything.
  --db FILE           SQLite hash cache; default:
                      ${XDG_CACHE_HOME:-$HOME/.cache}/de-duper/hashes.sqlite3
  --rehash            Ignore cached hashes for this scan.
  --threads N         GNU Parallel jobs; default 1 when not interactive.

Only same-size candidates are hashed. Unchanged candidates reuse their MD5.
Every deletion is verified byte for byte with cmp, even when hashes are cached.
The oldest modification time is kept (path order breaks ties).
Symlinks and hard-linked files are excluded. Existing reports are not overwritten.
Requires Bash 4.4+, sqlite3, GNU Parallel, GNU find and GNU coreutils.
HELP
}

# Function to get the full path without losing special characters
absolute_path() {
  local resolved_path
  if ! IFS= read -r -d '' resolved_path < <(realpath --canonicalize-missing --zero -- "$1"); then
    return 1
  fi
  printf -v "$2" '%s' "$resolved_path"
}

# Function to quote file paths for the SQLite database
sql_key() {
  local encoded_key
  printf -v encoded_key '%q' "$1"
  encoded_key=${encoded_key//\'/\'\'}
  printf -v "$2" '%s' "$encoded_key"
}

# Function to run SQLite commands
db() {
  sqlite3 -init /dev/null -batch -bail "$db_path" "$@"
}

# Function to check the file details before hashing or deleting
file_stamp() {
  local details device inode bytes modified changed permissions links
  if ! [[ -f $1 && ! -L $1 ]]; then
    return 1
  fi
  if ! details=$(stat --printf='%d|%i|%s|%y|%z|%a|%h' -- "$1"); then
    return 1
  fi
  IFS='|' read -r device inode bytes modified changed permissions links <<<"$details"
  if ! [[ $links == 1 && ! -L $1 ]]; then
    return 1
  fi
  modified=${modified% +0000}
  changed=${changed% +0000}
  printf '%s:%s:%s:%s:%s:%s:%s' "$device" "$inode" "$bytes" "$modified" "$changed" "$permissions" "$links"
}

# Function to check if a file has changed
unchanged() {
  local current_stamp
  if ! current_stamp=$(file_stamp "$1"); then
    return 1
  fi
  [[ $current_stamp == "$2" ]]
}

# Function to get the MD5 hash for one file
hash_one() {
  local id=$1
  local expected=$2
  local path=$3
  local output checksum
  if ! unchanged "$path" "$expected"; then
    printf 'File changed before hashing: %q\n' "$path" >&2
    return 1
  fi
  if ! output=$(md5sum <"$path"); then
    printf 'Could not hash: %q\n' "$path" >&2
    return 1
  fi
  checksum=${output%% *}
  if ! [[ $checksum =~ ^[0-9a-f]{32}$ ]]; then
    return 1
  fi
  if ! unchanged "$path" "$expected"; then
    printf 'File changed during hashing: %q\n' "$path" >&2
    return 1
  fi
  printf '%s|%s\n' "$id" "$checksum"
}

# Function to read the quoted file paths from a saved report
decode_path() {
  local encoded=$1
  local decoded=""
  local position=0
  local inner char escape digits byte length
  if [[ $encoded == \$\'*\' ]]; then
    inner=${encoded:2:${#encoded}-3}
    length=${#inner}
    while ((position < length)); do
      char=${inner:position:1}
      position=$((position + 1))
      if [[ $char != \\ ]]; then
        decoded+=$char
        continue
      fi
      if ! ((position < length)); then
        show_error 'Incomplete escape in a report path.'
      fi
      escape=${inner:position:1}
      position=$((position + 1))
      case $escape in
        \\ | \')
          decoded+=$escape
          ;;
        a)
          decoded+=$'\a'
          ;;
        b)
          decoded+=$'\b'
          ;;
        e | E)
          decoded+=$'\e'
          ;;
        f)
          decoded+=$'\f'
          ;;
        n)
          decoded+=$'\n'
          ;;
        r)
          decoded+=$'\r'
          ;;
        t)
          decoded+=$'\t'
          ;;
        v)
          decoded+=$'\v'
          ;;
        [0-7])

          digits=$escape
          while ((${#digits} < 3 && position < length)) && [[ ${inner:position:1} == [0-7] ]]; do
            digits+=${inner:position:1}
            position=$((position + 1))
          done
          if ! ((8#$digits > 0 && 8#$digits <= 255)); then
            show_error 'Invalid byte in a report path.'
          fi
          printf -v byte '%b' "\\$digits"
          decoded+=$byte
          ;;
        x)

          digits=
          while ((${#digits} < 2 && position < length)) && [[ ${inner:position:1} == [0-9a-fA-F] ]]; do
            digits+=${inner:position:1}
            position=$((position + 1))
          done
          if [[ -z $digits ]] || ! ((16#$digits > 0)); then
            show_error 'Invalid hex escape in a report path.'
          fi
          printf -v byte '%b' "\\x$digits"
          decoded+=$byte
          ;;
        *)
          show_error "Unsupported escape in report path: \\$escape"
          ;;
      esac
    done
  else
    inner=$encoded
    length=${#inner}
    while ((position < length)); do
      char=${inner:position:1}
      position=$((position + 1))
      if [[ $char == \\ ]]; then
        if ! ((position < length)); then
          show_error 'Incomplete escape in a report path.'
        fi
        char=${inner:position:1}
        position=$((position + 1))
      fi
      decoded+=$char
    done
  fi
  if ! [[ $decoded == /* ]]; then
    show_error 'Report paths must be absolute.'
  fi
  printf -v "$2" '%s' "$decoded"
}

# Function to load the KEEP and REMOVE entries from a saved report
load_report() {
  local line label encoded path current_group="" group_index index key
  local -A group_indexes=() seen_removals=() keep_paths=()
  if ! [[ -f $delete_report && -r $delete_report ]]; then
    show_error 'Could not read the duplicate report.'
  fi
  if ! absolute_path "$delete_report" delete_report; then
    show_error 'Could not resolve the report path.'
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    if [[ $line =~ ^[[:space:]]*Group[[:space:]]+([0-9]+):[[:space:]]+MD5[[:space:]]+([0-9a-fA-F]{32})[[:space:]]*$ ]]; then
      current_group=g${BASH_REMATCH[1]}
      if [[ -z ${group_indexes[$current_group]+yes} ]]; then
        group_indexes[$current_group]=${#keepers[@]}
        keepers+=("")
        keeper_stamps+=("")
      fi
    elif [[ $line =~ ^[[:space:]]*(KEEP|REMOVE)[[:space:]]+(.+)$ ]]; then
      label=${BASH_REMATCH[1]}
      encoded=${BASH_REMATCH[2]}
      # Skip explanatory headers such as REMOVE = proposed removal only.
      case $encoded in /* | \$\'/*) ;; *)
        continue
        ;;
      esac
      if [[ -z $current_group ]]; then
        show_error 'A KEEP/REMOVE entry has no duplicate group.'
      fi
      decode_path "$encoded" path
      # Use one quoting form for de-duplication. file_stamp and the deletion
      # preflight reject links and aliases of any retained file.
      printf -v key '%q' "$path"
      group_index=${group_indexes[$current_group]}
      if [[ $label == KEEP ]]; then
        if [[ -n ${keepers[group_index]} || ${keepers[group_index]} == "$path" ]]; then
          show_error 'A duplicate group has conflicting KEEP entries.'
        fi
        keepers[group_index]=$path
        keep_paths[$key]=1
      elif [[ -n ${seen_removals[$key]+yes} ]]; then
        index=${seen_removals[$key]}
        if ! [[ ${removal_groups[index]} == "$group_index" ]]; then
          show_error 'One REMOVE path belongs to conflicting groups.'
        fi
      else
        seen_removals[$key]=${#removals[@]}
        removals+=("$path")
        removal_stamps+=("")
        removal_groups+=("$group_index")
      fi
    fi
  done <"$delete_report"
  for index in "${!removals[@]}"; do
    group_index=${removal_groups[index]}
    if [[ -z ${keepers[group_index]} ]]; then
      show_error 'A REMOVE entry has no KEEP in its group.'
    fi
    printf -v key '%q' "${removals[index]}"
    if [[ -n ${keep_paths[$key]+yes} ]]; then
      show_error 'The report marks one path as both KEEP and REMOVE.'
    fi
    if ! [[ ${removals[index]} != "$delete_report" && ${removals[index]} != "$db_path" &&
      ${removals[index]} != "$db_path.lock" ]]; then
      show_error 'The report would remove a control file.'
    fi
  done
}

# Function to verify and delete the duplicate files
delete_plan() {
  local answer index keeper_index removed=0 key signature identity rest
  local -A used_keepers=() keep_identities=() remove_identities=()
  if ! ((${#removals[@]})); then
    echo "No REMOVE paths found."
    return 0
  fi
  printf 'Unique paths proposed for removal: %d\n' "${#removals[@]}"
  if ((dry_run)); then
    printf 'REMOVE %q\n' "${removals[@]}"
    echo "Dry run complete. No files were deleted."
    return 0
  fi
  if ! read -rp "Type DELETE to verify and remove ${#removals[@]} extra copies: " answer; then
    answer=
  fi
  if ! [[ $answer == DELETE ]]; then
    echo "Canceled. No files were deleted."
    return 0
  fi
  echo "Verifying every KEEP/REMOVE pair before deleting the first file..."
  for index in "${!removals[@]}"; do
    used_keepers[${removal_groups[index]}]=1
  done
  for keeper_index in "${!used_keepers[@]}"; do
    if [[ -z ${keeper_stamps[keeper_index]} ]]; then
      if ! keeper_stamps[keeper_index]=$(file_stamp "${keepers[keeper_index]}"); then
        show_error "KEEP is missing, linked, or unreadable: ${keepers[keeper_index]}. No files were deleted."
      fi
    fi
    if ! unchanged "${keepers[keeper_index]}" "${keeper_stamps[keeper_index]}"; then
      show_error 'A KEEP file changed since the scan/review. No files were deleted.'
    fi
    signature=${keeper_stamps[keeper_index]}
    rest=${signature#*:}
    identity=d${signature%%:*}i${rest%%:*}
    keep_identities[$identity]=1
  done
  # Preflight the whole plan. A stale/missing/mismatched pair prevents deletion.
  for index in "${!removals[@]}"; do
    keeper_index=${removal_groups[index]}
    if [[ -z ${removal_stamps[index]} ]]; then
      if ! removal_stamps[index]=$(file_stamp "${removals[index]}"); then
        show_error "REMOVE is missing, linked, or unreadable: ${removals[index]}. No files were deleted."
      fi
    fi
    signature=${removal_stamps[index]}
    rest=${signature#*:}
    identity=d${signature%%:*}i${rest%%:*}
    if [[ -n ${keep_identities[$identity]+yes} ]]; then
      show_error 'A REMOVE path aliases a KEEP file. No files were deleted.'
    fi
    if [[ -n ${remove_identities[$identity]+yes} ]]; then
      show_error 'Multiple REMOVE paths alias one file. No files were deleted.'
    fi
    remove_identities[$identity]=1
    if ! [[ ! ${removals[index]} -ef $db_path && ! ${removals[index]} -ef $db_path.lock ]]; then
      show_error 'A REMOVE path aliases a cache control file. No files were deleted.'
    fi
    if ! unchanged "${keepers[keeper_index]}" "${keeper_stamps[keeper_index]}" || ! unchanged "${removals[index]}" "${removal_stamps[index]}"; then
      show_error 'A file changed since the scan/review. No files were deleted.'
    fi
    if ! cmp --silent -- "${keepers[keeper_index]}" "${removals[index]}"; then
      show_error "Contents differ or cannot be read: ${removals[index]}. No files were deleted."
    fi
    if ! unchanged "${keepers[keeper_index]}" "${keeper_stamps[keeper_index]}" || ! unchanged "${removals[index]}" "${removal_stamps[index]}"; then
      show_error 'A file changed during verification. No files were deleted.'
    fi
  done
  printf 'BEGIN IMMEDIATE;\n' >"$workdir/deleted.sql"
  for index in "${!removals[@]}"; do
    keeper_index=${removal_groups[index]}
    if ! unchanged "${keepers[keeper_index]}" "${keeper_stamps[keeper_index]}" || ! unchanged "${removals[index]}" "${removal_stamps[index]}"; then
      show_error "A file changed; deletion stopped after removing $removed files."
    fi
    if ! rm -- "${removals[index]}"; then
      show_error "Deletion stopped after removing $removed files."
    fi
    removed=$((removed + 1))
    sql_key "${removals[index]}" key
    printf "DELETE FROM hash_cache WHERE path_key='%s';\n" "$key" >>"$workdir/deleted.sql"
    printf 'Deleted: %q\n' "${removals[index]}"
  done
  printf 'COMMIT;\n' >>"$workdir/deleted.sql"
  if ! db <"$workdir/deleted.sql"; then
    show_error "Deleted $removed files, but could not update the cache."
  fi
  printf '\n%bDeleted %d extra copies.%b KEEP files were preserved.\n' "$red" "$removed" "$reset"
}

# Function to save the duplicate results to a text file
save_report() {
  local destination=${report_path:-"$HOME/duplicate-files-$(date +%Y%m%d%H%M%S)-$$.txt"}
  if ! (
    set -o noclobber
    cat -- "$workdir/report.txt" >"$destination"
  ); then
    show_error "Could not save the report: $destination"
  fi
  printf 'Duplicate results saved to: %q\n' "$destination"
}

#######################
## BEGINNING OF SCRIPT
#######################

# Read the command line options.
while (($#)); do
  case "$1" in
    --threads | --report | --db | --delete-report)

      if ! (($# >= 2)) || [[ -z $2 ]]; then
        show_error "$1 requires a value."
      fi
      case "$1" in
        --threads)
          num_threads=$2
          ;;
        --report)
          report_path=$2
          ;;
        --db)
          db_path=$2
          ;;
        --delete-report)
          delete_report=$2
          ;;
      esac
      shift 2
      ;;
    --delete)

      delete_requested=1
      shift
      ;;
    --dry-run)

      dry_run=1
      shift
      ;;
    --rehash)

      rehash=1
      shift
      ;;
    --help | -h)

      usage
      exit 0
      ;;
    --)

      shift
      if ! (($# == 1)); then
        show_error 'Supply one directory after --.'
      fi
      if [[ -n $directory ]]; then
        show_error 'Supply only one directory.'
      fi
      directory=$1
      shift
      ;;
    -*)
      show_error "Unknown option: $1"
      ;;
    *)
      if [[ -n $directory ]]; then
        show_error 'Supply only one directory.'
      fi
      directory=$1
      shift
      ;;
  esac
done
if [[ -n $delete_report ]]; then
  if [[ -n $directory && -z $report_path && -z $num_threads ]] || ! ((delete_requested == 0 && rehash == 0)); then
    show_error '--delete-report cannot be combined with scan options.'
  fi
fi

# Set up the hash database and temporary files.
if ! absolute_path "$db_path" db_path; then
  show_error 'Could not resolve the cache path.'
fi
if ! mkdir -p -- "${db_path%/*}"; then
  show_error 'Could not create the cache directory.'
fi
if [[ -d $db_path ]]; then
  show_error 'The cache path is a directory.'
fi
if ! exec {cache_lock_fd}>"$db_path.lock"; then
  show_error 'Could not open the cache lock.'
fi
if ! flock --nonblock "$cache_lock_fd"; then
  show_error 'Another de-duper run is using this database.'
fi
if ! workdir=$(mktemp -d -- "${TMPDIR:-/tmp}/de-duper.XXXXXXXX"); then
  show_error 'Could not create temporary files.'
fi
trap 'rm -rf -- "$workdir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! app_id=$(db 'PRAGMA application_id;'); then
  show_error 'Could not read the SQLite database.'
fi
if ! schema_version=$(db 'PRAGMA user_version;'); then
  show_error 'Could not read the cache version.'
fi
if [[ $app_id == 0 ]]; then
  if ! table_count=$(db "SELECT COUNT(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%';"); then
    show_error 'Could not inspect the database.'
  fi
  if ! [[ $table_count == 0 ]]; then
    show_error 'This is an existing unrelated SQLite database. Choose another --db.'
  fi
elif [[ $app_id != 1396982835 || $schema_version != 1 ]]; then
  show_error 'The database is not a supported de-duper cache. Choose another --db.'
fi
if ! db <<'SQL' >/dev/null; then
.timeout 10000
BEGIN IMMEDIATE;
PRAGMA application_id=1396982835;
PRAGMA user_version=1;
CREATE TABLE IF NOT EXISTS hash_cache (
  root_key TEXT NOT NULL,
  path_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  md5 TEXT NOT NULL CHECK(length(md5)=32 AND md5 NOT GLOB '*[^0-9a-f]*'),
  PRIMARY KEY(root_key,path_key)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS scan_files (
  id INTEGER PRIMARY KEY,
  path_key TEXT UNIQUE NOT NULL,
  size INTEGER NOT NULL,
  mtime TEXT NOT NULL,
  signature TEXT NOT NULL,
  md5 TEXT
);
CREATE INDEX IF NOT EXISTS scan_files_size ON scan_files(size);
COMMIT;
SQL
  show_error 'Could not initialize the SQLite cache.'
fi
if ! chmod 600 -- "$db_path"; then
  show_error 'Could not set cache permissions.'
fi

export -f hash_one file_stamp unchanged
PARALLEL_SHELL=$(command -v bash)
export PARALLEL_SHELL

keepers=()
keeper_stamps=()
removals=()
removal_stamps=()
removal_groups=()

if [[ -n $delete_report ]]; then
  load_report
  printf 'Report: %q\n' "$delete_report"
  delete_plan
  exit 0
fi

# Script splash
echo -e "${orange}"
cat << 'SPLASH'
                                          WELCOME TO THE

                    ██████╗ ███████╗    ██████╗ ██╗   ██╗██████╗ ███████╗██████╗
                    ██╔══██╗██╔════╝    ██╔══██╗██║   ██║██╔══██╗██╔════╝██╔══██╗
                    ██║  ██║█████╗█████╗██║  ██║██║   ██║██████╔╝█████╗  ██████╔╝
                    ██║  ██║██╔══╝╚════╝██║  ██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗
                    ██████╔╝███████╗    ██████╔╝╚██████╔╝██║     ███████╗██║  ██║
                    ╚═════╝ ╚══════╝    ╚═════╝  ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝

              Find duplicate files with an SQLite hash cache, report, and verified deletion.
SPLASH
echo -e "${reset}"

# Ask the user if they want to use the current directory.
if [[ -z $directory ]]; then
  echo "$PWD"
  if ! read -rp 'Do you want to use the current directory to check for duplicate files? ([Y]es, [N]o, [Q]uit): ' choice; then
    show_error 'Canceled.'
  fi
  case "${choice,,}" in
    y | yes | '')
      directory=$PWD
      ;;
    n | no)
      if ! read -rp 'Enter the directory path to search for duplicate files: ' directory; then
        show_error 'Canceled.'
      fi
      ;;
    q | quit)
      echo "Exiting script. Goodbye!"
      exit 0
      ;;
    *)
      show_error 'Invalid choice.'
      ;;
  esac
fi
validate_directory "$directory"
if ! absolute_path "$directory" directory; then
  show_error 'Could not resolve the directory.'
fi
if [[ -n $report_path ]]; then
  if ! absolute_path "$report_path" report_path; then
    show_error 'Could not resolve the report path.'
  fi
  if [[ -e $report_path || -L $report_path ]]; then
    show_error 'The report already exists. Choose another filename.'
  fi
  if ! [[ $report_path != "$db_path" && $report_path != "$db_path.lock" ]]; then
    show_error 'The report path is a cache control file.'
  fi
fi
# Call the function to get the number of threads.
get_num_threads

sql_key "$directory" root_key

#######################
## WHERE THE PARTY STARTS
#######################

printf 'Scanning directory metadata: %q\nCache: %q\n' "$directory" "$db_path"
# Get the file details from the directory and all subdirectories
if ! find "$directory" -type f -links 1 \
  -printf '%D\t%i\t%s\t%TY-%Tm-%Td %TH:%TM:%TS\t%CY-%Cm-%Cd %CH:%CM:%CS\t%m\t%n\t%p\0' \
  >"$workdir/metadata.nul"; then
  show_error 'The directory scan failed. No files were deleted.'
fi
paths=()
stamps=()
file_sizes=()
num_files=0
{
  printf 'BEGIN IMMEDIATE;\nDELETE FROM scan_files;\n'
  while IFS= read -r -d '' record; do
    fields=()
    for ((field_index = 0; field_index < 7; field_index++)); do
      if ! [[ $record == *$'\t'* ]]; then
        show_error 'Unexpected find metadata.'
      fi
      fields+=("${record%%$'\t'*}")
      record=${record#*$'\t'}
    done
    path=$record
    # Control files and temporary files must never become duplicate candidates.
    case $path in
      "$db_path" | "$db_path.lock" | "$db_path-journal" | "$db_path-wal" | "$db_path-shm" | "$report_path")
        continue
        ;;
    esac
    if ! [[ $path != "$workdir/"* ]]; then
      continue
    fi
    modified=${fields[3]}
    changed=${fields[4]}
    # find emits ten decimal places; GNU stat emits nine. Normalize once.
    modified=${modified%?}
    changed=${changed%?}
    signature="${fields[0]}:${fields[1]}:${fields[2]}:$modified:$changed:${fields[5]}:${fields[6]}"
    sql_key "$path" key
    paths+=("$path")
    stamps+=("$signature")
    file_sizes+=("${fields[2]}")
    printf "INSERT INTO scan_files(id,path_key,size,mtime,signature) VALUES(%d,'%s',%s,'%s','%s');\n" \
      "$num_files" "$key" "${fields[2]}" "$modified" "$signature"
    num_files=$((num_files + 1))
  done <"$workdir/metadata.nul"
  if ((rehash == 0)); then
    printf "UPDATE scan_files SET md5=(SELECT md5 FROM hash_cache c WHERE c.root_key='%s' AND c.path_key=scan_files.path_key AND c.signature=scan_files.signature);\n" "$root_key"
  fi
  printf 'COMMIT;\n'
} >"$workdir/scan.sql"
if ! db <"$workdir/scan.sql"; then
  show_error 'Could not store scan metadata. No files were deleted.'
fi

# Skip files with unique sizes and reuse any unchanged hashes.
candidate_where='size IN (SELECT size FROM scan_files GROUP BY size HAVING COUNT(*)>1)'
if ! num_candidates=$(db "SELECT COUNT(*) FROM scan_files WHERE $candidate_where;"); then
  show_error 'Could not query candidate sizes.'
fi
if ! cached_count=$(db "SELECT COUNT(*) FROM scan_files WHERE $candidate_where AND md5 IS NOT NULL;"); then
  show_error 'Could not query cached hashes.'
fi
hash_count=$((num_candidates - cached_count))
printf 'Files scanned: %d\nUnique-size files skipped: %d\nCached hashes reused: %d\nFiles to hash: %d\n' \
  "$num_files" "$((num_files - num_candidates))" "$cached_count" "$hash_count"
if ! db "SELECT id,signature FROM scan_files WHERE $candidate_where AND md5 IS NULL ORDER BY id;" \
  >"$workdir/missing.txt"; then
  show_error 'Could not list files to hash.'
fi
while IFS='|' read -r id signature; do
  if ! [[ $id =~ ^[0-9]+$ ]]; then
    show_error 'Invalid cache file ID.'
  fi
  printf '%s\0%s\0%s\0' "$id" "$signature" "${paths[id]}"
done <"$workdir/missing.txt" >"$workdir/jobs.nul"
: >"$workdir/hashes.txt"
if ((hash_count)); then
  printf 'Hashing new or changed candidates with %s jobs...\n' "$num_threads"
  parallel_options=(--halt 'now,fail=1' --jobs "$num_threads" --null -N3)
  if [[ -t 2 ]]; then
    parallel_options+=(--eta)
  fi
  if ! parallel "${parallel_options[@]}" \
    'hash_one {1} {2} {3}' <"$workdir/jobs.nul" >"$workdir/hashes.txt"; then
    show_error 'Hashing failed. The scan is incomplete. No files were deleted.'
  fi
fi
{
  printf 'BEGIN IMMEDIATE;\n'
  result_count=0
  while IFS='|' read -r id checksum; do
    if ! [[ $id =~ ^[0-9]+$ && $checksum =~ ^[0-9a-f]{32}$ ]]; then
      show_error 'Unexpected hash result.'
    fi
    printf "UPDATE scan_files SET md5='%s' WHERE id=%s;\n" "$checksum" "$id"
    result_count=$((result_count + 1))
  done <"$workdir/hashes.txt"
  if ! ((result_count == hash_count)); then
    show_error 'Hashing did not return every result. No files were deleted.'
  fi
  # Prune missing/changed cache entries only inside this root's cache namespace.
  printf "DELETE FROM hash_cache WHERE root_key='%s' AND NOT EXISTS(SELECT 1 FROM scan_files s WHERE s.path_key=hash_cache.path_key AND s.signature=hash_cache.signature);\n" "$root_key"
  printf "INSERT OR REPLACE INTO hash_cache(root_key,path_key,signature,md5) SELECT '%s',path_key,signature,md5 FROM scan_files WHERE md5 IS NOT NULL;\n" "$root_key"
  printf 'COMMIT;\n'
} >"$workdir/hashes.sql"
if ! db <"$workdir/hashes.sql"; then
  show_error 'Could not update the cache. No files were deleted.'
fi
if ! unhashed=$(db "SELECT COUNT(*) FROM scan_files WHERE $candidate_where AND md5 IS NULL;"); then
  show_error 'Could not check scan completeness.'
fi
if ! [[ $unhashed == 0 ]]; then
  show_error 'Some candidate files have no hash. No files were deleted.'
fi

# Find the duplicate groups and keep the oldest file in each group.
if ! db 'SELECT s.id,s.md5 FROM scan_files s JOIN (SELECT md5,size FROM scan_files WHERE md5 IS NOT NULL GROUP BY md5,size HAVING COUNT(*)>1) d ON s.md5=d.md5 AND s.size=d.size ORDER BY s.md5,s.size,s.mtime,s.path_key;' \
  >"$workdir/duplicates.txt"; then
  show_error 'Could not query duplicate groups.'
fi
: >"$workdir/report-body.txt"
group_checksum=""
group_size=""
keeper_index=0
duplicate_files=0
extra_bytes=0
while IFS='|' read -r id checksum; do
  if [[ $checksum != "$group_checksum" || ${file_sizes[id]} != "$group_size" ]]; then
    group_checksum=$checksum
    group_size=${file_sizes[id]}
    keeper_index=${#keepers[@]}
    keepers+=("${paths[id]}")
    keeper_stamps+=("${stamps[id]}")
    printf '\nGroup %d: MD5 %s\nKEEP   %q\n' "$((keeper_index + 1))" "$checksum" "${paths[id]}" >>"$workdir/report-body.txt"
  else
    removals+=("${paths[id]}")
    removal_stamps+=("${stamps[id]}")
    removal_groups+=("$keeper_index")
    extra_bytes=$((extra_bytes + file_sizes[id]))
    printf 'REMOVE %q\n' "${paths[id]}" >>"$workdir/report-body.txt"
  fi
  duplicate_files=$((duplicate_files + 1))
done <"$workdir/duplicates.txt"
{
  printf 'SUPER-DE-DUPER 3.0\nDirectory: %q\nFiles scanned: %d\n' "$directory" "$num_files"
  printf 'Duplicate groups: %d\nFiles in duplicate groups: %d\nExtra copies: %d\nExtra logical bytes: %d\n' \
    "${#keepers[@]}" "$duplicate_files" "${#removals[@]}" "$extra_bytes"
  printf 'Cached hashes reused: %d\nFiles hashed this run: %d\n' "$cached_count" "$hash_count"
  printf 'KEEP = oldest modification time. REMOVE = proposed removal only.\n'
  printf 'Paths use Bash quoting. Groups are hash matches; deletion verifies all pairs byte for byte.\n'
  cat -- "$workdir/report-body.txt"
} >"$workdir/report.txt"

printf '\nDuplicate groups: %d\nExtra copies: %d\nExtra logical bytes: %d\n' \
  "${#keepers[@]}" "${#removals[@]}" "$extra_bytes"
if ((delete_requested)); then
  save_report
  delete_plan
elif [[ -n $report_path ]]; then
  save_report
elif ((dry_run)); then
  delete_plan
elif ((${#removals[@]} == 0)); then
  echo "No duplicate files found in the completed scan."
else
  while true; do
    echo ""
    echo "Would you like to..."
    echo "   a) Save a KEEP/REMOVE report"
    echo "   b) Save a report and delete duplicate files"
    echo "   q) Quit"
    if ! read -rp 'Enter your choice (a/b/q): ' user_choice; then
      show_error 'Canceled.'
    fi
    case "${user_choice,,}" in
      a)
        save_report
        break
        ;;
      b)
        save_report
        delete_plan
        break
        ;;
      q | quit)
        echo "Exiting without deleting files."
        break
        ;;
      *)
        echo "Invalid choice. Enter a, b, or q."
        ;;
    esac
  done
fi
