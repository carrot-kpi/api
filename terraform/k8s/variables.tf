variable "bootstrap_peer_id" {}

variable "bootstrap_peer_private_key" {}

variable "cluster_secret" {}

variable "cluster_rest_api_user" {}

variable "cluster_rest_api_password" {}

variable "base_api_domain" {}

variable "ws_rpc_url_sepolia" {}

variable "ws_rpc_url_gnosis" {}

variable "ws_rpc_url_scroll_testnet" {}

variable "ipfs_storage_volume_size" {}

variable "cluster_storage_volume_size" {}

variable "persistent_volume_storage_class" {}

variable "web3_storage_api_key" {}

variable "pinning_proxy_jwt_secret" {}

variable "postgres_user" {}

variable "postgres_password" {}

variable "postgres_storage_volume_size" {}

variable "local" {
  type = bool
}
