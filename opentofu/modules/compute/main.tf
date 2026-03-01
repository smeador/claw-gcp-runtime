data "google_compute_image" "vm_image" {
  family  = split("/", var.machine_image)[1]
  project = split("/", var.machine_image)[0]
}

resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "claw-runtime-vm-sa"
  display_name = "Claw Runtime VM service account"
  description  = "Least-privilege service account for the Claw Runtime VM."
}

resource "google_project_iam_member" "vm_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_compute_instance" "vm" {
  project      = var.project_id
  name         = var.vm_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["agent-lab-iap-ssh"]
  labels       = var.labels

  boot_disk {
    auto_delete = true

    initialize_params {
      image = data.google_compute_image.vm_image.self_link
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }

    kms_key_self_link = var.boot_disk_kms_key_self_link
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnet_self_link
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    serial-port-enable     = "FALSE"
  }

  service_account {
    email = google_service_account.vm.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  metadata_startup_script = file("${path.module}/startup.sh")
}
