data "archive_file" "shutdown_function" {
  type        = "zip"
  source_dir  = "${path.module}/function_source"
  output_path = "${path.root}/.tofu-build/${var.function_name}.zip"
}

resource "google_pubsub_topic" "budget_notifications" {
  project = var.project_id
  name    = var.topic_name
}

resource "google_storage_bucket" "function_source" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.function_name}-src"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 14
    }
  }
}

resource "google_storage_bucket_object" "function_archive" {
  name   = "${var.function_name}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.shutdown_function.output_path
}

resource "google_service_account" "function" {
  project      = var.project_id
  account_id   = var.function_service_account_id
  display_name = "Claw Runtime budget shutdown function"
}

resource "google_project_iam_custom_role" "vm_stopper" {
  project     = var.project_id
  role_id     = var.function_role_id
  title       = "Claw Runtime VM Stopper"
  description = "Stops the single Claw Runtime VM when budget thresholds are exceeded."
  permissions = [
    "compute.instances.get",
    "compute.instances.stop",
    "compute.zoneOperations.get",
  ]
}

resource "google_project_iam_member" "function_vm_stopper" {
  project = var.project_id
  role    = google_project_iam_custom_role.vm_stopper.name
  member  = "serviceAccount:${google_service_account.function.email}"
}

resource "google_cloudfunctions2_function" "shutdown" {
  project     = var.project_id
  name        = var.function_name
  location    = var.region
  description = "Stops the Claw Runtime VM when a billing budget threshold is exceeded."

  build_config {
    runtime     = "nodejs22"
    entry_point = "stopLabVm"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }

  service_config {
    available_memory               = "512M"
    timeout_seconds                = 60
    max_instance_count             = 1
    min_instance_count             = 0
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.function.email

    environment_variables = {
      TARGET_PROJECT_ID    = var.project_id
      TARGET_INSTANCE      = var.target_instance_name
      TARGET_INSTANCE_ZONE = var.target_instance_zone
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.budget_notifications.id
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
  }

  depends_on = [google_project_iam_member.function_vm_stopper]
}
