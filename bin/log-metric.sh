#!/usr/bin/env bash
set -euo pipefail

# Metrics Logger (autoresearch results.tsv pattern)
# Appends a row to data/metrics.tsv for every pipeline run

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
METRICS_FILE="${METRICS_FILE:-$SCRIPT_DIR/data/metrics.tsv}"

# Read context from stdin
CONTEXT=$(cat 2>/dev/null || echo '{}')

# Initialize TSV if missing
if [ ! -f "$METRICS_FILE" ]; then
  printf "timestamp\trequest_id\tworkflow\tstatus\tduration_s\treview_rounds\ttest_attempts\thuman_interventions\n" > "$METRICS_FILE"
fi

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
request_id="${REQUEST_ID:-unknown}"
workflow="${WORKFLOW:-unknown}"
review_rounds="${REVIEW_ROUNDS:-$(echo "$CONTEXT" | jq -r '.rounds // 0' 2>/dev/null || echo 0)}"
test_attempts="${TEST_ATTEMPTS:-$(echo "$CONTEXT" | jq -r '.attempts // 0' 2>/dev/null || echo 0)}"
duration=$(echo "$CONTEXT" | jq -r '.duration_seconds // 0' 2>/dev/null || echo 0)

# Determine status
passed=$(echo "$CONTEXT" | jq -r '.tests_passed // .review_passed // false' 2>/dev/null || echo "false")
if [ "$passed" = "true" ]; then
  status="success"
else
  status="failure"
fi

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t0\n" \
  "$timestamp" "$request_id" "$workflow" "$status" "$duration" "$review_rounds" "$test_attempts" \
  >> "$METRICS_FILE"

# Pass through context
echo "$CONTEXT"
