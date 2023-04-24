data "digitalocean_kubernetes_cluster" "main" {
  name = digitalocean_kubernetes_cluster.main.name
  depends_on = [
    digitalocean_kubernetes_cluster.main
  ]
}

output "k8s_cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.main.endpoint
}


output "k8s_cluster_token" {
  value = data.digitalocean_kubernetes_cluster.main.kube_config[0].token
}

output "k8s_cluster_certificate" {
  value = base64decode(
    data.digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}
