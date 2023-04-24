variable "bootstrap_peer_id" {}

variable "bootstrap_peer_private_key" {}

variable "cluster_secret" {}

variable "base_api_domain" {}

variable "ipfs_storage_volume_size" {}

variable "cluster_storage_volume_size" {}

variable "persistent_volume_storage_class" {}

variable "local" {
  type = bool
}
