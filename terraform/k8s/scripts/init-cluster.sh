#!/bin/sh

user=ipfs

# if the cluster sidecar hasn't been initialized, do it
if [ ! -f /data/ipfs-cluster/service.json ]; then
    ipfs-cluster-service init
fi

PEER_HOSTNAME=`cat /proc/sys/kernel/hostname`

grep -q ".ipfs-node-0.*" /proc/sys/kernel/hostname
if [ $? -eq 0 ]; then
    CLUSTER_ID=${BOOTSTRAP_PEER_ID} \
    CLUSTER_PRIVATEKEY=${BOOTSTRAP_PEER_PRIVATE_KEY} \
    exec ipfs-cluster-service daemon --upgrade --leave
else
    exec ipfs-cluster-service daemon --upgrade --bootstrap /dns4/ipfs-node-0.ipfs-node/tcp/9096/ipfs/${BOOTSTRAP_PEER_ID} --leave
fi