name: bugfix
args:
  repo:
    description: "Target repository path (absolute)"
  bug_report:
    description: "Bug report or error description"
  request_id:
    description: "Unique request identifier"
  bugs_thread:
    description: "Discord thread ID for #bugs"
  dev_thread:
    description: "Discord thread ID for #dev"
  qa_thread:
    description: "Discord thread ID for #qa"
  release_thread:
    description: "Discord thread ID for #release"
steps:
  - id: init
    run: |
      mkdir -p "${repo}/docs/.pipeline/handoffs"
      STATE="${repo}/docs/.pipeline/state.json"
      jq -n --arg rid "${request_id}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{request_id:$rid, workflow:"bugfix", created_at:$now, current_phase:"triage",
          phases:{triage:{status:"in_progress",started_at:$now},
                  fix:{status:"pending"},review:{status:"pending"},
                  verify:{status:"pending"},release:{status:"pending"}}}' > "$STATE"
      cd "${repo}" && git add docs/.pipeline/ && git commit -q -m "chore(bugfix): init pipeline ${request_id}" 2>/dev/null || true
      echo "initialized"

  - id: triage
    run: |
      MSG="Repo ${repo}. Bug report: ${bug_report}. Analyze root cause, assess severity, provide fix plan. Reply in markdown Chinese."
      openclaw agent -m "$MSG" --agent p-triage --deliver --channel discord --to ${bugs_thread} --json

  - id: triage_done
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="fix" | .phases.triage.status="completed" | .phases.triage.completed_at=$now | .phases.fix.status="in_progress" | .phases.fix.started_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"01-triage",from_phase:"triage",to_phase:"fix",artifact:"triage report",summary:"Bug triaged",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/01-triage.json"
      echo "phase: fix"

  - id: triage_notify
    run: |
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "🐛 **Bug 分诊完成**" --components '{"text":"根因分析和修复方案已生成，确认执行修复？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准修复","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"

  - id: triage_signoff
    approval:
      prompt: "Bug triaged. Approve fix?"
    stdin: $triage.json

  - id: fix
    run: |
      TRIAGE=$(cat)
      MSG="Repo ${repo}. Triage result: $TRIAGE. Fix the bug, run tests, commit: fix(scope): description. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-dev --deliver --channel discord --to ${dev_thread} --json
    stdin: $triage.stdout
    when: $triage_signoff.approved

  - id: review
    run: |
      MSG="Repo ${repo}. Review recent bugfix changes. Reply with issues or approval in Chinese."
      openclaw agent -m "$MSG" --agent p-reviewer --deliver --channel discord --to ${dev_thread} --json
    when: $triage_signoff.approved

  - id: verify
    run: |
      MSG="Repo ${repo}. Original bug: ${bug_report}. Verify fix, run all tests, write report to ${repo}/docs/test-report.md. Reply with results in Chinese."
      openclaw agent -m "$MSG" --agent p-qa --deliver --channel discord --to ${qa_thread} --json
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
      openclaw message send --channel discord --target "channel:${dev_thread}" --message "✅ **Bug 修复已验证**" --components '{"text":"测试通过，确认发布？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准发布","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' || echo "WARNING: approval notification failed" >&2
      echo "approval requested"
    when: $triage_signoff.approved

  - id: release_signoff
    approval:
      prompt: "Bug fix verified. Approve release?"
    stdin: $verify.json
    when: $triage_signoff.approved

  - id: release
    run: |
      MSG="Repo ${repo}. Request ID: ${request_id}. Write release notes to ${repo}/docs/release-notes.md, commit. Reply with summary in Chinese."
      openclaw agent -m "$MSG" --agent p-release --deliver --channel discord --to ${release_thread} --json
    when: $release_signoff.approved

  - id: finalize
    run: |
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      STATE="${repo}/docs/.pipeline/state.json"
      TMP=$(mktemp) && jq --arg now "$NOW" '.current_phase="done" | .phases.release.status="completed" | .phases.release.completed_at=$now' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
      jq -n --arg now "$NOW" '{id:"04-release",from_phase:"release",to_phase:"done",artifact:"docs/release-notes.md",summary:"Released",created_at:$now}' > "${repo}/docs/.pipeline/handoffs/04-release.json"
      cd "${repo}" && git add docs/.pipeline/ docs/release-notes.md && git commit -q -m "chore(bugfix): pipeline complete ${request_id}" 2>/dev/null || true
      echo '{"status":"complete"}'
    when: $release_signoff.approved
