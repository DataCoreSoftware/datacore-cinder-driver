#!/bin/bash

repos="cinder devstack glance horizon keystone neutron nova novnc tempest placement requirements"

cd /opt/stack/
for repo in $repos
do
       	cd $repo
	echo "Updating $repo"
	git checkout master -f
       	git pull
       	cd ../
done
