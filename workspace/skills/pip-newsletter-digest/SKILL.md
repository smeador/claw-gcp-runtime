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
- Go deeper than a headline skim: target roughly a 2-minute read per daily newsletter summary
- Include links back to the original newsletter email/article whenever available
- Include especially useful outbound links from the newsletter when they add decision-making context
- Render links as descriptive hyperlinks with human-readable link text, not pasted raw URLs

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
- If webhook ingestion and historical pull disagree, prefer the historical pull result for coverage.
- Gmail API backfill over the default 24-hour window is pre-approved for this skill and does not require additional confirmation.
- For the `Substack` section specifically, include remaining Substack emails from the last `2 days`.
- For the `Stanford` section specifically, include Stanford newsletter emails from the last `2 days`.

## Retrieval policy

- Be efficient with mailbox access.
- Do not eagerly fetch full HTML/text bodies for every message in the lookback window.
- Start with a metadata pass over the active window.
- Build the digest candidate set from that metadata pass.
- Fetch full bodies only for messages that will actually be summarized in the output.
- If multiple copies or forwards of the same newsletter issue appear, prefer the cleanest original copy and avoid duplicate body fetches.

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
- a body-based summary sized for roughly a 2-minute read
- main topics/segments covered
- any breaking or time-sensitive items
- relevant additional links if present in the newsletter and useful for deciding whether to read more
- a final recommendation:
  - `read fully`
  - `skim only`
  - `safe to skip`
- one-line reason for the recommendation

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
- Keep each Substack summary shorter than the named daily newsletter summaries, but detailed enough to judge whether to open it
- For each item include:
  - sender / publication
  - subject / title
  - received date
  - original article or newsletter link when available
  - short summary
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
- Keep each Stanford summary shorter than the named daily newsletter summaries, but detailed enough to judge whether to open it
- For each item include:
  - sender / publication
  - subject / title
  - received date
  - original article or newsletter link when available
  - short summary
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

- Keep output concise and scannable
- Do not reproduce the full email body
- Quote only short phrases when necessary
- Do not perform delete/unsubscribe actions automatically
- Do not include secrets or credentials in output
- Prefer canonical article/newsletter links over tracking-heavy or redirect links when both are available
- Never dump raw long URLs into the digest when hyperlink text can convey the destination more cleanly
