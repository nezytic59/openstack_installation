#! /bin/bash

DEVSTACK_PATH='/opt/stack/devstack'
LOCAL_INTERFACE=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
SECOND_INTERFACE=${1}
LOCAL_CONF='/opt/stack/devstack/local.conf'
HOST_IP=`hostname -I | cut -d ' ' -f1`
OPENSTACK_PATH="/usr/local/bin/openstack"

### Make sure only root can run our script
if (( $EUID != 0 )); then
	echo "This script must be run as root"
	echo $EUID
	exit
fi

### Translate sources
sed -i 's/kr.archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
sed -i 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list

### Update and Upgrade
apt update && apt dist-upgrade -y

### Make stack user
useradd -s /bin/bash -d /opt/stack -m stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

### Install Devstack
if [ -f $DEVSTACK_PATH ]; then
	echo "devstack file exist"
else
	echo "devstack file not exist"
        su - stack -c "git clone https://github.com/59nezytic/devstack.git"
fi

while :
do	
	echo -e '\nEnter Your Openstack PASSWD: '
	read -s PASSWD
	echo -e 'Check Your Openstack PASSWD: '
	read -s CHECK_PASSWD

	if [ $PASSWD == $CHECK_PASSWD ]; then
		break
	else
		echo 'PASSWORD is not correct'
	fi
done
echo ''

### Check local.conf File
while :
do
	if [ ! -e $LOCAL_CONF ]; then
		echo "Make local.conf file"
		touch $LOCAL_CONF
		echo -e '[[local|localrc]]\nHOST_IP='${HOST_IP}'\nMULTI_HOST=True\n\nADMIN_PASSWORD='${PASSWD}\
		'\nDATABASE_PASSWORD=$ADMIN_PASSWORD\nRABBIT_PASSWORD=$ADMIN_PASSWORD\nSERVICE_PASSWORD=$ADMIN_PASSWORD\nSERVICE_TOKEN=$ADMIN_PASSWORD'\
		'\n\nFLAT_INTERFACE='${SECOND_INTERFACE}''\
	       '\n\nLOGFILE=$DEST/logs/stack.sh.log\nLOGDAYS=2\nLOG_COLOR=True\n\n#Barbican\n#enable_plugin barbican'\
	       'https://opendev.org/openstack/barbican stable/victoria\n\ndisable_service tempest\ndisable_service c-vol cinder c-sch c-bak c-api'\
	       '\n\nUSE_PYTHON3=True\n\n#Disable security groups\nQ_USE_SECGROUP=False'\
	       '\nLIBVIRT_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver'\
	       '\n\n[[post-config|/etc/neutron/dhcp_agent.ini]]\n[DEFAULT]\nenable_isolated_metadata=True\n' >> $LOCAL_CONF
		break
	else
		rm -rf $LOCAL_CONF
		echo 'Delete original local.conf'
	fi
done

### Fix outfilter.py
OUTFILTER_PATH='/opt/stack/devstack/tools/outfilter.py'
sed -i "s/outfile.write(ts_line.encode('utf-8'))/outfile.write(ts_line.encode('utf-8','surrogatepass'))/g" $OUTFILTER_PATH

### Start Install Openstack
su - stack -c "devstack/stack.sh"

### Ovs setting
su - stack -c "sudo ovs-vsctl add-port br-ex ${SECOND_INTERFACE}"

### Start openrc
source ${DEVSTACK_PATH}/openrc admin admin

### Setting SEC_GROUP
SEC_ID="$(${OPENSTACK_PATH} security group list --project admin | grep default | cut -f 2 -d ' ')"

while :
do
	RULE_ID="$(${OPENSTACK_PATH} security group rule list ${SEC_ID} | grep None | sed -n '1p' | cut -f 2 -d ' ')"
	if [ -z "${RULE_ID}"  ]; then
		echo "SEC_GROUP Delete Complete !"
		break
	fi
	${OPENSTACK_PATH} security group rule delete ${RULE_ID}

done

${OPENSTACK_PATH} security group rule create ${SEC_ID} --protocol any --egress
${OPENSTACK_PATH} security group rule create ${SEC_ID} --protocol any --ingress
${OPENSTACK_PATH} security group rule create ${SEC_ID} --protocol tcp --dst-port 22:22

### Setting Public Network
ROUTER_ID="$(${OPENSTACK_PATH} router list | grep ACTIVE | cut -f 2 -d ' ')"
PORT_ID_1="$(${OPENSTACK_PATH} router show router1 | grep "port_id" | cut -f 4 -d '"')"
PORT_ID_2="$(${OPENSTACK_PATH} router show router1 | grep "port_id" | cut -f 16 -d '"')"

${OPENSTACK_PATH} router remove port router1 ${PORT_ID_1}
${OPENSTACK_PATH} router remove port router1 ${PORT_ID_2}
${OPENSTACK_PATH} router delete ${ROUTER_ID}

PUBLIC_ID="$(${OPENSTACK_PATH} network list | grep public | cut -f 2 -d ' ')"
${OPENSTACK_PATH} network delete ${PUBLIC_ID}

${OPENSTACK_PATH} network create --project admin --provider-network-type flat --provider-physical-network public --share --external public

HOST_IP_1=`echo ${HOST_IP} | cut -f 1 -d '.'` 
HOST_IP_2=`echo ${HOST_IP} | cut -f 2 -d '.'` 
HOST_IP_3=`echo ${HOST_IP} | cut -f 3 -d '.'` 

HOST_IP_CIDR=${HOST_IP_1}"."${HOST_IP_2}"."${HOST_IP_3}".0/24"
GATEWAY=${HOST_IP_1}"."${HOST_IP_2}"."${HOST_IP_3}".1"
DNS_SERVER="8.8.8.8"

${OPENSTACK_PATH} subnet create --project admin --network public --subnet-range ${HOST_IP_CIDR} --gateway ${GATEWAY} --dns-nameserver ${DNS_SERVER} --ip-version 4 public_subnet

### Download Ubuntu Image 18.04
FILE_ID="1gWL91lkHUjH8Mm-mIRj-LPDk9joUDtKI"
IMAGE="ubuntu_18.04.img"

wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=${FILE_ID}' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=${FILE_ID}" -O ${IMAGE} && rm -rf /tmp/cookies.txt

${OPENSTACK_PATH} image create --disk-format raw --file /root/openstack_installation/${IMAGE} --shared ubuntu_18.04

echo "********************OPENSTACK INSTALLATION AND BASIC SETTING IS FINISHED !!!!********************"