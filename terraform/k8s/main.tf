terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

resource "kubernetes_namespace" "api" {
  metadata {
    name = "api"
  }
}

resource "kubernetes_secret" "ipfs_node" {
  metadata {
    name      = "ipfs-node"
    namespace = kubernetes_namespace.api.metadata.0.name
  }

  data = {
    bootstrap_peer_private_key = var.bootstrap_peer_private_key
    cluster_secret             = var.cluster_secret
  }
}

resource "kubernetes_config_map" "init_scripts" {
  metadata {
    name      = "init-scripts"
    namespace = kubernetes_namespace.api.metadata.0.name
  }

  data = {
    "init-kubo.sh"    = "${file("${path.module}/scripts/init-kubo.sh")}"
    "init-cluster.sh" = "${file("${path.module}/scripts/init-cluster.sh")}"
  }
}

resource "kubernetes_stateful_set" "ipfs_node" {
  metadata {
    name      = "ipfs-node"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    service_name = "ipfs-node-internal"
    selector {
      match_labels = {
        app = "node"
      }
    }
    replicas = 2
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
            name  = "SERVICE_NAME"
            value = kubernetes_service_v1.ipfs_node.metadata.0.name
          }
          env {
            name = "BOOTSTRAP_PEER_PRIVATE_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ipfs_node.metadata.0.name
                key  = "bootstrap_peer_private_key"
              }
            }
          }
          env {
            name = "CLUSTER_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ipfs_node.metadata.0.name
                key  = "cluster_secret"
              }
            }
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
        name      = "cluster-storage"
        namespace = kubernetes_namespace.api.metadata.0.name
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
        name      = "ipfs-storage"
        namespace = kubernetes_namespace.api.metadata.0.name
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

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "nginx"
  create_namespace = true

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/do-loadbalancer-name"
    value = "k8s-ingress"
  }

  values = [
    file("${path.module}/charts/nginx-ingress-values.yaml")
  ]
}

resource "helm_release" "cert_manager" {
  count = var.local ? 0 : 1

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubectl_manifest" "letsencrypt_issuer_staging" {
  count = var.local ? 0 : 1

  yaml_body = templatefile("${path.module}/resources/cert-issuer-staging.yaml", {
    namespace = kubernetes_namespace.api.metadata.0.name
  })

  depends_on = [
    helm_release.cert_manager
  ]
}

resource "kubectl_manifest" "letsencrypt_issuer_prod" {
  count = var.local ? 0 : 1

  yaml_body = templatefile("${path.module}/resources/cert-issuer-prod.yaml", {
    namespace = kubernetes_namespace.api.metadata.0.name
  })

  depends_on = [
    helm_release.cert_manager
  ]
}

resource "kubernetes_service_v1" "ipfs_node" {
  metadata {
    name      = "ipfs-node"
    namespace = kubernetes_namespace.api.metadata.0.name
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
      name        = "cluster-swarm"
      port        = 9096
      target_port = "cluster-swarm"
    }
  }
}

locals {
  ipfs_gateway_domain = "gateway.${var.base_api_domain}"
}

resource "kubernetes_ingress_v1" "main" {
  wait_for_load_balancer = true
  metadata {
    name      = "api"
    namespace = kubernetes_namespace.api.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/issuer"      = "letsencrypt-prod"
    }
  }
  spec {
    tls {
      hosts       = [local.ipfs_gateway_domain]
      secret_name = "ingress-tls"
    }
    rule {
      host = local.ipfs_gateway_domain
      http {
        path {
          path      = "/ipfs"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.ipfs_node.metadata.0.name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.nginx_ingress,
    helm_release.cert_manager,
    kubectl_manifest.letsencrypt_issuer_staging,
    kubectl_manifest.letsencrypt_issuer_prod
  ]
}
