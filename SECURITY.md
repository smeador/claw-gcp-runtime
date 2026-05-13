# Security Policy

## Scope

This repository contains infrastructure code, workspace configuration, and local/cloud deployment scaffolding for an OpenClaw runtime environment.

It must not contain:
- credentials
- API keys
- OAuth client secrets
- refresh tokens
- secret payloads
- OpenTofu state files
- live environment files

Secrets belong in Google Cloud Secret Manager or other approved secret storage, not in Git.

## Reporting a Vulnerability

Do not open a public issue for suspected security problems that could expose credentials, infrastructure access, or active attack paths.

Instead, report the issue privately to the repository owner with:
- a short description
- affected files or components
- reproduction steps, if safe to share
- impact assessment
- any suggested mitigation

If the issue involves leaked credentials or tokens:
1. rotate the affected credential immediately
2. remove the secret from active systems where possible
3. assess whether Git history or logs contain the secret
4. treat the credential as compromised until rotation is complete

## Hardening Expectations

- Keep `.tfvars`, `.env`, rendered config, and local override files out of version control
- Keep OpenTofu state in the configured remote GCS backend only
- Review skills and agent policy changes as security-sensitive code
- Prefer workspace-local reviewed skills over user-global skill directories
- Do not publish debugging artifacts that reveal internal topology, tokens, or operational metadata unnecessarily

## Supported Use

This is a personal lab repository, not a production support offering.
Security fixes should be applied directly in the mainline repository history.
