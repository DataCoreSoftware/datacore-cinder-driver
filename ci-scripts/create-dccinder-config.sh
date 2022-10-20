#!/bin/bash

fc_config="datacore_api_timeout=300
datacore_disk_failed_delay=300
datacore_disk_pools=cinder-pool
datacore_disk_type=single
san_ip=10.200.2.115
san_login=Administrator
san_password=Datacore1
volume_backend_name=datacore_fc1
volume_driver=cinder.volume.drivers.datacore.fc.FibreChannelVolumeDriver
backend_host=hostgroup"


iscsi_config="datacore_api_timeout=300
datacore_disk_failed_delay=300
datacore_disk_pools=cinder-pool
datacore_disk_type=single
san_ip=10.200.2.115
san_login=Administrator
san_password=Datacore1
volume_backend_name=datacore_iscsi1
volume_driver=cinder.volume.drivers.datacore.iscsi.ISCSIVolumeDriver
backend_host=hostgroup"

lvm_config="image_volume_cache_enabled = True
volume_clear = zero
lvm_type = auto
target_helper = lioadm
volume_group = stack-volumes-lvmdriver-1
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_backend_name = lvmdriver-1"


iscsi_fc_cinder="iscsi_fc_cinder.conf"
fc_cinder_conf="fc_cinder.conf"
iscsi_cinder_conf="iscsi_cinder.conf"
cinder_config="/etc/cinder/cinder.conf"


if [ ! -f $cinder_config ]; then
	echo "$cinder_config file not found"
	exit 1
fi


create_base_config() {
	rm -rf /tmp/base_cinder_config
	while read line
	do
		echo "$line" | grep "^\[" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			parant="$line"
		fi
		if [[ "$parant" == "[lvmdriver-1]" || "$parant" == "[datacore_iscsi1]" || "$parant" == "[datacore_fc1]" ]]; then
			continue
		fi
		echo "$line" >> /tmp/base_cinder_config
	done < $cinder_config
}

add_default_vol_type() {
	vol_type="$1"
	backend="$2"
	file_name="$3"

	sed -i 's/default_volume_type =.*/default_volume_type = '$vol_type'/' $file_name
	sed -i 's/enabled_backends =.*/enabled_backends = '$backend'/' $file_name
}

create_datacore_cinder_config() {
	if [ ! -f /tmp/base_cinder_config ]; then
		echo "unable to create /tmp/base_cinder_config"
		exit 1
	fi

	if [ ! -s /tmp/base_cinder_config ]; then
		echo "/tmp/base_cinder_config is empty"
		exit 
	fi

#	if [ -f $iscsi_cinder_conf ]; then
#		cp $iscsi_cinder_conf $iscsi_cinder_conf\.back
#	fi
	cp /tmp/base_cinder_config $iscsi_cinder_conf
	cp /tmp/base_cinder_config $fc_cinder_conf
	cp /tmp/base_cinder_config $iscsi_fc_cinder

	echo -e "\n[datacore_iscsi1]" >> $iscsi_cinder_conf
	for line in $iscsi_config
	do
		echo $line >> $iscsi_cinder_conf
	done

	add_default_vol_type "datacore_iscsi1" "datacore_iscsi1" $iscsi_cinder_conf

	echo -e "\n[datacore_fc1]" >> $fc_cinder_conf
	for line in $fc_config
	do
		echo $line >> $fc_cinder_conf
	done

	add_default_vol_type "datacore_fc1" "datacore_fc1" $fc_cinder_conf

	echo -e "\n[datacore_iscsi1]" >> $iscsi_fc_cinder
	for line in $iscsi_config
	do
		echo $line >> $iscsi_fc_cinder
	done

	echo -e "\n[datacore_fc1]" >> $iscsi_fc_cinder
	for line in $fc_config
	do
		echo $line >> $iscsi_fc_cinder
	done

	add_default_vol_type "datacore_fc1" "datacore_iscsi1,datacore_fc1" $iscsi_fc_cinder
}

create_base_config
create_datacore_cinder_config
