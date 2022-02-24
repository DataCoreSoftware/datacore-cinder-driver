# Copyright (c) 2017 DataCore Software Corp. All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

"""Fibre Channel Driver for DataCore SANsymphony storage array."""

from oslo_log import log as logging

from cinder import exception as cinder_exception
from cinder.i18n import _
from cinder import interface
from cinder import utils as cinder_utils
from cinder.volume.drivers.datacore import driver
from cinder.volume.drivers.datacore import exception as datacore_exception
from cinder.volume.drivers.datacore import utils as datacore_utils
from oslo_utils import excutils


LOG = logging.getLogger(__name__)


@interface.volumedriver
class FibreChannelVolumeDriver(driver.DataCoreVolumeDriver):
    """DataCore SANsymphony Fibre Channel volume driver.

    Version history:

    .. code-block:: none

        1.0.0 - Initial driver

    """

    VERSION = '1.0.0'
    STORAGE_PROTOCOL = 'FC'
    CI_WIKI_NAME = 'DataCore_CI'

    def __init__(self, *args, **kwargs):
        super(FibreChannelVolumeDriver, self).__init__(*args, **kwargs)

    def validate_connector(self, connector):
        """Fail if connector doesn't contain all the data needed by the driver.

        :param connector: Connector information
        """

        required_data = ['host', 'wwpns']
        for required in required_data:
            if required not in connector:
                LOG.error("The volume driver requires %(data)s "
                          "in the connector.", {'data': required})
                raise cinder_exception.InvalidConnectorException(
                    missing=required)

    def initialize_connection(self, volume, connector):
        """Allow connection to connector and return connection info.

        :param volume: Volume object
        :param connector: Connector information
        :return: Connection information
        """

        LOG.debug("Initialize connection for volume %(volume)s for "
                  "connector %(connector)s.",
                  {'volume': volume['id'], 'connector': connector})

        virtual_disk = self._get_virtual_disk_for(volume, raise_not_found=True)

        if virtual_disk.DiskStatus != 'Online':
            LOG.warning("Attempting to attach virtual disk %(disk)s "
                        "that is in %(state)s state.",
                        {'disk': virtual_disk.Id,
                         'state': virtual_disk.DiskStatus})

        server_group = self._get_our_server_group()

        @cinder_utils.synchronized(
            'datacore-backend-%s' % server_group.Id, external=True)
        def serve_virtual_disk():
            available_ports = self._api.get_ports()

            connector_wwpns = list(wwpn.replace('-', '').lower()
                                   for wwpn in connector['wwpns'])

            fc_initiator = self._get_initiator(connector['host'],
                                               connector_wwpns,
                                               available_ports)

            fc_targets = self._get_targets(virtual_disk, available_ports)
            if not fc_targets:
                msg = (_("Suitable targets not found for "
                    "virtual disk %(disk)s for volume %(volume)s.")
                    % {'disk': virtual_disk.Id, 'volume': volume['id']})
                LOG.error(msg)
                raise cinder_exception.VolumeDriverException(message=msg)

            virtual_logical_units = self._map_virtual_disk(
                    virtual_disk, fc_targets, fc_initiator)
            return fc_targets, virtual_logical_units

        targets, logical_units = serve_virtual_disk()

        connection_data = {}

        connection_data = {
            'target_discovered': False,
            'target_lun': logical_units[targets[0]].Lun.Quad,
            'target_wwn': targets[0].PortName.replace('-', '').lower(),
            'volume_id': volume['id'],
            'access_mode': 'rw',
        }

        LOG.debug("Connection data: %s", connection_data)

        return {
            'driver_volume_type': 'fibre_channel',
            'data': connection_data,
        }

    def _get_online_ports(self, online_servers):
        ports = self._api.get_ports()
        online_ports = {port.Id: port for port in ports
                        if port.HostId in online_servers}

        return online_ports

    def _get_online_devices(self, online_ports):
        devices = self._api.get_target_devices()
        online_devices = {device.Id: device for device in devices
                          if device.TargetPortId in online_ports}

        return online_devices

    def _get_initiator(self, host, connector_wwpns, available_ports):
        client = self._get_client(host, create_new=True)

        fc_initiator_ports = self._get_host_fc_initiator_ports(
            client, available_ports)

        fc_initiator = datacore_utils.get_first_or_default(
            lambda port: True if(port.PortName in connector_wwpns) else False,
            fc_initiator_ports,
            None)

        if not fc_initiator:
            wwn='-'.join(a + b for a, b in zip(*[iter(connector_wwpns[0].upper())]*2))
            scsi_port_data = self._api.build_scsi_port_data(
                client.Id, wwn, 'Initiator', 'FibreChannel')
            fc_initiator = self._api.register_port(scsi_port_data)

        return fc_initiator

    @staticmethod
    def _get_host_fc_initiator_ports(host, ports):
        return [port for port in ports
                if port.PortType == 'FibreChannel'
                and port.PortMode == 'Initiator'
                and port.HostId == host.Id]

    def _get_targets(self, virtual_disk, available_ports):
        fc_target_ports = self._get_frontend_fc_target_ports(
            available_ports)
        server_port_map = {}

        for target_port in fc_target_ports:
            if target_port.HostId in server_port_map:
                server_port_map[target_port.HostId].append(target_port)
            else:
                server_port_map[target_port.HostId] = [target_port]
        fc_targets = []
        if virtual_disk.FirstHostId in server_port_map:
            fc_targets += server_port_map[virtual_disk.FirstHostId]
        if virtual_disk.SecondHostId in server_port_map:
            fc_targets += server_port_map[virtual_disk.SecondHostId]
        return fc_targets

    def _is_fc_frontend_port(self, port):
        if (port.PortType == 'FibreChannel'
                and port.PortMode == 'Target'
                and port.HostId):
           if (port.PresenceStatus == 'Present'):
               port_roles = port.ServerPortProperties.Role.split()
               port_state = (port.StateInfo.State)
               if 'Frontend' in port_roles and port_state == 'LoopLinkUp':
                     return True
        return False

    def _get_frontend_fc_target_ports(self, ports):
        return [target_port for target_port in ports
                if self._is_fc_frontend_port(target_port)]

    def _map_virtual_disk(self, virtual_disk, targets, initiator):
        logical_disks = self._api.get_logical_disks()

        logical_units = {}
        created_mapping = {}
        created_devices = []
        created_domains = []
        try:
            for target in targets:
                target_domain = self._get_target_domain(target, initiator)
                if not target_domain:
                    target_domain = self._api.create_target_domain(
                        initiator.HostId, target.HostId)
                    created_domains.append(target_domain)

                nexus = self._api.build_scsi_port_nexus_data(
                    initiator.Id, target.Id)

                target_device = self._get_target_device(
                    target_domain, target, initiator)
                if not target_device:
                    target_device = self._api.create_target_device(
                        target_domain.Id, nexus)
                    created_devices.append(target_device)

                logical_disk = self._get_logical_disk_on_host(
                    virtual_disk.Id, target.HostId, logical_disks)
                logical_unit = self._get_logical_unit(
                    logical_disk, target_device)
                if not logical_unit:
                    logical_unit = self._create_logical_unit(
                        logical_disk, nexus, target_device)
                    created_mapping[logical_unit] = target_device
                logical_units[target] = logical_unit
        except Exception:
            with excutils.save_and_reraise_exception():
                LOG.exception("Mapping operation for virtual disk %(disk)s "
                              "failed with error.",
                              {'disk': virtual_disk.Id})
                try:
                    for logical_unit in created_mapping:
                        nexus = self._api.build_scsi_port_nexus_data(
                            created_mapping[logical_unit].InitiatorPortId,
                            created_mapping[logical_unit].TargetPortId)
                        self._api.unmap_logical_disk(
                            logical_unit.LogicalDiskId, nexus)
                    for target_device in created_devices:
                        self._api.delete_target_device(target_device.Id)
                    for target_domain in created_domains:
                        self._api.delete_target_domain(target_domain.Id)
                except datacore_exception.DataCoreException as e:
                    LOG.warning("An error occurred on a cleanup after "
                                "failed mapping operation: %s.", e)

        return logical_units

    def _get_target_domain(self, target, initiator):
        target_domains = self._api.get_target_domains()
        target_domain = datacore_utils.get_first_or_default(
            lambda domain: (domain.InitiatorHostId == initiator.HostId
                            and domain.TargetHostId == target.HostId),
            target_domains,
            None)
        return target_domain

    def _get_target_device(self, target_domain, target, initiator):
        target_devices = self._api.get_target_devices()
        target_device = datacore_utils.get_first_or_default(
            lambda device: (device.TargetDomainId == target_domain.Id
                            and device.InitiatorPortId == initiator.Id
                            and device.TargetPortId == target.Id),
            target_devices,
            None)
        return target_device

    def _get_logical_unit(self, logical_disk, target_device):
        logical_units = self._api.get_logical_units()
        logical_unit = datacore_utils.get_first_or_default(
            lambda unit: (unit.LogicalDiskId == logical_disk.Id
                          and unit.VirtualTargetDeviceId == target_device.Id),
            logical_units,
            None)
        return logical_unit

    def _create_logical_unit(self, logical_disk, nexus, target_device):
        free_lun = self._api.get_next_free_lun(target_device.Id)
        logical_unit = self._api.map_logical_disk(logical_disk.Id,
                                                  nexus,
                                                  free_lun,
                                                  logical_disk.ServerHostId,
                                                  'Client')
        return logical_unit

    @staticmethod
    def _get_logical_disk_on_host(virtual_disk_id,
                                  host_id, logical_disks):
        logical_disk = datacore_utils.get_first(
            lambda disk: (disk.ServerHostId == host_id
                          and disk.VirtualDiskId == virtual_disk_id),
            logical_disks)
        return logical_disk
