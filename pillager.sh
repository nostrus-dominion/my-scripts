#!/bin/bash

## Version 2.0
## License: Open Source GPL
## Copyright: (c) 2023

#######################
## ALL THE BORING STUFF
#######################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Dependency check
dependencies=("tput" "wget" "mkdir")
size_requested=0
# getopts in a subshell preserves the main parser's OPTIND and supports combined flags.
if (while getopts 'ishmd:l:' dependency_option; do
      [[ $dependency_option != s ]] || exit 0
    done; exit 1); then
  dependencies+=(sleep grep awk rm)
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

############
## FUNCTIONS
############

# Function to initialize script variables
initialize() {
  [[ -d $HOME/.pillager ]] || mkdir "$HOME/.pillager"
  savepath="$HOME/Pillager/"
  list=$HOME/.pillager/list
  index="--reject index.html,index.html*"
  flags="-r -np -nc "
  log="/tmp/website-size-log"
}

# Function to display help message
show_help() {
  cat << 'HELP'
  Oh you need help?
  By default, pillager will download all files
  recursively from a given link, avoiding index.html files,
  to the current working directory. A list of pillaged
  links is saved to ~/.pillager/list.
  If no link is provided when called, you'll be prompted for a link.
  
  OPTIONS
  -d [PATH]: Change download directory
  -h:        Show this message
  -i:        Include index.html files
  -l [LINK]: Link to pillage
  -m:        Mirror site
  -s:        Estimate link size
HELP
}

# Function to parse command-line options
parse_options() {
  while getopts 'ishmd:l:' flag; do
    case "${flag}" in
      i) index=" " ;;
      h) show_help ;;
      d) savepath="${OPTARG}" ;;
      m)
        flags="-mkEpnp "
        index=" "
        ;;
      l)
        lflag=1
        link="${OPTARG}"
        ;;
      s) sflag=1 ;;
      *) show_help ;;
    esac
  done
}

# Function to prompt user for link if not provided
get_link() {
  if [ -z "$link" ]; then
    echo -n "Link to pillage: "
    read -r link
  fi
}

# Function to estimate website size
estimate_size() {
  echo "Crawling site..."
  wget -rSnd -np -l inf --spider -o "$log" "${link}"
  echo "Finished crawling."
  sleep 1s
  echo "Estimated size: $(
    grep -e "Content-Length" "$log" |
      awk '{sum+=$2} END {printf("%.0f", sum / 1024 / 1024)}'
  ) Mb"
  rm "$log"
}

# Function to download files
download_files() {
  echo "$link" >> "$list"
  echo "Downloading files..."
  wget $flags -e robots=off -c $index "${link}" -P "$savepath" /dev/null 2>&1
}

# Main function
main() {
  initialize         # Initialize script variables
  parse_options "$@" # Parse command-line options
  get_link           # Prompt user for link if not provided

  # Perform actions based on options
  if [ -v "$sflag" ]; then
    estimate_size # Estimate website size
  else
    download_files # Download files
  fi

  echo "Finished. Yar."
}

# Call the main function with command-line arguments
main "$@"
