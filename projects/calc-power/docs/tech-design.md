{
  "architecture_overview": "The test-calc-app is a minimal ES module calculator library with a single index.js exporting arithmetic functions and a single test file using Node's built-in test runner. The power function will be added as a third named export in index.js, following the exact same pattern as the existing add and subtract functions (single-line arrow/function expression using the ** operator). A corresponding describe/it block will be added to the existing test file to cover positive, zero, and negative exponent cases. No new files, dependencies, or architectural changes are needed.",
  "components": [
    {
      "name": "Calculator Module",
      "responsibility": "Exports arithmetic functions (add, subtract, power) as named ES module exports",
      "files_to_create": [],
      "files_to_modify": ["index.js"],
      "changes_summary": "Add a new exported function `power(base, exponent)` that returns `base ** exponent`, appended after the existing subtract function on a new line, following the same single-line export function pattern."
    },
    {
      "name": "Test Suite",
      "responsibility": "Unit tests for all calculator functions using node:test framework",
      "files_to_create": [],
      "files_to_modify": ["test/calc.test.js"],
      "changes_summary": "Import `power` alongside `add` and `subtract` from '../index.js'. Add a new describe block or it() calls within the existing 'Calculator' describe block covering: positive exponents (2^3=8), zero exponent (5^0=1), identity exponent (7^1=7), and negative exponents (2^-1=0.5, 4^-2=0.0625, 10^-1=0.1)."
    }
  ],
  "api_design": [],
  "data_model": {
    "new_entities": [],
    "schema_changes": [],
    "migration_notes": "No data model changes required. This is a pure function addition."
  },
  "tech_decisions": [
    {
      "decision": "Use the ** (exponentiation) operator for the power function implementation",
      "rationale": "The ** operator is native ES2016+, more idiomatic than Math.pow(), produces identical results for numeric inputs, and keeps the code consistent with the terse single-line style of existing functions. The project already uses ES modules (type: module), confirming modern JS support.",
      "alternatives_considered": ["Math.pow(base, exponent) — functionally equivalent but slightly more verbose", "Manual loop-based implementation — unnecessary complexity, no benefit over built-in operator"]
    },
    {
      "decision": "Add tests inside the existing 'Calculator' describe block rather than creating a new test file",
      "rationale": "The PRD explicitly states the existing project structure (single test file) should be preserved. The existing describe block groups calculator tests logically.",
      "alternatives_considered": ["Separate test/power.test.js file — violates the single-test-file structure assumption"]
    }
  ],
  "risks": [
    {
      "risk": "Floating-point precision for negative exponents (e.g., power(10, -1) might produce 0.10000000000000001 instead of exactly 0.1)",
      "severity": "low",
      "mitigation": "JavaScript's ** operator returns the same IEEE 754 results as Math.pow. For the specific test cases in the PRD (2^-1=0.5, 4^-2=0.0625, 10^-1=0.1), all are exactly representable or match strictEqual expectations. 10**-1 evaluates to exactly 0.1 in V8. No mitigation needed for the specified cases."
    },
    {
      "risk": "0 raised to a negative exponent produces Infinity, which is out of scope but could surprise consumers",
      "severity": "low",
      "mitigation": "Explicitly listed as out of scope in the PRD. Document this behavior if needed in future iterations."
    }
  ],
  "nfr": {
    "performance": "Single arithmetic operation using native JS operator; negligible overhead. No performance concerns.",
    "security": "Pure function with no I/O, no side effects, no user input handling. No security surface.",
    "scalability": "Not applicable — stateless library function.",
    "observability": "Test suite via `npm test` provides regression detection. No runtime observability needed for a pure function."
  },
  "estimated_effort": "small",
  "implementation_order": [
    "Step 1: Add `export function power(base, exponent) { return base ** exponent; }` to index.js after the subtract function",
    "Step 2: In test/calc.test.js, add `power` to the import destructuring from '../index.js'",
    "Step 3: Add it() test cases within the Calculator describe block for positive exponents (2,3)→8, zero exponent (5,0)→1, identity (7,1)→7, and negative exponents (2,-1)→0.5, (4,-2)→0.0625, (10,-1)→0.1",
    "Step 4: Run `npm test` to verify all existing and new tests pass with exit code 0"
  ]
}
