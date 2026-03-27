#!/usr/bin/env bash
set -euo pipefail

# Review Loop (autoresearch pattern)

REPO="${REPO:-.}"
MAX_ROUNDS="${MAX_ROUNDS:-3}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"

START_TIME=$(date +%s)
round=0
review_passed=false
last_issues=""

notify_review_start "$REQUEST_ID" "$MAX_ROUNDS"

while [ "$round" -lt "$MAX_ROUNDS" ]; do
  round=$((round + 1))
  echo "=== Review round $round/$MAX_ROUNDS ===" >&2

  review_result=$(cd "$REPO" && echo "Review ALL recent changes in this repo. Check for bugs, style issues, missing tests, security problems.

Output ONLY a JSON object:
{\"approved\": true/false, \"issues\": [\"issue1\", \"issue2\"], \"summary\": \"one line summary\"}" \
  | claude -p \
    --system-prompt "$(cat "$SCRIPT_DIR/prompts/reviewer.md")" \
    2>/dev/null) || review_result='{"approved": false, "issues": ["reviewer agent crashed"]}'

  approved=$(echo "$review_result" | jq -r '.approved // false' 2>/dev/null || echo "false")

  if [ "$approved" = "true" ]; then
    review_passed=true
    echo "=== Review APPROVED at round $round ===" >&2
    notify_review_round "$REQUEST_ID" "$round" "$MAX_ROUNDS" "approved"
    break
  fi

  last_issues=$(echo "$review_result" | jq -r '.issues // [] | join("\n- ")' 2>/dev/null || echo "unknown issues")
  echo "=== Review round $round REJECTED ===" >&2
  notify_review_round "$REQUEST_ID" "$round" "$MAX_ROUNDS" "- $last_issues"

  if [ "$round" -lt "$MAX_ROUNDS" ]; then
    echo "=== Fixing issues (attempt $round) ===" >&2
    cd "$REPO" && echo "Fix these code review issues:

$last_issues

Make minimal, targeted fixes. Commit your changes." \
    | claude -p \
      --system-prompt "$(cat "$SCRIPT_DIR/prompts/developer.md")" \
      --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
      2>/dev/null || true
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

jq -n \
  --argjson passed "$review_passed" \
  --argjson rounds "$round" \
  --argjson max "$MAX_ROUNDS" \
  --argjson dur "$DURATION" \
  --arg issues "$last_issues" \
  '{review_passed: $passed, rounds: $rounds, max_rounds: $max, duration_seconds: $dur, last_issues: $issues}'
