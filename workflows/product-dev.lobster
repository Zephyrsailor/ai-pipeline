name: product-development
args:
  slug:
    description: "Project slug (lowercase-hyphenated)"
  requirement:
    description: "Raw requirement or idea from user"
  repo:
    description: "Target repository path"
    default: "."
  user_id:
    description: "Requesting user ID"
    default: "unknown"
  user_name:
    description: "Requesting user display name"
    default: "unknown"
  channel:
    description: "Source channel type (discord/telegram/cli)"
    default: "cli"
steps:
  # ── Phase 0: Initialize project ──
  - id: init
    run: ./bin/init-project.sh
    env:
      SLUG: "${slug}"

  # ── Phase 1: Requirements ──
  - id: requirements
    run: ./bin/requirements.sh
    env:
      REPO: "${repo}"
      REQUIREMENT: "${requirement}"
      PROJECT_NAME: "${slug}"
      REQUEST_ID: "${slug}"

  - id: save_prd
    run: |
      echo "$LOBSTER_STDIN" > /tmp/prd-content.md
      SLUG="${SLUG}" SUMMARY="PRD completed" USER_ID="${USER_ID}" USER_NAME="${USER_NAME}" CHANNEL="${CHANNEL}" \
        ./bin/save-and-handoff.sh < /tmp/prd-content.md
    env:
      SLUG: "${slug}"
      USER_ID: "${user_id}"
      USER_NAME: "${user_name}"
      CHANNEL: "${channel}"
    stdin: $requirements.stdout

  - id: prd_signoff
    approval:
      prompt: "PRD saved to Git. Review and approve to proceed to technical design."
    stdin: $save_prd.json

  # ── Phase 2: Technical Design ──
  - id: design
    run: ./bin/design.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${slug}"
    stdin: $requirements.json
    when: $prd_signoff.approved

  - id: save_design
    run: |
      echo "$LOBSTER_STDIN" > /tmp/design-content.md
      SLUG="${SLUG}" SUMMARY="Technical design completed" USER_ID="${USER_ID}" USER_NAME="${USER_NAME}" CHANNEL="${CHANNEL}" \
        ./bin/save-and-handoff.sh < /tmp/design-content.md
    env:
      SLUG: "${slug}"
      USER_ID: "${user_id}"
      USER_NAME: "${user_name}"
      CHANNEL: "${channel}"
    stdin: $design.stdout
    when: $prd_signoff.approved

  - id: design_signoff
    approval:
      prompt: "Technical design saved to Git. Approve to start development."
    stdin: $save_design.json
    when: $prd_signoff.approved

  # ── Phase 3: Development ──
  - id: development
    run: ./bin/develop.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${slug}"
    stdin: $design.json
    when: $design_signoff.approved

  # ── Phase 4: Code Review (loop max 3 rounds) ──
  - id: review
    run: ./bin/review-loop.sh
    env:
      REPO: "${repo}"
      MAX_ROUNDS: "3"
    when: $design_signoff.approved

  # ── Phase 5: Testing ──
  - id: testing
    run: ./bin/test.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${slug}"
    stdin: $requirements.json
    when: $design_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Tests complete. Approve release?"
    stdin: $testing.json
    when: $design_signoff.approved

  # ── Phase 6: Release ──
  - id: release
    run: ./bin/release.sh
    env:
      REPO: "${repo}"
      REQUEST_ID: "${slug}"
    when: $release_signoff.approved

  # ── Metrics ──
  - id: metrics
    run: ./bin/log-metric.sh
    env:
      REQUEST_ID: "${slug}"
      WORKFLOW: "product-dev"
