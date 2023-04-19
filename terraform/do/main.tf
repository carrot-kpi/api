terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

resource "digitalocean_kubernetes_cluster" "k8s" {
  name         = "api"
  version      = "1.26.3-do.0"
  region       = "nyc1"
  auto_upgrade = true

  node_pool {
    name       = "worker-pool"
    size       = "s-1vcpu-2gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 3
  }
}

resource "digitalocean_domain" "main" {
  name       = "carrot-kpi.dev"
  ip_address = data.kubernetes_ingress.main.status[0].load_balancer[0].ingress[0].ip
}

resource "digitalocean_certificate" "k8s-balancer" {
  name    = "k8s-balancer"
  type    = "lets_encrypt"
  domains = [digitalocean_domain.main.name]
}

