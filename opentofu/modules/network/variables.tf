variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for regional networking resources."
  type        = string
}

variable "network_name" {
  description = "VPC name."
  type        = string
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR."
  type        = string
}

variable "nat_log_filter" {
  description = "Cloud NAT log filter."
  type        = string
}

variable "iap_ssh_tag" {
  description = "Network tag used for IAP SSH access."
  type        = string
}

variable "labels" {
  description = "Labels applied to supported resources."
  type        = map(string)
}
