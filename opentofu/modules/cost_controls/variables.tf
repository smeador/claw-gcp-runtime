variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for cost-control resources."
  type        = string
}

variable "zone" {
  description = "Primary lab zone."
  type        = string
}

variable "topic_name" {
  description = "Pub/Sub topic name for budget notifications."
  type        = string
}

variable "function_name" {
  description = "Name of the shutdown function."
  type        = string
}

variable "function_service_account_id" {
  description = "Service account ID for the shutdown function."
  type        = string
}

variable "function_role_id" {
  description = "Custom IAM role ID used by the shutdown function."
  type        = string
}

variable "target_instance_name" {
  description = "Compute Engine instance to stop."
  type        = string
}

variable "target_instance_zone" {
  description = "Zone of the instance to stop."
  type        = string
}
