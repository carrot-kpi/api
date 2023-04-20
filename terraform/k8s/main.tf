resource "kubernetes_service_v1" "ipfs_node_internal" {
  metadata {
    name = "ipfs-node-internal"
    labels = {
      app = "ipfs-node-internal"
    }
  }
  spec {
    selector = {
      app = "node"
    }
    port {
      name        = "kubo-gateway"
      port        = 8080
      target_port = "kubo-gateway"
    }
    port {
      name        = "kubo-swarm"
      port        = 4001
      target_port = "kubo-swarm"
    }
    port {
      name        = "cluster-proxy"
      port        = 9095
      target_port = "cluster-proxy"
    }
    port {
      name        = "cluster-swarm"
      port        = 9096
      target_port = "cluster-swarm"
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
      api_version = "apps/v1"
      kind        = "StatefulSet"
      name        = "ipfs-node"
    }
    min_replicas = 2
    max_replicas = 3
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
    service_name = "ipfs-node-internal"
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
          resources {
            limits = {
              cpu = "500m"
            }
            requests = {
              cpu = "250m"
            }
          }
          volume_mount {
            name       = "init-scripts"
            mount_path = "/custom"
          }
        }
        container {
          name              = "kubo"
          image             = "ipfs/kubo:latest"
          image_pull_policy = "IfNotPresent"
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
          resources {
            limits = {
              cpu = "500m"
            }
            requests = {
              cpu = "250m"
            }
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
            name           = "cluster-proxy"
            protocol       = "TCP"
            container_port = 9095
          }
          port {
            name           = "cluster-swarm"
            protocol       = "TCP"
            container_port = 9096
          }
          resources {
            limits = {
              cpu = "500m"
            }
            requests = {
              cpu = "250m"
            }
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
        container {
          name              = "pinner-gnosis"
          image             = "luzzif/carrot-kpi-ipfs-pinner:v0.3.1"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "IPFS_API_ENDPOINT"
            value = "http://localhost:9095"
          }
          env {
            name  = "WS_RPC_ENDPOINT"
            value = "wss://rpc.gnosischain.com/wss"
          }
        }
        container {
          name              = "pinner-sepolia"
          image             = "luzzif/carrot-kpi-ipfs-pinner:v0.3.1"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "IPFS_API_ENDPOINT"
            value = "http://localhost:9095"
          }
          env {
            name  = "WS_RPC_ENDPOINT"
            value = "wss://sepolia.infura.io/ws/v3/963198614f2a452e9e4927f94b3320cd"
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

resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name = "nginx-config"
  }
  data = {
    "use-gzip" = "true"
  }
}

resource "kubernetes_ingress_v1" "main" {
  metadata {
    name = "api"
    annotations = var.local ? {
      "nginx.ingress.kubernetes.io/enable-cors"        = "true"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, OPTIONS"
      } : {
      "kubernetes.digitalocean.com/load-balancer-id"              = "k8s-ingress"
      "service.beta.kubernetes.io/do-loadbalancer-certificate-id" = "k8s-ingress"
      "nginx.ingress.kubernetes.io/enable-cors"                   = "true"
      "nginx.ingress.kubernetes.io/cors-allow-methods"            = "GET, OPTIONS"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = var.local ? "carrot-kpi.local" : "carrot-kpi.dev"
      http {
        path {
          path = "/ipfs"
          backend {
            service {
              name = "ipfs-node-internal-service"
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
