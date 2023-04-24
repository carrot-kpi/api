provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

module "k8s" {
  source = "../k8s"

  bootstrap_peer_id               = var.bootstrap_peer_id
  bootstrap_peer_private_key      = var.bootstrap_peer_private_key
  cluster_secret                  = var.cluster_secret
  base_api_domain                 = "carrot-kpi.local"
  local                           = true
  ipfs_storage_volume_size        = var.ipfs_storage_volume_size
  cluster_storage_volume_size     = var.cluster_storage_volume_size
  persistent_volume_storage_class = "standard"
}
