terraform {
  required_version = ">= 1.8.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "claw-runtime-example-opentofu-state"
    prefix = "agent-lab/lab"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
