# pip-newsletter-digest

Use this skill to produce Pip's daily newsletter digest from email only.

## Scope

- Input source is newsletter email in Pip's inbox
- Ignore GoodLinks and non-email sources for now
- Current phase focuses on three named daily newsletters:
  - `NY Times Morning`
  - `Daily Upside`
  - `AI News` (`swyx+ainews@substack.com`)
- Read the body of each newsletter and summarize the actual content, not just subject/sender metadata
- Every run must perform a historical pull over a rolling last 24 hours window
- Include backlog items still in inbox within the window, even if they predate the current webhook watcher session
- Pub/Sub webhook events are optional context, not the sole source of truth
- Do not depend on Gmail labels in the current phase; use sender/title/content matching until Pip's labeling workflow is set up correctly
- Use a two-pass retrieval strategy:
  - first fetch metadata/snippets for the active lookback window
  - then fetch full bodies only for messages selected into the digest

## Current sources

- `NY Times Morning`
- `Daily Upside`
- `AI News`

If one or more are present in the last 24 hours, summarize each one found and explicitly note any expected newsletter that was not found.

## Interpretation goals

- Explain what the newsletter is mainly about today
- Identify the main topics or segments covered
- Call out any breaking news or genuinely time-sensitive items
- Help Sean decide whether the newsletter is worth opening and reading in full
- Go deeper than a headline skim: target a medium-depth synthesis for each important item
- The digest should let Sean get the gist of the newsletter or article by reading the digest alone, and only open the original when he wants additional depth
- Prefer synthesis over bullet-point extraction:
  - explain what mattered
  - connect related points
  - surface the overall narrative or thesis
- Include links back to the original newsletter email/article whenever available
- Include especially useful outbound links from the newsletter when they add decision-making context
- Render links as descriptive hyperlinks with human-readable link text, not pasted raw URLs
- After generating the digest, email it by default to `user@example.com` from `automation@example.com`

## Link extraction rules

For each newsletter, distinguish between:

- `newsletterLink`: the best link to the full newsletter itself
- `supportingLinks`: individual article or roundup links referenced inside the newsletter

Choose `newsletterLink` in this priority order:

1. explicit "View in browser" / "Read online" / newsletter permalink link
2. masthead or edition link that clearly opens the specific newsletter issue
3. publication page for that newsletter issue

Operational rule:

- `newsletterLink` should point to the issue as a whole, not to the lead story inside the issue.
- If a `View in browser` link exists, use it as `newsletterLink`.
- If the email contains both a browser-version issue link and a generic publication link, choose the browser-version issue link.
- If the available link is a tracked wrapper but it is clearly the browser-version issue link, still use it rather than substituting an unrelated homepage or article.

Do not use these as `newsletterLink` unless no better option exists:

- generic homepage links (for example `nytimes.com`)
- unsubscribe/settings links
- ad/sponsor links
- image-only asset URLs
- lead-story links embedded in the opening paragraphs
- section links such as `The Latest News`, `Morning Reads`, `The Interview`, or similar newsletter subsections

For newsletters like `NY Times Morning` that contain many inline article links:

- use the top `View in browser` link as `newsletterLink`
- if both `View in browser` and `nytimes.com` appear in the header, `View in browser` wins
- do not treat the first linked sentence in the intro as the newsletter link
- treat article links in sections like `The Latest News`, `Morning Reads`, or `The Interview` as `supportingLinks`

For newsletters with dense HTML like `NY Times Morning`, extract links with this precedence:

1. header utility links immediately above or beside the newsletter masthead
2. issue-level masthead or edition permalink
3. only then body/article links

If multiple candidates remain, prefer the one whose anchor text most clearly implies "this issue" rather than "this story."

For `supportingLinks`:

- include only the most relevant 2-5 links that materially help decide whether to read more
- prefer canonical editorial links over tracking-heavy wrappers when identifiable
- do not include `newsletterLink` again in `supportingLinks`
- present each link with short descriptive anchor text, not the raw URL string

## Source identification

Use sender, publication, subject, and body cues to identify newsletters.

Rules:

- Prefer canonical sender/publication identification over labels for now.
- Source query must include relevant newsletter messages within the active lookback window, not only newly arrived webhook events.
- Prefer the newsletter body as the primary source of truth for the summary.
- First identify candidate messages using sender, subject, publication, received date, and snippet/preview when available.
- Only fetch the full body after a message has been selected as one of:
  - a named daily newsletter
  - a Substack item to include
  - a Stanford item to include

## Lookback policy

- Default: rolling `last 24 hours`
- Override only when explicitly requested (for example: `last 48 hours` bootstrap run)
- Test mode may explicitly reuse an already-processed lookback window for rerendering and delivery checks.
- If webhook ingestion and historical pull disagree, prefer the historical pull result for coverage.
- Gmail API backfill over the default 24-hour window is pre-approved for this skill and does not require additional confirmation.
- For the `Substack` section specifically, include remaining Substack emails from the last `2 days`.
- For the `Stanford` section specifically, include Stanford newsletter emails from the last `2 days`.

## Test mode

- Support an explicit test mode for reruns.
- If the user says `test mode`, `rerender`, `rerun for test`, or otherwise clearly asks for a test rerun:
  - do not require newly arrived source emails
  - reuse matching newsletter content from the requested lookback window
  - ignore previously sent digest emails as source material
  - ignore the fact that a similar digest was already generated or delivered
  - still send the email
  - prioritize rendering and delivery validation over freshness checks
- In test mode, the goal is to validate digest content and real email rendering/delivery, not to prove that new mail arrived.
- Outside test mode, continue using the normal freshness behavior.

## Retrieval policy

- Be efficient with mailbox access.
- Do not eagerly fetch full HTML/text bodies for every message in the lookback window.
- Start with a metadata pass over the active window.
- Build the digest candidate set from that metadata pass.
- Fetch full bodies only for messages that will actually be summarized in the output.
- If multiple copies or forwards of the same newsletter issue appear, prefer the cleanest original copy and avoid duplicate body fetches.

## Delivery policy

- Default delivery is email only.
- After composing the digest, send it to `user@example.com` from `automation@example.com`.
- Use the existing Gmail send path via `gog`, not SMTP.
- Use this subject format:
  - `Pip Newsletter Digest - YYYY-MM-DD`
- Use the local date in `America/Chicago` for the subject line.
- Before sending, produce two separate email artifacts:
  - `email_text`: the plain-text fallback body
  - `email_html`: the HTML email body
- The send step must use both artifacts:
  - `email_text` for the plain-text body
  - `email_html` for the HTML body
- Do not treat Markdown or rich plain text as a substitute for `email_html`.
- Do not also send the digest to Telegram by default in this phase.
- If email delivery fails:
  - keep the digest content in the agent response
  - report that email delivery failed
  - include the intended recipient and subject in the failure message
  - do not retry automatically
- If only a plain-text body was produced, treat that as an incomplete delivery artifact set and do not claim HTML email succeeded.

## Email rendering requirements

- `email_html` must be real HTML markup suitable for email clients, not Markdown and not pseudo-HTML fragments.
- The renderer should specify the HTML styling directly in the generated email markup.
- Use conservative, email-safe HTML with inline styles that render well in Gmail, Apple Mail, and Outlook.
- Keep the HTML self-contained; do not depend on external CSS, JavaScript, or remote layout assets.
- Use a consistent editorial style rather than generic app-style cards.
- Visual direction:
  - clean newsroom / weekend-brief aesthetic
  - light background, dark text, muted secondary text
  - restrained accent color for links and recommendation badges
- Preferred email-safe palette:
  - page background `#f5f1ea`
  - content background `#ffffff`
  - primary text `#1f1a17`
  - secondary text `#6b625c`
  - border `#ded6cd`
  - accent/link `#0f5c4d`
- Typography should feel editorial:
  - use Georgia or a similar serif stack for major headings and newsletter titles
  - use Arial/Helvetica/sans-serif for metadata, labels, and utility text
  - keep body copy highly readable, around `16px` with generous line height
- Use a clean visual hierarchy:
  - top masthead block with digest title, date, and lookback window
  - distinct section headers with subtle dividers
  - separated content blocks for each newsletter item
  - consistent spacing rhythm with generous padding
- Layout rules:
  - center the content in a single readable column
  - target a max width around `640px`
  - use section blocks with light borders or background contrast, not heavy shadows
  - avoid dense walls of text; break long summaries into short paragraphs
- Recommendations such as `read fully`, `skim only`, and `safe to skip` should be visually distinct.
  - render them as small pill-style labels or restrained badges
  - `read fully`: dark accent background with light text
  - `skim only`: light neutral background with dark text
  - `safe to skip`: very light muted background with subdued text
- Link treatment:
  - render links as labeled anchors, never raw URLs
  - use underlined editorial-style text links for supporting links
  - use a restrained button-like treatment only for the main `original newsletter link` when it improves scanning
- Section-specific style:
  - `Daily Newsletters` should feel like the main feature well, with slightly stronger visual weight
  - `Substack` and `Stanford` should be more compact and list-like
  - `Quick Compare` should read like a concise editor's note or takeaway box
  - `Source Coverage` should be de-emphasized as footer metadata
- Avoid heavy visual design that may break in email clients:
  - no large hero images
  - no complex responsive layouts
  - no reliance on CSS classes without inline fallback
  - no dark-mode-dependent design
  - no decorative gradients, oversized banners, or gimmicky UI chrome
- `email_text` should preserve the same section order and essential content as the HTML version.
- Build `email_text` and `email_html` from the same digest content so they stay semantically aligned.
- Do not make the HTML version materially shorter than the plain-text version.
- HTML is for presentation improvement, not summary compression.

## Required digest format

1. Daily Digest Header
- date / lookback window used
- which newsletters were found

2. Daily Newsletters

Include up to these three sources:
- `NY Times Morning`
- `Daily Upside`
- `AI News`

For each newsletter found, include:
- newsletter name
- sender / publication
- original newsletter link
- a medium-depth body-based synthesis sized for a few substantive paragraphs
- main topics/segments covered
- any breaking or time-sensitive items
- relevant additional links if present in the newsletter and useful for deciding whether to read more
- a final recommendation:
  - `read fully`
  - `skim only`
  - `safe to skip`
- one-line reason for the recommendation

Daily newsletter synthesis expectations:

- Aim for enough depth that Sean can understand the issue without opening the source immediately.
- Cover:
  - the central narrative or purpose of the issue
  - the most important sections or arguments
  - what is genuinely new, important, or surprising
  - what is skimmable versus what merits deeper reading
- Do not collapse the summary into only 2-4 bullets unless the issue itself is unusually thin.

### AI News special handling

For `AI News`:

- go slightly deeper than the other daily newsletters
- include the main AI stories covered
- capture notable tools, model launches, research, or ecosystem updates
- if the issue contains a Twitter/X roundup, include:
  - the main themes from that roundup
  - the most relevant linked posts/articles
  - why those links matter
- include direct links for the most useful roundup items when available

If a named daily newsletter is not found, note it explicitly.

3. Substack

- Summarize each remaining Substack email from the last 2 days that is not already covered in `Daily Newsletters`
- Exclude `AI News` from this section because it is already covered above
- Apply that exclusion silently; do not print a note saying that `AI News` was excluded
- These are usually longer-form pieces, so each summary should capture:
  - core thesis
  - main arguments or sections
  - whether it appears worth reading in full
- Keep each Substack summary shorter than the named daily newsletter summaries, but still substantive enough to understand the argument before deciding whether to open it
- For each item include:
  - sender / publication
  - subject / title
  - received date
  - original article or newsletter link when available
  - medium-length synthesis
  - relevant supporting links when they materially help decide whether to read it
  - recommendation:
    - `read fully`
    - `skim only`
    - `safe to skip`

4. Stanford

- Summarize each Stanford newsletter email from the last 2 days that is not already covered in `Daily Newsletters`
- Treat this section like `Substack`: these are usually longer-form or institution-specific updates, so capture:
  - core thesis or main update
  - major sections, announcements, or takeaways
  - whether it appears worth reading in full
- Keep each Stanford summary shorter than the named daily newsletter summaries, but still substantive enough to convey the real content and significance
- For each item include:
  - sender / publication
  - subject / title
  - received date
  - original article or newsletter link when available
  - medium-length synthesis
  - relevant supporting links when they materially help decide whether to read it
  - recommendation:
    - `read fully`
    - `skim only`
    - `safe to skip`

5. Quick Compare

- Compare the three named daily newsletters if more than one is present:
  - which one matters most today
  - where they overlap
  - which can be safely skimmed or skipped

6. Source Coverage
- count of processed newsletter messages by source/publication
- note if expected daily newsletter was missing from the last 24 hours
- note how many additional Substack emails were summarized from the last 2 days
- note how many Stanford newsletter emails were summarized from the last 2 days

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
