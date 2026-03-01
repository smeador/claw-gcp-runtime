locals {
  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "eventarc.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_compute_project_metadata_item" "enable_oslogin" {
  project = var.project_id
  key     = "enable-oslogin"
  value   = "TRUE"

  depends_on = [google_project_service.required]
}

module "network" {
  source = "../../modules/network"

  project_id     = var.project_id
  region         = var.region
  network_name   = var.network_name
  subnet_name    = var.subnet_name
  subnet_cidr    = var.subnet_cidr
  nat_log_filter = var.nat_log_filter
  labels         = var.labels

  depends_on = [
    google_project_service.required,
    google_compute_project_metadata_item.enable_oslogin,
  ]
}

module "compute" {
  source = "../../modules/compute"

  project_id                  = var.project_id
  zone                        = var.zone
  region                      = var.region
  vm_name                     = var.vm_name
  machine_type                = var.machine_type
  network_self_link           = module.network.network_self_link
  subnet_self_link            = module.network.subnet_self_link
  machine_image               = "${var.image_project}/${var.image_family}"
  boot_disk_size_gb           = var.boot_disk_size_gb
  boot_disk_type              = var.boot_disk_type
  boot_disk_kms_key_self_link = var.boot_disk_kms_key_self_link
  enable_secure_boot          = var.enable_secure_boot
  labels                      = var.labels

  depends_on = [google_project_service.required]
}

module "cost_controls" {
  source = "../../modules/cost_controls"

  project_id           = var.project_id
  region               = var.shutdown_function_region
  zone                 = var.zone
  topic_name           = var.shutdown_topic_name
  function_name        = var.shutdown_function_name
  target_instance_name = module.compute.vm_name
  target_instance_zone = var.zone

  depends_on = [google_project_service.required]
}
