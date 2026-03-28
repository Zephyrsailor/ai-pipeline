name: product-development
args:
  slug:
    description: "Project slug (lowercase-hyphenated)"
  requirement:
    description: "Raw requirement from user"
  repo:
    description: "Target repository path (absolute)"
  product_thread:
    description: "Discord thread ID for #product (already created by PM)"
  discord_token:
    description: "Discord bot token"
    default: ""
steps:
  # ── Init: create threads + project structure ──
  - id: init
    run: |
      SLUG="${slug}"
      REPO="${repo}"
      TOKEN="${discord_token}"
      API="https://discord.com/api/v10"
      if [ -z "$TOKEN" ]; then TOKEN=$(grep DISCORD_BOT_TOKEN /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/.env 2>/dev/null | cut -d= -f2); fi
      create_thread() {
        local cid=$1 name=$2
        curl -sf -X POST "$API/channels/$cid/threads" -H "Authorization: Bot $TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"$name\",\"type\":11,\"auto_archive_duration\":10080}" | jq -r '.id // empty'
      }
      DT=$(create_thread 1486613609839726736 "$SLUG")
      VT=$(create_thread 1486613643851202743 "$SLUG")
      QT=$(create_thread 1486613658984517683 "$SLUG")
      RT=$(create_thread 1486613723241123900 "$SLUG")
      mkdir -p "$REPO/docs/.pipeline/handoffs" "$REPO/src" "$REPO/tests"
      STATE="$REPO/docs/.pipeline/state.json"
      jq -n --arg slug "$SLUG" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg pt "${product_thread}" --arg dt "$DT" --arg vt "$VT" --arg qt "$QT" --arg rt "$RT" \
        '{project:$slug, created_at:$now, current_phase:"requirements",
          threads:{product:$pt, design:$dt, dev:$vt, qa:$qt, release:$rt},
          phases:{requirements:{status:"in_progress",started_at:$now},
                  design:{status:"pending"},development:{status:"pending"},
                  testing:{status:"pending"},release:{status:"pending"}}}' > "$STATE"
      cd "$REPO" && git add docs/.pipeline/ && git commit -q -m "chore($SLUG): init pipeline" 2>/dev/null || true
      jq -n --arg dt "$DT" --arg vt "$VT" --arg qt "$QT" --arg rt "$RT" \
        '{design_thread:$dt, dev_thread:$vt, qa_thread:$qt, release_thread:$rt}'

  # ── Requirements (PRD already done by PM Agent in Discord) ──
  - id: requirements
    run: |
      openclaw agent -m "Project [${slug}]. Requirement: ${requirement}. Tasks: 1) Analyze and write full PRD to ${repo}/docs/prd.md (markdown with overview, user stories, acceptance criteria) 2) Git commit in ${repo}: docs(${slug}): PRD completed 3) Reply with markdown summary. Write in Chinese." \
        --agent p-pm --deliver --channel discord --to ${product_thread} --json

  - id: requirements_done
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="design" | .phases.requirements.status="completed" | .phases.requirements.completed_at=$now | .phases.design.status="in_progress" | .phases.design.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"01-requirements",from_phase:"requirements",to_phase:"design",artifact:"docs/prd.md",summary:"PRD completed",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/01-requirements.json"
      echo "phase: design"

  - id: prd_notify
    run: |
      openclaw message send --channel discord --target "channel:${product_thread}" --message "📋 **[${slug}] PRD 已完成**" --components '{"text":"PRD 已写入 docs/prd.md，请审阅后在 #dashboard 批准。","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准 PRD","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"

  - id: prd_signoff
    approval:
      prompt: "PRD written to ${repo}/docs/prd.md. Review and approve."
    stdin: $requirements.json

  # ── Design ──
  - id: design
    run: |
      DT=$(jq -r '.design_thread' <<< '$init.stdout' 2>/dev/null || jq -r '.threads.design' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Tasks: 1) Read ${repo}/docs/prd.md 2) Write tech design to ${repo}/docs/tech-design.md 3) Write task breakdown to ${repo}/docs/tasks.md 4) Git commit in ${repo}: docs(${slug}): technical design and tasks 5) Reply with markdown summary. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-architect --deliver --channel discord --to "$DT" --json
    when: $prd_signoff.approved

  - id: design_done
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="development" | .phases.design.status="completed" | .phases.design.completed_at=$now | .phases.development.status="in_progress" | .phases.development.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"02-design",from_phase:"design",to_phase:"development",artifact:"docs/tech-design.md",summary:"Technical design and task breakdown completed",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/02-design.json"
      echo "phase: development"
    when: $prd_signoff.approved

  - id: design_notify
    run: |
      DT=$(jq -r '.threads.design' "${repo}/docs/.pipeline/state.json")
      openclaw message send --channel discord --target "channel:$DT" --message "🏗️ **[${slug}] 技术设计已完成**" --components '{"text":"tech-design.md 和 tasks.md 已写入，请审阅。","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准设计","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"
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
      git push -u origin "feat/${slug}-mvp" 2>/dev/null || true
      echo "branch: feat/${slug}-mvp"
    when: $design_signoff.approved

  - id: development
    run: |
      VT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Tasks: 1) Read ${repo}/docs/tech-design.md and ${repo}/docs/tasks.md 2) Implement all code in ${repo} on current branch 3) Generate ${repo}/README.md (project description, install steps, usage) 4) Commit each module: feat(${slug}): description 5) Ensure tests pass 6) Reply with summary and file list. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-dev --deliver --channel discord --to "$VT" --json
    when: $design_signoff.approved

  - id: push_and_pr
    run: |
      cd "${repo}" && git push origin "feat/${slug}-mvp" 2>/dev/null || true
      PR_URL=$(gh pr create --base main --head "feat/${slug}-mvp" --title "[WIP] feat(${slug}): MVP implementation" --body "## Source\n- PRD: docs/prd.md\n- Tech Design: docs/tech-design.md\n- Tasks: docs/tasks.md\n\n## Status\nDraft — awaiting review and testing." --draft 2>/dev/null || echo "PR exists")
      echo "$PR_URL"
    when: $design_signoff.approved

  # ── Review ──
  - id: review
    run: |
      VT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}], repo ${repo}. Review recent code changes on branch feat/${slug}-mvp. Check quality, security, test coverage, README completeness. Reply with issues or approval. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-reviewer --deliver --channel discord --to "$VT" --json
    when: $design_signoff.approved

  # ── Testing ──
  - id: testing
    run: |
      QT=$(jq -r '.threads.qa' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Tasks: 1) Read acceptance criteria from ${repo}/docs/prd.md 2) Run existing tests in ${repo} 3) Write additional tests for uncovered criteria 4) Write test report to ${repo}/docs/test-report.md 5) Git commit: test(${slug}): test report 6) Reply with test results. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-qa --deliver --channel discord --to "$QT" --json
    when: $design_signoff.approved

  - id: testing_done
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="release" | .phases.development.status="completed" | .phases.development.completed_at=$now | .phases.testing.status="completed" | .phases.testing.completed_at=$now | .phases.release.status="in_progress" | .phases.release.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"03-development",from_phase:"development",to_phase:"testing",artifact:"src/",summary:"Implementation completed",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/03-development.json"
      jq -n --arg now "$NOW" '{id:"04-testing",from_phase:"testing",to_phase:"release",artifact:"docs/test-report.md",summary:"Tests passed",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/04-testing.json"
      echo "phase: release"
    when: $design_signoff.approved

  - id: release_notify
    run: |
      VT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      openclaw message send --channel discord --target "channel:$VT" --message "🚀 **[${slug}] 开发测试完成**" --components '{"text":"代码审查和测试已通过，确认发布？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准发布","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"
    when: $design_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Development, review, and testing complete. Approve release?"
    stdin: $testing.json
    when: $design_signoff.approved

  # ── Release ──
  - id: release
    run: |
      RT=$(jq -r '.threads.release' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}], repo ${repo}. Tasks: 1) Verify code and test status 2) Write release notes to ${repo}/docs/release-notes.md 3) Git commit: docs(${slug}): release notes 4) Reply with release summary. Write in Chinese."
      openclaw agent -m "$MSG" --agent p-release --deliver --channel discord --to "$RT" --json
    when: $release_signoff.approved

  - id: finalize
    run: |
      cd "${repo}"
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      gh pr ready 2>/dev/null || true
      STATE="docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="done" | .phases.release.status="completed" | .phases.release.completed_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"05-release",from_phase:"release",to_phase:"done",artifact:"docs/release-notes.md",summary:"Released",created_at:$now}' > "docs/.pipeline/handoffs/05-release.json"
      git add docs/.pipeline/ docs/release-notes.md && git commit -q -m "chore(${slug}): pipeline complete" 2>/dev/null || true
      git push origin "feat/${slug}-mvp" 2>/dev/null || true
      PR_URL=$(gh pr view --json url -q '.url' 2>/dev/null || echo "no PR")
      echo "{\"status\":\"complete\",\"pr\":\"$PR_URL\"}"
    when: $release_signoff.approved
