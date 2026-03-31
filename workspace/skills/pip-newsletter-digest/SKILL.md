# pip-newsletter-digest

Use this skill to produce Pip's newsletter digest from email only.

## Core goal

Write a real digest, not a quick summary.

The digest should:

- preserve the original content and intent while reducing length
- give detail according to the section-specific rules below
- help Sean understand each newsletter without opening it immediately
- write directly, not with framing like `the piece says` or `the newsletter explains`
- keep plaintext and HTML identical in substance
- synthesize only within each newsletter section, not across the whole digest

## Invocation rules

Treat these user requests as explicit commands to execute this workflow immediately:

- `Run pip-newsletter-digest now.`
- `Run pip-newsletter-digest now in test mode.`
- `Run the Pip newsletter digest now.`
- `Send today's Pip newsletter digest.`

Do not ask follow-up questions like:

- `Run what, specifically?`
- `Which job/script do you mean?`

Assume the user means this skill and execute it.

## Sources in scope

### Primary newsletters

- `NY Times Morning`
- `Daily Upside`
- `AI News` (`swyx+ainews@substack.com`)

### Additional sections

- Substack emails from the last `24 hours`
- Stanford newsletter emails from the last `24 hours`

Ignore GoodLinks and non-email sources.

## Retrieval and issue selection

### Lookback window

- default lookback: rolling `last 24 hours`
- always do a historical pull; do not rely only on webhook or new-mail state
- first fetch metadata/snippets for the lookback window
- then fetch full bodies only for messages you are actually going to use

### Gmail command pattern

Use `gog` in this specific way for retrieval:

- use `gog gmail messages search ... --json --no-input` to find candidate message ids
- then use `gog gmail get MESSAGE_ID --json --no-input` to fetch the full message body for a selected message

Do not improvise other read commands when fetching full bodies.

In particular:

- do not use `gog gmail messages get`
- do not switch between multiple Gmail read subcommands mid-run unless the known-good `gog gmail get MESSAGE_ID --json --no-input` form has already failed and you are explicitly diagnosing a tool problem

The normal retrieval flow for this skill is:

1. `gog gmail messages search` to identify candidates
2. choose the newest valid issue
3. `gog gmail get MESSAGE_ID --json --no-input` for the full body of that chosen message

If a `gog gmail get` call fails for a selected message:

- treat it as a tool failure
- report the failure clearly
- do not silently substitute a different unsupported command shape
- do not continue as though you successfully read the full body

### Selection rules

- for each primary newsletter, choose the newest valid issue in the active window
- prefer the newest same-day issue in `America/Chicago` when one exists
- if the digest runs shortly after the normal send time, explicitly check whether a newer same-day issue arrived after an earlier digest run

### Fast-path senders

Use these first for speed and precision:

- `NY Times Morning`: `nytdirect@nytimes.com`
- `Daily Upside`: `squad@thedailyupside.com`
- `AI News`: `swyx+ainews@substack.com`

If a fast-path sender query returns no valid issue, fall back to broader sender/subject/publication/body matching before marking the source as missing.

### Daily Upside matching

- do not rely on one exact sender forever
- if a message looks plausibly like Daily Upside but sender formatting changed, inspect it instead of excluding it
- treat sender variants, wrappers, and aliases as eligible when the subject or publication clearly indicate Daily Upside

## Link rules

For every primary newsletter and every included Substack item, find the real browser/article link.

For the three primary newsletters in this workflow, assume there is an issue-level browser link to find and actively look for it.

### What to link

- primary newsletters should link to the issue-level browser version
- Substack items should link to the article page
- Stanford items should link to a useful public article page when one exists, and may omit the link only when no such public link is available

### Preferred link patterns

Look for phrases such as:

- `View in browser`
- `Read in browser`
- `Read online`

Prefer those issue-level links over generic publication links.

### Disallowed links

Never use:

- Gmail links
- mailbox links
- message-view links
- thread-view links
- unsubscribe or settings links
- ad or sponsor links
- image asset URLs

### Formatting rules

- in HTML, links must always be rendered as hyperlinks, not raw plaintext URLs
- use human-readable linked text
- for primary newsletters, place the issue link near the section header
- do not include a secondary-links section

## Writing rules

- do not flatten the entire digest into one synthesis
- keep each newsletter section separate
- preserve the original structure and emphasis of each newsletter
- reduce length, but do not strip out the important secondary sections
- write with enough detail that Sean can usually decide whether to open the original
- plaintext and HTML must contain the same content in the same order

## Output structure

### Header

Include:

- title
- date
- short inventory of newsletters found

The inventory should be brief, for example:

- which primary newsletters were found
- which primary newsletters were missing
- count of Substack and Stanford items included

Do not add extra header blocks beyond those items.

In particular:

- do not include a separate lookback line in the email header
- do not repeat the title in multiple stacked forms
- keep the header compact and single-pass

## Primary newsletters

Create one section for each found primary newsletter.

For each section include:

- newsletter title
- issue date
- sender or publication
- issue link
- body content using the source-specific structure below

Each primary newsletter section must use clear internal subsection labels so the reader can immediately see where one part ends and the next begins.

### NY Times

Structure:

- main article summary: `2-3` paragraphs
- bullets for the remaining important stories

Rules:

- use an explicit subsection label such as `Main article`
- the main article summary should explain the lead story clearly and with real detail
- use a second explicit subsection label such as `Other major stories`
- the bullet section should focus on the most important remaining stories
- each bullet should describe what happened and why it matters

### Daily Upside

Structure:

- opening section
- section for each of the `3` main stories
- distinct mini section for `Extra Upside`

Rules:

- use explicit subsection labels:
  - `Opener`
  - `Story 1`
  - `Story 2`
  - `Story 3`
  - `Extra Upside`
- summarize the opener first
- then give one paragraph for each of the `3` main stories
- if there are more than `3` meaningful story blocks, prioritize the main three and then use the `Extra Upside` mini section for the remaining useful item(s)
- `Extra Upside` should be clearly labeled as its own small closing section when present
- on Sunday, if the issue is really a single in-depth story, follow that structure instead of forcing weekday blocks
- do not let the opener and main stories run together as unlabeled consecutive paragraphs

### AI News

Structure:

- main article summary: `2-3` paragraphs
- Twitter roundup bullets

Rules:

- use an explicit subsection label such as `Main article`
- summarize the main article or opening section in `2-3` paragraphs
- use a second explicit subsection label such as `Twitter roundup`
- then include bullets for the most important Twitter/X roundup items
- each roundup bullet should be `1-2` sentences
- keep the bullets descriptive enough that Sean understands why each item mattered

## Substack review

Include one bullet for each included Substack item.

Do not include `AI News` in this section, since it already appears in the primary newsletters section.

Each bullet should contain:

- newsletter or publication name
- hyperlinked title
- brief summary of `2-3` sentences

## Stanford

Include one bullet for each included Stanford email.

Each bullet should contain:

- hyperlinked title when a useful public link exists, otherwise plain title
- brief summary of `1-2` sentences

## Delivery

- send by default to `user@example.com` from `automation@example.com`
- use `gog gmail send`, not SMTP
- subject format:
  - `Pip Newsletter Digest - YYYY-MM-DD`
- use the local date in `America/Chicago`
- produce both:
  - `email_text`
  - `email_html`
- both formats must carry the same substance
- `email_html` must contain the actual HTML markup to send, not a filesystem path, temp-file path, or filename
- do not place values like `/workspace/.../digest.html` into the email body; if a temp file is used during generation, read its contents and send the contents

If delivery fails:

- keep the digest in the agent response
- report the failure clearly
- include intended recipient and subject
- do not auto-retry

## HTML rendering

Use a fixed editorial HTML style that matches the current digest pattern.

### Overall look

- very slightly off-white page background, but neutral rather than warm
- one centered reading column around `760px` wide
- generous vertical spacing
- distinctive serif masthead styling for the newsletter title
- clean sans-serif body copy
- muted metadata text
- thin horizontal rules between major newsletter sections
- no dashboard styling, no heavy cards, no shadows

### Header styling

- one compact masthead block
- title first
- date directly below
- one compact summary block for found/missing counts
- do not add a separate lookback banner or duplicate title lines
- make `Pip Newsletter Digest` notably larger than the rest of the email
- use a custom-feeling editorial serif stack for the title, such as Georgia plus similar serif fallbacks

### Section styling

- each major newsletter should start with a clear section heading
- issue date and publication line should sit just below the heading in muted text
- the issue link should sit near the top of the section
- internal subsection labels such as `Main article`, `Other major stories`, `Opener`, `Story 1`, and `Twitter roundup` should be visually distinct from body paragraphs
- use spacing and simple type treatment to separate subsections rather than colored boxes or card panels
- major newsletter section headings must remain visibly larger and stronger than internal subsection labels
- do not let mobile rendering collapse the hierarchy so that `NY Times`, `Daily Upside`, `AI News`, `Substack review`, and `Stanford` look the same size as subsection labels
- subsection labels should be smaller than section headings and read as internal markers, not peer headers

### Link styling

- render links as normal inline hyperlinks
- use human-readable link text
- avoid raw plaintext URLs in HTML
- do not style links as buttons

### What to avoid

- warm beige or cream-heavy backgrounds
- stacked cards
- rounded panels
- dark mode treatment
- marketing hero blocks
- oversized badges or decorative UI chrome
- overly wide left/right padding, especially on mobile

### Mobile spacing

- keep left/right padding tight enough that the reading column does not feel cramped on phones
- prefer smaller horizontal padding on mobile than desktop
- do not sacrifice readable line length by wrapping the content in an overly padded inner container

## Test mode

If the user says `test mode`, `rerender`, or similar:

- reuse matching source content from the requested lookback window
- ignore previously sent digest emails as source material
- still send the email
- prioritize rendering and delivery validation

## Constraints

- keep the digest readable and useful, but do not optimize for brevity at the expense of understanding
- do not reproduce the full email body
- quote only short phrases when necessary
- do not perform delete or unsubscribe actions
- do not include secrets or credentials in output
- prefer canonical article or newsletter links over noisy tracking-heavy links when both are available
