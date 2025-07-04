#!/bin/bash

cacheFile=".cache/MAM.ip"
cookieFile=".cache/MAM.cookie"
mamIdArg="$1"

# Use MAM ID from argument, or extract from cookie if not provided
if [ -n "$mamIdArg" ]; then
    echo "Using MAM ID from argument to refresh session."
    mamId="$mamIdArg"
    response=$(curl -s -b "mam_id=$mamId" -c "$cookieFile" https://t.myanonamouse.net/json/dynamicSeedbox.php)

    if echo "$response" | grep -q '"Success":true'; then
        echo "New cookie saved to $cookieFile."
    else
        echo "Failed to refresh session with provided MAM ID."
        echo "Server response: $response"
        exit 1
    fi
elif [ -f "$cookieFile" ]; then
    echo "No MAM ID provided. Checking if existing cookie is still valid..."
    response=$(curl -s -b "$cookieFile" https://t.myanonamouse.net/json/dynamicSeedbox.php)

    if echo "$response" | grep -q '"Success":true'; then
        echo "Existing cookie is still valid."
    else
        echo "Existing cookie is invalid. Please re-run the script with your MAM ID:"
        echo "Usage: ./mam-cookie.sh <your_mam_id>"
        exit 1
    fi
else
    echo "No cookie file and no MAM ID provided. Cannot proceed."
    echo "Usage: ./mam-cookie.sh <mam_id>"
    exit 1
fi

# Get previous IP hash
[ -f "$cacheFile" ] && oldIp=$(cat "$cacheFile") || oldIp=""

# Hash current IP
newIp=$(curl -s ip4.me/api/ | md5sum | awk '{print $1}')

# Check if IP changed
if [ "$oldIp" != "$newIp" ]; then
    echo "New IP detected. Attempting to notify tracker..."

    response=$(curl -s -b "$cookieFile" https://t.myanonamouse.net/json/dynamicSeedbox.php)

    if echo "$response" | grep -q '"Success":true'; then
        echo "$newIp" > "$cacheFile"
        echo "IP update successful."
    else
        echo "Failed to notify tracker with existing cookie."
        echo "Server response: $response"
        exit 1
    fi
else
    echo "IP unchanged. No action taken."
fi
