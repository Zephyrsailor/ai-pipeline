name: poc
args:
  message:
    default: "hello from ai-pipeline"
    description: "Test message"
steps:
  - id: analyze
    run: |
      echo "{\"received\": \"${message}\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"status\": \"analyzed\"}"

  - id: approve
    approval:
      prompt: "Analysis complete. Proceed with action?"
    stdin: $analyze.json

  - id: execute
    run: |
      echo "{\"action\": \"executed\", \"input\": $(cat), \"completed\": true}"
    stdin: $analyze.json
    when: $approve.approved

  - id: summary
    run: |
      echo "{\"pipeline\": \"poc\", \"result\": \"success\", \"steps_completed\": 4}"
    when: $approve.approved
