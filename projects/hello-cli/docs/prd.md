{
  "project_name": "hello-cli",
  "summary": "A minimal Node.js command-line tool that accepts an optional name argument and prints a greeting. When a name is provided (e.g., `hello-cli Alice`), it prints \"Hello Alice\". When no argument is given, it defaults to printing \"Hello World\". The tool should be installable globally via npm and follow Node.js CLI best practices.",
  "user_stories": [
    {
      "id": "US-001",
      "persona": "Developer / CLI user",
      "story": "As a CLI user, I want to run the command with a name argument, so that I see a personalized greeting printed to stdout.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the CLI is installed, when I run `hello-cli Alice`, then stdout prints exactly `Hello Alice`",
        "Given the CLI is installed, when I run `hello-cli 'John Doe'`, then stdout prints exactly `Hello John Doe`"
      ]
    },
    {
      "id": "US-002",
      "persona": "Developer / CLI user",
      "story": "As a CLI user, I want to run the command without any arguments, so that I see the default greeting 'Hello World'.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the CLI is installed, when I run `hello-cli` with no arguments, then stdout prints exactly `Hello World`"
      ]
    },
    {
      "id": "US-003",
      "persona": "Developer",
      "story": "As a developer, I want to install the tool globally via `npm install -g`, so that I can invoke `hello-cli` from any directory.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the package is published or linked locally, when I run `npm install -g hello-cli` or `npm link`, then the `hello-cli` command is available in my PATH",
        "Given the tool is installed globally, when I run `hello-cli` from any directory, then it executes correctly"
      ]
    },
    {
      "id": "US-004",
      "persona": "Developer",
      "story": "As a developer, I want the tool to use only the first positional argument as the name, so that the behavior is predictable and simple.",
      "priority": "should",
      "acceptance_criteria": [
        "Given the CLI is installed, when I run `hello-cli Alice Bob`, then stdout prints `Hello Alice` (only the first argument is used)"
      ]
    }
  ],
  "acceptance_criteria": [
    "The CLI entry point uses a proper shebang line (#!/usr/bin/env node)",
    "The package.json includes a valid `bin` field mapping `hello-cli` to the entry script",
    "The tool exits with code 0 on successful execution",
    "The tool works on Node.js >= 18",
    "No external dependencies — uses only Node.js built-in APIs (process.argv)"
  ],
  "out_of_scope": [
    "Flag/option parsing (e.g., --help, --version)",
    "Interactive input (stdin prompting)",
    "Internationalization / localization",
    "Colored output or fancy formatting",
    "TypeScript — plain JavaScript is sufficient for this scope",
    "Publishing to npm registry"
  ],
  "assumptions": [
    "The name is taken from the first positional CLI argument (process.argv[2])",
    "No input validation or sanitization is needed — any string is a valid name",
    "Output is a single line to stdout followed by a newline",
    "The project will be a standalone new repository, not part of the existing ai-pipeline codebase",
    "ESM (type: module) or CJS — either is acceptable; CJS is simpler for a trivial CLI"
  ],
  "dependencies": [
    "Node.js runtime >= 18 installed on the target machine",
    "npm for package management and global install/link"
  ],
  "priority": "must",
  "estimated_complexity": "low"
}
