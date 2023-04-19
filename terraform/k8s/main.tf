resource "kubernetes_service_v1" "ipfs_node_swarm" {
  metadata {
    name = "ipfs-node-swarm"
    labels = {
      app = "ipfs-node-swarm"
    }
  }
  spec {
    type = "LoadBalancer"
    port {
      name        = "kubo-swarm"
      target_port = "kubo-swarm"
      port        = 4001
    }
    port {
      name        = "cluster-swarm"
      target_port = "cluster-swarm"
      port        = 9096
    }
    selector = {
      app = "node"
    }
  }
}

resource "kubernetes_service_v1" "ipfs_node_gateway" {
  metadata {
    name = "ipfs-node-gateway"
    labels = {
      app = "ipfs-node-gateway"
    }
  }
  spec {
    port {
      name        = "kubo-gateway"
      target_port = "kubo-gateway"
      port        = 8080
    }
    selector = {
      app = "node"
    }
  }
}

resource "kubernetes_config_map" "init_scripts" {
  metadata {
    name = "init-scripts"
  }

  data = {
    "init-kubo.sh"    = "${file("${path.module}/scripts/init-kubo.sh")}"
    "init-cluster.sh" = "${file("${path.module}/scripts/init-cluster.sh")}"
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "ipfs_node" {
  metadata {
    name = "ipfs-node"
  }
  spec {
    scale_target_ref {
      kind = "StatefulSet"
      name = "ipfs-node"
    }
    min_replicas = 2
    max_replicas = 4
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 85
        }
      }
    }
  }
}

resource "kubernetes_stateful_set" "ipfs_node" {
  metadata {
    name = "ipfs-node"
  }
  spec {
    service_name = "ipfs-node"
    selector {
      match_labels = {
        app = "node"
      }
    }
    template {
      metadata {
        labels = {
          app = "node"
        }
      }
      spec {
        init_container {
          name    = "init-kubo"
          image   = "ipfs/kubo:latest"
          command = ["sh", "/custom/init-kubo.sh"]
          volume_mount {
            name       = "init-scripts"
            mount_path = "/custom"
          }
        }
        container {
          name              = "kubo"
          image             = "ipfs/kubo:latest"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "IPFS_FD_MAX"
            value = "4096"
          }
          port {
            name           = "kubo-swarm"
            protocol       = "TCP"
            container_port = 4001
          }
          port {
            name           = "kubo-api"
            protocol       = "TCP"
            container_port = 5001
          }
          port {
            name           = "kubo-gateway"
            protocol       = "TCP"
            container_port = 8080
          }
          liveness_probe {
            tcp_socket {
              port = "kubo-swarm"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
            period_seconds        = 15
          }
          volume_mount {
            name       = "ipfs-storage"
            mount_path = "/data/ipfs"
          }
          volume_mount {
            name       = "init-scripts"
            mount_path = "/custom"
          }
        }
        container {
          name    = "cluster"
          image   = "ipfs/ipfs-cluster:latest"
          command = ["sh", "/custom/init-cluster.sh"]
          env {
            name  = "BOOTSTRAP_PEER_PRIVATE_KEY"
            value = var.bootstrap_peer_private_key
          }
          env {
            name  = "CLUSTER_SECRET"
            value = var.cluster_secret
          }
          env {
            name  = "CLUSTER_MONITOR_PING_INTERVAL"
            value = "3m"
          }
          env {
            name  = "BOOTSTRAP_PEER_ID"
            value = var.bootstrap_peer_id
          }
          port {
            name           = "http"
            protocol       = "TCP"
            container_port = 9095
          }
          port {
            name           = "cluster-swarm"
            protocol       = "TCP"
            container_port = 9096
          }
          liveness_probe {
            tcp_socket {
              port = "cluster-swarm"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
            period_seconds        = 10
          }
          volume_mount {
            name       = "cluster-storage"
            mount_path = "/data/ipfs-cluster"
          }
          volume_mount {
            name       = "init-scripts"
            mount_path = "/custom"
          }
        }
        volume {
          name = "init-scripts"
          config_map {
            name = "init-scripts"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "cluster-storage"
      }
      spec {
        storage_class_name = var.persistent_volume_storage_class
        access_modes       = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.cluster_storage_volume_size
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "ipfs-storage"
      }
      spec {
        storage_class_name = var.persistent_volume_storage_class
        access_modes       = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.ipfs_storage_volume_size
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "main" {
  metadata {
    name = "ipfs-cluster"
    annotations = var.local ? {} : {
      "kubernetes.digitalocean.com/load-balancer-id"              = "k8s-balancer"
      "service.beta.kubernetes.io/do-loadbalancer-certificate-id" = "k8s-balancer"
    }
  }
  spec {
    rule {
      host = var.local ? "carrot-kpi.local" : "carrot-kpi.dev"
      http {
        path {
          path = "/ipfs"
          backend {
            service {
              name = "ipfs-node-gateway"
              port {
                name = "kubo-gateway"
              }
            }
          }
        }
      }
    }
  }
}
