# pip-newsletter-digest

Use this skill to run the Pip newsletter digest workflow end to end.

This skill is the orchestrator. It owns:

- email retrieval
- filtering and issue selection
- issue-link extraction
- handing the selected source material to the formatter
- delivery through `gog gmail send`

Do not use this skill to invent the final digest structure from scratch. Use the formatter skill at:

- `/workspace/skills/pip-newsletter-digest-format/SKILL.md`

once the source set is selected.

## Invocation rules

Treat these requests as direct execution commands:

- `Run pip-newsletter-digest now.`
- `Run pip-newsletter-digest now in test mode.`
- `Run the Pip newsletter digest now.`
- `Send today's Pip newsletter digest.`

Do not ask:

- `Run what, specifically?`
- `Which job/script do you mean?`

Execute the workflow.

Before running, re-read this skill and the formatter skill from disk.

## Sources in scope

### Primary newsletters

- `NY Times Morning`
- `Daily Upside`
- `AI News` (`swyx+ainews@substack.com`)

### Additional sections

- Substack emails from the last `24 hours`
- Stanford newsletter emails from the last `24 hours`

Ignore GoodLinks and non-email sources.

## Retrieval rules

### Lookback window

- default lookback: rolling `last 24 hours`
- always do a historical pull; do not rely only on webhook or new-mail state
- first fetch metadata/snippets for the lookback window
- then fetch full bodies only for the messages you actually plan to use

### Gmail command pattern

Use `gog` in this exact retrieval flow:

1. `gog gmail messages search ... --json --no-input`
2. choose the newest valid issue
3. `gog gmail get MESSAGE_ID --json --no-input`

Hard rules:

- do not use `gog gmail messages get`
- do not switch between multiple Gmail read subcommands during a normal run
- if `gog gmail get` fails, treat that as a tool failure and report it clearly
- do not silently substitute another unsupported command shape and continue

### Fast-path senders

Start with these:

- `NY Times Morning`: `nytdirect@nytimes.com`
- `Daily Upside`: `squad@thedailyupside.com`
- `AI News`: `swyx+ainews@substack.com`

If no valid issue is found, fall back to broader sender, subject, publication, and body matching before marking the source as missing.

### Selection rules

- for each primary newsletter, choose the newest valid issue in the active window
- prefer the newest same-day issue in `America/Chicago` when one exists
- if the digest runs shortly after the normal send time, explicitly check whether a newer same-day issue arrived after an earlier digest run
- do not include `AI News` again in the Substack section

### Daily Upside matching

- do not rely on one exact sender forever
- if a message plausibly looks like Daily Upside but sender formatting changed, inspect it
- treat sender variants, wrappers, and aliases as eligible when the subject or publication clearly indicate Daily Upside

## Link extraction rules

Find one useful public link for every primary newsletter and every included Substack item.

### Preferred links

- for primary newsletters: issue-level browser version
- for Substack: article page
- for Stanford: useful public article page when one exists

Look for phrases such as:

- `View in browser`
- `Read in browser`
- `Read online`

Prefer those over generic publication pages.

### Disallowed links

Never use:

- Gmail links
- mailbox links
- message-view links
- thread-view links
- unsubscribe/settings links
- ad/sponsor links
- image asset URLs

## Formatter handoff

After source selection is complete, switch to the formatter skill:

- `/workspace/skills/pip-newsletter-digest-format/SKILL.md`

Pass it the selected source material cleanly:

- newsletter name
- issue date
- sender/publication
- chosen public link
- full body or the relevant extracted content needed for summarization

Do not keep discovering new emails while formatting unless a required primary newsletter is still missing.

The formatter owns:

- digest structure
- depth
- section labels
- plaintext/HTML parity
- pre-send output checks

## Delivery

- send by default to `user@example.com` from `automation@example.com`
- use `gog gmail send`, not SMTP
- subject format:
  - `Pip Newsletter Digest - YYYY-MM-DD`
- use the local date in `America/Chicago`
- send the digest as an HTML email with a plain-text fallback

Hard rules:

- use `gog gmail send` in a way that includes the HTML body for the digest
- include a plain-text fallback body for email compatibility
- a plaintext-only send is not a successful digest send unless the user explicitly asked for plaintext-only
- `email_html` must be actual HTML markup, not a file path
- `email_html` is the primary digest body; `email_text` is fallback only
- if you generate HTML in a temp file, read the contents before sending
- do not send a filesystem path like `/workspace/...html` as the body

If delivery fails:

- keep the digest in the response
- report the failure clearly
- include intended recipient and subject
- do not auto-retry

## Test mode

If the request says `test mode`, `rerender`, or similar:

- reuse matching source content from the same `24 hour` lookback window
- ignore previously sent digest emails as source material
- still send the email
- do not reduce digest depth just because it is a test

## Constraints

- preserve the original content and intent while reducing length
- do not flatten the entire digest into one synthesis
- synthesize within each newsletter section only
- do not reproduce the full email body
- quote only short phrases when necessary
- do not perform delete or unsubscribe actions automatically
- do not include secrets or credentials in output
