#!/bin/bash
disk=$1
if [ -z $disk ]; then
	echo "$0 <disk name>"
	exit 1
fi
lsscsi | grep $disk | awk {'print $1'}| sed 's/\[//'| sed 's/\]//'
hba=`lsscsi | grep $disk| awk {'print $1'}| sed 's/\[//'| sed 's/\]//'`
echo 1 > /sys/class/scsi_device/$hba/device/delete
