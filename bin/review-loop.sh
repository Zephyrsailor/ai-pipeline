#!/usr/bin/env bash
set -euo pipefail

# Review Loop (autoresearch pattern):
#   LOOP (max N rounds):
#     1. Claude Code reviews code → {approved: bool, issues: [...]}
#     2. If approved → KEEP, break
#     3. If not → Claude Code fixes issues → repeat
#   OUTPUT: {review_passed: bool, rounds: N}

REPO="${REPO:-.}"
MAX_ROUNDS="${MAX_ROUNDS:-3}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

START_TIME=$(date +%s)
round=0
review_passed=false
last_issues=""

while [ "$round" -lt "$MAX_ROUNDS" ]; do
  round=$((round + 1))
  echo "=== Review round $round/$MAX_ROUNDS ===" >&2

  # Step 1: Run reviewer
  review_result=$(claude --print \
    --system-prompt "$(cat "$SCRIPT_DIR/prompts/reviewer.md")" \
    --prompt "Review ALL recent changes in this repo. Check for bugs, style issues, missing tests, security problems.

Output ONLY a JSON object:
{\"approved\": true/false, \"issues\": [\"issue1\", \"issue2\"], \"summary\": \"one line summary\"}" \
    --cwd "$REPO" \
    --output-format json \
    --max-turns 3 \
    2>/dev/null) || review_result='{"approved": false, "issues": ["reviewer agent crashed"]}'

  # Extract approval status
  approved=$(echo "$review_result" | jq -r '.approved // false' 2>/dev/null || echo "false")

  if [ "$approved" = "true" ]; then
    review_passed=true
    echo "=== Review APPROVED at round $round ===" >&2
    break
  fi

  # Extract issues for fix attempt
  last_issues=$(echo "$review_result" | jq -r '.issues // [] | join("\n")' 2>/dev/null || echo "unknown issues")
  echo "=== Review round $round REJECTED: $last_issues ===" >&2

  # Step 2: If not approved and more rounds left, fix
  if [ "$round" -lt "$MAX_ROUNDS" ]; then
    echo "=== Fixing issues (attempt $round) ===" >&2
    claude --print \
      --system-prompt "$(cat "$SCRIPT_DIR/prompts/programmer.md")" \
      --prompt "Fix these code review issues found in the repo:

$last_issues

Make minimal, targeted fixes. Commit your changes." \
      --cwd "$REPO" \
      --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
      2>/dev/null || true
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Output structured result (like autoresearch's results.tsv row)
jq -n \
  --argjson passed "$review_passed" \
  --argjson rounds "$round" \
  --argjson max "$MAX_ROUNDS" \
  --argjson dur "$DURATION" \
  --arg issues "$last_issues" \
  '{review_passed: $passed, rounds: $rounds, max_rounds: $max, duration_seconds: $dur, last_issues: $issues}'
