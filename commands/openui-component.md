---
description: Create a new OpenUI component with Zod schema and React renderer
---

Create a new component and add it to the component library.

**Step 1 — Gather requirements:**

Ask the user:
- What does this component display or do?
- What props does it need? (or let the agent infer from the description)

**Step 2 — Research patterns:**

Read `references/component-patterns.md` for production examples that match the use case. Look for similar component types (data display, input, layout, feedback) and follow the same structural conventions.

**Step 3 — Generate the component:**

Use `templates/component.tsx.template` as the base structure. Create the component using `defineComponent` from `@openuidev/react-lang`:

```tsx
import { defineComponent } from "@openuidev/react-lang";
import { z } from "zod";

export const ${NAME} = defineComponent({
  name: "${NAME}",
  description: "${DESCRIPTION}",
  props: z.object({
    // props here
  }),
  component: ({ props }) => (
    // JSX here
  ),
});
```

**CRITICAL design rules (these directly affect LLM generation quality):**

- `.describe()` on EVERY Zod prop — this is the LLM's only documentation for what to put in each field
- Flat schemas — avoid nesting deeper than 2 levels
- Specific types — use `z.enum(["sm", "md", "lg"])` over `z.string()` when values are constrained
- Clear, unique names — the LLM picks components by name + description alone
- Use `ref` from other DefinedComponents for nested component references
- Keep the total library under 30 components — more = more prompt tokens = worse LLM output

**Step 4 — Add to the library:**

Find the existing `createLibrary` call in the project. Add the new component import and place it in the appropriate `componentGroups` group. If no suitable group exists, create one.

**Step 5 — Regenerate the system prompt:**

Remind the user to run `/openui:prompt` to regenerate the system prompt so the LLM knows about the new component. This step is mandatory — the LLM cannot use components it does not see in the system prompt.
