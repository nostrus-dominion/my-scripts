#!/bin/bash

# Bourne Again shell version of 99 Bottles that
# sings to you. It's just a stupid thing to do.
# Dave Plonka - plonka@carroll1.cc.edu
# Edited by Paul Musselman so it goes VERY slow

# Dependency check.
dependencies=("sleep")
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

typeset -i n=99
typeset bottles=bottles
typeset no

trap '' SIGINT

while [ 0 != $((n)) ]; do
  echo "${n?} ${bottles?} of beer on the wall,"
  sleep 1.5
  echo "${n?} ${bottles?} of beer,"
  sleep 1.5
  echo "you take one down, you pass it around,"
  sleep 1.5
  n=n-1
  case ${n?} in
    0)
      no=no
      bottles=${bottles%s}s
      ;;
    1)
      bottles=${bottles%s}
      ;;
  esac
  echo "${no:-${n}} ${bottles?} of beer on the wall."
  sleep 2.5
  echo
done

exit
