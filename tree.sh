#!/bin/bash
# Creates DISK0.tree, DISK1.tree, DISKx.tree inside each disk, with the output of tree command.
# After generating the report, it send via email using mail.
# To add more disks, just add DISK[x]=/full/path to the disk. Just make sure that the array index are sequencial.
# Why this?
# With the reports from tree, in case of disk failure, you will know which file got lost and you can recover them, downloading or via backups.
# GIST: https://gist.github.com/rafaelbiriba/0ee7ca2baec1ef80a878c825295f09e1

EMAIL_ADDRESS="" # EMAIL_ADDRESS="email@gmail.com" or leave it blank "" to disable email
DISKS[0]="/srv/dev-disk-by-id-ata-WDC_WD80EMAZ-00WJTA0_ABC123-part1"
DISKS[1]="/srv/dev-disk-by-id-ata-WDC_WD80EMAZ-00WJTA0_XYZ456-part1"
#DISKS[2]="/full/path/to/disk/mount"

### DON'T CHANGE BELOW ###
email_output_tmp=$(mktemp)
date=$(date +"%Y-%m-%d")

for i in ${!DISKS[@]}; do
  cd ${DISKS[$i]}
  echo "Disk tree report from $date" > "DISK$i.tree"
  echo "DISK$i - ${DISKS[$i]}" >> "DISK$i.tree"
  echo "=================================================================" >> "DISK$i.tree"
  tree -h >> "DISK$i.tree"
  cat "DISK$i.tree" >> $email_output_tmp
done

if [ "$EMAIL_ADDRESS" != "" ]; then
  /usr/bin/mail -s "Disk tree report from $date" "$EMAIL_ADDRESS" < $email_output_tmp
  rm $email_output_tmp
fi
