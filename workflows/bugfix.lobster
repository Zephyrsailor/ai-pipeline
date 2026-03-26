name: bugfix
args:
  repo:
    description: "Target repository path"
    default: "."
  bug_report:
    description: "Bug report or error description"
  request_id:
    description: "Unique request identifier"
steps:
  # Phase 1: Triage
  - id: triage
    run: ./bin/triage.sh
    env:
      REPO: "${repo}"
      BUG_REPORT: "${bug_report}"
      REQUEST_ID: "${request_id}"

  - id: triage_signoff
    approval:
      prompt: "Bug triaged. Review root cause analysis and approve fix plan."
    stdin: $triage.json

  # Phase 2: Fix Loop (max 5 attempts)
  - id: fix
    run: ./bin/fix-until-pass.sh
    env:
      REPO: "${repo}"
      MAX_ATTEMPTS: "5"
      REQUEST_ID: "${request_id}"
    stdin: $triage.json
    when: $triage_signoff.approved

  # Phase 3: Code Review
  - id: review
    run: ./bin/review-loop.sh
    env:
      REPO: "${repo}"
      MAX_ROUNDS: "2"
    when: $triage_signoff.approved

  # Phase 4: Verification
  - id: verify
    run: ./bin/test.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${request_id}"
    stdin: $triage.json
    when: $triage_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Fix verified. Approve release?"
    stdin: $verify.json
    when: $triage_signoff.approved

  # Phase 5: Release
  - id: release
    run: ./bin/release.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${request_id}"
    when: $release_signoff.approved

  # Metrics
  - id: metrics
    run: ./bin/log-metric.sh
    env:
      REQUEST_ID: "${request_id}"
      WORKFLOW: "bugfix"
