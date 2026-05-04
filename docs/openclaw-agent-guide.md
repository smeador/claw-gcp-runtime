# OpenClaw Agent Guide

This document captures practical lessons for building reliable agent workflows with OpenClaw. It is written as a general guide for agent-based systems rather than a description of one specific repository.

## What OpenClaw Is Good At

OpenClaw works well as an execution environment for agents that need to:

- read and write files in a workspace
- call local tools and scripts
- maintain reusable skills
- run on a schedule
- operate in local and cloud environments with similar behavior

It is especially effective when the agent is treated as a coordinator over deterministic tools, not as the place where all logic lives.

## Keep The Runtime Contract Explicit

OpenClaw workflows get much easier to reason about when the runtime promises are small and concrete.

Good runtime promises:

- where writable artifact paths live
- which helper commands are on `PATH`
- which auth account is configured
- how cron jobs are reconciled

Bad runtime promises:

- implicit dependence on one repo layout
- hidden dependence on ad hoc host edits
- assuming `/workspace` is globally writable

In practice, this means:

- keep `/workspace` mostly read-only in containerized environments
- expose only explicitly writable subpaths such as `/workspace/memory` and `/workspace/.openclaw`
- let integrations bring their own commands and skills rather than teaching the agent repo-root implementation details

## Core Principle

Move as much operational behavior as possible out of prompts and into code.

This is the single most important lesson.

When a workflow depends on the model to:

- discover the right tool
- invent command shapes
- choose file locations
- manage run directories
- decide what counts as success

it becomes expensive, fragile, and hard to debug.

When the same workflow uses code-owned helpers for those steps, OpenClaw becomes much more reliable.

## Recommended Architecture

The most robust OpenClaw workflows follow this pattern:

1. deterministic retrieval
2. deterministic preprocessing
3. bounded model synthesis
4. deterministic delivery or side effects

In practice, that means:

- tools gather raw inputs
- scripts normalize and reduce them
- the model works on cleaned, bounded artifacts
- scripts perform final writes, sends, or mutations

This pattern reduces token usage, makes runs easier to inspect, and lowers the chance of the agent drifting into unhelpful behavior.

## Keep Raw Inputs Out of the Model Context

Raw data is usually much larger and messier than the model needs.

Examples:

- Gmail or API JSON payloads
- full HTML bodies
- MIME parts
- logs with transport metadata
- large tool outputs with repeated boilerplate

The model should usually not read those directly.

Instead:

- fetch raw inputs with tools
- parse them with code
- strip junk and normalize structure
- save inspectable artifacts
- pass only the cleaned result to the model

Good agent inputs are:

- compact metadata
- cleaned markdown or text
- curated links
- small structured summaries

This makes costs predictable and improves instruction-following because the model is not wasting attention on irrelevant transport details.

## Use Artifacts as Workflow Boundaries

Artifact directories are a strong pattern for OpenClaw workflows.

Each run or source item should write inspectable files to disk, for example:

- raw source
- cleaned source
- metadata
- extracted links
- final output
- send or action results

Benefits:

- easy debugging
- reruns can reuse cached work
- model context stays smaller
- failures are easier to localize
- humans can inspect intermediate state without replaying the run

Good artifact design rules:

- keep file names predictable
- keep each file focused on one purpose
- separate raw inputs from model-facing cleaned outputs
- write machine-readable sidecars for metadata and results

## Make Success Conditions Code-Owned

Do not rely on prompt wording alone for critical success checks.

For operations like sending email, writing external records, or triggering downstream jobs:

- use a helper script
- validate the result in code
- emit a structured result file

Examples of good validation:

- require a returned id
- require a non-empty output file
- require the existence of expected artifacts
- fail explicitly if those conditions are missing

This prevents the agent from declaring success after only partial completion.

## Prefer Stable Script Interfaces

OpenClaw agents behave better when they call a small number of stable scripts rather than improvising shell commands every run.

Good pattern:

- expose a wrapper in a stable workspace path
- let the wrapper resolve environment-specific details
- keep the skill focused on when to use the wrapper, not how to construct it

This is useful for:

- local versus cloud differences
- host versus container paths
- auth or account selection
- helper fallbacks

The agent should reference the stable interface, not re-derive the underlying implementation.

## Keep Skills Focused

Skills should define:

- purpose
- inputs
- outputs
- rules for synthesis or judgment
- when to call code-owned helpers

Skills should not be overloaded with:

- deep filesystem choreography
- complicated path construction
- ad hoc tool-discovery behavior
- long procedural shell sequences that code can own instead

When a skill starts reading like an operations manual, it is usually a sign that a script should exist.

## Reset and Isolation Matter

Long-lived sessions can become expensive and unpredictable.

For workflows that should behave the same way every run:

- use isolated execution when possible
- reset the session at the start of the run
- avoid inheriting unrelated conversational history

Why:

- token costs stay bounded
- prior exploration does not pollute current behavior
- scheduled jobs become easier to reason about

Fresh context is especially important for cron jobs and repeatable production tasks.

## Treat Persisted Runtime State As A First-Class Input

Rendered config is not the whole runtime.

OpenClaw also persists state under its home directory, including model/provider metadata and session state. That means a deploy can look correct on disk while the runtime still behaves differently because persisted state drifted earlier.

Practical lessons:

- compare rendered config and persisted state when local and cloud diverge
- inspect `models.json` under the OpenClaw home when provider behavior looks wrong
- if a stale persisted value can break normal operation, repair it on startup or fail loudly

This came up directly with a stale OpenRouter base URL in persisted state. The rendered config was healthy, but the runtime still failed until the persisted `models.json` entry was repaired.

## Prevent Workspace Wandering

Agents often drift when the prompt is vague.

Common failure mode:

- the agent receives a high-level instruction
- it begins scanning the workspace for scripts or skills
- it spends tokens orienting itself instead of executing the known workflow

Mitigation:

- point directly at the intended skill or script
- tell the agent not to scan for alternatives first
- reduce ambiguity in entrypoint prompts

This is often the difference between a scheduled job that starts immediately and one that burns tokens on orientation.

## Cron Config Is Desired State, Not Static Config

Cron is best treated as runtime state that is reconciled from repo-managed desired state.

That means:

- keep a neutral cron schema example in runtime docs
- keep concrete workflow cron jobs in the composed workspace config
- apply or reconcile those jobs after the gateway starts

This is easier to reason about than pretending cron belongs inside `openclaw.json`, and it matches how OpenClaw actually persists cron jobs.

## Use Bounded Synthesis

OpenClaw can support sophisticated synthesis workflows, but the safest pattern is bounded synthesis.

That means:

- the model works on one cleaned source or one clearly scoped bundle at a time
- the model is not asked to hold the whole world in memory
- deterministic code handles retrieval, parsing, and delivery

Bounded synthesis is a good fit for:

- one-section summaries
- per-source digests
- structured transformations over cleaned inputs

If parallel agent work is introduced later, this is the right shape:

- one worker per already-clean source
- each worker returns a structured section output
- a coordinator assembles the final result

This is much safer than having multiple agents independently perform raw retrieval and side effects.

## Cache Carefully

Caches are useful, but only when they are trustworthy.

Recommended cache rules:

- cache by stable source identity, not by date alone
- require the full artifact set, not one sentinel file
- include a cache or extractor version in structured outputs
- invalidate old cache entries when parsing logic changes

Without versioning, improved parsers can silently reuse stale artifacts and make debugging confusing.

## Container Env Precedence Can Break Good Config

In Docker-based OpenClaw setups, be careful about where environment variables are sourced.

A useful rendered runtime env file can still lose to:

- Compose-time default interpolation
- stale container-level overrides
- placeholder values baked into Compose files

When auth or account selection looks wrong, verify the final environment visible inside the container, not just the rendered source file on disk.

## Treat HTML as a Parsing Problem, Not a Prompting Problem

If a workflow consumes HTML emails, webpages, or rich content:

- parse with code
- clean with code
- convert to plain text or markdown before handing it to the model

Do not expect the model to reliably extract visible content from raw HTML every run.

Useful processing steps include:

- stripping layout and tracking markup
- removing navigation, footers, and app prompts
- normalizing links
- converting visible content to markdown

The model should receive cleaned content, not transport markup.

## Package Integrations As Snapshots For Cloud Deploys

If the runtime consumes sibling workflow repos during development, cloud deploys should package a concrete snapshot of that integration rather than assuming the VM will pull from another repo at deploy time.

This keeps the deploy unit inspectable and makes it much easier to answer:

- which integration code was deployed
- which skills were staged
- which commands were installed in the image

The runtime can still stay lightweight:

- read an integration manifest
- stage the integration into the deploy tree
- expose the declared skills and bins

This preserves local flexibility while keeping cloud deploys deterministic enough to debug.

## Cloud Hygiene Matters

A healthy OpenClaw workflow can still fail because the host around it is drifting.

The highest-value operational checks are often simple:

- free disk space on the VM
- stale Docker images accumulating across rebuilds
- macOS metadata files accidentally entering the synced app tree

If cloud deploys start failing in surprising ways, check host health early. A full root disk can interrupt deploys and leave runtime state looking partially updated.

## Prefer File-Backed Interfaces Over Large Inline Payloads

For larger outputs, file-backed interfaces are usually more robust than passing large bodies inline on the command line.

Prefer:

- write content to files
- pass file paths to helpers
- save result files next to the artifacts

This improves:

- debuggability
- shell safety
- repeatability
- interoperability between local and cloud runs

## Local and Cloud Parity

OpenClaw is much easier to operate when local and cloud flows use the same high-level workflow.

Good parity goals:

- same skill entrypoints
- same helper scripts or wrappers
- same artifact layout
- same success checks

Differences should be hidden behind wrappers or environment setup, not reflected in different agent instructions.

If local and cloud behavior diverge too much, debugging becomes much slower.

## Scheduled Jobs Need Extra Guardrails

Cron jobs should be treated as production automation.

Recommended safeguards:

- fresh or isolated context
- deterministic entrypoint prompt
- helper-backed side effects
- structured run artifacts
- post-run inspection path

Important operational lesson:

- a scheduler can report a run as successful even when the workflow did not actually finish the intended action

That is why artifact-backed validation and result files are important.

## Observe Runs Through Artifacts First, Logs Second

Logs are useful, but for agent workflows they are not always the best first debugging surface.

A better order is:

1. inspect run artifacts
2. inspect structured result files
3. inspect session transcripts
4. inspect service logs

Artifacts usually tell you:

- what inputs were chosen
- what the cleaned data looked like
- whether final outputs were written
- whether the side effect actually succeeded

That is often more actionable than raw gateway logs.

## Cost Control Principles

The biggest drivers of cost in OpenClaw workflows are usually:

- long-lived context
- raw input bloat
- repeated exploratory tool use
- too many model turns for tasks code could do once

The best cost reductions usually come from:

- smaller cleaned inputs
- fewer exploratory steps
- isolated sessions
- deterministic helpers

Switching models can help, but architecture matters more than model choice when costs are caused by workflow shape.

## Documentation Guidance

Keep three kinds of documentation separate:

- source-of-truth system design and current behavior
- backlog and future enhancements
- operational runbooks or commands

This prevents design docs from turning into a mix of current facts and future intentions.

For OpenClaw projects, it is especially helpful to document:

- where artifacts are written
- which scripts own side effects
- what a successful run must produce
- how local and cloud execution differ, if they do

## Practical Heuristics

If an OpenClaw workflow is misbehaving, ask:

- Is the model reading raw data that code should clean first?
- Is a prompt telling the model to do filesystem or command choreography that a script should own?
- Is the run reusing too much old context?
- Is the agent scanning for tools instead of being pointed at the correct one?
- Is success defined by prose instead of a code check?
- Are local and cloud paths or wrappers inconsistent?

Those questions usually lead quickly to the real problem.

## Rule of Thumb

Use the model for judgment, synthesis, and writing.

Use code for:

- retrieval
- parsing
- normalization
- file layout
- validation
- side effects

OpenClaw works best when those responsibilities stay clearly separated.
