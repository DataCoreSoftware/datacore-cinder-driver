#!/bin/bash

repos="cinder devstack glance horizon keystone neutron nova novnc tempest placement requirements"

cd /opt/stack/devstack/
echo "Running unstack.sh"
./unstack.sh
sleep 10

cd /opt/stack/
for repo in $repos
do
       	cd $repo
	echo "Updating $repo"
	git checkout master -f
       	git pull
       	cd ../
done

cd /opt/stack/devstack/
./clean.sh
sleep 30
sudo rm -rf  /var/run/ovn/
sudo rm -rf  /var/run/openvswitch/
echo "Running stack.sh"
./stack.sh
