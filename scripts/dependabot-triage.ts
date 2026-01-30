#!/usr/bin/env bun
/**
 * Dependabot Triage Script
 * Shows Dependabot PRs needing attention
 *
 * Usage: bun run scripts/dependabot-triage.ts [repo]
 * Example: bun run scripts/dependabot-triage.ts owner/repo
 */

import { $ } from "bun";
process.env.PATH = `/opt/homebrew/bin:/usr/local/bin:${process.env.PATH}`;
delete process.env.GITHUB_TOKEN; // Use gh keyring auth, not stale env token

interface PR {
  number: number;
  title: string;
  url: string;
  labels: string[];
  mergeable: string;
  statusCheckRollup: { state: string }[];
}

async function main() {
  const repo = process.argv[2] || (await getDefaultRepo());

  console.log(`\n📦 Dependabot Triage: ${repo}\n`);
  console.log("─".repeat(60));

  // Get all Dependabot PRs
  const prs = await getDependabotPRs(repo);

  if (prs.length === 0) {
    console.log("✅ No Dependabot PRs pending\n");
    await showBrewOutdated();
    return;
  }

  // Categorize
  const majors: PR[] = [];
  const failing: PR[] = [];
  const autoMerging: PR[] = [];

  for (const pr of prs) {
    const isMajor = pr.title.includes("from") && isMajorUpdate(pr.title);

    if (isMajor) {
      majors.push(pr);
    } else if (hasCIFailure(pr)) {
      failing.push(pr);
    } else {
      autoMerging.push(pr);
    }
  }

  // Display results
  if (majors.length > 0) {
    console.log("\n🔴 Major Updates (manual review required):");
    for (const pr of majors) {
      console.log(`   #${pr.number}: ${pr.title}`);
      console.log(`   └─ ${pr.url}`);
    }
  }

  if (failing.length > 0) {
    console.log("\n🟡 Failing CI (fix required):");
    for (const pr of failing) {
      console.log(`   #${pr.number}: ${pr.title}`);
      console.log(`   └─ ${pr.url}`);
    }
  }

  if (autoMerging.length > 0) {
    console.log(`\n🟢 Auto-merging (${autoMerging.length} PRs):`);
    for (const pr of autoMerging.slice(0, 3)) {
      console.log(`   #${pr.number}: ${pr.title}`);
    }
    if (autoMerging.length > 3) {
      console.log(`   ... and ${autoMerging.length - 3} more`);
    }
  }

  console.log("\n" + "─".repeat(60));
  await showBrewOutdated();
}

async function getDefaultRepo(): Promise<string> {
  const result =
    await $`gh repo view --json nameWithOwner -q .nameWithOwner`.quiet();
  return result.text().trim();
}

async function getDependabotPRs(repo: string): Promise<PR[]> {
  try {
    const result =
      await $`gh pr list --repo ${repo} --author "dependabot[bot]" --json number,title,url,labels,mergeable,statusCheckRollup`.quiet();
    return JSON.parse(result.text());
  } catch {
    console.error("❌ Failed to fetch PRs. Is gh authenticated?");
    process.exit(1);
  }
}

function isMajorUpdate(title: string): boolean {
  // Match "from X.Y.Z to A.B.C" and check if major version changed
  const match = title.match(/from (\d+)\.\d+\.\d+ to (\d+)\.\d+\.\d+/);
  if (match) {
    return match[1] !== match[2];
  }
  return false;
}

function hasCIFailure(pr: PR): boolean {
  if (!pr.statusCheckRollup || pr.statusCheckRollup.length === 0) {
    return false;
  }
  return pr.statusCheckRollup.some((check) => check.state === "FAILURE");
}

async function showBrewOutdated() {
  console.log("\n🍺 Homebrew Outdated (notify only):");
  try {
    const result =
      await $`brew outdated --verbose 2>/dev/null | head -10`.quiet();
    const output = result.text().trim();
    if (output) {
      console.log(
        output
          .split("\n")
          .map((l: string) => `   ${l}`)
          .join("\n"),
      );
    } else {
      console.log("   All Homebrew packages up to date");
    }
  } catch {
    console.log("   (brew not available or error)");
  }
  console.log("");
}

main().catch(console.error);
