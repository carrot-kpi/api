terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.4.0"
    }
  }
}

resource "digitalocean_vpc" "k8s" {
  name     = "k8s"
  region   = "nyc1"
  ip_range = "10.128.0.0/16"
}

resource "digitalocean_kubernetes_cluster" "main" {
  name         = "api"
  version      = "1.26.5-do.0"
  region       = "nyc1"
  auto_upgrade = true
  vpc_uuid     = digitalocean_vpc.k8s.id

  node_pool {
    name       = "k8s-node"
    size       = "s-1vcpu-2gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 2
  }
}

resource "digitalocean_domain" "main" {
  name = var.base_api_domain
}

resource "digitalocean_record" "ipfs_gateway" {
  domain = digitalocean_domain.main.name
  type   = "A"
  name   = "gateway"
  value  = var.cluster_ingress_ip
}

resource "digitalocean_record" "token_list" {
  domain = digitalocean_domain.main.name
  type   = "A"
  name   = "tokens"
  value  = var.cluster_ingress_ip
}

resource "digitalocean_record" "pinning_proxy" {
  domain = digitalocean_domain.main.name
  type   = "A"
  name   = "pinning-proxy."
  value  = var.cluster_ingress_ip
}
