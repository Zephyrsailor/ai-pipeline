name: product-development
args:
  project_name:
    description: "Project or feature name"
  requirement:
    description: "Raw requirement or idea from user"
  repo:
    description: "Target repository path"
    default: "."
  request_id:
    description: "Unique request identifier"
steps:
  # Phase 1: Requirements Analysis
  - id: requirements
    run: ./bin/requirements.sh
    env:
      REPO: "${repo}"
      REQUIREMENT: "${requirement}"
      PROJECT_NAME: "${project_name}"
      REQUEST_ID: "${request_id}"

  - id: prd_signoff
    approval:
      prompt: "PRD ready. Review and approve to proceed to technical design."
    stdin: $requirements.json

  # Phase 2: Technical Design
  - id: design
    run: ./bin/design.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${request_id}"
    stdin: $requirements.json
    when: $prd_signoff.approved

  - id: design_signoff
    approval:
      prompt: "Technical design ready. Approve to start development."
    stdin: $design.json
    when: $prd_signoff.approved

  # Phase 3: Task Breakdown
  - id: tasks
    run: ./bin/task-breakdown.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${request_id}"
    stdin: $design.json
    when: $design_signoff.approved

  # Phase 4: Development
  - id: development
    run: ./bin/develop.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${request_id}"
    stdin: $tasks.json
    when: $design_signoff.approved

  # Phase 5: Code Review (loop - max 3 rounds)
  - id: review
    run: ./bin/review-loop.sh
    env:
      REPO: "${repo}"
      MAX_ROUNDS: "3"
    when: $design_signoff.approved

  # Phase 6: Testing
  - id: testing
    run: ./bin/test.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${request_id}"
    stdin: $requirements.json
    when: $design_signoff.approved

  - id: release_signoff
    approval:
      prompt: "All tests passed. Approve release?"
    stdin: $testing.json
    when: $design_signoff.approved

  # Phase 7: Release
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
      WORKFLOW: "product-dev"
