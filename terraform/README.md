<br />

<p align="center">
    <img src=".github/static/logo.svg" alt="Carrot logo" width="60%" />
</p>

<br />

<p align="center">
    Carrot is a web3 protocol trying to make incentivization easier and more capital
    efficient.
</p>

<br />

<p align="center">
    <img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPL v3">
</p>

# Carrot API infra

This repository is a collection of files used to manage Carrot KPI's API
infrastructure deployment on potentially various cloud service providers
(DigitalOcean is the current choice). The deployment and its management is
performed using [Terraform](https://www.terraform.io/) and the services run on a
Kubernetes cluster.

## Overview

Under the `./terraform` folder you can find the Terraform files used to
bootstrap the needed infrastructure (ignore the `./local` folder for now). The
following main resources are created:

- **S3 bucket**: a `aws_s3_bucket` is created to store certain resources.
- **S3 bucket object**: a `aws_s3_bucket_object` is created to store the hero
  video in the previously created S3 bucket.
- **Cloudfront distribution**: a `aws_cloudfront_distribution` is created to
  serve contents from the previously created S3 bucket.
- **Cluster VPC**: a `digitalocean_vpc` for the cluster.
- **Kubernetes cluster**: the `digitalocean_kubernetes_cluster` resource that
  will actually run the K8s cluster, with autoscaling enabled going from a
  minimum of 1 to up to 2 1 vCPU/2Gb memory nodes.
- **Base API domain**: a `digitalocean_domain` that will be the base of the API
  domain. An `api` A record will be added so that `api.<base-api-domain>` will
  point to the cluster's ingress load balancer through the next resource. The
  actual domain name can be set through the `base_api_domain` variable.
- **Gateway domain A record setting**: a `digitalocean_record` that will add an
  A record to the API domain to correctly point to the cluster's ingress load
  balancer, once deployed. The A record's hostname is `gateway` (it will access
  the IPFS gateway API).
- **Token list domain A record setting**: a `digitalocean_record` that will add
  an A record to the API domain to correctly point to the cluster's ingress load
  balancer, once deployed. The A record's hostname is `tokens` (it will access
  the token list served through the static server).
- **Initizalization scripts config map**: a config map to mount initialization
  scripts into the IPFS node pods so that both Kubo and IPFS cluster can
  correctly be set up.
- **IPFS nodes stateful set**: a `kubernetes_stateful_set` resource responsible
  to bootstrap and manage the heart of the API: the IPFS nodes through which
  Carrot API data is pinned. Each node pod runs 2 conatiners:
  - `Kubo`: the main and official implementation of an IPFS node in Go.
  - `IPFS cluster`: a sidecar service that allows orchestrating pinning across
    various IPFS nodes so that everything is always up to date across
    potentially many nodes.
- **IPFS pinner deployment**: a `kubernetes_deployment` resource responsible to
  bootstrap and manage an
  [IPFS pinner](https://github.com/carrot-kpi/ipfs-pinner) instance for each
  supported chain.
- **NGINX ingress**: a `helm_release` that installs the NGINX ingress server
  theough which the main ingress load balancer is bootstrapped. A few custom
  annotations are applied to govern DigitalOcean's behavior when instantiating
  the load balancer cloud resource.
- **Cert manager**: a `helm_release` that installs Cert Manager and its custom
  resource definitions on the cluster. Cert manager helps managing SSL
  certificates for ingresses.
- **Cert manager staging Let's Encrypt issuer**: a `kubectl_manifest` that adds
  a staging Let's Encrypt certificate issuer.
- **Cert manager prod Let's Encrypt issuer**: a `kubectl_manifest` that adds a
  prod Let's Encrypt certificate issuer.
- **IPFS node service**: a `kubernetes_service_v1` internal service that allows
  internal communication between nodes and external communication to Kubo's
  gateway API through the ingress load balancer rules.
- **IPFS gateway ingress**: an ingress that allows calls to the
  `gateway.<base-api-domain>` host to be redirected to the backend IPFS node
  service. It leverages the NGINX ingress controller and the Let's Encrypt prod
  certificate issuer.
- **NGINX configuration config map**: this config map is used to mount the
  `nginx` static server configuration under `/etc/nginx/conf.d` so that it can
  be picked up by the `nginx` container. Static files can be served by it.
- **Build token list null resource**: an empty resource used to trigger a build
  of the token list in the token list repo submodule and nothing else.
- **Static files config map**: this config map is used to mount static files in
  the `nginx` static server under `/usr/share/nginx/html` so that static files
  can be served by it.
- **Static server deployment**: a deployment for a `nginx` server used to serve
  static files. The configuration is mounted through the `nginx` configuration
  config map mentioned above and static files through the static files config
  map mentioned above.
- **Static server service**: an internal service used to communicate with the
  static server.
- **Token list ingress**: an ingress that allows calls to the
  `tokens.<base-api-domain>` host to be redirected to the backend static server
  service. It leverages the NGINX ingress controller and the Let's Encrypt prod
  certificate issuer.

It's worth noting that even the Kubernetes cluster configuration is managed
through Terraform thanks to the Kubernetes provider provided by Hashicorp. This
allows a couple different things, such as having the same configuration language
for everything and allowing Terraform to have a better overview of what
resources need to be created/destroyed at each `apply`/`destroy` command even
inside the cluster, resulting in an improved lifecycle management overall.

## Variables

In order to perform the deployment either locally (see below) or remotely, a few
variables need to be provided to correctly set up the infrastructure. For
simplicity, we divide the variables in 2 groups depending on how they need to be
generated/determined. The first group is the one of generic variables, and these
are:

- `do_token`: this one is only needed if performing the deployment remotely on
  DigitalOcean, and it's the DigitalOcean API token. See
  [here](https://docs.digitalocean.com/reference/api/create-personal-access-token/)
  for how to create one.
- `api_domain`: the domain that will point to the API ingress.
- `ws_rpc_url_sepolia`: a websocket RPC URL to index contract events on Sepolia
  (needed by the IPFS pinner).
- `ws_rpc_url_gnosis`: a websocket RPC URL to index contract events on Gnosis
  (needed by the IPFS pinner).
- `ws_rpc_url_scroll_testnet`: a websocket RPC URL to index contract events on
  the Scroll testnet (needed by the IPFS pinner).
- `ipfs_storage_volume_size (optional)`: self-describing, this instructs K8s on
  the size of the IPFS storage volume to assign to each IPFS node (defaults to
  100Mb for local deployment and 20Gb for remote deployment).
- `cluster_storage_volume_size (optional)`: self-describing, this instructs K8s
  on the size of the cluster sidecar storage volume to assign to each IPFS node
  (defaults to 100Mb for local deployment and 5Gb for remote deployment).

The other group of variables is strictly related to IPFS and IPFS cluster's
setup, and all of them can be generated using
[`ipfs-key`](https://github.com/whyrusleeping/ipfs-key) and a few other tricks.

Let's see how you can install `ipfs-key` in order to generate the necessary
variables...

The first step is to have Go installed on your system. Have a look
[here](https://go.dev/doc/install) on how to do it. At the moment of writing,
`go install`ing `ipfs-key` directly seems to be broken (see
[here](https://github.com/whyrusleeping/ipfs-key/issues/17)), so you might need
to:

- Clone the [IPFS key repo](https://github.com/whyrusleeping/ipfs-key).
- `cd` into it.
- Run `go install` to install the needed dependencies.
- Run `go run main.go | base64 -w 0`. This should print to the screen a private
  key ID and the base64 encoded private key itself. Save the two values
  somewhere as you'll need them.

After having done the above, you should be able to set the following variables:

- `bootstrap_peer_id`: an identifier for the boostrap peer in the IPFS nodes
  cluster (in our case the boostrap node is the first IPFS node pod to be
  created in the stateful set). This must be the private key ID you have
  generated with IPFS key following the short guide above.
- `bootstrap_peer_private_key`: the bootstrap peer private key in the IPFS nodes
  cluster. This must be the base64-encoded private key you have generated with
  IPFS key following the short guide above.
- `cluster_secret`: this is a base64-encoded 32 byte random value that can be
  generated by running `od -vN 32 -An -tx1 /dev/urandom | tr -d ' \n'`
- `cluster_rest_api_basic_auth_credentials`: a username-password map that
  determines who can access the cluster's REST API.

The advice here would be to create a `terraform.tfvars` file under either
`./terraform/local` or `./terraform` (depending on where you want to perform the
deployment) containing the definitions for the variables above in the format
`variable_name="value_as_string"`. The 2 files should automatically be picked up
by Terraform when executing for example the `apply` command.

> **Warning** Absolutely make sure the `tfvars` files are not included in
> version control as they contain sensitive data. A `.gitignore` rule should
> take care of that, but be extra cautious.

In addition to the above, it's necessary to have AWS credentials configured
locally in order to perform the remote deployment. See
[here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
on how to create the file and be sure to have it ready before applying the
Terraform config.

## Deploying the Kubernetes cluster locally

It's possible to deploy and test the Kubernetes cluster locally before creating
it remotely on DigitalOcean. In order to do so, make sure you have installed and
correctly set up [`Minikube`](https://minikube.sigs.k8s.io/docs/) and
[Terraform](https://developer.hashicorp.com/terraform), and have followed the
section above on how to set variables first (pick reasonable values for the
`ipfs_storage_volume_size` and `cluster_storage_volume_size` variables)

Once you have installed Minikube, start it locally by running `minikube start`.
Now, run `minikube tunnel` if you want to be able to use the main ingress.

Create a `terraform.tfvars` file under `./terraform/local` and populate it
following the "variables" section above.

The `./terraform/local` folder contains the definition of a local `kubernetes`
and `helm` providers pointing to the local Minikube cluster (notice the
`config_context` and `config_path` settings in both providers), as well as a
reference to the `k8s` module that contains all the Kubernetes cluster
configuration to terraform the right infrastructure. You can use that to create
the local cluster in the following way:

- From the root of the repo, change directory to `./terraform/local` using
  `cd ./terraform/local`.
- Run `terraform init`.
- Let Terraform plan the execution of the creation of the infrastructure using
  `terraform plan -out tfplan`. This command will create a binary `tfplan` under
  `./terraform/local/` that Terraform can use to execute the infrastructure
  creation in a deterministic way. Carefully examine what Terraform has planned
  to do by either looking at the terminal (the command should print out the
  plan) or by converting the more detailed `tfplan` binary file to a human
  readable format (JSON) using `terraform show -json tfplan | jq > tfplan.json`
  (the output JSON file will be put under `./terraform/local`).
- Once you have confirmed that everything looks right in the Terraform plan, go
  ahead and apply it using `terraform apply tfplan`.

You should now see Terraform applying your K8s cluster configuration to the
local Minikube cluster and you should now be able to use `kubectl` as usual to
monitor the cluster, or start up the K8s dashboard by running
`minikube dashboard` in a terminal.

If and when you want to destroy the resources inside the cluster, just run
`terraform destroy`.

The default ingress through which you can get access to all the APIs has by
default a host of `carrot-kpi.local`, so in order to correctly communicate with
it run `kubectl get ingress` and take note of the IP address of the ingress. You
can then add an entry to the `/etc/hosts` file as follows:

```
gateway.carrot-kpi.local  <ingress-ip-address>
```

If you now go to
`http://gateway.carrot-kpi.local/ipfs/QmQPeNsJPyVWPFDVHb77w8G42Fvo15z4bG2X8D2GhfbSXc/readme`,
you should see the page correctly in the browser, as pulled from IPFS.
