#!/bin/bash

GERRIT_CHANGE_NUMBER=836996
GERRIT_PATCHSET_NUMBER=39
GERRIT_REFSPEC="refs/changes/96/836996/39"
DIR="/opt/stack/cinder/"

cd $DIR

changeBranch="change-${GERRIT_CHANGE_NUMBER}-${GERRIT_PATCHSET_NUMBER}"
echo "changeBranch: $changeBranch"
git fetch origin ${GERRIT_REFSPEC}:${changeBranch}
git checkout ${changeBranch}
