#!/bin/bash

MAX_DIR_COUNT=100
dest_dir=$1

if [ $# -eq 0 ]; then
	echo "$0 <dir_name>"
	exit 1
fi

cd $dest_dir
dir_count=`ls | grep "ci-result" | wc -l`
if [ $dir_count -gt $MAX_DIR_COUNT ]; then
	dir_rm_count=$(expr $dir_count - $MAX_DIR_COUNT)
	dirs_to_remove=`ls -lrta| grep ci-result| head -$dir_rm_count | awk {'print $9'}`
	for dir in $dirs_to_remove
	do
		echo $dir
		git rm -r $dir
		rm -vrf $dir
	done
fi
