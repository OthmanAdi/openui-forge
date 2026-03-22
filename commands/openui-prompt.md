---
description: Generate or regenerate the system prompt from the component library
---

Generate the system prompt that tells the LLM which components are available and how to use OpenUI Lang.

---

## Step 1 — Detect the approach

Check the project to determine which prompt generation method to use:

- **Non-JS backend** (Python, Go, Rust, or no backend yet): Use the CLI approach
- **JS/TS backend that imports the library at runtime**: Use the runtime approach
- If unclear, default to CLI — it works universally

---

## Step 2a — CLI approach (recommended, required for non-JS backends)

Find the component library file (search for `createLibrary` calls).

Run:
```bash
npx @openuidev/cli generate ${LIBRARY_PATH} --out ${OUTPUT_PATH}
```

Typical paths:
- Library: `./src/lib/library.ts`
- Output: `./src/generated/system-prompt.txt` or `./system-prompt.txt`

For JSON Schema output (useful for structured generation or validation):
```bash
npx @openuidev/cli generate ${LIBRARY_PATH} --json-schema --out ${OUTPUT_PATH}/schema.json
```

After running, verify:
1. The output file exists
2. The output file is non-empty (at least a few hundred bytes)
3. The file contains component names that match the library

---

## Step 2b — Runtime approach (JS/TS backends)

If the backend already imports the library, the system prompt can be generated at runtime using `library.prompt()`. Verify this is set up in the API route:

```typescript
import { myLibrary } from "./lib/library";

const systemPrompt = myLibrary.prompt({
  preamble: "You are a helpful assistant that generates interactive UIs.",
  additionalRules: [
    "Always use Stack as root when combining multiple components.",
    "Prefer existing components over generating raw text.",
  ],
  examples: [
    'root = Stack([title, chart])\ntitle = Header("Sales")\nchart = BarChart(labels, [s1])\nlabels = ["Q1","Q2"]\ns1 = Series("Rev", [100, 200])',
  ],
});
```

Verify:
1. The library import path resolves correctly
2. `.prompt()` is called with at least a `preamble`
3. The result is passed as the system message to the LLM call

---

## Step 3 — Verify the output

Regardless of approach, confirm:
- The system prompt or `.prompt()` call exists and is reachable by the backend
- The prompt content includes all components from the library
- The prompt is loaded server-side only (never sent to the frontend)

---

## When to regenerate

You MUST regenerate the system prompt after any of these changes:
- Adding, removing, or renaming a component
- Changing a component's Zod schema or `.describe()` text
- Changing component descriptions
- Modifying prompt options (preamble, additionalRules, examples)
- Restructuring componentGroups

If using the runtime approach, regeneration is automatic on server restart. If using the CLI approach, the command must be re-run manually.
