# pip-newsletter-digest

Use this skill to produce Pip's newsletter digest from email only.

## Core goal

Write a digest that lets Sean understand each newsletter without opening it immediately.

The digest should:

- explain the main story clearly
- follow the structure of the original newsletter
- include the important secondary sections below the main story
- preserve the same substance in plaintext and HTML
- be notably more descriptive than a skim summary
- err on the side of more useful detail when there is enough source material

Do not write a short teaser. Write a real digest.

## Invocation rules

Treat these user requests as explicit commands to execute this workflow immediately, without asking what to run:

- `Run pip-newsletter-digest now.`
- `Run pip-newsletter-digest now in test mode.`
- `Run the Pip newsletter digest now.`
- `Send today's Pip newsletter digest.`

When the user uses one of those phrasings, do not ask follow-up questions like:

- `Run what, specifically?`
- `Which job/script do you mean?`

Assume they mean this skill and execute it.

## Sources in scope

Named daily newsletters:

- `NY Times Morning`
- `Daily Upside`
- `AI News` (`swyx+ainews@substack.com`)

Additional sections:

- Substack emails from the last `2 days`
- Stanford newsletter emails from the last `2 days`

Ignore GoodLinks and non-email sources.

## Retrieval rules

- Default lookback: rolling `last 24 hours`
- Always do a historical pull; do not rely only on webhook/new-mail state
- First fetch metadata/snippets for the lookback window
- Then fetch full bodies only for messages you are actually going to use
- For each named daily newsletter, choose the newest valid issue in the active window
- Prefer the newest same-day issue in `America/Chicago` when one exists
- If the digest runs shortly after the normal send time, explicitly check whether a newer same-day issue arrived after an earlier digest run

### Fast-path senders

Use these first for speed and precision:

- `NY Times Morning`: `nytdirect@nytimes.com`
- `Daily Upside`: `squad@thedailyupside.com`
- `AI News`: `swyx+ainews@substack.com`

If a fast-path sender query returns no valid issue, fall back to broader sender/subject/publication/body matching before marking the source as missing.

### Daily Upside matching

- Do not rely on one exact sender forever
- If a message looks plausibly like Daily Upside but sender formatting changed, inspect it instead of excluding it
- Treat sender variants, wrappers, and aliases as eligible when the subject/publication clearly indicate Daily Upside

## Link rules

For each newsletter, distinguish between:

- `newsletterLink`: best link to the issue as a whole
- `supportingLinks`: useful links to stories or roundup items inside the issue

For the named daily newsletters in this workflow, assume there is an issue-level browser link to find.

Pick `newsletterLink` in this order:

1. explicit `View in browser` / `Read in browser` / `Read online` / issue permalink
2. masthead or issue-level permalink
3. publication page for that issue

Do not use these as `newsletterLink` unless no better option exists:

- generic homepage links
- Gmail links, mailbox links, message-view links, or thread-view links
- unsubscribe/settings links
- ad/sponsor links
- image-only asset URLs
- lead-story links that are clearly not the issue itself

For `supportingLinks`:

- include only the most useful 2-5 links
- do not repeat `newsletterLink`
- use descriptive link text, not raw URLs
- do not use Gmail links, mailbox links, message-view links, or thread-view links

Daily newsletter browser-link rule:

- `NY Times Morning`, `Daily Upside`, and `AI News` should each have an issue-level browser link in the email.
- Actively look for phrases such as:
  - `View in browser`
  - `Read in browser`
  - `Read online`
- Prefer that browser link over internal mailbox links or generic publication links.

## Writing rules

- Prefer synthesis over headline extraction
- Explain what mattered, not just what appeared
- Preserve the structure of the original newsletter when possible
- HTML and plaintext must contain the same substantive content
- Do not make the HTML version materially shorter than plaintext
- The safe rule is: write the digest once at full depth, then render that same content into both formats

### Depth rules

Named daily newsletters:

- medium depth by default
- in practice, aim for roughly twice as much detail as a brief newsletter summary
- usually `3-5` substantive paragraphs for the main synthesis when the issue has real content
- then section bullets for the additional meaningful sections
- each section bullet should usually be `2-4` sentences
- describe what happened, why it matters, and what Sean would learn by opening the original
- do not compress meaningful sections into single-sentence blurbs

Substack and Stanford:

- keep the same recommendation model
- go a bit deeper than a one-line blurb
- usually `2-4` sentences each
- explain thesis, key point, and why it may or may not be worth opening

## Per-newsletter structure

### NY Times Morning

Typical structure:

- one main intro story
- several additional top stories / highlights / breaking news items below

Digest structure:

- write the main synthesis around the lead story and the issue's overall frame
- then add bullets for the notable stories and breaking news below
- those bullets should explain what happened and why it matters, not just list topics
- when the issue has several meaningful lower sections, cover enough of them that the digest feels like a faithful short-form version of the full newsletter

### Daily Upside

Typical structure:

- one intro story
- `3-4` other stories
- `Other Upside` at the bottom
- on Sunday, often one in-depth story instead

Digest structure:

- write the main synthesis around the opener
- then add bullets for the other stories below it
- if `Other Upside` exists and is meaningful, include it in bullets too
- on Sunday, if it is a single in-depth story, summarize that one story in more depth instead of forcing the normal multi-story shape
- for the weekday format, aim to cover the opener plus the main additional stories rather than only one or two highlights

### AI News

Typical structure:

- one main story / opener
- Twitter/X roundup

Digest structure:

- write the main synthesis around the opener and overall takeaway
- then add bullets for the important Twitter/X roundup items
- each roundup bullet should be `2-3` sentences and explain why the item mattered
- include enough descriptive context that the roundup feels informative on its own rather than just a list of names and links

## Delivery

- Send by default to `user@example.com` from `automation@example.com`
- Use `gog gmail send`, not SMTP
- Subject format:
  - `Pip Newsletter Digest - YYYY-MM-DD`
- Use the local date in `America/Chicago`
- Produce both:
  - `email_text`
  - `email_html`
- Both formats must carry the same substance

If delivery fails:

- keep the digest in the agent response
- report the failure clearly
- include intended recipient and subject
- do not auto-retry

## HTML rendering

- Keep the HTML version editorial, restrained, and email-safe
- Do not render the digest as a centered card floating on a contrasting page background
- Prefer a full-width reading surface with simple horizontal rhythm, like a briefing page or newspaper column
- The body should feel like one continuous editorial document, not a stack of app cards

Layout guidance:

- use the full email width for the main reading surface
- avoid a narrow boxed card with heavy border treatment
- use section dividers, spacing, and typography for structure instead of card chrome
- use light borders or rules only where they help separate sections
- keep the page background and content background close in tone so the message reads as full-width
- preserve generous padding and readable line length, but not a boxed panel aesthetic

Visual direction:

- clean editorial briefing
- light warm background
- dark readable text
- muted metadata and restrained accent color
- no heavy shadows, no stacked tiles, no app-dashboard feel

The HTML should feel closer to:

- a full-width Sunday briefing
- a newsroom digest
- a longform editorial email

and less like:

- a marketing card
- a boxed newsletter widget
- a dashboard of separate panels

## Test mode

If the user says `test mode`, `rerender`, or similar:

- reuse matching source content from the requested lookback window
- ignore previously sent digest emails as source material
- still send the email
- prioritize rendering and delivery validation

## Required output shape

### 1. Header

- date
- lookback window
- which daily newsletters were found
- which expected daily newsletters were missing

### 2. Daily Newsletters

For each found daily newsletter, include:

- newsletter name
- sender / publication
- original newsletter link
- main synthesis
- section bullets for the important items below the main story
- any especially useful supporting links
- recommendation:
  - `read fully`
  - `skim only`
  - `safe to skip`
- one-line reason

The daily newsletter section should feel substantially richer than the current brief format:

- more narrative detail in the main synthesis
- fuller bullets for the lower sections
- enough descriptive content that Sean can often skip opening the original unless he wants extra depth

If a named daily newsletter is missing, say so explicitly.

### 3. Substack

- summarize remaining Substack emails from the last `2 days`
- exclude `AI News` from this section silently
- for each item include sender/publication, title, link when available, `2-3` sentence synthesis, and recommendation

### 4. Stanford

- summarize Stanford newsletter emails from the last `2 days`
- for each item include sender/publication, title, link when available, `2-3` sentence synthesis, and recommendation

### 5. Quick Compare

If more than one named daily newsletter is present, compare:

- which one matters most today
- where they overlap
- which can be skimmed or skipped

### 6. Source Coverage

- processed count by source/publication
- which expected daily newsletters were missing
- how many Substack items were summarized
- how many Stanford items were summarized

## Constraints

- Keep output readable and scannable, but do not optimize for brevity at the expense of understanding
- It is acceptable for the digest email to be long if that is necessary to preserve useful synthesis
- Do not reproduce the full email body
- Quote only short phrases when necessary
- Do not perform delete/unsubscribe actions automatically
- Do not include secrets or credentials in output
- Prefer canonical article/newsletter links over tracking-heavy or redirect links when both are available
- Never dump raw long URLs into the digest when hyperlink text can convey the destination more cleanly
- Email output should be HTML-first with a plain-text fallback in this phase
