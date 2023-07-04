variable "bootstrap_peer_id" {}

variable "bootstrap_peer_private_key" {}

variable "cluster_secret" {}

variable "cluster_rest_api_basic_auth_credentials" {}

variable "ipfs_storage_volume_size" {
  default = "100M"
}

variable "cluster_storage_volume_size" {
  default = "100M"
}
