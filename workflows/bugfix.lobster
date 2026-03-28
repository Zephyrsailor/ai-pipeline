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
  - id: triage
    run: |
      MSG="Repo ${repo}. Bug report: ${bug_report}. Analyze root cause, assess severity, provide fix plan. Reply in markdown Chinese."
      openclaw agent -m "$MSG" --agent p-triage --deliver --channel discord --to ${bugs_thread} --json

  - id: triage_notify
    run: |
      openclaw message send --channel discord --target "channel:${bugs_thread}" --message "🐛 **Bug 分诊完成**" --components '{"text":"根因分析和修复方案已生成，确认执行修复？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准修复","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' 2>/dev/null || true
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

  - id: release_notify
    run: |
      openclaw message send --channel discord --target "channel:${dev_thread}" --message "✅ **Bug 修复已验证**" --components '{"text":"测试通过，确认发布？","blocks":[{"type":"actions","buttons":[{"label":"✅ 批准发布","style":"success"},{"label":"❌ 驳回","style":"danger"}]}]}' 2>/dev/null || true
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
