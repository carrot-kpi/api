#!/bin/sh

user=ipfs

if [ ! -f /data/ipfs-cluster/service.json ]; then
    ipfs-cluster-service init
fi

if [ "$(cat /proc/sys/kernel/hostname)" == "ipfs-node-0" ]; then
    CLUSTER_ID=${BOOTSTRAP_PEER_ID} \
    CLUSTER_PRIVATEKEY=${BOOTSTRAP_PEER_PRIVATE_KEY} \
    exec ipfs-cluster-service daemon --upgrade --leave
else
    exec ipfs-cluster-service daemon --upgrade --bootstrap /dns4/ipfs-node-internal.default.svc.cluster.local/tcp/9096/ipfs/${BOOTSTRAP_PEER_ID} --leave
fi