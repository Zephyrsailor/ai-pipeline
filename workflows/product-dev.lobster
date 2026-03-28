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
  - id: init
    run: |
      SLUG="${slug}"
      REPO="${repo}"
      TOKEN=$(grep DISCORD_BOT_TOKEN /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/.env 2>/dev/null | cut -d= -f2)
      API="https://discord.com/api/v10"
      ct() { curl -sf -X POST "$API/channels/$1/threads" -H "Authorization: Bot $TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"$2\",\"type\":11,\"auto_archive_duration\":10080}" | jq -r '.id // empty'; }
      DT=$(ct 1486613609839726736 "$SLUG")
      VT=$(ct 1486613643851202743 "$SLUG")
      QT=$(ct 1486613658984517683 "$SLUG")
      RT=$(ct 1486613723241123900 "$SLUG")
      mkdir -p "$REPO/docs/.pipeline/handoffs" "$REPO/src" "$REPO/tests"
      jq -n --arg slug "$SLUG" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg pt "${product_thread}" --arg dt "$DT" --arg vt "$VT" --arg qt "$QT" --arg rt "$RT" \
        '{project:$slug,created_at:$now,current_phase:"design",
          threads:{product:$pt,design:$dt,dev:$vt,qa:$qt,release:$rt},
          phases:{requirements:{status:"completed"},design:{status:"in_progress",started_at:$now},
                  development:{status:"pending"},testing:{status:"pending"},release:{status:"pending"}}}' \
        > "$REPO/docs/.pipeline/state.json"
      cd "$REPO" && git add docs/.pipeline/ && git commit -q -m "chore($SLUG): init pipeline" 2>/dev/null || true
      echo "initialized"

  - id: notify_design
    run: |
      openclaw message send --channel discord --target "channel:${product_thread}" --message "⏳ **Architect 正在做技术设计...**" 2>/dev/null || true

  - id: design
    run: |
      DT=$(jq -r '.threads.design' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Read ${repo}/docs/prd.md, write tech design to ${repo}/docs/tech-design.md and task breakdown to ${repo}/docs/tasks.md. Git commit in ${repo}. Reply with markdown summary in Chinese."
      openclaw agent -m "$MSG" --agent p-architect --deliver --channel discord --to "$DT" --json

  - id: design_signoff
    approval:
      prompt: "Design complete. Check #design thread. Confirm to start development."
    stdin: $design.json

  - id: create_branch
    run: |
      cd "${repo}" && git checkout -b "feat/${slug}-mvp" 2>/dev/null || git checkout "feat/${slug}-mvp"
      git push -u origin "feat/${slug}-mvp" 2>/dev/null || true
      echo "branch: feat/${slug}-mvp"
    when: $design_signoff.approved

  - id: notify_dev
    run: |
      openclaw message send --channel discord --target "channel:${product_thread}" --message "⏳ **Developer 正在写代码...**" 2>/dev/null || true
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
      gh pr create --base main --head "feat/${slug}-mvp" --title "feat(${slug}): MVP" --body "PRD: docs/prd.md | Design: docs/tech-design.md" --draft 2>/dev/null || echo "PR exists"
    when: $design_signoff.approved

  - id: review
    run: |
      VT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}], repo ${repo}. Review recent code changes. Check quality, security, tests. Reply in Chinese."
      openclaw agent -m "$MSG" --agent p-reviewer --deliver --channel discord --to "$VT" --json
    when: $design_signoff.approved

  - id: dev_signoff
    approval:
      prompt: "Development and review complete. Check #dev thread and PR. Confirm to proceed to testing and release."
    stdin: $review.json
    when: $design_signoff.approved

  - id: notify_test
    run: |
      openclaw message send --channel discord --target "channel:${product_thread}" --message "⏳ **QA 正在跑测试...**" 2>/dev/null || true
    when: $dev_signoff.approved

  - id: testing
    run: |
      QT=$(jq -r '.threads.qa' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}]. Read ${repo}/docs/prd.md acceptance criteria. Run tests, write report to ${repo}/docs/test-report.md. Git commit. Reply with results in Chinese."
      openclaw agent -m "$MSG" --agent p-qa --deliver --channel discord --to "$QT" --json
    when: $dev_signoff.approved

  - id: release
    run: |
      RT=$(jq -r '.threads.release' "${repo}/docs/.pipeline/state.json")
      MSG="Project [${slug}], repo ${repo}. Write release notes to ${repo}/docs/release-notes.md. Git commit. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-release --deliver --channel discord --to "$RT" --json
    when: $dev_signoff.approved

  - id: finalize
    run: |
      cd "${repo}"
      gh pr ready 2>/dev/null || true
      git add docs/ && git commit -q -m "chore(${slug}): pipeline complete" 2>/dev/null || true
      git push origin "feat/${slug}-mvp" 2>/dev/null || true
      PR_URL=$(gh pr view --json url -q '.url' 2>/dev/null || echo "no PR")
      openclaw message send --channel discord --target "channel:${product_thread}" --message "🎉 **流水线完成！**
- #design → 技术方案
- #dev → 代码 + 审查
- #qa → 测试报告
- #release → 发布说明
- PR: $PR_URL" 2>/dev/null || true
      echo "{\"status\":\"complete\",\"pr\":\"$PR_URL\"}"
    when: $dev_signoff.approved
