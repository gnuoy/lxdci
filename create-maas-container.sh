#!/bin/bash

create_vm () {
    NAME=$1
    lxc launch ubuntu:22.04 $LXC_NAME
    lxc exec $LXC_NAME -- bash -c 'while [ "$(systemctl is-system-running 2>/dev/null)" != "running" ] && [ "$(systemctl is-system-running 2>/dev/null)" != "degraded" ]; do :; done'
    lxc file push /home/liam/.ssh/id_rsa.pub $LXC_NAME/home/ubuntu/.ssh/authorized_keys
}

LXC_NAME=$(petname)
echo $LXC_NAME
create_vm $LXC_NAME
IP=$(lxc ls -f compact  -c4 $LXC_NAME | awk '/eth0/ {print $1}')
ssh-keyscan -H $IP >> ~/.ssh/known_hosts
echo $IP

VENV=$(mktemp -d)
python3 -m venv $VENV
source $VENV/bin/activate
pip install ansible netaddr
echo $VENV
cd /home/liam/branches/maas-ansible-playbook
MAAS_URL="http://$IP:5240/MAAS"


echo "
# Define hosts for MAAS here

[maas_corosync]

[maas_pacemaker:children]
maas_corosync

[maas_postgres]
ubuntu@$IP

[maas_postgres_proxy]

[maas_proxy]

[maas_region_controller]
ubuntu@$IP

[maas_rack_controller]
ubuntu@$IP
" > $VENV/hosts

echo "$VENV/hosts"

ansible-playbook -i $VENV/hosts --extra-vars="maas_installation_type=snap maas_version=3.2 maas_postgres_password=example maas_url=$MAAS_URL" ./site.yaml

echo "sudo iptables -t nat -A PREROUTING -i enp5s0 -p tcp --dport 6240 -j DNAT --to-destination $IP:5240"

#lxc exec $LXC_NAME -- maas createadmin --username lambdaadmin --password lambdaadmin  --email duff@lambdal.com
#API_KEY=$(lxc exec $LXC_NAME -- maas apikey --username=lambdaadmin)

SECRET=$(lxc exec $LXC_NAME -- cat /var/snap/maas/common/maas/secret)
API_KEY=$(lxc exec $LXC_NAME -- maas apikey --username=admin)
echo $API_KEY
