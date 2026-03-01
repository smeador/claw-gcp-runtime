# Tool Policy

## Allowed Tool Classes

- Reviewed workspace skills
- Repository-local file reads and edits
- Explicitly configured integrations with scoped credentials
- Approved shell execution only where the runtime policy allows it

## Default Restrictions

- No unrestricted shell access by default
- No arbitrary package installation
- No access to user-global skill directories as a primary source of project behavior
- No broad filesystem traversal outside the reviewed workspace and configured mounts

## Network Use

- Prefer official APIs and documented endpoints
- Respect per-skill domain allowlists
- Avoid network actions that are not necessary for the current task
