variable "do_token" {
  default = ""
}

variable "bootstrap_peer_id" {}

variable "bootstrap_peer_private_key" {}

variable "cluster_secret" {}

variable "ipfs_storage_volume_size" {
  default = "20Gi"
}

variable "cluster_storage_volume_size" {
  default = "5Gi"
}
