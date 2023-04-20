terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

resource "digitalocean_vpc" "k8s" {
  name     = "k8s"
  region   = "nyc1"
  ip_range = "10.10.10.0/24"
}

resource "digitalocean_firewall" "k8s" {
  name = "k8s"

  # enable ipfs swarm
  inbound_rule {
    source_kubernetes_ids = digitalocean_kubernetes_cluster.main
    protocol              = "tcp"
    port_range            = "4001"
  }

  outbound_rule {
    destination_addresses = ["0.0.0.0/0", "::/0"]
    protocol              = "tcp"
    port_range            = "4001"
  }

  inbound_rule {
    source_kubernetes_ids = digitalocean_kubernetes_cluster.main
    protocol              = "udp"
    port_range            = "4002"
  }

  outbound_rule {
    destination_addresses = ["0.0.0.0/0", "::/0"]
    protocol              = "udp"
    port_range            = "4002"
  }
}

resource "digitalocean_kubernetes_cluster" "main" {
  name         = "api"
  version      = "1.26.3-do.0"
  region       = "nyc1"
  auto_upgrade = true
  vpc_uuid     = digitalocean_vpc.k8s.id

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

resource "digitalocean_certificate" "k8s-ingress" {
  name    = "k8s-ingress"
  type    = "lets_encrypt"
  domains = [digitalocean_domain.main.name]
}

resource "digitalocean_project" "main" {
  name      = "api"
  resources = [digitalocean_kubernetes_cluster.main.urn, digitalocean_domain.main.urn]
}
