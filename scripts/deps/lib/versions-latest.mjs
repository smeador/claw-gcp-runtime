#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

export const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../../..");
const versionsPath = path.join(repoRoot, "versions.json");

function ensureOk(response, context) {
  if (!response.ok) {
    throw new Error(`${context} failed: ${response.status} ${response.statusText}`);
  }
}

export function loadVersions() {
  return JSON.parse(fs.readFileSync(versionsPath, "utf8"));
}

export function saveVersions(versions) {
  fs.writeFileSync(versionsPath, `${JSON.stringify(versions, null, 2)}\n`);
}

async function fetchJson(url, context) {
  const response = await fetch(url, {
    headers: {
      "user-agent": "claw-gcp-runtime/deps-check"
    }
  });
  ensureOk(response, context);
  return await response.json();
}

async function fetchNpmLatest(packageName) {
  const data = await fetchJson(`https://registry.npmjs.org/${encodeURIComponent(packageName)}`, `npm lookup for ${packageName}`);
  const latest = data?.["dist-tags"]?.latest;
  if (typeof latest !== "string" || latest.length === 0) {
    throw new Error(`npm lookup for ${packageName} returned no dist-tags.latest`);
  }
  return latest;
}

async function fetchGoLatest(modulePath) {
  const data = await fetchJson(`https://proxy.golang.org/${modulePath}/@latest`, `Go module lookup for ${modulePath}`);
  const latest = data?.Version;
  if (typeof latest !== "string" || latest.length === 0) {
    throw new Error(`Go module lookup for ${modulePath} returned no Version`);
  }
  return latest;
}

function makeManualEntry(current, note) {
  return {
    current,
    latest: current,
    changed: false,
    source: "manual",
    note
  };
}

function makeResolvedEntry(current, latest, source) {
  return {
    current,
    latest,
    changed: current !== latest,
    source
  };
}

export async function resolveLatestVersions() {
  const versions = loadVersions();
  const cloudDeps = versions.cloudFunction?.dependencies ?? {};
  const cloudDependencyEntries = await Promise.all(
    Object.entries(cloudDeps).map(async ([packageName, current]) => [
      packageName,
      makeResolvedEntry(current, await fetchNpmLatest(packageName), "npm")
    ])
  );

  return {
    docker: {
      goImage: makeManualEntry(
        versions.docker.goImage,
        "Manual family pin. Update intentionally when you want a different Go image track."
      ),
      nodeImage: makeManualEntry(
        versions.docker.nodeImage,
        "Manual family pin. Update intentionally when you want a different Node image track."
      )
    },
    runtime: {
      openclawVersion: makeResolvedEntry(
        versions.runtime.openclawVersion,
        await fetchNpmLatest("openclaw"),
        "npm"
      ),
      gogVersion: makeResolvedEntry(
        versions.runtime.gogVersion,
        await fetchGoLatest("github.com/steipete/gogcli"),
        "go"
      )
    },
    cloudFunction: {
      node: makeManualEntry(
        versions.cloudFunction.node,
        "Manual platform pin. Keep aligned with supported Cloud Functions Node runtimes."
      ),
      dependencies: Object.fromEntries(cloudDependencyEntries)
    }
  };
}

export function applyResolvedVersions(versions, resolved) {
  const next = structuredClone(versions);
  next.runtime.openclawVersion = resolved.runtime.openclawVersion.latest;
  next.runtime.gogVersion = resolved.runtime.gogVersion.latest;

  for (const [packageName, entry] of Object.entries(resolved.cloudFunction.dependencies)) {
    next.cloudFunction.dependencies[packageName] = entry.latest;
  }

  return next;
}

export function summarizeChanges(resolved) {
  const changes = [];

  if (resolved.runtime.openclawVersion.changed) {
    changes.push(`runtime.openclawVersion ${resolved.runtime.openclawVersion.current} -> ${resolved.runtime.openclawVersion.latest}`);
  }
  if (resolved.runtime.gogVersion.changed) {
    changes.push(`runtime.gogVersion ${resolved.runtime.gogVersion.current} -> ${resolved.runtime.gogVersion.latest}`);
  }
  for (const [packageName, entry] of Object.entries(resolved.cloudFunction.dependencies)) {
    if (entry.changed) {
      changes.push(`cloudFunction.dependencies.${packageName} ${entry.current} -> ${entry.latest}`);
    }
  }

  return changes;
}
