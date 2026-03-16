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
- No assumption that `/tmp` is writable; tools should prefer workspace-local scratch paths

## Temporary Files

- Prefer stdin/stdout piping over temporary files when possible
- When a temporary file is necessary, write it under `workspace/.tmp/` by default, or another explicitly writable mount when required
- Do not write temp files to `/tmp`, `/var/tmp`, or other host-global locations unless the runtime policy explicitly allows it
- Keep temporary files ephemeral and remove them after the operation completes

## Network Use

- Prefer official APIs and documented endpoints
- Respect per-skill domain allowlists
- Avoid network actions that are not necessary for the current task
