# opentofu-readonly-review

Use this skill for read-only inspection of OpenTofu configuration and outputs.

## Requirements

- Prefer `tofu validate`, `tofu plan`, and configuration review
- Do not apply destructive changes without explicit approval
- Report risk, drift, and missing guardrails clearly

## Refuse When

- The task requests destructive OpenTofu actions without approval
- The requested scope extends beyond the reviewed infrastructure repository
