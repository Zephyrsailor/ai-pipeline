name: product-development
args:
  slug:
    description: "Project slug (lowercase-hyphenated)"
  requirement:
    description: "Raw requirement (one-line summary)"
  repo:
    description: "Target repository path (absolute)"
  product_thread:
    description: "Discord thread ID for #product (created by PM)"
steps:
  # ── Init: create threads in other channels ──
  - id: init
    run: |
      SLUG="${slug}"
      REPO="${repo}"
      TOKEN=$(grep DISCORD_BOT_TOKEN /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/.env 2>/dev/null | cut -d= -f2)
      API="https://discord.com/api/v10"
      create_thread() {
        curl -sf -X POST "$API/channels/$1/threads" -H "Authorization: Bot $TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"$2\",\"type\":11,\"auto_archive_duration\":10080}" | jq -r '.id // empty'
      }
      DT=$(create_thread 1486613609839726736 "$SLUG")
      VT=$(create_thread 1486613643851202743 "$SLUG")
      QT=$(create_thread 1486613658984517683 "$SLUG")
      RT=$(create_thread 1486613723241123900 "$SLUG")
      mkdir -p "$REPO/docs/.pipeline/handoffs" "$REPO/src" "$REPO/tests"
      jq -n --arg slug "$SLUG" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg pt "${product_thread}" --arg dt "$DT" --arg vt "$VT" --arg qt "$QT" --arg rt "$RT" \
        '{project:$slug, created_at:$now, current_phase:"design",
          threads:{product:$pt, design:$dt, dev:$vt, qa:$qt, release:$rt},
          phases:{requirements:{status:"completed",completed_at:$now},
                  design:{status:"in_progress",started_at:$now},development:{status:"pending"},
                  testing:{status:"pending"},release:{status:"pending"}}}' > "$REPO/docs/.pipeline/state.json"
      jq -n --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{id:"01-requirements",from_phase:"requirements",to_phase:"design",artifact:"docs/prd.md",summary:"PRD completed via Discord",created_at:$now}' > "$REPO/docs/.pipeline/handoffs/01-requirements.json"
      cd "$REPO" && git add docs/.pipeline/ && git commit -q -m "chore($SLUG): init pipeline" 2>/dev/null || true
      echo "initialized"

  # ── Design (PRD already done by PM in Discord) ──
  - id: design
    run: |
      DT=$(jq -r '.threads.design' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Read ${repo}/docs/prd.md, write tech design to ${repo}/docs/tech-design.md and task breakdown to ${repo}/docs/tasks.md. Git commit in ${repo}. Reply with markdown summary in Chinese."
      openclaw agent -m "$MSG" --agent p-architect --deliver --channel discord --to "$DT" --json

  - id: design_signoff
    approval:
      prompt: "Tech design complete. Check #design thread. Approve to start development."
    stdin: $design.json

  # ── Development ──
  - id: create_branch
    run: |
      cd "${repo}" && git checkout -b "feat/${slug}-mvp" 2>/dev/null || git checkout "feat/${slug}-mvp"
      git push -u origin "feat/${slug}-mvp" 2>/dev/null || true
      echo "branch: feat/${slug}-mvp"
    when: $design_signoff.approved

  - id: development
    run: |
      VT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Read ${repo}/docs/tech-design.md and ${repo}/docs/tasks.md. Implement all code in ${repo}, generate ${repo}/README.md. Commit each module. Ensure tests pass. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-dev --deliver --channel discord --to "$VT" --json
    when: $design_signoff.approved

  - id: push_and_pr
    run: |
      cd "${repo}" && git push origin "feat/${slug}-mvp" 2>/dev/null || true
      gh pr create --base main --head "feat/${slug}-mvp" --title "[WIP] feat(${slug}): MVP" --body "PRD: docs/prd.md | Design: docs/tech-design.md" --draft 2>/dev/null || echo "PR exists"
    when: $design_signoff.approved

  # ── Review ──
  - id: review
    run: |
      VT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}], repo ${repo}. Review recent code changes. Check quality, security, tests. Reply in Chinese."
      openclaw agent -m "$MSG" --agent p-reviewer --deliver --channel discord --to "$VT" --json
    when: $design_signoff.approved

  # ── Testing ──
  - id: testing
    run: |
      QT=$(jq -r '.threads.qa' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Read ${repo}/docs/prd.md acceptance criteria. Run tests, write report to ${repo}/docs/test-report.md. Git commit. Reply with results in Chinese."
      openclaw agent -m "$MSG" --agent p-qa --deliver --channel discord --to "$QT" --json
    when: $design_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Dev, review, testing complete. Check #dev and #qa threads. Approve release?"
    stdin: $testing.json
    when: $design_signoff.approved

  # ── Release ──
  - id: release
    run: |
      RT=$(jq -r '.threads.release' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}], repo ${repo}. Write release notes to ${repo}/docs/release-notes.md. Git commit. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-release --deliver --channel discord --to "$RT" --json
    when: $release_signoff.approved

  - id: finalize
    run: |
      cd "${repo}"
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      gh pr ready 2>/dev/null || true
      STATE="docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="done" | .phases | to_entries | map(if .value.status != "completed" then .value.status = "completed" | .value.completed_at = $now else . end) | from_entries | {current_phase:"done",phases:.}' "$STATE" > "$TMP" 2>/dev/null && mv "$TMP" "$STATE" || true
      git add docs/ && git commit -q -m "chore(${slug}): pipeline complete" 2>/dev/null || true
      git push origin "feat/${slug}-mvp" 2>/dev/null || true
      PR_URL=$(gh pr view --json url -q '.url' 2>/dev/null || echo "no PR")
      echo "{\"status\":\"complete\",\"pr\":\"$PR_URL\"}"
    when: $release_signoff.approved
