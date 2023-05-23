terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.9.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "aws" {
  source = "./aws"
}

provider "digitalocean" {
  token = var.do_token
}

module "do" {
  source = "./do"

  do_token           = var.do_token
  cluster_ingress_ip = module.k8s.cluster_ingress_ip
  base_api_domain    = var.base_api_domain
}

provider "kubernetes" {
  host                   = module.do.k8s_cluster_endpoint
  token                  = module.do.k8s_cluster_token
  cluster_ca_certificate = module.do.k8s_cluster_certificate
}

provider "kubectl" {
  host                   = module.do.k8s_cluster_endpoint
  token                  = module.do.k8s_cluster_token
  cluster_ca_certificate = module.do.k8s_cluster_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.do.k8s_cluster_endpoint
    token                  = module.do.k8s_cluster_token
    cluster_ca_certificate = module.do.k8s_cluster_certificate
  }
}

module "k8s" {
  source = "./k8s"

  bootstrap_peer_id               = var.bootstrap_peer_id
  bootstrap_peer_private_key      = var.bootstrap_peer_private_key
  cluster_secret                  = var.cluster_secret
  base_api_domain                 = var.base_api_domain
  ws_rpc_url_sepolia              = var.ws_rpc_url_sepolia
  ws_rpc_url_gnosis               = var.ws_rpc_url_gnosis
  ws_rpc_url_scroll_testnet       = var.ws_rpc_url_scroll_testnet
  local                           = false
  ipfs_storage_volume_size        = var.ipfs_storage_volume_size
  cluster_storage_volume_size     = var.cluster_storage_volume_size
  persistent_volume_storage_class = "do-block-storage-retain"
}
