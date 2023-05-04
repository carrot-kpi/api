data "kubernetes_ingress_v1" "main" {
  metadata {
    name      = kubernetes_ingress_v1.ipfs_gateway.metadata.0.name
    namespace = kubernetes_namespace.api.metadata.0.name
  }
}

output "cluster_ingress_ip" {
  value = data.kubernetes_ingress_v1.main.status.0.load_balancer.0.ingress.0.ip
}
