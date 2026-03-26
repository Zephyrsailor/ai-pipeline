name: bugfix
args:
  repo:
    description: "Target repository path"
  bug_report:
    description: "Bug report description"
  request_id:
    description: "Unique request identifier"
steps:
  - id: triage
    run: ./bin/triage.sh
    env:
      REPO: "${repo}"
      BUG_REPORT: "${bug_report}"

  - id: fix
    run: ./bin/fix-until-pass.sh
    env:
      REPO: "${repo}"
      MAX_ATTEMPTS: "5"
    stdin: $triage.json

  - id: merge_approval
    approval:
      prompt: "Fix verified. Approve PR creation and merge?"
    stdin: $fix.json

  - id: create_pr
    run: |
      cd "${repo}" && gh pr create \
        --title "fix: ${request_id}" \
        --body "Auto-fix by ai-pipeline" \
        2>&1 | jq -Rs '{pr_url: .}'
    when: $merge_approval.approved

  - id: metrics
    run: ./bin/log-metric.sh
    env:
      REQUEST_ID: "${request_id}"
      WORKFLOW: "bugfix"
      TEST_ATTEMPTS: "$(echo '$fix.json' | jq -r '.attempts // 1')"
