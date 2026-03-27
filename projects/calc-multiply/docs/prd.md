{
  "project_name": "calc-multiply",
  "summary": "Extend the existing simple calculator module with multiply and divide functions. The calculator currently supports add and subtract operations as pure functions with ES module exports. This feature adds two new arithmetic operations following the same patterns: multiply returns the product of two numbers, and divide returns the quotient of two numbers with explicit error handling for division by zero.",
  "user_stories": [
    {
      "id": "US-001",
      "persona": "Developer consuming the calculator module",
      "story": "As a developer using the calculator module, I want a multiply function that accepts two numbers and returns their product, so that I can perform multiplication without implementing it myself.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the multiply function is imported from index.js, when called with two positive numbers (e.g., 3, 4), then it returns their product (12)",
        "Given the multiply function is called with zero as one argument (e.g., 5, 0), when executed, then it returns 0",
        "Given the multiply function is called with negative numbers (e.g., -2, 3), when executed, then it returns the correct signed product (-6)",
        "Given the multiply function is called with two negative numbers (e.g., -2, -3), when executed, then it returns a positive product (6)"
      ]
    },
    {
      "id": "US-002",
      "persona": "Developer consuming the calculator module",
      "story": "As a developer using the calculator module, I want a divide function that accepts two numbers and returns their quotient, so that I can perform division without implementing it myself.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the divide function is imported from index.js, when called with two numbers (e.g., 10, 2), then it returns their quotient (5)",
        "Given the divide function is called with a dividend that does not divide evenly (e.g., 7, 2), when executed, then it returns the correct decimal quotient (3.5)",
        "Given the divide function is called with a negative number (e.g., -10, 2), when executed, then it returns the correct signed quotient (-5)"
      ]
    },
    {
      "id": "US-003",
      "persona": "Developer consuming the calculator module",
      "story": "As a developer using the calculator module, I want the divide function to throw an error when the divisor is zero, so that I can handle division-by-zero cases explicitly rather than receiving Infinity.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the divide function is called with 0 as the second argument (e.g., 10, 0), when executed, then it throws an Error",
        "Given the divide function throws on division by zero, when caught, then the error message clearly indicates division by zero (e.g., 'Cannot divide by zero')"
      ]
    }
  ],
  "acceptance_criteria": [
    "Both multiply and divide are exported as named exports from index.js, consistent with existing add and subtract exports",
    "Both functions follow the same pure-function pattern as add and subtract (two parameters, return a value)",
    "All new functions have corresponding tests in test/calc.test.js using node:test and node:assert",
    "Existing add and subtract tests continue to pass without modification",
    "Running `npm test` executes all tests (old and new) and all pass"
  ],
  "out_of_scope": [
    "Handling non-numeric inputs or type validation",
    "Supporting more than two operands per function call",
    "Chaining or composing operations",
    "Adding any external dependencies",
    "Modifying the existing add or subtract functions",
    "Modular arithmetic, exponentiation, or other advanced math operations"
  ],
  "assumptions": [
    "The functions will receive JavaScript number types as arguments; input validation is not required",
    "The divide-by-zero error should be a standard JavaScript Error thrown via 'throw new Error(...)'",
    "The existing code conventions (ES modules, pure functions, node:test framework) should be followed exactly",
    "No TypeScript migration or build step is needed; the project remains plain JavaScript",
    "Node.js version supports the built-in node:test module (v18+)"
  ],
  "dependencies": [
    "Existing index.js module with add and subtract functions",
    "Existing test infrastructure using node:test and node:assert",
    "Node.js >= 18.0.0 runtime (already in use)"
  ],
  "priority": "must",
  "estimated_complexity": "low"
}
