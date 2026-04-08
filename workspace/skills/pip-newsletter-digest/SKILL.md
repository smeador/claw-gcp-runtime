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

Start execution immediately.

Do not spend the first step on workspace orientation or generic environment checking unless a real failure forces you to diagnose it.

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

1. `gog gmail search ... --json --no-input`
2. choose the newest valid issue
3. run the newsletter extractor for each selected message id:
   - `bash scripts/extract-newsletter-from-gmail.sh --account ACCOUNT --message-id MESSAGE_ID --output /workspace/memory/.tmp/NAME.json`
4. read the extractor output, not the raw Gmail payload

The extractor also writes inspectable artifacts and cache files under:

- `/workspace/memory/newsletters/MESSAGE_ID/`

Those artifacts include:

- `raw.html` when an HTML body exists
- `raw.txt`
- `clean.md`
- `links.json`
- `metadata.json`
- `extracted.json`

If the same message id is selected again on a repeat run, prefer reusing the cached `extracted.json` instead of rebuilding it unless you explicitly need a refresh.

Normal workflow rule:

- use the cached artifact set as the source of truth for formatting handoff
- read `metadata.json`, `links.json`, and `clean.md`
- do not read `raw.html` or `raw.txt` during a normal digest run
- do not read duplicate body fields from `extracted.json` when `clean.md` is available
- use `raw.html` and `raw.txt` only when you are explicitly debugging extraction quality

The wrapper resolves to the installed helper when available and otherwise falls back to the repo copy of the extractor.

Hard rules:

- do not use `gog gmail messages get`
- do not paste raw `gog gmail get --json` output into the model conversation
- do not read raw MIME or raw HTML blobs directly into the conversation
- do not switch between multiple Gmail read subcommands during a normal run
- if the extractor fails, treat that as a tool failure and report it clearly
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
- cleaned markdown from `clean.md`
- curated links from `links.json`
- metadata from `metadata.json`
- only the relevant extracted content needed for summarization

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

Before sending, write delivery artifacts under:

- `/workspace/memory/digests/YYYY-MM-DD/`

Required files:

- `email.html`
- `email.txt`
- `summary.json`

`summary.json` should include at least:

- subject
- recipient
- sender
- local date
- selected message ids
- source artifact directories

Hard rules:

- use `gog gmail send` in a way that includes the HTML body for the digest
- include a plain-text fallback body for email compatibility
- a plaintext-only send is not a successful digest send unless the user explicitly asked for plaintext-only
- `email_html` must be actual HTML markup, not a file path
- `email_html` is the primary digest body; `email_text` is fallback only
- use local `America/Chicago` time for the run directory name
- write the final `email_html` markup and fallback text into a local day directory such as `/workspace/memory/digests/YYYY-MM-DD/`
- let the digest send helper create the final ISO-like run subdirectory `YYYY-MM-DDTHH-MM-SS`
- the helper must write `email.html`, `email.txt`, `summary.json`, and `send-result.json` into that run directory
- use those saved files as the source material for the final send step
- before invoking the helper, write `selected-message-ids.json` and `source-artifact-dirs.json` in the day directory
- use `bash scripts/send-gog-digest.sh ACCOUNT TO SUBJECT TEXT_FILE HTML_FILE DAY_DIR FROM MESSAGE_IDS_JSON SOURCE_ARTIFACTS_JSON`
- the wrapper resolves to the installed helper when available and otherwise falls back to the repo copy
- do not send a filesystem path like `/workspace/...html` as the body
- run one explicit helper-backed send step after the formatter returns the final bodies
- only treat delivery as successful if the helper returns a Gmail id in either `send_result.message_id` or `send_result.messageId`
- if both `message_id` and `messageId` are missing, treat that as a send failure even if the command printed other output

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
