variable "deploy_env" {
  type    = string
  default = "development"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "scheduled_destruction" {
  type    = string
  default = "false"
}

variable "cli_terraform_remote_state_bucket_prefix" {
  type    = string
  default = ""
}

variable "bucket_versioning_enabled" {
  type    = bool
  default = false
}

variable "region_primary" {
  type    = string
  default = "us-west-1"
}

variable "region_replication" {
  type    = string
  default = "us-east-2"
}
