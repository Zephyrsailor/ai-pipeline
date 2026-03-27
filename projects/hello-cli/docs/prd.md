{
  "project_name": "hello-cli",
  "summary": "A minimal Node.js command-line tool that accepts an optional name argument and prints a personalized greeting. When a name is provided, it outputs 'Hello, {name}!' to stdout. When no argument is given, it defaults to 'Hello, World!'. The tool is intentionally kept simple as a lightweight utility with no external dependencies.",
  "user_stories": [
    {
      "id": "US-001",
      "persona": "CLI user",
      "story": "As a CLI user, I want to run hello-cli with a name argument, so that I get a personalized greeting printed to the console.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the CLI is installed, when I run 'hello-cli Alice', then the output is exactly 'Hello, Alice!'",
        "Given the CLI is installed, when I run 'hello-cli \"John Doe\"', then the output is exactly 'Hello, John Doe!'"
      ]
    },
    {
      "id": "US-002",
      "persona": "CLI user",
      "story": "As a CLI user, I want to run hello-cli without any arguments, so that I get the default greeting 'Hello, World!' printed to the console.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the CLI is installed, when I run 'hello-cli' with no arguments, then the output is exactly 'Hello, World!'"
      ]
    }
  ],
  "acceptance_criteria": [
    "The tool runs on Node.js without any external runtime dependencies",
    "The executable is invokable as 'hello-cli' after npm install or npm link",
    "Output is printed to stdout followed by a newline",
    "The process exits with code 0 on success",
    "package.json includes a 'bin' field mapping 'hello-cli' to the entry script"
  ],
  "out_of_scope": [
    "Interactive prompts or input",
    "Flag/option parsing (e.g., --help, --version)",
    "Multiple name arguments or list handling",
    "Colorized or formatted output",
    "Configuration files",
    "Logging or error reporting beyond basic stdout",
    "Publishing to npm registry"
  ],
  "assumptions": [
    "The tool will be a standalone Node.js project with its own package.json",
    "Only the first positional argument is used as the name; additional arguments are ignored",
    "The name is used as-is with no validation, sanitization, or transformation",
    "The stakeholder wants ESM or CommonJS — we will default to ESM (type: module) consistent with the parent pipeline conventions",
    "The shebang line (#!/usr/bin/env node) will be included for direct execution"
  ],
  "dependencies": [
    "Node.js >= 18 runtime installed on the target machine"
  ],
  "priority": "must",
  "estimated_complexity": "low"
}
