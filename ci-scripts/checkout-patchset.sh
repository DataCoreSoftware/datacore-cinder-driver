#!/bin/bash

destination="/opt/stack/cinder/"
tempest="/opt/stack/tempest/"
url="https://opendev.org/openstack/cinder.git"
GERRIT_CHANGE_NUMBER="$1"
GERRIT_PATCHSET_NUMBER="$2"
GERRIT_REFSPEC="$3"

error_check() {
	status=$1
	msg="$2"

	if [ $status -eq 0 ]; then
		echo "$msg Success"
	else
		echo "$msg Failed"
		exit 1
	fi
}

delete_prev_patch() {
	for i in `git branch| grep -v master`
       	do
	       	git branch -D $i >>/dev/null
       	done
}

if [ ! -d $destination ]; then
	echo "echo $destination not found"
	exit 1
fi

cd $destination
git checkout master
error_check $? "git checkout cinder master"
git pull
error_check $? "git pull"

delete_prev_patch

# This will be enabled once DataCore Driver is upstreamed
#<<COMM
changeBranch="change-${GERRIT_CHANGE_NUMBER}-${GERRIT_PATCHSET_NUMBER}"
echo "changeBranch: $changeBranch"
git fetch origin ${GERRIT_REFSPEC}:${changeBranch}
error_check $? "git fetch origin $GERRIT_REFSPEC:$changeBranch"
git checkout ${changeBranch}
error_check $? "git checkout $changeBranch"
#COMM

# checkout tempest
cd $tempest
git pull

sudo systemctl restart "devstack@*"
sleep 10

