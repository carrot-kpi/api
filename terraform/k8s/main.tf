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

resource "kubernetes_secret" "pinning_proxy" {
  metadata {
    name      = "pinning-proxy"
    namespace = kubernetes_namespace.api.metadata.0.name
  }

  data = {
    pinning_proxy_jwt_secret   = var.pinning_proxy_jwt_secret
    postgres_user              = var.postgres_user
    postgres_password          = var.postgres_password
    postgres_connection_string = "postgresql://${var.postgres_user}:${var.postgres_password}@127.0.0.1:5432/pinning-proxy"
  }
}

resource "kubernetes_secret" "ipfs_node" {
  metadata {
    name      = "ipfs-node"
    namespace = kubernetes_namespace.api.metadata.0.name
  }

  data = {
    bootstrap_peer_private_key              = var.bootstrap_peer_private_key
    cluster_secret                          = var.cluster_secret
    cluster_rest_api_user                   = var.cluster_rest_api_user
    cluster_rest_api_password               = var.cluster_rest_api_password
    cluster_rest_api_basic_auth_credentials = "${var.cluster_rest_api_user}:${var.cluster_rest_api_password}"
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

resource "kubernetes_secret" "pinner_config" {
  metadata {
    name      = "pinner-config"
    namespace = kubernetes_namespace.api.metadata.0.name
  }

  data = {
    "config.yaml" = templatefile("${path.module}/resources/pinner-config.yaml", {
      web3_storage_api_key      = var.web3_storage_api_key,
      ws_rpc_url_gnosis         = var.ws_rpc_url_gnosis,
      ws_rpc_url_sepolia        = var.ws_rpc_url_sepolia,
      ws_rpc_url_scroll_testnet = var.ws_rpc_url_scroll_testnet
    })
  }
}

resource "kubernetes_stateful_set" "ipfs_node" {
  metadata {
    name      = "ipfs-node"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    service_name = "ipfs-node"
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
            name           = "kubo-swarm-tcp"
            protocol       = "TCP"
            container_port = 4001
          }
          port {
            name           = "kubo-swarm-udp"
            protocol       = "UDP"
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
              port = "kubo-swarm-tcp"
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
            name = "CLUSTER_RESTAPI_BASICAUTHCREDENTIALS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ipfs_node.metadata.0.name
                key  = "cluster_rest_api_basic_auth_credentials"
              }
            }
          }
          env {
            name  = "CLUSTER_MONITOR_PING_INTERVAL"
            value = "3m"
          }
          env {
            name  = "CLUSTER_IPFSPROXY_LISTENMULTIADDRESS"
            value = "/ip4/0.0.0.0/tcp/9095"
          }
          env {
            name  = "CLUSTER_RESTAPI_HTTPLISTENMULTIADDRESS"
            value = "/ip4/0.0.0.0/tcp/9094"
          }
          env {
            name  = "BOOTSTRAP_PEER_ID"
            value = var.bootstrap_peer_id
          }
          port {
            name           = "cluster-rest"
            protocol       = "TCP"
            container_port = 9094
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

resource "kubernetes_deployment" "ipfs_pinner" {
  metadata {
    name      = "ipfs-pinner"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    selector {
      match_labels = {
        app = "pinner"
      }
    }
    template {
      metadata {
        labels = {
          app = "pinner"
        }
      }
      spec {
        container {
          name              = "pinner"
          image             = "luzzif/carrot-kpi-ipfs-pinner:v0.6.0"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "CONFIG_PATH"
            value = "/custom/config.yaml"
          }
          volume_mount {
            name       = "pinner-config"
            mount_path = "/custom"
          }
        }
        volume {
          name = "pinner-config"
          secret {
            secret_name = "pinner-config"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_stateful_set.ipfs_node
  ]
}

resource "kubernetes_stateful_set" "pinning-proxy" {
  metadata {
    name      = "pinning-proxy"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    service_name = "pinning-proxy"
    selector {
      match_labels = {
        app = "pinning-proxy"
      }
    }
    template {
      metadata {
        labels = {
          app = "pinning-proxy"
        }
      }
      spec {
        container {
          name              = "pinning-proxy"
          image             = "luzzif/carrot-kpi-pinning-proxy:v0.5.0"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "HOST"
            value = "0.0.0.0"
          }
          env {
            name  = "PORT"
            value = 2222
          }
          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pinning_proxy.metadata.0.name
                key  = "pinning_proxy_jwt_secret"
              }
            }
          }
          env {
            name = "DB_CONNECTION_STRING"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pinning_proxy.metadata.0.name
                key  = "postgres_connection_string"
              }
            }
          }
          env {
            name  = "IPFS_CLUSTER_BASE_URL"
            value = "http://ipfs-node:9094"
          }
          env {
            name = "IPFS_CLUSTER_AUTH_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ipfs_node.metadata.0.name
                key  = "cluster_rest_api_user"
              }
            }
          }
          env {
            name = "IPFS_CLUSTER_AUTH_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ipfs_node.metadata.0.name
                key  = "cluster_rest_api_password"
              }
            }
          }
          port {
            name           = "api"
            protocol       = "TCP"
            container_port = 2222
          }
          liveness_probe {
            tcp_socket {
              port = "api"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
            period_seconds        = 15
          }
        }
        container {
          name  = "postgres"
          image = "postgres:latest"
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pinning_proxy.metadata.0.name
                key  = "postgres_user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pinning_proxy.metadata.0.name
                key  = "postgres_password"
              }
            }
          }
          env {
            name  = "POSTGRES_DB"
            value = "pinning-proxy"
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          port {
            name           = "postgres"
            protocol       = "TCP"
            container_port = 5432
          }
          liveness_probe {
            tcp_socket {
              port = "postgres"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
            period_seconds        = 10
          }
          volume_mount {
            name       = "db-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name      = "db-storage"
        namespace = kubernetes_namespace.api.metadata.0.name
      }
      spec {
        storage_class_name = var.persistent_volume_storage_class
        access_modes       = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.postgres_storage_volume_size
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_stateful_set.ipfs_node,
    kubernetes_deployment.ipfs_pinner,
  ]
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
      name        = "kubo-swarm-udp"
      protocol    = "UDP"
      port        = 4001
      target_port = "kubo-swarm-udp"
    }
    port {
      name        = "kubo-swarm-tcp"
      protocol    = "TCP"
      port        = 4001
      target_port = "kubo-swarm-tcp"
    }
    port {
      name        = "cluster-swarm"
      port        = 9096
      target_port = "cluster-swarm"
    }
    port {
      name        = "cluster-proxy"
      port        = 9095
      target_port = "cluster-proxy"
    }
    port {
      name        = "cluster-rest"
      port        = 9094
      target_port = "cluster-rest"
    }
  }
}

resource "kubernetes_service_v1" "ipfs_node_0_swarm" {
  metadata {
    name      = "ipfs-node-0-swarm"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    type = "LoadBalancer"
    selector = {
      app = "node"
      "statefulset.kubernetes.io/pod-name" : "ipfs-node-0"
    }
    port {
      name        = "kubo-swarm-udp"
      port        = 4001
      protocol    = "UDP"
      target_port = "kubo-swarm-udp"
    }
    port {
      name        = "kubo-swarm-tcp"
      port        = 4001
      protocol    = "TCP"
      target_port = "kubo-swarm-tcp"
    }
  }
}

resource "kubernetes_service_v1" "ipfs_node_1_swarm" {
  metadata {
    name      = "ipfs-node-1-swarm"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    type = "LoadBalancer"
    selector = {
      app = "node"
      "statefulset.kubernetes.io/pod-name" : "ipfs-node-1"
    }
    port {
      name        = "kubo-swarm-udp"
      port        = 4001
      protocol    = "UDP"
      target_port = "kubo-swarm-udp"
    }
    port {
      name        = "kubo-swarm-tcp"
      port        = 4001
      protocol    = "TCP"
      target_port = "kubo-swarm-tcp"
    }
  }
}

resource "kubernetes_service_v1" "pinning_proxy" {
  metadata {
    name      = "pinning-proxy"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    selector = {
      app = "pinning-proxy"
    }
    port {
      name        = "api"
      port        = 2222
      protocol    = "TCP"
      target_port = "api"
    }
  }
}

locals {
  ipfs_gateway_domain  = "gateway.${var.base_api_domain}"
  pinning_proxy_domain = "pinning-proxy.${var.base_api_domain}"
}

resource "kubernetes_ingress_v1" "ipfs_gateway" {
  wait_for_load_balancer = true
  metadata {
    name      = "ipfs-gateway"
    namespace = kubernetes_namespace.api.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class"                       = "nginx"
      "cert-manager.io/issuer"                            = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/limit-rps"             = 50
      "nginx.ingress.kubernetes.io/limit-req-status-code" = 429
    }
  }
  spec {
    tls {
      hosts       = [local.ipfs_gateway_domain]
      secret_name = "ipfs-gateway-ingress-tls"
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

resource "kubernetes_ingress_v1" "pinning_proxy" {
  wait_for_load_balancer = true
  metadata {
    name      = "pinning-proxy"
    namespace = kubernetes_namespace.api.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class"                       = "nginx"
      "cert-manager.io/issuer"                            = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/limit-rps"             = 20
      "nginx.ingress.kubernetes.io/limit-req-status-code" = 429
    }
  }
  spec {
    tls {
      hosts       = [local.pinning_proxy_domain]
      secret_name = "pinning-proxy-ingress-tls"
    }
    rule {
      host = local.pinning_proxy_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.pinning_proxy.metadata.0.name
              port {
                number = 2222
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

resource "kubernetes_config_map" "static_server_nginx_config" {
  metadata {
    name      = "static-server-nginx-config"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  data = {
    "default.conf" = file("${path.module}/nginx/static-server.conf")
  }
}

resource "kubernetes_config_map" "static_files" {
  metadata {
    name      = "static-server-static-files"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  data = {
    "tokens.json" = file("${path.module}/token-list/out/list.json")
  }
}

resource "kubernetes_deployment" "static_server" {
  metadata {
    name      = "static-server"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    selector {
      match_labels = {
        app = "static-server"
      }
    }
    replicas = 1
    template {
      metadata {
        labels = {
          app = "static-server"
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/nginx/conf.d"
          }
          volume_mount {
            name       = "static-files"
            mount_path = "/usr/share/nginx/html"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.static_server_nginx_config.metadata.0.name
          }
        }
        volume {
          name = "static-files"
          config_map {
            name = kubernetes_config_map.static_files.metadata.0.name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "static_server" {
  metadata {
    name      = "static-server"
    namespace = kubernetes_namespace.api.metadata.0.name
  }
  spec {
    selector = {
      app = "static-server"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}


locals {
  token_list_domain = "tokens.${var.base_api_domain}"
}

resource "kubernetes_ingress_v1" "token_list" {
  wait_for_load_balancer = true
  metadata {
    name      = "token-list"
    namespace = kubernetes_namespace.api.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class"                       = "nginx"
      "cert-manager.io/issuer"                            = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/limit-rps"             = 10
      "nginx.ingress.kubernetes.io/limit-req-status-code" = 429
    }
  }
  spec {
    tls {
      hosts       = [local.token_list_domain]
      secret_name = "token-list-ingress-tls"
    }
    rule {
      host = local.token_list_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.static_server.metadata.0.name
              port {
                name = "http"
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
