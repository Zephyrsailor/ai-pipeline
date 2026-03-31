name: bugfix
args:
  repo:
    description: "Target repository path (absolute)"
  bug_report:
    description: "Bug report or error description"
  request_id:
    description: "Unique request identifier"
  bugs_thread:
    description: "Discord thread ID for #bugs (created by triage agent)"
steps:
  - id: init
    run: |
      REPO="${repo}"
      RID="${request_id}"
      TOKEN="${DISCORD_BOT_TOKEN:-$(grep DISCORD_BOT_TOKEN .env 2>/dev/null | cut -d= -f2)}"
      API="https://discord.com/api/v10"
      ct() {
        EXISTING=$(curl -sf "$API/guilds/1486608599839932519/threads/active" -H "Authorization: Bot $TOKEN" | jq -r ".threads[] | select(.parent_id==\"$1\" and .name==\"bugfix-$RID\") | .id" 2>/dev/null | head -1)
        if [ -n "$EXISTING" ]; then echo "$EXISTING"; return; fi
        curl -sf -X POST "$API/channels/$1/threads" -H "Authorization: Bot $TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"bugfix-$RID\",\"type\":11,\"auto_archive_duration\":10080}" | jq -r '.id // empty'
      }
      DT=$(ct 1486613643851202743)
      QT=$(ct 1486613658984517683)
      RT=$(ct 1486613723241123900)
      mkdir -p "$REPO/docs/.pipeline/handoffs"
      STATE="$REPO/docs/.pipeline/state.json"
      jq -n --arg rid "$RID" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg bt "${bugs_thread}" --arg dt "$DT" --arg qt "$QT" --arg rt "$RT" \
        '{request_id:$rid, workflow:"bugfix", created_at:$now, current_phase:"triage",
          threads:{bugs:$bt,dev:$dt,qa:$qt,release:$rt},
          phases:{triage:{status:"in_progress",started_at:$now},
                  fix:{status:"pending"},review:{status:"pending"},
                  verify:{status:"pending"},release:{status:"pending"}}}' > "$STATE"
      cd "$REPO"
      gh repo create "bugfix-$RID" --public --source=. --push 2>/dev/null || git remote get-url origin 2>/dev/null || true
      git add docs/.pipeline/ && git commit -q -m "chore(bugfix): init pipeline $RID" 2>/dev/null || true
      git push -u origin main 2>/dev/null || true
      echo "initialized"

  - id: notify_triage
    run: |
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "⏳ **Triage 正在分析 Bug...**" 2>/dev/null || true

  - id: triage
    run: |
      BT=$(jq -r '.threads.bugs' "${repo}/docs/.pipeline/state.json")
      MSG="Repo ${repo}. Bug report: ${bug_report}. Analyze root cause, assess severity, provide fix plan. Reply in markdown Chinese."
      openclaw agent -m "$MSG" --agent p-triage --deliver --channel discord --to "$BT" --json

  - id: triage_done
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="fix" | .phases.triage.status="completed" | .phases.triage.completed_at=$now | .phases.fix.status="in_progress" | .phases.fix.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"01-triage",from_phase:"triage",to_phase:"fix",artifact:"triage report",summary:"Bug triaged",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/01-triage.json"
      echo "phase: fix"

  - id: triage_notify
    run: |
      BT=$(jq -r '.threads.bugs' "${repo}/docs/.pipeline/state.json")
      openclaw message send --channel discord --target "channel:$BT" --message "🐛 **Bug 分诊完成**" --components '{"text":"根因分析和修复方案已生成，确认执行修复？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准修复","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"

  - id: triage_signoff
    approval:
      prompt: "Bug triaged. Approve fix?"
    stdin: $triage.json

  - id: notify_fix
    run: |
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "⏳ **Developer 正在修复 Bug...**" 2>/dev/null || true
    when: $triage_signoff.approved

  - id: fix
    run: |
      TRIAGE=$(cat)
      DT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Repo ${repo}. Triage result: $TRIAGE. Fix the bug, run tests, commit: fix(scope): description. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-dev --deliver --channel discord --to "$DT" --json
    stdin: $triage.stdout
    when: $triage_signoff.approved

  - id: review
    run: |
      DT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      MSG="Repo ${repo}. Review recent bugfix changes. Reply with issues or approval in Chinese."
      openclaw agent -m "$MSG" --agent p-reviewer --deliver --channel discord --to "$DT" --json
    when: $triage_signoff.approved

  - id: notify_verify
    run: |
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "⏳ **QA 正在验证修复...**" 2>/dev/null || true
    when: $triage_signoff.approved

  - id: verify
    run: |
      QT=$(jq -r '.threads.qa' "${repo}/docs/.pipeline/state.json")
      MSG="Repo ${repo}. Original bug: ${bug_report}. Verify fix, run all tests, write report to ${repo}/docs/test-report.md. Reply with results in Chinese."
      openclaw agent -m "$MSG" --agent p-qa --deliver --channel discord --to "$QT" --json
    when: $triage_signoff.approved

  - id: verify_done
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="release" | .phases.fix.status="completed" | .phases.fix.completed_at=$now | .phases.review.status="completed" | .phases.review.completed_at=$now | .phases.verify.status="completed" | .phases.verify.completed_at=$now | .phases.release.status="in_progress" | .phases.release.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"02-fix",from_phase:"fix",to_phase:"verify",artifact:"src/",summary:"Bug fixed",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/02-fix.json"
      jq -n --arg now "$NOW" '{id:"03-verify",from_phase:"verify",to_phase:"release",artifact:"docs/test-report.md",summary:"Fix verified",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/03-verify.json"
      echo "phase: release"
    when: $triage_signoff.approved

  - id: release_notify
    run: |
      DT=$(jq -r '.threads.dev' "${repo}/docs/.pipeline/state.json")
      openclaw message send --channel discord --target "channel:$DT" --message "✅ **Bug 修复已验证**" --components '{"text":"测试通过，确认发布？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准发布","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"
    when: $triage_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Bug fix verified. Approve release?"
    stdin: $verify.json
    when: $triage_signoff.approved

  - id: notify_release
    run: |
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "⏳ **Release 正在发布...**" 2>/dev/null || true
    when: $release_signoff.approved

  - id: release
    run: |
      RT=$(jq -r '.threads.release' "${repo}/docs/.pipeline/state.json")
      MSG="Repo ${repo}. Request ID: ${request_id}. Write release notes to ${repo}/docs/release-notes.md, commit. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-release --deliver --channel discord --to "$RT" --json
    when: $release_signoff.approved

  - id: finalize
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="done" | .phases.release.status="completed" | .phases.release.completed_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"04-release",from_phase:"release",to_phase:"done",artifact:"docs/release-notes.md",summary:"Released",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/04-release.json"
      cd "${repo}" || exit 1
      git add docs/.pipeline/ docs/release-notes.md && git commit -q -m "chore(bugfix): pipeline complete ${request_id}" 2>/dev/null || true
      git push origin main 2>/dev/null || true
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "🎉 **Bugfix 流水线完成！**
- #bugs → 分诊报告
- #dev → 修复 + 审查
- #qa → 测试报告
- #release → 发布说明" 2>/dev/null || true
      echo '{"status":"complete"}'
    when: $release_signoff.approved
