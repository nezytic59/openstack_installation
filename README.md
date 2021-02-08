# Install Openstack(victoria) (Before execute this shell, make sure Reinstall Ubuntu 18.04 on your computer)
It should be connected by two LAN lines.

$ifconfig

After checking the interface, copy the INTERFACE_ID that inet is not set (like eno2 or enx~~)

$./openstack_install.sh ${INTERFACE_ID}(on root)

Set Openstack Dashboard Password
