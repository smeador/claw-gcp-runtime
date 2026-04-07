# pip-newsletter-digest-format

Use this skill to turn the already-selected newsletter source material into the final Pip newsletter digest.

This skill does not own inbox discovery. Do not do mailbox search or tool discovery here unless the caller explicitly says the source set is incomplete.

## Core writing contract

Write a real digest, not a quick summary.

Hard rules:

- preserve the original content and intent while reducing length
- give detail according to the section-specific rules below
- present the substance as a direct briefing, not commentary about a source document
- avoid source-framing language such as `the article says`, `the piece argues`, `the post mentions`, `the newsletter notes`, or `the author explains`
- prefer direct constructions like `OpenAI released...`, `Congress is considering...`, or `the company reported...`
- keep plaintext and HTML identical in substance and order
- synthesize only within each newsletter section, not across the whole digest
- do not flatten the whole digest into one narrative

## Output structure

### Header

Include only:

- title
- date
- short inventory of newsletters found

The inventory should be brief:

- which primary newsletters were found
- which primary newsletters were missing
- count of Substack and Stanford items included

Do not:

- add a separate lookback line
- repeat the title in multiple stacked forms
- add extra header blocks

## Primary newsletters

Create one section per found primary newsletter.

Each primary newsletter section must include:

- newsletter title
- issue date
- sender or publication
- issue link near the section header
- body content using the exact section rules below

Each section must use clear internal subsection labels.

### NY Times

Required structure:

- `Main article`
- `Other major stories`

Hard rules:

- `Main article` must be `2-3` paragraphs
- do not collapse it into one paragraph
- explain the lead story clearly and with real detail
- `Other major stories` must be bullets
- each bullet must describe what happened and why it matters
- do not use headline fragments as bullets

### Daily Upside

Required structure:

- `Opener`
- one section for each of the `3` main stories using the actual article titles as the subsection headers
- `Extra Upside` as a distinct mini section when present

Hard rules:

- do not use generic labels like `Story 1` if the article title is clear
- the opener must be its own labeled section
- the three main stories must each get one paragraph
- if more than three meaningful story blocks exist, keep the main three and place the remaining useful material in `Extra Upside`
- do not let the opener and the main stories run together as unlabeled paragraphs

### AI News

Required structure:

- `Main article`
- `Twitter roundup`

Hard rules:

- `Main article` must be `2-3` paragraphs
- do not collapse it into one paragraph
- `Twitter roundup` must be bullets
- each roundup bullet must be `1-2` descriptive sentences
- choose the most important items rather than trying to include everything

## Substack review

Include one bullet per included item.

Do not include `AI News` here.

Each bullet must contain:

- newsletter or publication name first
- hyperlinked title
- `2-3` sentence summary

## Stanford

Include one bullet per included item.

Each bullet must contain:

- hyperlinked title when a useful public link exists, otherwise plain title
- `1-2` sentence summary

## HTML rules

- HTML and plaintext must contain the same content in the same order
- links in HTML must be hyperlinks, not raw URLs
- keep the current restrained editorial layout
- primary section headers must remain visually stronger than subsection headers, including on mobile
- keep horizontal mobile padding tight enough that the reading column does not become too narrow
- use a very slightly off-white neutral background, not a warm beige tone
- keep the title `Pip Newsletter Digest` large and in a distinctive editorial serif stack

## Pre-send checklist

Before finalizing, verify every item below:

1. every found primary newsletter has a visible issue link near its header
2. `NY Times` has a `Main article` section with at least `2` paragraphs
3. `NY Times` `Other major stories` bullets explain significance, not just headlines
4. `Daily Upside` has `Opener`, three titled story sections, and `Extra Upside` when present
5. `AI News` has a `Main article` section with at least `2` paragraphs
6. `AI News` roundup bullets are `1-2` descriptive sentences each
7. Substack bullets start with the publication name, then the hyperlinked title
8. plaintext and HTML contain the same sections and same substantive content

If any item fails, revise the digest before handing it back for send.

## Constraints

- keep output readable and scannable, but do not optimize for brevity at the expense of understanding
- it is acceptable for the digest to be long if that is required to preserve useful synthesis
- do not reproduce the full email body
- quote only short phrases when necessary
- do not include secrets or credentials
