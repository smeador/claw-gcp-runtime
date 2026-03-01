output "network_self_link" {
  description = "Self link for the VPC."
  value       = google_compute_network.this.self_link
}

output "subnet_self_link" {
  description = "Self link for the subnet."
  value       = google_compute_subnetwork.this.self_link
}
