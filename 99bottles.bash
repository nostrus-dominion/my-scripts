#!/bin/bash
# Bourne Again shell version of 99 Bottles
# Dave Plonka - plonka@carroll1.cc.edu
# Edited by Paul Musselman so it goes VERY slow

typeset -i n=99
typeset bottles=bottles
typeset no

while [ 0 != $[ n ] ]
do
   echo "${n?} ${bottles?} of beer on the wall,"
   sleep 1.5
   echo "${n?} ${bottles?} of beer,"
   sleep 1.5
   echo "take one down, pass it around,"
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
