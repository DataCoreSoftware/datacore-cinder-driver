#!/bin/bash

config_path=$1
cd /opt/stack/
git clone https://opendev.org/openstack/devstack
echo "Running stack.sh"
cd /opt/stack/devstack/
cp $config_path/local.conf .
./stack.sh
sleep 30
