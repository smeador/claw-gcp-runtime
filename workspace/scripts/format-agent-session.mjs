#!/usr/bin/env node

import fs from "node:fs";

const sessionPath = process.argv[2];
const logView = process.env.LOG_VIEW || "messages";

if (!sessionPath) {
  console.error("Usage: node /workspace/scripts/format-agent-session.mjs <session-jsonl>");
  process.exit(1);
}

const raw = fs.readFileSync(sessionPath, "utf8");
const lines = raw.split("\n").filter(Boolean);

function printBlock(prefix, text) {
  const body = String(text ?? "").replace(/\r\n/g, "\n");
  const chunks = body.split("\n");
  for (const line of chunks) {
    console.log(`${prefix}${line}`);
  }
}

function itemText(item) {
  if (!item || typeof item !== "object") return "";
  if (item.type === "text") return String(item.text ?? "");
  return "";
}

function isToolFailure(entry) {
  if (!entry?.message || entry.message.role !== "toolResult") {
    return false;
  }

  if (entry.message.isError === true) {
    return true;
  }

  const details = entry.message.details;
  if (details && typeof details === "object") {
    if (details.status === "failed") {
      return true;
    }
    if (typeof details.exitCode === "number" && details.exitCode !== 0) {
      return true;
    }
  }

  return false;
}

for (const line of lines) {
  let entry;
  try {
    entry = JSON.parse(line);
  } catch {
    continue;
  }

  if (entry.type !== "message" || !entry.message) {
    continue;
  }

  const ts = entry.timestamp ?? "";
  const role = entry.message.role ?? "unknown";
  const content = Array.isArray(entry.message.content) ? entry.message.content : [];

  if (logView === "replies" && role !== "assistant") {
    continue;
  }

  if (logView === "errors") {
    if (role !== "assistant" && !isToolFailure(entry)) {
      continue;
    }
  }

  if (logView === "messages" && role === "user") {
    continue;
  }

  if (logView === "messages" && role === "toolResult" && !isToolFailure(entry)) {
    continue;
  }

  console.log(`\n[${ts}] ${role}`);

  for (const item of content) {
    if (!item || typeof item !== "object") continue;

    if (item.type === "text") {
      if (logView === "messages" && role === "toolResult") {
        continue;
      }
      printBlock("  ", item.text ?? "");
      continue;
    }

    if (item.type === "thinking") {
      if (logView === "errors") {
        continue;
      }
      console.log("  [assistant thinking omitted]");
      continue;
    }

    if (item.type === "toolCall") {
      if (logView === "messages") {
        console.log(`  [tool use] ${item.name ?? "unknown"}`);
        continue;
      }
      if (logView !== "full") {
        continue;
      }
      console.log(`  [tool call] ${item.name ?? "unknown"}`);
      if (item.arguments !== undefined) {
        const args =
          typeof item.arguments === "string"
            ? item.arguments
            : JSON.stringify(item.arguments, null, 2);
        printBlock("    ", args);
      }
      continue;
    }
  }

  if (role === "toolResult") {
    if (logView === "messages") {
      if (isToolFailure(entry)) {
        console.log("  [tool error]");
      }
      continue;
    }
    for (const item of content) {
      if (!item || typeof item !== "object") continue;
      if (item.type === "text") {
        if (logView === "replies") {
          continue;
        }
        printBlock("  ", item.text ?? "");
      }
    }
  }
}
