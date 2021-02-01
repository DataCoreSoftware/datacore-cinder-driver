# DataCore SANsymphony Cinder volume driver for RHOSP16.1

## Overview

This page provides detailed steps on how to install containerized Cinder driver plugin for DataCore SANsymphony in a RHOSP 16.1 environment.

## Prerequisites

* Deployed overcloud with director as per the instructions in [Director Installation and Usage Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.1/html-single/director_installation_and_usage/index).

* DataCore SANsymphony server deployed and configured.

## Steps

There are two options to deploy the containerized cinder driver based on the overcloud nodes' network configuration where the cinder service is configured. In this example, cinder service is installed in a controller node. If the controller node is able to access external network then follow the first option. Otherwise the container image has to be pulled a priori in the director and it can be deployed from the local registry. Both options are described below.


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

Create an environment file similar to [datacore-cinder-backend-env.yaml](https://github.com/DataCoreSoftware/datacore-cinder-driver/blob/master/RHOSP16.1/datacore-cinder-backend-env.yaml) in `/home/stack/templates/`. Populate the `<sansymphony_management_ip_addr>`, `<username>`, `<password>` and `<diskpoolname>` as per your SANsymphony server environment. If multiple SANsymphony servers are present, then you can configure multiple backends as well, please refer [Custom Block Storage Back End Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.1/html-single/custom_block_storage_back_end_deployment_guide/index) for further details.

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
$ sudo podman pull registry.connect.redhat.com/datacore-software/openstack-cinder-volume-datacore-rhosp-16-1:latest
```

1.3	Run `podman images` command to verify if the container got pulled successfully or not
```
$ sudo podman images
REPOSITORY                                                                                            TAG      IMAGE ID       CREATED       SIZE
registry.connect.redhat.com/datacore-software/openstack-cinder-volume-datacore-rhosp-16-1             latest   4f62b1537b8d   6 weeks ago   1.45 GB
```

1.4	Add tag to the image created

In the below command, datacore-director.ctlplane.localdomain:8787 acts as local registry.
```
$ sudo podman tag <image id> datacore-director.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-volume-datacore-rhosp-16-1:latest
```

1.5	Run `podman images` command to verify the repository and tag is correctly updated to the docker image

```
$ sudo podman images
REPOSITORY                                                                                            TAG      IMAGE ID       CREATED       SIZE
datacore-director.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-volume-datacore-rhosp-16-1   latest   4f62b1537b8d   6 weeks ago   1.45 GB
```

1.6	Push the container to a local registry

```
$ sudo openstack tripleo container image push --local datacore-director.ctlplane.localdomain:8787/rhosp-rhel8/openstack-cinder-volume-datacore-rhosp-16-1:latest
```

1.7	Create environment file

Create an environment file similar to [datacore-cinder-config.yaml](https://github.com/DataCoreSoftware/datacore-cinder-driver/blob/master/RHOSP16.1/datacore-cinder-config.yaml) in `/home/stack/templates/`. Populate the `<sansymphony_management_ip_addr>`, `<username>`, `<password>` and `<diskpoolname>` as per your SANsymphony server environment. Update the `<local_registry>` also. If multiple SANsymphony servers are present, then you can configure multiple backends as well, please refer [Custom Block Storage Back End Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.1/html-single/custom_block_storage_back_end_deployment_guide/index) for further details.

1.8	Re-deploy overcloud

```
$ openstack overcloud deploy --templates \
    -e [existing environment files]
    ...
    -e /home/stack/templates/datacore-cinder-config.yaml
```

