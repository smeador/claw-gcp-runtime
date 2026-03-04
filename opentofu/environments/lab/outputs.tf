output "vm_name" {
  description = "Name of the Agent VM."
  value       = module.compute.vm_name
}

output "vm_internal_ip" {
  description = "Internal IP address of the Agent VM."
  value       = module.compute.vm_internal_ip
}

output "service_account_email" {
  description = "Service account attached to the Agent VM."
  value       = module.compute.service_account_email
}

output "iap_ssh_command" {
  description = "Command to reach the VM over IAP TCP forwarding."
  value       = "gcloud compute ssh ${module.compute.vm_name} --project ${var.project_id} --zone ${var.zone} --tunnel-through-iap"
}

output "budget_notification_topic" {
  description = "Pub/Sub topic for Cloud Billing budget notifications."
  value       = module.cost_controls.topic_name
}

output "shutdown_function_name" {
  description = "Cloud Run function that stops the Agent VM."
  value       = module.cost_controls.function_name
}

output "openclaw_runtime_secret_name" {
  description = "Secret Manager secret that stores the OpenClaw cloud runtime payload."
  value       = google_secret_manager_secret.openclaw_runtime.secret_id
}
