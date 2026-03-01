variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for regional IAM references."
  type        = string
}

variable "zone" {
  description = "Zone for the VM."
  type        = string
}

variable "vm_name" {
  description = "VM name."
  type        = string
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
}

variable "network_self_link" {
  description = "VPC self link."
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self link."
  type        = string
}

variable "machine_image" {
  description = "Image in project/family form."
  type        = string
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
}

variable "boot_disk_type" {
  description = "Boot disk type."
  type        = string
}

variable "boot_disk_kms_key_self_link" {
  description = "Optional CMEK key self link for the boot disk."
  type        = string
  default     = null
}

variable "enable_secure_boot" {
  description = "Enable Shielded VM secure boot."
  type        = bool
}

variable "labels" {
  description = "Labels applied to supported resources."
  type        = map(string)
}
