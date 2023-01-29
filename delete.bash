#!/bin/bash

echo -e "\033[1;31mWARNING!! THESE DELETIONS ARE PERMANENT!!\033[0m"
echo -e "\033[1;31mDO NOT USE THIS UNLESS YOU'RE 100% SURE!!\033[0m"

while true; do
    read -p "Are you sure you want to continue? (y/n): " response
    case $response in
        [Yy]* ) break;;
        [Nn]* ) exit 1;;
        * ) echo "Please answer yes (y) or no (n).";;
    esac
done

echo "Enter the file extension to delete (e.g. txt): "
read -r file_extension

if [[ ! $file_extension =~ ^[A-Za-z]+$ ]]
then
    echo -e "\033[1;31mError! Invalid file extension entered.\033[0m"
    echo -e "\033[1;31mExiting script.\033[0m"
    exit 1
fi

while true; do
    echo "Deleting all .$file_extension files. Are you sure you want to continue? (y/n): "
    read -n 1 response
    case $response in
        [Yy]* ) break;;
        [Nn]* ) exit 1;;
        * ) echo "Please answer yes (y) or no (n).";;
    esac
done

echo "Last chance to exit script."
echo "Five second countdown to [CTRL-C] to cancel"

for i in {5..1}; do
    if [ "$i" -lt 4 ]
    then
        echo -ne "\033[1;32m$i.\033[0m"
    elif [ "$i" -lt 3 ]
    then
        echo -ne "\033[1;33m$i.\033[0m"
    else
        echo -ne "\033[1;31m$i.\033[0m"
    fi
    sleep 1
done

echo
echo "Deleting all .$file_extension files..."
find . -name "*.$file_extension" -exec rm -rf {} \;

echo "Finished!"
