FROM registry.redhat.io/rhosp-rhel8/openstack-cinder-volume:16.1
MAINTAINER DataCore Software, Inc.

LABEL name="rhosp16.1/openstack-cinder-volume-datacore" \
      maintainer="DataCore Software, Inc." \
      vendor="DataCore" \
      version="1.0" \
      release="1" \
      summary="DataCore Software Openstack Cinder Plugin" \
      description="DataCore Software Openstack Cinder Plugin"

USER root

ARG LICENSE_PATH="/licenses"
ARG CINDER_PATH="/usr/lib/python3.6/site-packages/cinder/volume/drivers/datacore"

# install python module websocket_client (dependent module for Datacore Cinder driver)
RUN pip3 install websocket_client==0.54.0

RUN mkdir -p ${CINDER_PATH}
RUN mkdir -p ${LICENSE_PATH}
COPY datacore ${CINDER_PATH}
COPY licensing.txt ${LICENSE_PATH}

USER cinder
