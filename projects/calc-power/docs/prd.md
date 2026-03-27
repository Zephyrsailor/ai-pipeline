{
  "project_name": "calc-power",
  "summary": "Add a power (exponentiation) function to the existing test-calc-app calculator module. The function raises a base number to a given exponent, supporting both positive and negative exponents. This extends the calculator's arithmetic capabilities alongside the existing add and subtract functions.",
  "user_stories": [
    {
      "id": "US-001",
      "persona": "Developer consuming the calc library",
      "story": "As a developer, I want a power(base, exponent) function that returns base raised to the exponent, so that I can perform exponentiation without depending on an external library.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the function is called as power(2, 3), when executed, then it returns 8",
        "Given the function is called as power(5, 0), when executed, then it returns 1",
        "Given the function is called as power(7, 1), when executed, then it returns 7"
      ]
    },
    {
      "id": "US-002",
      "persona": "Developer consuming the calc library",
      "story": "As a developer, I want the power function to handle negative exponents correctly, so that I can compute fractional results like reciprocals.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the function is called as power(2, -1), when executed, then it returns 0.5",
        "Given the function is called as power(4, -2), when executed, then it returns 0.0625",
        "Given the function is called as power(10, -1), when executed, then it returns 0.1"
      ]
    },
    {
      "id": "US-003",
      "persona": "Developer consuming the calc library",
      "story": "As a developer, I want the power function exported as a named ES module export from index.js, so that I can import it consistently with add and subtract.",
      "priority": "must",
      "acceptance_criteria": [
        "Given index.js is imported, when destructuring { power } from '../index.js', then the power function is available and callable",
        "Given the existing add and subtract exports, when power is added, then add and subtract continue to work unchanged"
      ]
    },
    {
      "id": "US-004",
      "persona": "Developer maintaining the calc library",
      "story": "As a maintainer, I want unit tests for the power function using the existing node:test framework, so that regressions are caught automatically.",
      "priority": "must",
      "acceptance_criteria": [
        "Given the test suite in test/calc.test.js, when npm test is run, then tests for positive exponents, zero exponent, and negative exponents all pass",
        "Given the new tests are added, when npm test is run, then all existing add and subtract tests still pass"
      ]
    }
  ],
  "acceptance_criteria": [
    "The power function is exported from index.js as a named export",
    "The function signature is power(base, exponent) accepting two numeric arguments",
    "All existing tests continue to pass without modification",
    "New tests cover positive exponents, zero exponent, and negative exponents",
    "npm test exits with code 0 and all tests pass"
  ],
  "out_of_scope": [
    "Handling non-numeric inputs or input validation/type checking",
    "Fractional (non-integer) exponents",
    "Handling base 0 with negative exponent (division by zero edge case)",
    "BigInt or arbitrary-precision arithmetic",
    "Changes to package.json or project configuration"
  ],
  "assumptions": [
    "The function will use JavaScript's built-in Math.pow or the ** operator for computation",
    "Both arguments are assumed to be finite numbers (no NaN/Infinity handling required)",
    "Exponents are integers as implied by the stakeholder examples",
    "The existing project structure (single index.js, single test file) should be preserved",
    "No additional dependencies are needed"
  ],
  "dependencies": [
    "Node.js runtime with built-in node:test module support (Node 18+)",
    "Existing index.js module with add and subtract functions",
    "Existing test/calc.test.js test suite"
  ],
  "priority": "must",
  "estimated_complexity": "low"
}
