# Agent Lab GCP Infrastructure

This repository provisions a private GCP lab for OpenClaw using OpenTofu.

The configuration still uses HCL's standard `terraform {}` block name because OpenTofu preserves that syntax for provider and backend settings.

## Layout

- `opentofu/environments/lab`: root environment
- `opentofu/modules/network`: VPC, subnet, router, NAT, IAP SSH firewall
- `opentofu/modules/compute`: VM, service account, startup bootstrap
- `opentofu/modules/cost_controls`: budget Pub/Sub and shutdown automation
- `workspace`: reviewed OpenClaw workspace files and skills
- `config`: local and cloud OpenClaw config templates
- `docker`: container and compose assets
- `scripts`: local and cloud run helpers

## First Run

1. Install OpenTofu and Google Cloud SDK.
2. Create a locked-down GCS bucket for remote state.
3. Update `opentofu/environments/lab/providers.tf` to enable the `gcs` backend.
4. Copy `opentofu/environments/lab/terraform.tfvars.example` to `terraform.tfvars` and set `project_id`.
5. Run:

```bash
cd /Users/sean/Repos/gcp-claw-lab/opentofu/environments/lab
tofu init
tofu fmt -recursive ../..
tofu validate
tofu plan
tofu apply
```

## Access

After apply, connect with:

```bash
gcloud compute ssh agent-lab-vm --project agent-lab-488918 --zone us-central1-a --tunnel-through-iap
```

## OpenClaw App Layer

The repository now includes a first-pass local-first scaffold for OpenClaw:

- workspace policy in [AGENTS.md](/Users/sean/Repos/gcp-claw-lab/workspace/AGENTS.md) and [TOOLS.md](/Users/sean/Repos/gcp-claw-lab/workspace/TOOLS.md)
- reviewed starter skills under [skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills)
- local and cloud config templates in [config](/Users/sean/Repos/gcp-claw-lab/config)
- Docker assets in [docker](/Users/sean/Repos/gcp-claw-lab/docker)
- helper scripts in [scripts](/Users/sean/Repos/gcp-claw-lab/scripts)

Current limitation:
- the Docker image is only a scaffold right now
- it does not yet install or launch OpenClaw
- the next step is to wire in the actual OpenClaw runtime command and VM bootstrap for Docker
