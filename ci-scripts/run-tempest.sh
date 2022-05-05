#!/bin/bash

if [ ! -z $1 ]; then
	dirname=$1
else
	dirname=`date +"%d_%m_%Y_%H_%M_%S"`
fi
log_path=/tmp/$dirname
script_dir=`dirname $0`
tempest_path="/opt/stack/tempest/"
run_type="--parallel"
failed_run=0
#concurrency="--concurrency 38"
#tests="tempest.api.compute.|tempest.api.volume.|tempest.scenario.|tempest.api.image."
tests="tempest.api.volume."
GERRIT_CHANGE_NUMBER="$2"
GERRIT_PATCHSET_NUMBER="$3"
GERRIT_REFSPEC="$4"


if [ $script_dir == "." ]; then
	script_dir=`pwd`
fi
mkdir -p $log_path
echo "Source the openrc file"
source /opt/stack/devstack/openrc admin admin

error_check() {
	err=$1
	msg=$2
	if [ $err -ne 0 ]; then
		echo "$msg [ FAILED ]"
		exit 1
	fi
	echo "$msg [ PASSED ]"
}
update_cinder_info() {
	ctype=$1
	cd $script_dir
	if [ $ctype == "iscsi" ]; then
		echo "Starting iSCSI Test configuration"
		cp iscsi_cinder.conf /etc/cinder/cinder.conf
		cp iscsi_cinder.conf $log_path
		error_check $? "Updating cinder.conf with iSCSI driver details"
		cinder type-list| grep datacore_iscsi1 >>/dev/null 2>&1
		if [ $? -ne 0 ]; then
			cinder type-create datacore_iscsi1
			error_check $? "Creating datacore_iscsi1 volume type"
			cinder type-key datacore_iscsi1 set volume_backend_name=datacore_iscsi1
			error_check $? "Adding datacore_iscsi1 volume backend"
		fi
	else
		echo "Starting Fiber Channel Test configuration"
		cp fc_cinder.conf /etc/cinder/cinder.conf 
		cp fc_cinder.conf $log_path
		error_check $? "Updating cinder.conf with Fiber Channel driver details"
		cinder type-list| grep datacore_fc1 >>/dev/null 2>&1
		if [ $? -ne 0 ]; then
			cinder type-create datacore_fc1
			error_check $? "Creating datacore_fc1 volume type"
			cinder type-key datacore_fc1 set volume_backend_name=datacore_fc1
			error_check $? "Adding datacore_fc1 volume backend"
		fi
	fi

	echo "Restarting devstack services"
	sudo systemctl restart devstack@*
	sleep 60
	sudo systemctl status  devstack@c-vol.service| grep Active:| grep running >> /dev/null
	error_check $? "Cinder volume service"

}

start_tempest() {
	ctype=$1
	cd $tempest_path
	tempest run --list-tests | grep -E $tests > /tmp/test_details
	if [ ! -s /tmp/test_details ]; then
		error_check 1 "Test file validation"
	fi
	cp /tmp/test_details $log_path
	cd $script_dir
	if [ $ctype == "iscsi" ]; then
		echo "Starting tempest for iSCSI driver"
		cp iscsi_tempest.conf /opt/stack/tempest/etc/tempest.conf
		cp iscsi_tempest.conf $log_path
		error_check $? "Updating tempest.conf with iSCSI driver details"
		cd $tempest_path
		echo "Running tempest"
		tempest run --load-list /tmp/test_details $run_type $concurrency > $log_path/iscsi_driver_test.log
		if [ $failed_run -eq 0 ]; then
			failed_run=`cat $log_path/iscsi_driver_test.log | grep "... FAILED" | wc -l`
		fi
	else
		echo "Starting tempest for Fiber Channel driver"
		cp fc_tempest.conf /opt/stack/tempest/etc/tempest.conf
		cp fc_tempest.conf $log_path
		error_check $? "Updating tempest.conf with Fiber Channel driver details"
		cd $tempest_path
		echo "Running tempest"
		tempest run --load-list /tmp/test_details $run_type $concurrency > $log_path/fc_driver_test.log
		if [ $failed_run -eq 0 ]; then
			failed_run=`cat $log_path/fc_driver_test.log | grep "... FAILED" | wc -l`
		fi
	fi
}


upload_logs_to_git() {
	cd /tmp
	sudo journalctl --unit  devstack@c-vol.service > $log_path/cinder_volume.log
	if [ ! -d cinder-tempest-logs ]; then
		git clone git@github.com:arun-kv/cinder-tempest-logs.git
		error_check $? "Cloning cinder-tempest-logs repo"
		cd cinder-tempest-logs
	else
		cd cinder-tempest-logs
		git pull
		error_check $? "Updating cinder-tempest-logs repo"
	fi
	cp -r $log_path .
	error_check $? "Copying logs to cinder-tempest-logs repo"
	$script_dir/cleanup-ci-result.sh /tmp/cinder-tempest-logs
	git add $dirname
	error_check $? "Adding logs to cinder-tempest-logs repo"
	git commit -m "tempest log"
	error_check $? "Git commit"
	git push
	error_check $? "Git push"
}

detach_disk() {
	cd $script_dir
	for i in `lsblk | grep ^s| grep 1G | awk {'print $1'}`
	do
	       	sudo detach_disk.sh $i >> /dev/null 2>&1
	done
}

update_cinder () {
	cd $script_dir
	./checkout-patchset.sh "$GERRIT_CHANGE_NUMBER $GERRIT_PATCHSET_NUMBER $GERRIT_REFSPEC"
	error_check $? "checkout patchset"
}

echo "Updating cinder code"
update_cinder

echo "Clearing logs"
sudo journalctl  --unit  devstack@c-vol.service  --vacuum-time=1s >> /dev/null 2>&1

detach_disk

echo $log_path
update_cinder_info "iscsi"
start_tempest "iscsi"

update_cinder_info "fc"
start_tempest "fc"

upload_logs_to_git

rm -rf $log_path

exit $failed_run
