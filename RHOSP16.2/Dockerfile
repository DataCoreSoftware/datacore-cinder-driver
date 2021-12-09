FROM registry.redhat.io/rhosp-rhel8/openstack-cinder-volume:16.2
MAINTAINER DataCore Software, Inc.

LABEL name="rhosp16.2/openstack-cinder-volume-datacore" \
      maintainer="DataCore Software, Inc." \
      vendor="DataCore" \
      version="1.1" \
      release="2" \
      summary="DataCore Software Openstack Cinder Plugin" \
      description="DataCore Software Openstack Cinder Plugin"

USER root

ARG LICENSE_PATH="/licenses"
ARG CINDER_PATH="/usr/lib/python3.6/site-packages/cinder/volume/drivers/datacore"

RUN yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical --sec-severity=Moderate

# install python module websocket_client (dependent module for Datacore Cinder driver)
RUN pip3 install websocket_client==0.54.0

RUN mkdir -p ${CINDER_PATH}
RUN mkdir -p ${LICENSE_PATH}
COPY datacore ${CINDER_PATH}
COPY licensing.txt ${LICENSE_PATH}

USER cinder
