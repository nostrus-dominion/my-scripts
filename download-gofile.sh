#!/bin/bash

# Shamelessly ripped from https://gist.github.com/kasumabalidps/72c831a284d7ac3218fc7a7030610724
# I will eventually work on this to get a good progress bar but I don't know how to do that yet

url="$1"

# Prompt for URL if not provided
until [ ! -z "$url" ]; do
  read -p "URL: " url
done

# Get list of file names from command line arguments
file_names=("${@:2}")

id=$(sed 's|.*gofile.io/d/||' <<< "$url")
echo "Downloading files from $id"

# Get guest account token for URL and cookie
token=$(curl -s 'https://api.gofile.io/createAccount' | jq -r '.data.token' 2>/dev/null)
[ "$?" -ne 0 ] && echo "Creating guest account failed, please try again later"

# Get website token for URL
websiteToken=$(curl -s 'https://gofile.io/dist/js/alljs.js' | grep 'fetchData.wt' | awk '{ print $3 }' | jq -r)
[ "$?" -ne 0 ] && echo "Getting website token failed, please try again later"

# Get content info from API
resp=$(curl -s 'https://api.gofile.io/getContent?contentId='"$id"'&token='"$token"'&wt='"$websiteToken"'&cache=true' | jq -r '.data.contents[].name' 2>/dev/null)
[ "$?" -ne 0 ] && echo "URL unreachable, check provided link" && exit 1

# Create download folder
mkdir "$id" 2>/dev/null
cd "$id"

# List available files
echo "Available files:"
echo "$resp" | cat -n

# Prompt user to select files for download
if [ "${#file_names[@]}" -eq 0 ]; then
  read -p "Enter the file numbers you want to download (comma-separated, e.g., '1,3'): " selections
  IFS=',' read -ra selected_files <<< "$selections"
else
  selected_files=("${file_names[@]}")
fi

# Download selected files
for i in "${selected_files[@]}"; do
  name=$(echo "$resp" | sed -n "${i}p")
  url=$(curl -s 'https://api.gofile.io/getContent?contentId='"$id"'&token='"$token"'&wt='"$websiteToken"'&cache=true' | jq -r --arg name "$name" '.data.contents[] | select(.name == $name) | .link')

  # Download file if not already downloaded
  if [ ! -f "$name" ]; then
    echo
    echo "Downloading $name"
    curl -s -H 'Cookie: accountToken='"$token" "$url" -o "$name" &

    # Show progress
    while kill -0 $! 2>/dev/null; do
        echo -n "."
        sleep 1
    done

    echo " Download complete."
  else
    echo "$name already downloaded."
  fi
done

echo
echo "Downloads complete."

echo
echo "Note: gofile.io is entirely free with no ads,"
echo "you can support it at https://gofile.io/donate"
