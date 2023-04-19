#!/bin/sh

set -x

if [ -f /data/ipfs/repo.lock ]; then
  echo "removing ipfs repo lock file"
  rm /data/ipfs/repo.lock
fi

ipfs init --profile="server,badgerds"
ipfs config Datastore.StorageMax 180GB
ipfs config --json Swarm.ConnMgr.HighWater 2000
ipfs config --json Datastore.BloomFilterSize 1048576

chown -R ipfs /data/ipfs

exit 0