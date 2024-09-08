#!/bin/bash

# Shamelessly ripped off from Zorg64
# https://gist.github.com/Zorg64/f0feddf1fedda3299babeef2c3c25029
# Works for now but I'll clean it up a bit to make it more user friendly.

# CONSTANTS

# Color outputs
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Directories
homedir="$HOME"

# FUNCTIONS

# Prompts the user for a URL if not provided as a command-line argument.
# Extracts the ID from the given URL to use in API requests.
function promptForURL() {
    local url="$1"
    until [ -n "$url" ]; do
        read -rp "URL: " url
    done
    id=$(sed 's|.*gofile.io/d/||g' <<< "$url")
    echo
    echo -n "Loading content from $id..."
}

# Retrieves a guest token from GoFile's API for authenticated requests.
function retrieveToken() {
    token=$(curl -s -X POST 'https://api.gofile.io/accounts' \
        -H 'User-Agent: Mozilla/5.0' \
        -H 'Accept-Encoding: gzip, deflate, br' \
        -H 'Accept: */*' \
        -H 'Connection: keep-alive' | jq -r '.data.token' 2>/dev/null)

    if [ -z "$token" ]; then
        echo
        echo -e "${red}ERROR!${reset} Failed to create guest account. Please try again later."
        echo "Exiting script."
        echo
        exit 1
    fi
}

# Retrieves a website token required for some API requests.
function retrieveWebsiteToken() {
    websiteToken=$(curl -s 'https://gofile.io/dist/js/alljs.js' | awk -F'"' '/var fetchData = { wt:/ {print $(NF-1)}')
    if [ -z "$websiteToken" ]; then
        echo
        echo -e "${red}ERROR!${reset} Failed to retrieve website token. Please try again later."
        echo
        exit 1
    fi
}

# Retrieve content from GoFile using the content ID.
# If a password is required, prompts the user for it.
function retrieveContent() {
    local password_hash="$1"
    local extra_params=""

    if [ -n "$password_hash" ]; then
        extra_params="&password=$password_hash"
    fi

    resp=$(curl -H "Authorization: Bearer $token" "https://api.gofile.io/contents/$id?wt=$websiteToken&cache=true$extra_params" 2>/dev/null)
    local status=$(jq -r '.status' <<< "$resp")
    local notFound=$(jq -r '.data.notFound // "false"' <<< "$resp")
    local passwordRequired=$(jq -r '.data.password // "false"' <<< "$resp")
    local passwordStatus=$(jq -r '.data.passwordStatus // "none"' <<< "$resp")

    if [[ "$notFound" == "true" ]]; then
        printf "\r\033[K"
        echo -e "${red}ERROR!${reset} Content not found. Please check the URL and try again."
        exit 1
    elif [[ "$status" == "ok" && "$passwordRequired" == "true" && "$passwordStatus" == "passwordRequired" && -z "$password_hash" ]]; then
        handlePassword
    elif [[ "$status" == "ok" && "$passwordRequired" == "true" && "$passwordStatus" != "passwordOk" ]]; then
        printf "\r\033[K"
        echo -e "${red}ERROR!${reset} Incorrect password provided. Please try again."
        exit 1
    elif [[ "$status" != "ok" ]]; then
        printf "\r\033[K"
        echo -e "${red}ERROR!${reset} Failed to retrieve content. Please check the URL or try again later."
        exit 1
    fi
}

# Prompts the user for a password if needed to access protected content.
function handlePassword() {
    printf "\r\033[K"
    echo "This content is password protected..."
    read -rsp "Please enter the password: " password
    echo
    password_hash=$(printf "%s" "$password" | sha256sum | cut -d' ' -f1)
    retrieveContent "$password_hash"
}

# Shows a spinner animation while background processes are running.
function spinner {
    local -r pid=$1
    local -r delay=0.2
    local spinstr='|/-\'

    tput civis  # Hide cursor
    echo -n " "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\b%c" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\b "
    tput cnorm  # Show cursor
}

# Formats the size of the file from bytes to a more readable format (MB or GB).
function format_size {
    local -i bytes=$1

    if [ $bytes -lt 1000000000 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1000000}")"" MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1000000000}")"" GB"
    fi
}

# Manages the stopping and starting of a spinner for background operations.
function start_and_stop_spinner() {
    local -a pids=("${!1}")
    spinner "${pids[0]}" &
    spinner_pid=$!

    # Waits for all processes to finish.
    for pid in "${pids[@]}"; do
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
            wait "$pid"
        fi
    done

    # Stops the spinner if it's still running.
    if kill -0 "$spinner_pid" 2>/dev/null; then
        kill -9 "$spinner_pid"
        wait "$spinner_pid" 2>/dev/null
    fi
}

# Tracks download progress and updates the console.
function download_progress() {
    local total_size=$1
    local name=$2
    local -a pids=("${!3}")
    local current_size=0
    local percent=0

    # Ensures the reported total size is valid.
    if [ "$total_size" -le 0 ]; then
        echo -e "${red}ERROR!${reset} Total size is invalid."
        return
    fi

    tput civis
    # Continuously updates progress until all parts are downloaded.
    while : ; do
        current_size=0
        for part in "$name.part"*; do
            if [ -f "$part" ]; then
                local size=$(stat -c "%s" "$part")
                current_size=$((current_size + size))
            fi
        done
        percent=$((current_size * 100 / total_size))
        printf "\r$name | $f_size | $percent%%"

        # Checks if all download processes have finished.
        local all_done=1
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_done=0
                break
            fi
        done

        [ "$all_done" -eq 1 ] && break
        sleep 1
    done
    printf "\r\033[K"
    tput cnorm
}

function determine_download_parts() {
    local file_size=$1  # File size in bytes

    if [ "$file_size" -le 50000000 ]; then
        echo 1  # Files 50 MB or smaller
    elif [ "$file_size" -gt 50000000 ] && [ "$file_size" -le 100000000 ]; then
        echo 2  # Files larger than 50 MB up to 100 MB
    else
        echo 3  # Files larger than 100 MB
    fi
}


function download_and_combine_file() {
    local name=$1
    local file_url=$2
    local total_size=$3
    local expected_md5=$4
    local num_parts=$(determine_download_parts "$total_size")  # Determine the number of parts
    local -a pids=()
    local f_size=$(format_size "$total_size")

    echo -n "$name | $f_size | "

    # Calculate the size of each part based on the total size and the number of parts
    local part_size=$(($total_size / $num_parts))
    local last_part_size=$(($total_size - ($part_size * ($num_parts - 1))))

    # Download each part
    for ((part=0; part<num_parts; part++)); do
        local start=$(($part * $part_size))
        local end=$(($start + $part_size - 1))

        # Adjust the end for the last part
        if [ $part -eq $(($num_parts - 1)) ]; then
            end=$(($start + $last_part_size - 1))
        fi

        curl -s -H 'Cookie: accountToken='"$token" -H "Range: bytes=$start-$end" "$file_url" -o "$name.part$part" &
        pids[${part}]=$!
    done

    # Monitors download progress.
    download_progress "$total_size" "$name" "pids[@]"

    echo "$name | $f_size | 100%"
    echo -n "Combining parts... "

    # Combines parts and calculates MD5 checksum in the background
    (
        for ((part=0; part<num_parts; part++)); do
            cat "$name.part$part" >> "$name"  # Appends each part in sequence
        done

        # Remove part files after combining
        for ((part=0; part<num_parts; part++)); do
            rm -f "$name.part$part"
        done

        # Calculating MD5 checksum of the combined file
        calculated_md5=$(md5sum "$name" | awk '{print $1}')
        echo $calculated_md5 > "$name.md5"
    ) &
    combine_pid=$!

    # Handles the spinner for the combining and MD5 calculation process.
    local -a combine_pids=($combine_pid)
    start_and_stop_spinner "combine_pids[@]"
    printf "\r\033[K"

    # Read the calculated MD5 from the file
    calculated_md5=$(<"$name.md5")

    # Comparing checksums
    if [ "$calculated_md5" != "$expected_md5" ]; then
        echo -e "${red}Error!${reset} Download corrupt, removing '$name'"
        rm -f "$name"
        failed_dl+=("$name")
        rm -f "$name.md5"
        return 1
    else
        echo "Combining parts... Done!"
    fi
    rm -f "$name.md5"
}


# Processes each file found within the content fetched from GoFile.
function processFiles() {
     # Extracts names and links for all files within the content and sorts them alphabetically.
    while IFS="|" read -r name total_size file_url md5_checksum; do
        if [ ! -f "$name" ]; then
            if ! [[ $total_size =~ ^[0-9]+$ ]]; then
                echo "${yellow}Warning!${reset} Failed to get valid content length for \"$name\""
                continue
            fi
            download_and_combine_file "$name" "$file_url" "$total_size" "$md5_checksum"
        fi
    done < <(jq -r '.data.children[] | "\(.name)|\(.size)|\(.link)|\(.md5)"' <<< "$resp" | sort -t "|" -k1,1)
}

#Main

# Initiates the script by prompting the user for a URL if not supplied as an argument.
promptForURL "$1"

# Retrieves a token for authentication with the GoFile API.
retrieveToken

# Retrieves a website token required for further API interactions.
retrieveWebsiteToken

# Fetch content info from GoFile using the ID extracted from the URL.
retrieveContent

#Download directory
downdir="$homedir/GoFile/"$id""
mkdir -p "$downdir"
cd "$downdir"

printf "\r\033[K"
echo "Loading $id content...✓"

# Processes files within the fetched content.
failed_dl=()
processFiles

# Show any failed downloads
echo
if [ ${#failed_dl[@]} -ne 0 ]; then
    echo "Failed Downloads: ${#failed_dl[@]}"
    for file in "${failed_dl[@]}"; do
        echo "- $file"
    done
    echo -e "\nRun script again to attempt failed files.\n"
else
    echo -e "All downloads successful.\n"
fi

echo -e "\nNote: gofile.io is entirely free with no ads,\nYou can support it at https://gofile.io/donate"
