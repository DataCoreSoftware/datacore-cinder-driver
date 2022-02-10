# DataCore SANsymphony Cinder volume driver for RHOSP 16.2

## Overview

DataCore SANsymphony containerized Cinder driver provides Red Hat OpenStack Platforms' (RHOSP) Compute instances with access to the SANsymphony(TM) Software-defined Storage Platform. When volumes are created in RHOSP, the driver creates corresponding virtual disks in the SANsymphony server group. When a volume is attached to an instance in RHOSP, a Linux host is registered and the corresponding virtual disk is served to the host in the SANsymphony server group.

This page provides detailed steps on how to install, configure and operate the containerized Cinder driver plugin for DataCore SANsymphony in a RHOSP 16.2 environment.

## Prerequisites

* Deployed overcloud with director as per the instructions in [Director Installation and Usage Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/director_installation_and_usage/index).

* DataCore SANsymphony 10 PSP6 or later server deployed and configured.

## Steps

There are two options to deploy the containerized cinder driver based on the overcloud nodes' network configuration where the cinder service is configured. In this example, cinder service is configured in a controller node. If the controller node is able to access external network then follow the first option. Otherwise the container image has to be pulled a priori in the director and it can be deployed from the local registry. Both options are described below.

For full detailed instruction of all options please refer to https://docs.openstack.org/cinder/queens/configuration/block-storage/drivers/datacore-volume-driver.html

### Option 1: Controller node has external network access

Since controller node has external network access the container image for the driver plugin can be directly pulled from the Red Hat Connect registry during deployment.

1.1	Update `containers-prepare-parameter.yaml` file with the credentials for Red Hat Connect registry.
```
parameter_defaults:
  ...
  ContainerImageRegistryCredentials:
    registry.redhat.io:
      myuser: 'p@55w0rd!'
    registry.connect.redhat.com:
      myuser1: '0th3rp@55w0rd!'
  ContainerImageRegistryLogin: true
```

Note that `ContainerImageRegistryLogin` should be set to `true`.

1.2	Create environment file

Create an environment file similar to [datacore-cinder-backend-env.yaml](https://github.com/DataCoreSoftware/datacore-cinder-driver/blob/master/RHOSP16.2/datacore-cinder-backend-env.yaml) in `/home/stack/templates/`. Populate the `<sansymphony_management_ip_addr>`, `<username>`, `<password>` and `<diskpoolname>` as per your SANsymphony server environment. If multiple SANsymphony servers are present, then you can configure multiple backends as well, please refer [Custom Block Storage Back End Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/custom_block_storage_back_end_deployment_guide/index) for further details.

1.3	Re-deploy overcloud

```
$ openstack overcloud deploy --templates \
    -e containers-prepare-parameter.yaml
    -e [existing environment files]
    ...
    -e /home/stack/templates/datacore-cinder-backend-env.yaml
```

### Option 2: Controller node does NOT have external network access

If the controller node does not have access to external network then the driver container image has to be pulled into the director node and pushed into a local registry, before it can be deployed.

1.1	Login to Red Hat registry

From the director node:
```
$ sudo podman login registry.redhat.io
```
Provide the necessary credentials

1.2	Pull the containerized driver

```
$ sudo podman pull registry.connect.redhat.com/datacore-software/openstack-cinder-volume-datacore-rhosp-16-2:latest
```

1.3	Run `podman images` command to verify if the container got pulled successfully or not
```
$ sudo podman images
REPOSITORY                                                                                            TAG      IMAGE ID       CREATED       SIZE
registry.connect.redhat.com/datacore-software/openstack-cinder-volume-datacore-rhosp-16-2             latest   4f62b1537b8d   6 weeks ago   1.45 GB
```

1.4	Add tag to the image created

In the below command, datacore-director.ctlplane.localdomain:8787 acts as local registry.
```
$ sudo podman tag <image id> datacore-director.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-volume-datacore-rhosp-16-2:latest
```

1.5	Run `podman images` command to verify the repository and tag is correctly updated to the docker image

```
$ sudo podman images
REPOSITORY                                                                                            TAG      IMAGE ID       CREATED       SIZE
datacore-director.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-volume-datacore-rhosp-16-2   latest   4f62b1537b8d   6 weeks ago   1.45 GB
```

1.6	Push the container to a local registry

```
$ sudo openstack tripleo container image push --local datacore-director.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-volume-datacore-rhosp-16-2:latest
```

1.7	Create environment file

Create an environment file similar to [datacore-cinder-config.yaml](https://github.com/DataCoreSoftware/datacore-cinder-driver/blob/master/RHOSP16.2/datacore-cinder-config.yaml) in `/home/stack/templates/`. Populate the `<sansymphony_management_ip_addr>`, `<username>`, `<password>` and `<diskpoolname>` as per your SANsymphony server environment. Update the `<local_registry>` also. If multiple SANsymphony servers are present, then you can configure multiple backends as well, please refer [Custom Block Storage Back End Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/custom_block_storage_back_end_deployment_guide/index) for further details.

1.8	Re-deploy overcloud

```
$ openstack overcloud deploy --templates \
    -e [existing environment files]
    ...
    -e /home/stack/templates/datacore-cinder-config.yaml
```

## Configuration options

The options below can be configured in the custom environment files.

Configuration options and default values:

 * `datacore_disk_pools = None`

Sets the pools to use for the DataCore RHOSP Cinder Volume Driver. This option acts like a filter and any number of pools may be specified. The list of specified pools will be used to select the storage sources needed for virtual disks: one for single or two for mirrored. Selection is based on the pools with the most free space.

 * `datacore_disk_type = single`

Sets the storage profile of the virtual disk. The default setting is Normal. Other valid values include the standard storage profiles (Critical, High, Low, and Archive) and the names of custom profiles that have been created.

 * `datacore_api_timeout = 300`

Sets the number of seconds to wait for a response from a DataCore API call.

 * `datacore_disk_failed_delay = 300`

Sets the number of seconds to wait for the SANsymphony virtual disk to come out of the “Failed” state.

 * `datacore_iscsi_unallowed_targets = []`

Sets a list of iSCSI targets that cannot be used to attach to the volume. By default, the DataCore iSCSI volume driver attaches a volume through all target ports with the Front-end role enabled.


To prevent the DataCore iSCSI volume driver from using some front-end targets in volume attachment, specify this option and list the iqn and target machine for each target as the value, such as `<iqn:target name>, <iqn:target name>, <iqn:target name>`. For example, `<iqn.2000-08.com.company:Server1-1, iqn.2000-08.com.company:Server2-1, iqn.2000-08.com.company:Server3-1>`.

 * `datacore_iscsi_chap_enabled = False`

Sets the CHAP authentication for the iSCSI targets that are used to serve the volume. This option is disabled by default and will allow hosts (OpenStack Compute nodes) to connect to iSCSI storage back-ends without authentication. To enable CHAP authentication, which will prevent hosts (OpenStack Compute nodes) from connecting to back-ends without authentication, set this option to `True`.


In addition, specify the location where the DataCore volume driver will store CHAP secrets by setting the `datacore_iscsi_chap_storage` option.


This option is used in the server group back-end configuration only. The driver will enable CHAP only for involved target ports, therefore, not all DataCore Servers may have CHAP configured. _Before enabling CHAP, ensure that there are no SANsymphony volumes attached to any instances_.

 * `datacore_iscsi_chap_storage = None`

Sets the path to the iSCSI CHAP authentication password storage file.


_CHAP secrets are passed from OpenStack Block Storage to compute in clear text. This communication should be secured to ensure that CHAP secrets are not compromised. This can be done by setting up file permissions. Before changing the CHAP configuration, ensure that there are no SANsymphony volumes attached to any instances_.

## Creating Volume Types

Before using any volume with DataCore SANsymphony server, the corresponding volume type needs to be created and the appropriate `volume_backend_name` needs to be set.
```
(overcloud) $ openstack volume type create datacore
(overcloud) $ openstack volume type set --property volume_backend_name='datacore_iscsi' datacore
```

### Detaching Volumes and Terminating Instances

Notes about the expected behavior of SANsymphony software when detaching volumes and terminating instances in OpenStack:


1. When a volume is detached from a host in OpenStack, the virtual disk will be unserved from the host in SANsymphony, but the virtual disk will not be deleted.
2. If all volumes are detached from a host in OpenStack, the host will remain registered and all virtual disks will be unserved from that host in SANsymphony. The virtual disks will not be deleted.
3. If an instance is terminated in OpenStack, the virtual disk for the instance will be unserved from the host and either be deleted or remain as unserved virtual disk depending on the option selected when terminating.


## Support

In the event that a support bundle is needed, the administrator should save the files from the `/var/log/containers/cinder` directory on the overcloud node where the containerized driver is deployed and attach to DataCore Technical Support incident manually.
