output "topic_name" {
  description = "Pub/Sub topic for budget notifications."
  value       = google_pubsub_topic.budget_notifications.name
}

output "function_name" {
  description = "Name of the Cloud Run shutdown function."
  value       = google_cloudfunctions2_function.shutdown.name
}
