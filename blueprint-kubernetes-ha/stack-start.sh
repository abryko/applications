#!/bin/bash
set -e
echo "Blueprint Kubernetes HA"
echo "-----------------------"
if [[ -z "$OS_PASSWORD" ]]
then
  cat <<EOF
  You must set OS_USERNAME / OS_PASSWORD / OS_TENANT_NAME / OS_AUTH_URL ...
  The simple way to do this is to follow theses instructions:

  - Bring your Cloudwatt credentials and go to this url : https://console.cloudwatt.com/project/access_and_security/api_access/openrc/
  - If you are not connected, fill your Cloudwatt username / password
  - A file suffixed by openrc.sh will be downloaded, once complete, type in your terminal :
    source COMPUTE-[...]-openrc.sh
EOF
  exit 1
fi
cat <<EOF
Openstack credentials :
Username: $OS_USERNAME
Password: *************
Tenant name: $OS_TENANT_NAME
Authentication url: $OS_AUTH_URL
Region: $OS_REGION_NAME
-----------------------
EOF
KEYS=$(nova keypair-list | egrep '\|.*' | tail -n +2 | cut -d' ' -f 2)
echo "What is your keypair name ?"
select KEYPAIR in $KEYS
do
  echo "Key selected: $KEYPAIR"
  break;
done

echo "Do you want to deploy Ceph (distributed storage) in your cluster ?"
select CEPH in yes no
do
  case "$CEPH" in
    yes) CEPH="true" ;;
    no)  CEPH="false" ;;
  esac
  echo "Ceph: $CEPH"
  break;
done
echo "Do you want to create a new cluster or join an existing one ?"
select MODE in Create Join
do
  echo "Mode: $MODE"
  break;
done
if [ "${MODE}" == "Join" ]
then
  read -p "Enter the peer Public IP: " PEER
  if [ "${PEER}" == "" ]; then echo "Peer cannot be empty"; exit 1; fi
else
  TOKEN=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

read -p "Enter the secret token (default: $TOKEN): " TOKEN_C
if [ "${TOKEN_C}" != "" ]; then TOKEN=$TOKEN_C; fi
if [ "$(echo -n $TOKEN | wc -c | sed 's/ //g')" != "16" ]; then echo "Token must be 16 alphanumeric characters"; exit 1; fi

read -p "How do you want to name this stack : " NAME
if [ "${NAME}" == "" ]; then echo "Name cannot be empty"; exit 1; fi

if [ "${MODE}" == "Create" ]
then
  heat stack-create -f stack-$OS_REGION_NAME.yml -P keypair_name=$KEYPAIR -P token=$TOKEN -P ceph=$CEPH $NAME
else
  heat stack-create -f stack-$OS_REGION_NAME.yml -P keypair_name=$KEYPAIR -P token=$TOKEN -P ceph=$CEPH -P peer=$PEER $NAME
fi

until heat stack-show $NAME 2> /dev/null | egrep 'CREATE_COMPLETE|CREATE_FAILED'
do
  echo "Waiting for stack to be ready..."
  sleep 10
done

if heat stack-show $NAME 2> /dev/null | grep CREATE_FAILED
then
  echo "Error while creating stack"
  exit 1
fi

for output in $(heat output-list $NAME 2> /dev/null | egrep '\|.*' | tail -n +2 | cut -d' ' -f 2)
do
  echo "$output: $(heat output-show $NAME $output 2> /dev/null)"
done
