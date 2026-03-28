name: product-development
args:
  slug:
    description: "Project slug (lowercase-hyphenated)"
  requirement:
    description: "Raw requirement from user"
  repo:
    description: "Target repository path (absolute)"
  product_thread:
    description: "Discord thread ID for #product"
  design_thread:
    description: "Discord thread ID for #design"
  dev_thread:
    description: "Discord thread ID for #dev"
  qa_thread:
    description: "Discord thread ID for #qa"
  release_thread:
    description: "Discord thread ID for #release"
steps:
  # ── Init ──
  - id: init
    run: |
      mkdir -p "${repo}/docs" "${repo}/src" "${repo}/tests"
      STATE="${repo}/docs/.pipeline-state.json"
      jq -n --arg slug "${slug}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{project:$slug, created_at:$now, current_phase:"requirements",
          phases:{requirements:{status:"in_progress",started_at:$now},
                  design:{status:"pending"},development:{status:"pending"},
                  testing:{status:"pending"},release:{status:"pending"}}}' > "$STATE"
      cd "${repo}" && git add -A && git commit -q -m "chore(${slug}): init pipeline" 2>/dev/null || true
      echo "initialized"

  # ── Requirements ──
  - id: requirements
    run: |
      MSG="Project [${slug}]. Requirement: ${requirement}. Tasks: 1) Analyze and write full PRD to ${repo}/docs/prd.md (markdown with overview, user stories, acceptance criteria) 2) Git commit in ${repo}: docs(${slug}): PRD completed 3) Reply with markdown summary. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-pm --deliver --channel discord --to ${product_thread} --json

  - id: requirements_done
    run: |
      STATE="${repo}/docs/.pipeline-state.json"
      TMP=$(mktemp) && jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.current_phase="design" | .phases.requirements.status="completed" | .phases.requirements.completed_at=$now | .phases.design.status="in_progress" | .phases.design.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      echo "phase: design"

  - id: prd_signoff
    approval:
      prompt: "PRD written to ${repo}/docs/prd.md. Review and approve."
    stdin: $requirements.json

  # ── Design ──
  - id: design
    run: |
      MSG="Project [${slug}]. Tasks: 1) Read ${repo}/docs/prd.md 2) Write tech design to ${repo}/docs/tech-design.md 3) Write task breakdown to ${repo}/docs/tasks.md 4) Git commit in ${repo}: docs(${slug}): technical design and tasks 5) Reply with markdown summary. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-architect --deliver --channel discord --to ${design_thread} --json
    when: $prd_signoff.approved

  - id: design_done
    run: |
      STATE="${repo}/docs/.pipeline-state.json"
      TMP=$(mktemp) && jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.current_phase="development" | .phases.design.status="completed" | .phases.design.completed_at=$now | .phases.development.status="in_progress" | .phases.development.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      echo "phase: development"
    when: $prd_signoff.approved

  - id: design_signoff
    approval:
      prompt: "Tech design and tasks written. Review and approve."
    stdin: $design.json
    when: $prd_signoff.approved

  # ── Development (on feature branch) ──
  - id: create_branch
    run: |
      cd "${repo}" && git checkout -b "feat/${slug}-mvp" 2>/dev/null || git checkout "feat/${slug}-mvp"
      echo "branch: feat/${slug}-mvp"
    when: $design_signoff.approved

  - id: development
    run: |
      MSG="Project [${slug}]. Tasks: 1) Read ${repo}/docs/tech-design.md and ${repo}/docs/tasks.md 2) Implement all code in ${repo} on current branch 3) Generate ${repo}/README.md (project description, install steps, usage) 4) Commit each module: feat(${slug}): description 5) Ensure tests pass 6) Reply with summary and file list. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-dev --deliver --channel discord --to ${dev_thread} --json
    when: $design_signoff.approved

  # ── Review ──
  - id: review
    run: |
      MSG="Project [${slug}], repo ${repo}. Review recent code changes on branch feat/${slug}-mvp. Check quality, security, test coverage, README completeness. Reply with issues or approval. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-reviewer --deliver --channel discord --to ${dev_thread} --json
    when: $design_signoff.approved

  # ── Testing ──
  - id: testing
    run: |
      MSG="Project [${slug}]. Tasks: 1) Read acceptance criteria from ${repo}/docs/prd.md 2) Run existing tests in ${repo} 3) Write additional tests for uncovered criteria 4) Write test report to ${repo}/docs/test-report.md 5) Git commit: test(${slug}): test report 6) Reply with test results. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-qa --deliver --channel discord --to ${qa_thread} --json
    when: $design_signoff.approved

  - id: testing_done
    run: |
      STATE="${repo}/docs/.pipeline-state.json"
      TMP=$(mktemp) && jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.current_phase="release" | .phases.development.status="completed" | .phases.development.completed_at=$now | .phases.testing.status="completed" | .phases.testing.completed_at=$now | .phases.release.status="in_progress" | .phases.release.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      echo "phase: release"
    when: $design_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Development, review, and testing complete. Approve release?"
    stdin: $testing.json
    when: $design_signoff.approved

  # ── Release ──
  - id: release
    run: |
      MSG="Project [${slug}], repo ${repo}. Tasks: 1) Verify code and test status 2) Write release notes to ${repo}/docs/release-notes.md 3) Git commit: docs(${slug}): release notes 4) Reply with release summary. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-release --deliver --channel discord --to ${release_thread} --json
    when: $release_signoff.approved

  - id: release_done
    run: |
      STATE="${repo}/docs/.pipeline-state.json"
      TMP=$(mktemp) && jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.current_phase="done" | .phases.release.status="completed" | .phases.release.completed_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      cd "${repo}" && git add docs/.pipeline-state.json && git commit -q -m "chore(${slug}): pipeline complete" 2>/dev/null || true
      cat "$STATE"
    when: $release_signoff.approved
