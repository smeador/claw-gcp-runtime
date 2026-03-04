variable "project_id" {
  description = "GCP project ID for the lab environment."
  type        = string
}

variable "region" {
  description = "Primary region for regional resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the Agent VM."
  type        = string
  default     = "us-central1-a"
}

variable "billing_account" {
  description = "Optional billing account ID if budget resources are added later."
  type        = string
  default     = null
}

variable "vm_name" {
  description = "Name of the Agent VM."
  type        = string
  default     = "claw-runtime-vm"
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 30
}

variable "boot_disk_type" {
  description = "Persistent disk type for the boot disk."
  type        = string
  default     = "pd-balanced"
}

variable "image_project" {
  description = "Image project for the VM boot image."
  type        = string
  default     = "debian-cloud"
}

variable "image_family" {
  description = "Image family for the VM boot image."
  type        = string
  default     = "debian-12"
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "agent-lab-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet."
  type        = string
  default     = "agent-lab-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet."
  type        = string
  default     = "10.42.0.0/24"
}

variable "nat_log_filter" {
  description = "Cloud NAT logging filter."
  type        = string
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat_log_filter)
    error_message = "nat_log_filter must be one of ERRORS_ONLY, TRANSLATIONS_ONLY, or ALL."
  }
}

variable "enable_secure_boot" {
  description = "Enable Shielded VM secure boot."
  type        = bool
  default     = true
}

variable "boot_disk_kms_key_self_link" {
  description = "Optional CMEK key self link for the VM boot disk."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to supported resources."
  type        = map(string)
  default = {
    environment = "lab"
    workload    = "agent-lab"
  }
}

variable "shutdown_topic_name" {
  description = "Pub/Sub topic that receives budget notifications."
  type        = string
  default     = "agent-lab-budget-notifications"
}

variable "shutdown_function_name" {
  description = "Name of the Cloud Run function that stops the Agent VM."
  type        = string
  default     = "agent-lab-budget-shutdown"
}

variable "shutdown_function_region" {
  description = "Region for the Cloud Run shutdown function."
  type        = string
  default     = "us-central1"
}

variable "openclaw_runtime_secret_name" {
  description = "Secret Manager secret name for the rendered OpenClaw runtime payload."
  type        = string
  default     = "openclaw-runtime-config"
}
