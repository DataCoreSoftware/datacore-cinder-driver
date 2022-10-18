#!/bin/bash

repos="cinder devstack glance horizon keystone neutron nova novnc tempest placement requirements"

cd /opt/stack/devstack/
echo "Running unstack.sh"
./unstack.sh
sleep 10

cd /opt/stack/devstack/
./clean.sh
sleep 30
sudo apt remove -y ovn-common ovn-controller-vtep ovn-host ovn-central
cd /opt/stack/
sudo rm -rf devstack requirements cinder tempest novnc horizon placement nova neutron glance keystone bin bindep-venv
