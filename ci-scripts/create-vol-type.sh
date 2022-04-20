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
        sleep 120
        sudo systemctl status  devstack@c-vol.service| grep Active:| grep running >> /dev/null
}

update_cinder_info "iscsi"
update_cinder_info "fc"
