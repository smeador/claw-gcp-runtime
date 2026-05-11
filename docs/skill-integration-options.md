# Skill Integration Options

This note explains the different ways to add skills in this runtime repo, from the lightest-weight OpenClaw-native path to the heavier sibling-integration path.

The goal is to keep standard OpenClaw skills easy to use while still giving us a clean packaging story for larger workflow systems.

## Recommendation summary

Use the lightest option that matches the skill's complexity.

1. Built-in or already-packaged OpenClaw skill: use it directly through OpenClaw config.
2. Small reviewed third-party or local-only skill: install or copy it into the runtime workspace as generated state, not as committed repo content.
3. Plugin-shipped skill: enable the plugin if the tool and the skill really belong together.
4. Complex workflow with real code, tests, or multiple commands: use a sibling integration repo and stage it through [workspace/integrations.json](../workspace/integrations.json).

## Option 1: Built-in or packaged OpenClaw skills

This is the lowest-overhead path.

Examples:

- bundled OpenClaw skills
- skills installed through `openclaw skills install <slug>`
- skills already present in one of OpenClaw's normal skill roots

How it works:

- OpenClaw loads the skill from its normal skill roots
- this repo only needs the runtime capabilities the skill depends on
- if needed, configure the skill through `skills.entries.*` or agent allowlists in OpenClaw config

Good fit:

- widely reusable OpenClaw skills
- skills that are mostly instructions in `SKILL.md`
- skills with simple binary/env requirements already satisfied by the runtime

Pros:

- almost no repo overhead
- closest to standard OpenClaw behavior
- easiest to adopt and update

Cons:

- weaker reproducibility unless the skill folder is committed somewhere controlled
- less control over local/cloud packaging if the skill expects extra scripts or tools

Recommended usage in this repo:

- prefer this path first for standard OpenClaw skills
- only add repo-managed packaging if the native skill shape becomes awkward to run across Docker-local and cloud

## Option 2: Generated workspace skill

This is still the standard OpenClaw skill model, but in this repo the `workspace/skills` directory is treated as generated runtime state rather than authored source.

How it works:

- install a skill through OpenClaw or copy a reviewed skill folder into `workspace/skills`
- keep it out of git
- let local Docker or cloud runtime consume it as part of the reviewed workspace surface

Good fit:

- simple custom workflows you are trying locally
- reviewed third-party skills that do not justify a dedicated repo
- temporary operator-local skill experiments

Pros:

- very little machinery
- fully visible in the reviewed workspace at runtime
- works naturally with OpenClaw's native skill loader

Cons:

- not reproducible unless you manage the skill source outside this repo
- easy to accumulate local-only drift if the skill matters long-term
- not ideal for large reusable workflows with real implementation code

Rule of thumb:

- if the skill is mostly `SKILL.md` and you just want it available locally, this is usually enough
- if it matters to the team or starts needing real implementation commands, move it into a dedicated integration repo

## Option 3: Plugin-shipped skill

OpenClaw plugins can ship their own skill directories.

How it works:

- install/enable the plugin
- OpenClaw loads the skill directories declared by that plugin
- the runtime repo just ensures the plugin is available and enabled

Good fit:

- tool-specific operating guides
- skills that are tightly coupled to a plugin-provided tool surface
- functionality that already has a natural plugin boundary

Pros:

- native OpenClaw packaging model
- keeps tool + skill together

Cons:

- more moving parts than a plain skill folder
- overkill for most lightweight custom skills
- less appropriate when the real problem is workflow packaging, not tool packaging

Rule of thumb:

- use this when the skill exists to document or steer a plugin tool
- do not reach for a plugin just to package arbitrary workflow code

## Option 4: Sibling integration repo

This is the strongest packaging model and the one we now use for the sibling `newsletter-digest` repo.

How it works:

1. declare the sibling repo in [workspace/integrations.json](../workspace/integrations.json)
2. the sibling repo provides:
   - `integration.json`
   - `adapter/openclaw/skills/...`
   - optional package bins and test runners
3. [scripts/stage-workspace-integrations.mjs](../scripts/stage-workspace-integrations.mjs) copies the repo into the generated staging area at `.runtime/integrations`
4. the runtime copies the declared skill folders into [workspace/skills](../workspace/skills)
5. the Docker image installs the staged package bins into the runtime image

Good fit:

- workflows with real extraction/render/send code
- integrations with multiple commands and tests
- cross-environment packaging where local Docker and cloud should run the same staged snapshot

Pros:

- strongest ownership boundary
- clean split between runtime provisioning and workflow implementation
- easier to test and evolve independently

Cons:

- more setup
- deploys currently package the local sibling checkout state unless we add pinning later

Rule of thumb:

- if another runtime would still need this code, it probably belongs in a sibling integration repo

## Decision table

### Use a built-in or ClawHub-installed skill when:

- the skill is already packaged for OpenClaw
- it is mostly instructions
- the runtime already provides the binaries/env it needs

### Use a generated workspace skill when:

- the skill is simple
- it is local-only or operator-specific
- we want minimal overhead without making it repo source

### Use a plugin-shipped skill when:

- the skill is really part of a plugin/tool package
- the plugin is the natural deployment unit

### Use a sibling integration repo when:

- the skill needs real implementation code
- the workflow has multiple commands, artifacts, or tests
- we want local/cloud parity from the same staged package

## OpenClaw-native assumptions to keep in mind

OpenClaw skills are more than "just markdown" in one important sense:

- the core unit is a skill directory centered on `SKILL.md`
- the skill can include supporting files
- load-time gating can require:
  - binaries
  - env vars
  - config keys
  - specific OSes
- OpenClaw can inject per-skill env/config for host runs
- skill visibility can be restricted per agent

But OpenClaw does not by itself give us the full cross-environment packaging story we wanted for larger workflows. That is why this repo adds the sibling-integration staging model on top of the native skill format.

## Practical default for this repo

When adding a new skill here:

1. try the native OpenClaw path first
2. keep `workspace/skills` as generated state, not committed source
3. use a sibling integration repo once the skill needs real implementation code or independent lifecycle/testing

That keeps standard OpenClaw skills easy to use without forcing everything through the heavier integration mechanism.
