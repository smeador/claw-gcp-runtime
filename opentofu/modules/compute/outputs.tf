output "vm_name" {
  description = "VM name."
  value       = google_compute_instance.vm.name
}

output "vm_internal_ip" {
  description = "Primary internal IPv4 address."
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "service_account_email" {
  description = "Service account email attached to the VM."
  value       = google_service_account.vm.email
}
