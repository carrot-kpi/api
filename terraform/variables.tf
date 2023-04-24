variable "do_token" {}

variable "bootstrap_peer_id" {}

variable "bootstrap_peer_private_key" {}

variable "cluster_secret" {}

variable "base_api_domain" {}

variable "ipfs_storage_volume_size" {
  default = "10Gi"
}

variable "cluster_storage_volume_size" {
  default = "3Gi"
}
