#!/bin/bash

# Load variables from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# Optional: Let the user choose the stream
read -p "Stream (default: stream1): " STREAM
STREAM=${STREAM:-stream1}

# Build RTSP URL
URL="rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/$STREAM"

echo "Opening $URL ..."
ffplay -rtsp_transport tcp "$URL" > /dev/null 2>&1 &
disown

