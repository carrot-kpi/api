# Carrot API

This repository is a collection of files used to manage Carrot KPI's API
deployment on potentially various cloud services (DigitalOcean is the current
choice). The deployment and its management is performed using
[Terraform](https://www.terraform.io/) and the services run on a Kubernetes
cluster with active pods and nodes autoscaling.

## Overview

Under the `./terraform` folder you can find the Terraform files used to
bootstrap the needed infrastructure (ignore the `./local` folder for now). The
following resources are created:

- **k8s Kubernetes cluster**: a `digitalocean_kubernetes_cluster` cluster
  resource that will actually run the API, with autoscaling enabled going from a
  minimum of 1 to up to 3 1 vCPU/2Gb memory nodes.
- **main domain**: a `digitalocean_domain`. The default value is
  `carrot-kpi.dev` and it's pointed to the K8s cluster's ingress through
  Terraform while deploying on DigitalOcean.
- **k8s-balancer certificate**: a [LetsEncrypt](https://letsencrypt.org/)
  certificate of type `digitalocean_certificate` used to enable HTTPS on the K8s
  cluster's main ingress.
- **init_scripts config map**: a config map to mount init scripts into the pod
  so that both Kubo and IPFS cluster can correctly be set up.
- **ipfs_node_swarm service**: the service responsible to allow swarm services
  on both Kubo and IPFS cluster to communicate with the external world.
- **ipfs_node_gateway service**: the service that makes available for internal
  querying (from the ingress) the Kubo gateway API.
- **ipfs_node HPA**: a `kubernetes_horizontal_pod_autoscaler` resource
  responsible to horizontally autoscale the IPFS nodes stateful set when CPU
  utilization goes over a certain limit.
- **ipfs_node stateful set**: a `kubernetes_stateful_set` resource responsible
  to bootstrap and manage the heart of the API: the IPFS nodes through which
  Carrot API data is pinned. Each node pod runs 2 conatiners:
  - `Kubo`: the main and official implementation of an IPFS node in Go.
  - `IPFS cluster`: a sidecar service that allows orchestrating pinning across
    various IPFS nodes so that everything is always up to date across n
    services.
- **main ingress**: the main ingress allows API users to access the API from the
  internet.

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
- `ipfs_storage_volume_size (optional)`: self-describing, this instructs K8s on
  the size of the IPFS storage volume to assign to each IPFS node (defaults to
  100Mb for local deployment and 20Gb for remote deployment).
- `cluster_storage_volume_size (optional)`: self-describing, this instructs K8s
  on the size of the cluster sidecar storage volume to assign to each IPFS node
  (defaults to 100Mb for local deployment and 5Gb for remote deployment).

The other group of variables is strictly related to IPFS setup, and all of them
can be generated using (`ipfs-key`)[https://github.com/whyrusleeping/ipfs-key]
and a few other tricks.

.Let's see how you can install `ipfs-key` in order to generate the necessary
variables...

At the moment of writing, `go install`ing `ipfs-key` directly seems to be broken
(see [here](https://github.com/whyrusleeping/ipfs-key/issues/17)), so you might
need to:

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

The advice here would be to create a `local.tfvars` and/or `remote.tfvars` file
under `./terraform/local` and `./terraform` respectively containing the
definitions for the variables above in the format
`variable_name="value_as_string"`. The 2 files will obviously be applied to 2
different deployment types: one performed locally (below is described how to do
that) and one on DigitalOcean, and should automatically be picked up by
Terraform when executing the various commands.

> **Warning** Absolutely make sure the `tfvars` files are not included in
> version control as they contain sensitive data.

## Deploying the Kubernetes cluster locally

It's possible to deploy and test the Kubernetes cluster locally before creating
it remotely on the chosen cloud provider. In order to do so, make sure you have
installed correctly set up [`Minikube`](https://minikube.sigs.k8s.io/docs/) and
[Terraform](https://developer.hashicorp.com/terraform), and have followed the
section above on how to set variables first (pick reasonable values for the
`ipfs_storage_volume_size` and `cluster_storage_volume_size` variables)

Once you have installed Minikube, start it locally by running `minikube start`
(Minikube should configure `kubectl` so that it can communicate with the locally
created cluster in the process).

Create a `terraform.tfvars` file under `./terraform/local` and populate it
following the "Variables" section above.

The `./terraform/local` folder contains the definition of a local `kubernetes`
provider pointing to the local Minikube cluster (notice the `config_context` and
`config_path` settings), as well as a reference to the `k8s` module that
contains all the Kubernetes cluster configuration to terraform the right
infrastructure. You can use that to create the local cluster in the following
way:

- From the root of the repo, change directory to `./terraform` using
  `cd ./terraform`.
- Run `terraform -chdir=./local init`.
- Let Terraform plan the execution of the creation of the infrastructure using
  `terraform -chdir=./local plan -out tfplan`. This command will create a binary
  `tfplan` under `./local/` that Terraform can use to execute the infrastructure
  creation in a deterministic way. Carefully examine what Terraform has planned
  to do by either looking at the terminal (the command should print out the
  plan) or by converting the more detailed `tfplan` binary file to a human
  readable format (JSON) using
  `terraform show -json ./local/tfplan | jq > tfplan.json` (the output JSON file
  will be put under `./terraform`).
- Once you have confirmed everything looks right in the Terraform plan, go ahead
  and apply it using `terraform -chdir=./local apply tfplan`.

If you see that Terraform takes a while while creating services, you might need
to run `minikube tunnel`, while if it gets stuck creating ingresses, you might
need to run `minikube addons enable ingress`

You should now see Terraform applying your K8s cluster configuration to the
local Minikube cluster and you should now be able to use `kubectl` as usual to
monitor the cluster, or start up the K8s dashboard by running
`minikube dashboard` in a terminal.

If and when you want to destroy the resources inside the cluster, just run
`terraform -chdir=./local destroy`.

The default ingress through which you can get access to all the APIs has by
default a host of `carrot-kpi.local`. In order to correctly communicate with it
run `kubectl get ingress` and take note of the IP address of the ingress. You
can then add an entry to the `/etc/hosts` file as follows:

```
carrot-kpi.local  <ingress-ip-address>
```

If you now go to
`http://carrot-kpi.local/ipfs/QmQPeNsJPyVWPFDVHb77w8G42Fvo15z4bG2X8D2GhfbSXc/readme`,
you should see the page correctly in the browser.
