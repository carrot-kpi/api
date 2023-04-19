terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  alias = "do"
  host  = data.digitalocean_kubernetes_cluster.example.endpoint
  token = data.digitalocean_kubernetes_cluster.example.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.example.kube_config[0].cluster_ca_certificate
  )
}

module "k8s" {
  source = "./k8s"

  bootstrap_peer_id               = var.bootstrap_peer_id
  bootstrap_peer_private_key      = var.bootstrap_peer_private_key
  cluster_secret                  = var.cluster_secret
  ipfs_storage_volume_size        = var.ipfs_storage_volume_size
  cluster_storage_volume_size     = var.cluster_storage_volume_size
  persistent_volume_storage_class = "do-block-storage-retain"
  local                           = false
}

module "digitalocean" {
  source = "./do"

  do_token = var.do_token
}
