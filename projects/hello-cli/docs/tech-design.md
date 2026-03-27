{
  "architecture_overview": "hello-cli is a minimal single-file Node.js CLI tool with zero external dependencies. The architecture is intentionally flat: one entry-point script that reads process.argv, extracts the first positional argument (defaulting to 'World'), and prints the greeting to stdout. The project follows the ai-pipeline convention with its own package.json (type: module, bin field), source in projects/hello-cli/src/, and tests in projects/hello-cli/tests/.\n\nThe entry point is src/index.js — an ESM script with a shebang line. It uses only Node.js built-ins (process.argv, console.log). The package.json bin field maps 'hello-cli' to src/index.js, enabling global invocation via npm link. No build step, no bundling, no transpilation.\n\nTesting uses Node.js built-in test runner (node:test + node:assert) to keep the zero-dependency constraint. Tests invoke the CLI as a child process via node:child_process to validate actual stdout output and exit codes against acceptance criteria.",
  "components": [
    {
      "name": "CLI Entry Point",
      "responsibility": "Parse first positional argument from process.argv, default to 'World', print 'Hello, {name}!' to stdout, exit 0",
      "files_to_create": ["projects/hello-cli/src/index.js"],
      "files_to_modify": [],
      "changes_summary": "Single ESM file with shebang. Reads process.argv[2], defaults to 'World', calls console.log with formatted greeting."
    },
    {
      "name": "Package Configuration",
      "responsibility": "Define project metadata, ESM type, and bin entry for CLI invocation",
      "files_to_create": ["projects/hello-cli/package.json"],
      "files_to_modify": [],
      "changes_summary": "Minimal package.json with name, version, type: module, bin: { 'hello-cli': './src/index.js' }. No dependencies."
    },
    {
      "name": "Test Suite",
      "responsibility": "Verify greeting output and exit code for all acceptance criteria scenarios",
      "files_to_create": ["projects/hello-cli/tests/index.test.js"],
      "files_to_modify": [],
      "changes_summary": "Uses node:test and node:child_process to spawn the CLI with various arguments and assert stdout matches expected output. Tests: no args → 'Hello, World!', single name → 'Hello, Alice!', quoted name with space → 'Hello, John Doe!', exit code 0."
    }
  ],
  "api_design": [],
  "data_model": {
    "new_entities": [],
    "schema_changes": [],
    "migration_notes": "No data model. CLI is stateless with no persistence."
  },
  "tech_decisions": [
    {
      "decision": "Use ESM (type: module) for the project",
      "rationale": "Consistent with parent ai-pipeline conventions (package.json has type: module). PRD assumptions explicitly state ESM.",
      "alternatives_considered": ["CommonJS — would work but inconsistent with parent project"]
    },
    {
      "decision": "Use Node.js built-in test runner (node:test) instead of Jest/Vitest/Mocha",
      "rationale": "PRD requires zero external dependencies. node:test is available in Node.js >= 18 which is the target runtime.",
      "alternatives_considered": ["Jest — adds devDependency", "Vitest — adds devDependency", "No tests — violates pipeline QA phase requirements"]
    },
    {
      "decision": "Test via child_process.execFile rather than importing the module",
      "rationale": "Tests should validate the actual CLI behavior (shebang, stdout output, exit code) as the user would experience it, not just the internal logic.",
      "alternatives_considered": ["Import and mock console.log — would not test bin/shebang integration"]
    },
    {
      "decision": "Single file, no src/lib separation",
      "rationale": "The logic is 3 lines of code. Splitting into a greet function + CLI wrapper would be over-architecture for this scope.",
      "alternatives_considered": ["Separate greet.js library + index.js CLI — unnecessary for this complexity"]
    }
  ],
  "risks": [
    {
      "risk": "node:test unavailable on older Node.js versions",
      "severity": "low",
      "mitigation": "PRD specifies Node.js >= 18 which includes node:test. Document minimum version in package.json engines field."
    },
    {
      "risk": "Shebang line not executable on Windows without node prefix",
      "severity": "low",
      "mitigation": "npm link / npx handles cross-platform shebang resolution. This is standard Node.js CLI behavior and not a custom concern."
    }
  ],
  "nfr": {
    "performance": "Negligible — single synchronous console.log call, sub-millisecond execution",
    "security": "No input validation per PRD assumptions (name used as-is). No file I/O, no network, no eval. Attack surface is effectively zero.",
    "scalability": "Not applicable — stateless single-invocation CLI tool",
    "observability": "Stdout only. Exit code 0 on success. No logging framework needed."
  },
  "estimated_effort": "small",
  "implementation_order": [
    "Create projects/hello-cli/package.json with name, version, type: module, bin field, and engines field",
    "Create projects/hello-cli/src/index.js with shebang, argv parsing, and greeting output",
    "Make src/index.js executable (chmod +x)",
    "Create projects/hello-cli/tests/index.test.js with acceptance criteria test cases",
    "Run tests via 'node --test tests/index.test.js' to verify all pass",
    "Run 'npm link' in projects/hello-cli/ and manually verify 'hello-cli' and 'hello-cli Alice' output"
  ]
}
