#!/bin/bash

# //Notes//
# Note1:  To enable a log of standard output add tee: VideoConverionBatchScript.sh | tee -a VideoConverionBatchScript.log
# Note2:  If using a media server like Plex, run this script from outside where Plex scans for media (one directory below is a good choice), otherwise Plex may detect the old files the Plex library may be duplicated.
# //Beginning of Script//
# Global Variable: Text Colors
red='\033[0;31m'
green='\033[0;32m'
cyan='\033[0;36m'
brown='\033[0;33m'
# Global Variable: Bold, uses tput since it's the most compatible, works with non-VT100 terminals (looks up appropriate codes according to TERM)
bold=`tput bold`
# Global Variable:  ffprobe string
# placeholder.  neccesary? better as function?
# Splash
echo
echo
echo -e "${brown}${bold}Welcome to FFmpeg-Batch-Converter"
echo  ' ___  ___        __   ___  __      __       ___  __           __   __             ___  __  ___  ___  __ '
echo  '|__  |__   |\/| |__) |__  / _` __ |__)  /\   |  /  ` |__| __ /  ` /  \ |\ | \  / |__  |__)  |  |__  |__)'
echo  '|    |     |  | |    |___ \__>    |__) /~~\  |  \__, |  |    \__, \__/ | \|  \/  |___ |  \  |  |___ |  \'
echo
# Module 1:  Set Search Directory where files for conversion are located
read -p "Enter the directory you'd like to search, e.g., ~/media : " directoryInput
#
# ChangeDirectory into home directory
cd ~
# ChangeDirectory to where files for conversion are located
cd $directoryInput
# Module 2: Whitespace FOR loop fixer
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
# Module 3:  Choose recursive search or not
read -p "Do you want recursive search (sub-directories included)?  Type y/n: " recursiveInput
while [ "$recursiveInput" != y ] && [ "$recursiveInput" != n ]; do
        read -p "Try again:  Enter "y" or "n" only, do you want recursive search (sub-directories included)?  Type y/n: " recursiveInput
done
# Module 4a:  Recursive search
if [ ${recursiveInput} == 'y' ]; then
        echo "Beginning search of "$directoryInput" and all sub-directories for files ending in .mp4,.mkv,.avi,.mpg"
        # Recursive Search: Finds files with the common extensions below, issues 'do' command
        for FIL in `find $directory -type f \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.avi -o -iname \*.mpg \)` ; do
        # FFProbe checks the files for H264/AAC streams
        output=$(ffprobe -v error -show_streams "$FIL" | grep codec_name)
        # If/ElseIf Statements: act as decision logic for correct encoding
        # If a stream is h264 and another is AAC
        if [[ $output == *codec_name=h264* ]] && [[ $output == *codec_name=aac* ]]; then
        echo -e "${green}${bold}Script: H264 and AAC streams found, skipping transcode for FILE: "$FIL""
        # ElseIf a stream is h264 and no stream is AAC
        elif [[ $output == *codec_name=h264* ]] && [[ $output != *codec_name=aac* ]]; then
                        echo -e "${red}${bold}Script:   Found H264 video stream, no AAC audio stream. Encoding AAC audio, passing-thru H264 video for FILE: "$FIL""
                        # pass-thru h264, encode AAC 2-channel constant bit rate 128k low-pass cutoff 18000KHz, overwrite files, 10 second probe
                        nice -19 ffmpeg -y -probesize 100000000 -analyzeduration 100000000 -i "$FIL" -vcodec copy -acodec libfdk_aac -ac 2 -b:a 128k -cutoff 18000 ${FIL%.*}.FFmpeg-Cron-Convert.mp4
                        # check if the CLEANUP directory exists, if not creates a directory named "CLEANUP" in home DIRECTORY.  Ensure CLEANUP is not in search directory otherwise files moved to CLEANUP directory may be processed again by the script
                        if [ ! -d ~/CLEANUP ]; then
                                echo -e "${red}${bold}Script:   Creating CLEANUP directory one folder below where script was run from"
                                mkdir -p ~/CLEANUP
                        fi
                        # moves original file to CLEANUP folder
                        mv "$FIL" ~/CLEANUP/
                        echo -e "${red}${bold}Script:   Moved original FILE to CLEANUP directory: "$FIL""
        #ElseIf a stream is NOT h264 and a stream is AAC
        elif [[ $output != *codec_name=h264* ]] && [[ $output == *codec_name=aac* ]]; then
                        echo -e "${red}${bold}Script:   Found AAC audio stream, no H264 video stream.   Encoding H264 video, passing-thru AAC audio for FILE: "$FIL""
                        # pass-thru AAC, encode h264 constant quality rate of 20, overwrite files, 10 second probe
                        nice -19 ffmpeg -y -probesize 100000000 -analyzeduration 100000000 -i "$FIL" -vcodec libx264 -crf 20 -preset veryslow -acodec copy ${FIL%.*}.FFmpeg-Batch-Convert.mp4
                        # check if the CLEANUP directory exists, if not creates it
                        if [ ! -d ~/CLEANUP ]; then
                                echo -e "${red}${bold}Script:   Creating CLEANUP directory one folder below where script was run from"
                                mkdir -p ~/CLEANUP
                        fi
                        # moves original file to CLEANUP folder
                        mv "$FIL" ~/CLEANUP/
                        echo -e "${red}${bold}Script:   Moved original FILE to CLEANUP directory: "$FIL""
        #ElseIf one stream is not h264 and another stream is not AAC
        elif [[ $output != *codec_name=h264* ]] && [[ $output != *codec_name=aac* ]]; then
                        echo -e "${red}${bold}Script:   H264/AAC stream not found. Transcoding video as H264 and audio as AAC for FILE: "$FIL""
                        # encode h264, AAC 2-channel at constant bitrate 128k low-pass cutoff 18000KHz, overwrite files, 10 second probe
                        nice -19 ffmpeg -y -probesize 100000000 -analyzeduration 100000000 -i "$FIL" -vcodec libx264 -crf 20 -preset veryslow -acodec libfdk_aac -ac 2 -b:a 128k -cutoff 18000 ${FIL%.*}.FFmpeg-Cron-Convert.mp4
                        # check if the CLEANUP directory exists, if not creates it
                        if [ ! -d ~/CLEANUP ]; then
                                echo -e "${red}${bold}Script:   Creating CLEANUP directory one folder below where script was run from"
                                mkdir -p ~/CLEANUP
                        fi
                        # moves original file to CLEANUP folder
                        mv "$FIL" ~/CLEANUP/
                        echo -e "${red}${bold}Script:   Moved original FILE to CLEANUP directory: "$FIL""
        fi
        done
# Module 4b:  non-recursive search
else
        echo "beginning search of this directory for files ending in .mp4,.mkv,.avi,.mpg"
        # Module 4a: Non-Recursive Search: Finds files with the extensions below, sorts them into lines, issues 'do' command
        for FIL in `ls *.mp4 *.mkv *.avi *.mpg | sort` ; do
        # FFProbe checks the files for H264/AAC streams
        output=$(ffprobe -v error -show_streams "$FIL" | grep codec_name)
        # If/ElseIf Statements: act as decision logic for correct encoding
        # If a stream is h264 and another is AAC
        if [[ $output == *codec_name=h264* ]] && [[ $output == *codec_name=aac* ]]; then
                echo -e "${green}${bold}Script: H264 and AAC streams found, skipping transcode for FILE: "$FIL""
        # ElseIf a stream is h264 and no stream is AAC
        elif [[ $output == *codec_name=h264* ]] && [[ $output != *codec_name=aac* ]]; then
                echo -e "${red}${bold}Script:   Found H264 video stream, no AAC audio stream. Encoding AAC audio, passing-thru H264 video for FILE: "$FIL""
                        # pass-thru h264, encode AAC 2-channel constant bit rate 128k low-pass cutoff 18000KHz, overwrite files, 10 second probe
                        nice -19 ffmpeg -y -probesize 100000000 -analyzeduration 100000000 -i "$FIL" -vcodec copy -acodec libfdk_aac -ac 2 -b:a 128k -cutoff 18000 ${FIL%.*}.FFmpeg-Cron-Convert.mp4
                        # check if the CLEANUP directory exists, if not creates a directory named "CLEANUP" in home DIRECTORY.  Ensure CLEANUP is not in search directory otherwise files moved to CLEANUP directory may be processed again by the script
                        if [ ! -d ~/CLEANUP ]; then
                                echo -e "${red}${bold}Script:   Creating CLEANUP directory one folder below where script was run from"
                                mkdir -p ~/CLEANUP
                        fi
                        # moves original file to CLEANUP folder
                        mv "$FIL" ~/CLEANUP/
                        echo -e "${red}${bold}Script:   Moved original FILE to CLEANUP directory: "$FIL""
        #ElseIf a stream is NOT h264 and a stream is AAC
        elif [[ $output != *codec_name=h264* ]] && [[ $output == *codec_name=aac* ]]; then
                        echo -e "${red}${bold}Script:   Found AAC audio stream, no H264 video stream.   Encoding H264 video, passing-thru AAC audio for FILE: "$FIL""
                        # pass-thru AAC, encode h264 constant quality rate of 20, overwrite files, 10 second probe
                        nice -19 ffmpeg -y -probesize 100000000 -analyzeduration 100000000 -i "$FIL" -vcodec libx264 -crf 20 -preset veryslow -acodec copy ${FIL%.*}.FFmpeg-Batch-Convert.mp4
                        # check if the CLEANUP directory exists, if not creates it
                        if [ ! -d ~/CLEANUP ]; then
                                echo -e "${red}${bold}Script:   Creating CLEANUP directory one folder below where script was run from"
                                mkdir -p ~/CLEANUP
                        fi
                        # moves original file to CLEANUP folder
                        mv "$FIL" ~/CLEANUP/
                        echo -e "${red}${bold}Script:   Moved original FILE to CLEANUP directory: "$FIL""
        #ElseIf one stream is not h264 and another stream is not AAC
        elif [[ $output != *codec_name=h264* ]] && [[ $output != *codec_name=aac* ]]; then
                        echo -e "${red}${bold}Script:   H264/AAC stream not found. Transcoding video as H264 and audio as AAC for FILE: "$FIL""
                        # encode h264, AAC 2-channel at constant bitrate 128k low-pass cutoff 18000KHz, overwrite files, 10 second probe
                        nice -19 ffmpeg -y -probesize 100000000 -analyzeduration 100000000 -i "$FIL" -vcodec libx264 -crf 20 -preset veryslow -acodec libfdk_aac -ac 2 -b:a 128k -cutoff 18000 ${FIL%.*}.FFmpeg-Cron-Convert.mp4
                        # check if the CLEANUP directory exists, if not creates it
                        if [ ! -d ~/CLEANUP ]; then
                                echo -e "${red}${bold}Script:   Creating CLEANUP directory one folder below where script was run from"
                                mkdir -p ~/CLEANUP
                        fi
                        # moves original file to CLEANUP folder
                        mv "$FIL" ~/CLEANUP/
                        echo -e "${red}${bold}Script:   Moved original FILE to CLEANUP directory: "$FIL""
        fi
        done
fi
echo -e "${red}${bold}************End of Script************"
