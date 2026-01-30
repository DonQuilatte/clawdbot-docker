#!/usr/bin/env bun
/**
 * Sync upstream repo changes
 * 
 * Usage: bun run scripts/sync-upstream.ts <repo-name>
 */

import { $ } from "bun";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { parse } from "yaml";

const repoName = process.argv[2];
if (!repoName) {
  console.error("Usage: bun run scripts/sync-upstream.ts <repo-name>");
  process.exit(1);
}

async function main() {
  const configPath = "/Users/jederlichman/Development/Projects/dev-infra/config/upstream-deps.yml";
  const config = parse(readFileSync(configPath, "utf-8"));
  const repo = config.upstream_repos[repoName];

  if (!repo) {
    console.error(`❌ Unknown repo: ${repoName}`);
    console.log("Available:", Object.keys(config.upstream_repos).join(", "));
    process.exit(1);
  }

  console.log(`\n🔄 Syncing ${repoName}...\n`);

  // Get latest commit
  const result = await $`git -C ${repo.path} log -1 --format=%H`.quiet();
  const latestHash = result.text().trim();

  // Show changes
  const changes = await $`git -C ${repo.path} log --oneline -10`.quiet();
  console.log("Recent commits:");
  console.log(changes.text());

  // Interactive review
  console.log(`\n📁 Watched paths: ${repo.watch.join(", ")}`);
  console.log(`📂 Sync to: ${repo.sync_to}`);
  console.log("\nReview changes and manually sync if needed.");
  console.log("(Auto-sync not implemented - requires manual review for safety)");

  // Record sync
  const trackingDir = "/Users/jederlichman/Development/Projects/dev-infra/.upstream";
  mkdirSync(trackingDir, { recursive: true });
  writeFileSync(`${trackingDir}/${repoName}.sync`, latestHash);
  
  console.log(`\n✅ Marked ${repoName} as reviewed at ${latestHash.substring(0, 7)}`);
}

main().catch(console.error);
