# Install Openstack(victoria) (Before execute this shell, make sure Clean Ubuntu 18.04 on your computer)
It should be connected by 2 LAN lines.

$ ifconfig

$ chmod 700 openstack.sh

After checking the interface, copy the INTERFACE_ID that inet is not set (like eno2 or enx~~)

$ ./openstack_install.sh ${INTERFACE_ID}(on root)

Set Openstack Dashboard Password
