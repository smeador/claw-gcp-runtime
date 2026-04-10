#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import process from "node:process";

function parseArgs(argv) {
  const options = {
    input: "",
    htmlOut: "",
    textOut: "",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    switch (arg) {
      case "--input":
        options.input = next ?? "";
        i += 1;
        break;
      case "--html-out":
        options.htmlOut = next ?? "";
        i += 1;
        break;
      case "--text-out":
        options.textOut = next ?? "";
        i += 1;
        break;
      case "-h":
      case "--help":
        printHelp();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!options.input || !options.htmlOut || !options.textOut) {
    printHelp();
    process.exit(1);
  }

  return options;
}

function printHelp() {
  console.log(`Usage:
  render-newsletter-digest.mjs --input DIGEST_JSON --html-out EMAIL_HTML --text-out EMAIL_TXT
`);
}

function readJson(path) {
  return JSON.parse(readFileSync(resolve(path), "utf8"));
}

function writeText(path, contents) {
  writeFileSync(resolve(path), contents.endsWith("\n") ? contents : `${contents}\n`, "utf8");
}

function assertString(value, label) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`Expected non-empty string for ${label}`);
  }
  return value;
}

function optionalString(value) {
  return typeof value === "string" ? value : "";
}

function assertArray(value, label) {
  if (!Array.isArray(value)) {
    throw new Error(`Expected array for ${label}`);
  }
  return value;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderLink(url, text) {
  const safeText = escapeHtml(text);
  if (!url) return safeText;
  return `<a href="${escapeHtml(url)}" style="color:#2563eb;text-decoration:none;">${safeText}</a>`;
}

function splitParagraphs(text) {
  return String(text)
    .trim()
    .split(/\n\s*\n/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function renderParagraphBlockHtml(text) {
  return splitParagraphs(text)
    .map(
      (paragraph) =>
        `        <p style="font-size:16px;line-height:1.75;margin:0 0 16px;">${escapeHtml(paragraph)}</p>`,
    )
    .join("\n");
}

function renderParagraphBlockText(text) {
  return splitParagraphs(text).join("\n\n");
}

function renderGroupHtml(group) {
  const title = optionalString(group.title);
  const kind = assertString(group.kind, "group.kind");
  let body = "";

  if (kind === "paragraphs") {
    body = renderParagraphBlockHtml(assertString(group.content, "group.content"));
  } else if (kind === "bullets") {
    const items = assertArray(group.content, "group.content");
    body = [
      '        <ul style="margin:0 0 24px 22px;padding:0;font-size:16px;line-height:1.75;">',
      ...items.map((item) => `          <li style="margin:0 0 10px;">${escapeHtml(assertString(item, "bullet"))}</li>`),
      "        </ul>",
    ].join("\n");
  } else {
    throw new Error(`Unsupported group kind: ${kind}`);
  }

  return [
    title
      ? `        <div style="font-size:12px;line-height:1.5;color:#6b7280;text-transform:uppercase;letter-spacing:1.2px;font-family:Arial, Helvetica, sans-serif;margin:0 0 8px;">${escapeHtml(title)}</div>`
      : "",
    body,
  ]
    .filter(Boolean)
    .join("\n");
}

function renderGroupText(group) {
  const title = optionalString(group.title);
  const kind = assertString(group.kind, "group.kind");

  if (kind === "paragraphs") {
    const body = renderParagraphBlockText(assertString(group.content, "group.content"));
    return [title, body].filter(Boolean).join("\n");
  }

  if (kind === "bullets") {
    const items = assertArray(group.content, "group.content");
    return [
      title,
      ...items.map((item) => `- ${assertString(item, "bullet")}`),
    ]
      .filter(Boolean)
      .join("\n");
  }

  throw new Error(`Unsupported group kind: ${kind}`);
}

function renderPrimarySectionHtml(section) {
  const groups = assertArray(section.groups, "section.groups");
  return [
    `      <div style="font-size:27px;line-height:1.25;font-weight:700;color:#111827;margin:28px 0 12px;">${escapeHtml(assertString(section.title, "section.title"))}</div>`,
    `      <div style="font-size:14px;line-height:1.7;color:#6b7280;margin:0 0 16px;">Issue date: ${escapeHtml(assertString(section.issueDate, "section.issueDate"))} · Sender: ${escapeHtml(assertString(section.sender, "section.sender"))} · ${renderLink(assertString(section.issueLink, "section.issueLink"), "Issue link")}</div>`,
    groups.map(renderGroupHtml).join("\n\n"),
    "",
  ].join("\n");
}

function renderPrimarySectionText(section) {
  const groups = assertArray(section.groups, "section.groups");
  return [
    assertString(section.title, "section.title"),
    `Issue date: ${assertString(section.issueDate, "section.issueDate")}`,
    `Sender: ${assertString(section.sender, "section.sender")}`,
    `Issue link: ${assertString(section.issueLink, "section.issueLink")}`,
    "",
    groups.map(renderGroupText).join("\n\n"),
  ].join("\n");
}

function renderSubstackHtml(section) {
  const items = assertArray(section.items, "section.items");
  const itemHtml =
    items.length === 0
      ? '        <ul style="margin:0 0 24px 22px;padding:0;font-size:16px;line-height:1.75;"><li style="margin:0;">No Substack items included today.</li></ul>'
      : [
          '        <ul style="margin:0 0 24px 22px;padding:0;font-size:16px;line-height:1.75;">',
          ...items.map((item) => {
            const publication = assertString(item.publication, "substack.publication");
            const title = assertString(item.title, "substack.title");
            const link = optionalString(item.link);
            const summary = assertString(item.summary, "substack.summary");
            return `          <li style="margin:0 0 12px;"><strong>${escapeHtml(publication)}</strong> — ${renderLink(link, title)}. ${escapeHtml(summary)}</li>`;
          }),
          "        </ul>",
        ].join("\n");

  return [
    `      <div style="font-size:27px;line-height:1.25;font-weight:700;color:#111827;margin:28px 0 12px;">${escapeHtml(assertString(section.title, "section.title"))}</div>`,
    itemHtml,
    "",
  ].join("\n");
}

function renderSubstackText(section) {
  const items = assertArray(section.items, "section.items");
  return [
    assertString(section.title, "section.title"),
    items.length === 0
      ? "No Substack items included today."
      : items
          .map((item) => {
            const publication = assertString(item.publication, "substack.publication");
            const title = assertString(item.title, "substack.title");
            const link = optionalString(item.link);
            const summary = assertString(item.summary, "substack.summary");
            return `${publication} — ${title}${link ? ` (${link})` : ""}. ${summary}`;
          })
          .map((line) => `- ${line}`)
          .join("\n"),
  ].join("\n");
}

function renderStanfordHtml(section) {
  const items = assertArray(section.items, "section.items");
  const itemHtml =
    items.length === 0
      ? `        <ul style="margin:0 0 8px 22px;padding:0;font-size:16px;line-height:1.75;"><li style="margin:0;">${escapeHtml(optionalString(section.emptyText) || "No Stanford items included today.")}</li></ul>`
      : [
          '        <ul style="margin:0 0 8px 22px;padding:0;font-size:16px;line-height:1.75;">',
          ...items.map((item) => {
            const title = assertString(item.title, "stanford.title");
            const link = optionalString(item.link);
            const summary = assertString(item.summary, "stanford.summary");
            return `          <li style="margin:0 0 12px;">${link ? renderLink(link, title) : escapeHtml(title)}. ${escapeHtml(summary)}</li>`;
          }),
          "        </ul>",
        ].join("\n");

  return [
    `      <div style="font-size:27px;line-height:1.25;font-weight:700;color:#111827;margin:28px 0 12px;">${escapeHtml(assertString(section.title, "section.title"))}</div>`,
    itemHtml,
    "",
  ].join("\n");
}

function renderStanfordText(section) {
  const items = assertArray(section.items, "section.items");
  return [
    assertString(section.title, "section.title"),
    items.length === 0
      ? optionalString(section.emptyText) || "No Stanford items included today."
      : items
          .map((item) => {
            const title = assertString(item.title, "stanford.title");
            const link = optionalString(item.link);
            const summary = assertString(item.summary, "stanford.summary");
            return `${title}${link ? ` (${link})` : ""}. ${summary}`;
          })
          .map((line) => `- ${line}`)
          .join("\n"),
  ].join("\n");
}

function renderSectionHtml(section) {
  const type = assertString(section.type, "section.type");
  if (type === "primary") return renderPrimarySectionHtml(section);
  if (type === "substack_review") return renderSubstackHtml(section);
  if (type === "stanford") return renderStanfordHtml(section);
  throw new Error(`Unsupported section type: ${type}`);
}

function renderSectionText(section) {
  const type = assertString(section.type, "section.type");
  if (type === "primary") return renderPrimarySectionText(section);
  if (type === "substack_review") return renderSubstackText(section);
  if (type === "stanford") return renderStanfordText(section);
  throw new Error(`Unsupported section type: ${type}`);
}

function renderInventoryText(inventory) {
  const foundPrimary = assertArray(inventory.foundPrimary, "inventory.foundPrimary");
  const missingPrimary = assertArray(inventory.missingPrimary, "inventory.missingPrimary");
  const substackCount = Number(inventory.substackCount ?? 0);
  const stanfordCount = Number(inventory.stanfordCount ?? 0);
  return `Found primary newsletters: ${foundPrimary.join(", ") || "none"}.\nMissing primary newsletters: ${missingPrimary.join(", ") || "none"}.\nIncluded extras: ${substackCount} Substack items, ${stanfordCount} Stanford items.`;
}

function renderInventoryHtml(inventory) {
  const foundPrimary = assertArray(inventory.foundPrimary, "inventory.foundPrimary");
  const missingPrimary = assertArray(inventory.missingPrimary, "inventory.missingPrimary");
  const substackCount = Number(inventory.substackCount ?? 0);
  const stanfordCount = Number(inventory.stanfordCount ?? 0);
  return `<strong>Found:</strong> ${escapeHtml(foundPrimary.join(", ") || "none")}. <strong>Missing:</strong> ${escapeHtml(missingPrimary.join(", ") || "none")}. <strong>Substack:</strong> ${substackCount} items. <strong>Stanford:</strong> ${stanfordCount} items.`;
}

function renderHtml(digest) {
  const sections = assertArray(digest.sections, "sections");
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(assertString(digest.title, "title"))}</title>
</head>
<body style="margin:0;padding:0;background:#f7f7f4;color:#1f2328;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;">
  <div style="max-width:760px;margin:0 auto;padding:24px 18px 40px;line-height:1.6;">
    <div style="font-family:Georgia,serif;font-size:38px;line-height:1.1;font-weight:700;margin:0 0 8px;color:#111827;">${escapeHtml(assertString(digest.title, "title"))}</div>
    <div style="margin:0 0 18px;font-size:16px;color:#4a5560;">${escapeHtml(assertString(digest.date, "date"))}</div>
    <div style="margin:0 0 26px;font-size:15px;line-height:1.7;">${renderInventoryHtml(digest.inventory ?? {})}</div>

${sections.map(renderSectionHtml).join("\n")}
  </div>
</body>
</html>`;
}

function renderText(digest) {
  const sections = assertArray(digest.sections, "sections");
  return [
    assertString(digest.title, "title"),
    assertString(digest.date, "date"),
    "",
    renderInventoryText(digest.inventory ?? {}),
    "",
    sections.map(renderSectionText).join("\n\n"),
  ].join("\n");
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const digest = readJson(options.input);
  const html = renderHtml(digest);
  const text = renderText(digest);
  writeText(options.htmlOut, html);
  writeText(options.textOut, text);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
