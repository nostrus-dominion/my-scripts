#!/bin/bash

## Version 1.1
## License: Open Source GPL
## Copyright: (c) 2023
## Dependecies: openssl
## Not my original work but I changed things to make it more readable

###########################################
## APOLOGIES TO THE ORIGINAL AUTHOR
###########################################
## Originally created by someone on github.
## I tried to find it to give credit and
## use their license but I honestly can't
## find it again. Sorry buddy.
############################################
## EXAMPLE OUTPUT WHEN RUN
############################################
##
## ./show-ssl-cert.sh https://google.com github.com:443
##
## google.com:443	Issuer	 C=US, O=Google Trust Services, CN=GTS CA 1O1
## google.com:443	Not Before	 Sep 17 13:30:43 2019 GMT
## google.com:443	Not After 	 Dec 10 13:30:43 2019 GMT
## *****************************************
##
## github.com:443	Issuer	 C=US, O=DigiCert Inc, OU=www.digicert.com, CN=DigiCert SHA2 Extended Validation Server CA
## github.com:443	Not Before	 May  8 00:00:00 2018 GMT
## github.com:443	Not After 	 Jun  3 12:00:00 2020 GMT
## ****************************************
##
############################################

#######################
## ALL THE BORING STUFF
#######################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Dependency check
dependencies=("tput" "openssl" "rm" "mktemp" "grep" "sed" "timeout")
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

# Supported protocols
PROTOCOLS="https://|ldaps://|smtps://"

# Temporary directory
TMPDIR="/tmp/certificate-info-$$"

############
## FUNCTIONS
############

# Check if the script is called without a URL
if [ "$#" -lt 1 ]; then
  echo -e "${red}ERROR!${reset} A valid URL is required to run this script."
  echo -e "USAGE: ./show-ssl-cert.sh [URL]"
  exit 1
fi

# Function to clean up temporary files
cleanUp() {
  rm -rf "${TMPDIR}"
}

# Function to print separator
printSeparator() {
  echo -e "****************************************"
  echo ""
}

# Function to print error message for timeout
printTimeoutError() {
  echo -e "${red}ERROR!!${reset} Connection to ${yellow}$1${reset} timed out after 30 seconds!"
}

##################
## Start of script
##################

# Trap signals to perform cleanup on script exit or interruption
trap cleanUp EXIT INT TERM

# Create a temporary directory
TMPDIR="$(mktemp -d)"

# Process input files and URLs
while [ $# -gt 0 ]; do
  # Handle certificate files
  if [ -f "$1" ]; then
    case "$1" in
      *.crt)
        < "$1" openssl x509 -text |
          grep -E "^\s*(Subject:|Issuer:|Not |DNS:)" |
          (
            sed -e "s/^\s*//" -e 's/^\([^:]*\):/\1\t/' -e "s/DNS://g"
            echo -e "MD5\t$(openssl x509 -noout -modulus < "$1" | openssl md5 | sed -e "s/^[^ ]* //")"
          ) | while read line; do
          echo -e "$1\t$line"
        done
        ;;
      *.key)
        # Handle key files
        echo -e "$1\tMD5\t$(openssl rsa -noout -modulus < "$1" | openssl md5 | sed -e "s/^[^ ]* //")"
        ;;
    esac
    printSeparator
  else
    # Handle URLs
    URL="$1"
    PROTOCOL=""
    PORT=""

    # Extract protocol, hostname, and port from the URL
    if [[ "$URL" =~ ^($PROTOCOLS)?([^:/]*)(:[0-9]*)? ]]; then
      PROTOCOL="${BASH_REMATCH[1]}"
      HOSTNAME="${BASH_REMATCH[2]}"
      PORT="${BASH_REMATCH[3]:-}"
    fi

    # Determine default port based on protocol
    case "$PROTOCOL" in
      "https://")
        PORT="${PORT:-:443}"
        ;;
      "ldaps://")
        PORT="${PORT:-:636}"
        ;;
      "smtps://")
        PORT="${PORT:-:587}"
        ;;
      *)
        PORT="${PORT:-:443}"
        ;;
    esac

    # Connect to the host with a 30-second timeout
    if ! timeout 30 openssl s_client -connect "${HOSTNAME}${PORT}" -servername "${HOSTNAME}" < /dev/zero 2> /dev/null |
      openssl x509 -text > "${TMPDIR}/x509_text"; then
      printTimeoutError "${HOSTNAME}${PORT}"
    else
      # Extract relevant certificate details and output
      < "${TMPDIR}/x509_text" grep -E "^\s*(Subject:|Issuer:|Not |DNS:)" |
        sed -e "s/^\s*//" -e 's/^\([^:]*\):/\1\t/' -e "s/DNS://g" -e "s/^/${HOSTNAME}${PORT}\t/"

      # Output MD5 hash of the certificate modulus
      echo -e "${HOSTNAME}${PORT}\t${yellow}MD5\t${reset}$(< "${TMPDIR}/x509_text" openssl x509 -noout -modulus | openssl md5 | sed -e "s/^[^ ]* //")"
    fi

    printSeparator
  fi
  shift
done
