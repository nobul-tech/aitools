#!/usr/bin/env bash
# analyze-session.sh — Scans a Claude Code session transcript for standing order violations
#
# Usage: bash scripts/analyze-session.sh <transcript.jsonl> [--verbose]
#
# Detects:
#   USO: Dedicated tools -- Bash tool used for file operations (cat, grep, sed, find, etc.)
#   USO: Scratch files -- Long inline Bash commands (5+ lines)
#   Batch size: Many consecutive write/edit operations without verification steps
#
# Requires: node (for JSON parsing of JSONL)

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <transcript.jsonl> [--verbose]"
    exit 1
fi

TRANSCRIPT="$1"
VERBOSE=false
[ "${2:-}" = "--verbose" ] && VERBOSE=true

if [ ! -f "$TRANSCRIPT" ]; then
    echo "Error: file not found: $TRANSCRIPT"
    exit 1
fi

if ! command -v node &>/dev/null; then
    echo "Error: node required for JSONL parsing"
    exit 1
fi

node -e '
const fs = require("fs");
const path = require("path");

const file = process.argv[1];
const verbose = process.argv[2] === "true";

const lines = fs.readFileSync(file, "utf8").trim().split("\n");

// --- Detection patterns ---

// USO: Dedicated tools -- file-op commands in Bash tool
const fileOpPatterns = [
    { regex: /^cat\s/, tool: "Read", cmd: "cat" },
    { regex: /^head\s/, tool: "Read (with limit)", cmd: "head" },
    { regex: /^tail\s/, tool: "Read (with offset)", cmd: "tail" },
    { regex: /^grep\s/, tool: "Grep", cmd: "grep" },
    { regex: /^rg\s/, tool: "Grep", cmd: "rg" },
    { regex: /^egrep\s/, tool: "Grep", cmd: "egrep" },
    { regex: /^fgrep\s/, tool: "Grep", cmd: "fgrep" },
    { regex: /^find\s/, tool: "Glob", cmd: "find" },
    { regex: /^sed\s/, tool: "Edit", cmd: "sed" },
    { regex: /^awk\s/, tool: "Read", cmd: "awk" },
    { regex: /^echo\s.*>/, tool: "Write", cmd: "echo >" },
    { regex: /^printf\s.*>/, tool: "Write", cmd: "printf >" },
];

// Results
const violations = { dedicatedTools: [], scratchFiles: [], batch: [] };
let toolCalls = [];
let lineNum = 0;

for (const line of lines) {
    lineNum++;
    let obj;
    try { obj = JSON.parse(line); } catch { continue; }

    if (obj.type !== "assistant" || !obj.message?.content) continue;
    if (!Array.isArray(obj.message.content)) continue;

    for (const block of obj.message.content) {
        if (block.type !== "tool_use") continue;

        const toolName = block.name;
        const input = block.input || {};

        // Track tool call sequence for batch analysis
        toolCalls.push({ tool: toolName, line: lineNum, input });

        // USO: Dedicated tools -- Bash used for file ops
        if (toolName === "Bash" && input.command) {
            const cmd = input.command;
            const firstToken = cmd.split(/\s/)[0];

            for (const pat of fileOpPatterns) {
                if (pat.regex.test(cmd)) {
                    violations.dedicatedTools.push({
                        line: lineNum,
                        cmd: firstToken,
                        shouldUse: pat.tool,
                        snippet: cmd.length > 80 ? cmd.substring(0, 80) + "..." : cmd,
                    });
                    break;
                }
            }

            // USO: Scratch files -- Long inline commands (5+ lines)
            const nlCount = (cmd.match(/\n/g) || []).length;
            if (nlCount >= 4) {
                violations.scratchFiles.push({
                    line: lineNum,
                    lines: nlCount + 1,
                    snippet: cmd.substring(0, 80) + (cmd.length > 80 ? "..." : ""),
                });
            }
        }
    }
}

// --- Batch size analysis ---
// Look for sequences of 5+ consecutive Write/Edit calls without Read/Bash/Grep between them
let streak = 0;
let streakStart = -1;
for (const call of toolCalls) {
    if (call.tool === "Write" || call.tool === "Edit" || call.tool === "NotebookEdit") {
        if (streak === 0) streakStart = call.line;
        streak++;
    } else if (call.tool === "Read" || call.tool === "Bash" || call.tool === "Grep") {
        // A read/check step breaks the streak
        if (streak >= 5) {
            violations.batch.push({
                startLine: streakStart,
                endLine: call.line,
                count: streak,
            });
        }
        streak = 0;
    }
    // Glob, Agent, etc. do not break or contribute to streak
}
// Final streak check
if (streak >= 5) {
    violations.batch.push({
        startLine: streakStart,
        endLine: toolCalls[toolCalls.length - 1].line,
        count: streak,
    });
}

// --- Output ---
const totalTools = toolCalls.length;
const bashCalls = toolCalls.filter(c => c.tool === "Bash").length;

console.log("=== Session Analysis ===");
console.log("File: " + path.basename(file));
console.log("Tool calls: " + totalTools + " (Bash: " + bashCalls + ")");
console.log("");

// USO: Dedicated tools
console.log("--- USO: Dedicated tools (" + violations.dedicatedTools.length + " violations) ---");
if (violations.dedicatedTools.length === 0) {
    console.log("  None found.");
} else {
    for (const v of violations.dedicatedTools) {
        console.log("  L" + v.line + ": " + v.cmd + " -> should use " + v.shouldUse);
        if (verbose) console.log("    " + v.snippet);
    }
}
console.log("");

// USO: Scratch files
console.log("--- USO: Scratch files (" + violations.scratchFiles.length + " violations) ---");
if (violations.scratchFiles.length === 0) {
    console.log("  None found.");
} else {
    for (const v of violations.scratchFiles) {
        console.log("  L" + v.line + ": " + v.lines + " lines");
        if (verbose) console.log("    " + v.snippet);
    }
}
console.log("");

// Batch
console.log("--- Batch size: Write/Edit streaks without verification (" + violations.batch.length + " found) ---");
if (violations.batch.length === 0) {
    console.log("  None found (good batch discipline).");
} else {
    for (const v of violations.batch) {
        console.log("  L" + v.startLine + "-L" + v.endLine + ": " + v.count + " consecutive writes without read/check");
    }
}
console.log("");

// Summary
const total = violations.dedicatedTools.length + violations.scratchFiles.length + violations.batch.length;
if (total === 0) {
    console.log("CLEAN: No violations detected.");
} else {
    console.log("TOTAL: " + total + " violation(s) found.");
}
' "$TRANSCRIPT" "$VERBOSE"
