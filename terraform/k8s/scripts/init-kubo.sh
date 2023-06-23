#!/bin/sh

set -x

if [ -f /data/ipfs/repo.lock ]; then
  echo "removing ipfs repo lock file"
  rm /data/ipfs/repo.lock
fi

ipfs init --profile="server"

# the peers include pinata and web3.storage, in order
peers= <<EOF
[
      {
        "ID": "QmWaik1eJcGHq1ybTWe7sezRfqKNcDRNkeBaLnGwQJz1Cj",
        "Addrs": [
          "/dnsaddr/fra1-1.hostnodes.pinata.cloud"
        ]
      },
      {
        "ID": "QmNfpLrQQZr5Ns9FAJKpyzgnDL2GgC6xBug1yUZozKFgu4",
        "Addrs": [
          "/dnsaddr/fra1-2.hostnodes.pinata.cloud"
        ]
      },
      {
        "ID": "QmPo1ygpngghu5it8u4Mr3ym6SEU2Wp2wA66Z91Y1S1g29",
        "Addrs": [
          "/dnsaddr/fra1-3.hostnodes.pinata.cloud"
        ]
      },
      {
        "ID": "QmRjLSisUCHVpFa5ELVvX3qVPfdxajxWJEHs9kN3EcxAW6",
        "Addrs": [
          "/dnsaddr/nyc1-1.hostnodes.pinata.cloud"
        ]
      },
      {
        "ID": "QmPySsdmbczdZYBpbi2oq2WMJ8ErbfxtkG8Mo192UHkfGP",
        "Addrs": [
          "/dnsaddr/nyc1-2.hostnodes.pinata.cloud"
        ]
      },
      {
        "ID": "QmSarArpxemsPESa6FNkmuu9iSE1QWqPX2R3Aw6f5jq4D5",
        "Addrs": [
          "/dnsaddr/nyc1-3.hostnodes.pinata.cloud"
        ]
      },
      {
        "ID": "12D3KooWPySxxWQjBgX9Jp6uAHQfVmdq8HG1gVvS1fRawHNSrmqW",
        "Addrs": [
          "/ip4/147.75.33.191/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWQYBPcvxFnnWzPGEx6JuBnrbF1FZq4jTahczuG2teEk1m",
        "Addrs": [
          "/ip4/147.75.80.9/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWDdzN3snjaMJEH9zuq3tjKUFpYHeSGNkiAreF6dQSbCiL",
        "Addrs": [
          "/ip4/147.75.80.39/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWEzCun34s9qpYEnKkG6epx2Ts9oVGRGnzCvM2s2edioLA",
        "Addrs": [
          "/ip4/147.75.80.143/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWQE3CWA3MJ1YhrYNP8EE3JErGbrCtpKRkFrWgi45nYAMn",
        "Addrs": [
          "/ip4/147.75.84.119/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWDYVuVFGb9Yj6Gi9jWwSLqdnzZgqJg1a1scQMDc4R6RUJ",
        "Addrs": [
          "/ip4/147.75.84.175/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWSafoW6yrSL7waghFAaiCqGy5mdjpQx4jn4CRNqbG7eqG",
        "Addrs": [
          "/ip4/147.75.84.173/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWJEfH2MB4RsUoaJPogDPRWbFTi8iehsxsqrQpiJwFNDrP",
        "Addrs": [
          "/ip4/136.144.57.15/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWHpE5KiQTkqbn8KbU88ZxwJxYJFaqP4mp9Z9bhNPhym9V",
        "Addrs": [
          "/ip4/147.75.63.131/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWBHvsSSKHeragACma3HUodK5FcPUpXccLu2vHooNsDf9k",
        "Addrs": [
          "/ip4/147.75.62.95/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWMaTJKNwQJyP1fw3ftGb5uqqM2U24Kam8aWqMRXzWHNiF",
        "Addrs": [
          "/ip4/147.75.50.77/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWNCmYvqPbeXmNC4rnTr7hbuVtJKDNpL1vvNz6mq9Sr2Xf",
        "Addrs": [
          "/ip4/147.75.50.141/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWDRak1XzURGh9MvGR4EWaP9kcbmdoagAcGMcNxBXXLzTF",
        "Addrs": [
          "/ip4/147.28.147.193/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWRi18oHN1j8McxS9RMnuibcTwxu6VCTYHyLNH2R14qhTy",
        "Addrs": [
          "/ip4/139.178.69.93/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWKhPb9tSnCqBswVfC5EPE7iSTXhbF4Ywwz2MKg5UCagbr",
        "Addrs": [
          "/ip4/139.178.91.227/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWAdxvJCV5KXZ6zveTJmnYGrSzAKuLUKZYkZssLk7UKv4i",
        "Addrs": [
          "/ip4/139.178.91.231/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWRgXWwnZQJgdW1GHW7hJ5UvZ8MLp7HBCSWS596PypAs8M",
        "Addrs": [
          "/ip4/147.75.49.91/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWPbxiW4wFYHs7MwCQNqK9YVedH7QYZXJKMFVduhwR1Lcs",
        "Addrs": [
          "/ip4/139.178.88.145/tcp/4001"
        ]
      },
      {
        "ID": "12D3KooWSH5uLrYe7XSFpmnQj1NCsoiGeKSRCV7T5xijpX2Po2aT",
        "Addrs": [
          "/ip4/145.40.90.155/tcp/4001"
        ]
      }
    ]
EOF

ipfs config --json Peering.Peers "$peers"

chown -R ipfs /data/ipfs

exit 0
