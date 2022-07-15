#!/bin/bash

tempest="/opt/stack/tempest/"
url="https://opendev.org/openstack/cinder.git"
GERRIT_CHANGE_NUMBER="$1"
GERRIT_PATCHSET_NUMBER="$2"
GERRIT_REFSPEC="$3"
FROM_JENKINS="$4"
GERRIT_PROJECT="$5"

echo $GERRIT_PROJECT | grep "openstack/os-brick"
if [ $? -eq 0 ]; then
	repo=os-brick
else
	repo=cinder
fi
destination="/opt/stack/$repo"

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

# This sleep is reqiered because, when the event comes from Gerrit the patchset is not 
# compleatly ready and the below git fetch fails
if [ $FROM_JENKINS -eq  1 ]; then
	echo "Waiting for patchset. FROM_JENKINS: $FROM_JENKINS"
	sleep 60
fi
cd $destination
git checkout master
error_check $? "git checkout cinder master"
git pull
error_check $? "git pull"

if [ ! -z $GERRIT_CHANGE_NUMBER ]; then
	delete_prev_patch

	changeBranch="change-${GERRIT_CHANGE_NUMBER}-${GERRIT_PATCHSET_NUMBER}"
	echo "changeBranch: $changeBranch"
	git fetch origin ${GERRIT_REFSPEC}:${changeBranch}
	error_check $? "git fetch origin $GERRIT_REFSPEC:$changeBranch"
	git checkout ${changeBranch}
	error_check $? "git checkout $changeBranch"
fi

# checkout tempest
cd $tempest
git pull

sudo systemctl restart "devstack@*"
sleep 10

