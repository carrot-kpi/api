#!/bin/sh

set -x

if [ -f /data/ipfs/repo.lock ]; then
  echo "removing ipfs repo lock file"
  rm /data/ipfs/repo.lock
fi

ipfs init --profile="server"

chown -R ipfs /data/ipfs

exit 0