# Skill Integration Options

This note explains the different ways to add skills in this runtime repo, from the lightest-weight OpenClaw-native path to the heavier sibling-integration path.

The goal is to keep standard OpenClaw skills easy to use while still giving us a clean packaging story for larger workflow systems.

## Recommendation summary

Use the lightest option that matches the skill's complexity.

1. Built-in or already-packaged OpenClaw skill: use it directly through OpenClaw config.
2. Small custom or third-party skill with little or no code: add a normal skill folder under [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills).
3. Plugin-shipped skill: enable the plugin if the tool and the skill really belong together.
4. Complex workflow with real code, tests, or multiple commands: use a sibling integration repo and stage it through [workspace/integrations.json](/Users/sean/Repos/gcp-claw-lab/workspace/integrations.json).

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

## Option 2: Repo-managed workspace skill

This is the standard OpenClaw skill model, but committed directly in this repo under [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills).

How it works:

- create a skill directory:
  - `workspace/skills/<skill-name>/SKILL.md`
- optionally add support files in the same folder:
  - `TEST.sh`
  - reference docs
  - tiny helper files

Good fit:

- repo-local skills
- simple custom workflows
- reviewed third-party skills we want to keep in the runtime repo directly
- capability skills that are runtime-specific, such as [workspace/skills/gmail-gog-webhook](/Users/sean/Repos/gcp-claw-lab/workspace/skills/gmail-gog-webhook)

Pros:

- very little machinery
- fully visible in the reviewed workspace
- works naturally with OpenClaw's native skill loader

Cons:

- logic can drift into the runtime repo if the skill grows
- not ideal for large reusable workflows with real implementation code

Rule of thumb:

- if the skill is mostly `SKILL.md` plus a small `TEST.sh`, this is usually enough
- if it starts needing real implementation commands, a dedicated repo is usually cleaner

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

This is the strongest packaging model and the one we now use for [`agent-newsletter-digest`](/Users/sean/Repos/agent-newsletter-digest).

How it works:

1. declare the sibling repo in [workspace/integrations.json](/Users/sean/Repos/gcp-claw-lab/workspace/integrations.json)
2. the sibling repo provides:
   - `integration.json`
   - `adapter/openclaw/skills/...`
   - optional package bins and test runners
3. [scripts/stage-workspace-integrations.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/stage-workspace-integrations.mjs) copies the repo into [`.runtime/integrations`](/Users/sean/Repos/gcp-claw-lab/.runtime/integrations)
4. the runtime copies the declared skill folders into [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills)
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

### Use a committed workspace skill when:

- the skill is simple
- it is specific to this runtime repo
- we want minimal overhead and clear reviewability

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
2. commit it directly under [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills) if it is small and repo-specific
3. only graduate it to a sibling integration repo once it needs real implementation code or independent lifecycle/testing

That keeps standard OpenClaw skills easy to use without forcing everything through the heavier integration mechanism.
