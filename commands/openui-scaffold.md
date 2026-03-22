---
description: Scaffold a new OpenUI project or add OpenUI to an existing project
---

Trigger the OpenUI scaffolding workflow. Follow the decision tree from SKILL.md exactly.

**Step 1 — Detect project state:**

1. Check if a package.json exists in the current directory
2. If yes, detect the framework by checking for next.config.*, vite.config.*, or neither
3. If no package.json exists, check if this is a non-JS project (look for requirements.txt, go.mod, Cargo.toml)

**Step 2 — Follow the scaffold decision tree:**

**No existing project detected:**
- Run `npx @openuidev/cli@latest create --name ${PROJECT_NAME}` (ask the user for a project name)
- Wait for scaffold to complete
- Inform the user to run `/openui:integrate` next

**Existing Next.js project:**
1. Install dependencies: `npm install @openuidev/react-ui @openuidev/react-headless @openuidev/react-lang lucide-react zod`
2. Add CSS imports to the root layout file (app/layout.tsx or similar):
   ```tsx
   import "@openuidev/react-ui/components.css";
   import "@openuidev/react-ui/styles/index.css";
   ```
3. Create a component library file using `templates/library.ts.template` — or ask the user if they want to use the built-in `openuiLibrary` from `@openuidev/react-ui`
4. Recommend running `/openui:integrate` next

**Existing Vite + React project:**
1. Same dependencies as Next.js
2. Add CSS imports to the main entry file (main.tsx or App.tsx)
3. Create a component library file using `templates/library.ts.template`
4. Note: A proxy to the backend will need to be configured in vite.config.ts during integration
5. Recommend running `/openui:integrate` next

**Non-JS backend (Python / Go / Rust):**
1. Create a React frontend (ask: Next.js or Vite?) and install OpenUI deps there
2. Create a component library in the frontend using `templates/library.ts.template`
3. Run `npx @openuidev/cli generate ./src/lib/library.ts --out system-prompt.txt` to pre-generate the system prompt
4. Copy system-prompt.txt to the backend service directory
5. Note: The backend handler will be created during `/openui:integrate`
6. Recommend running `/openui:integrate` next

**After scaffolding, always run `/openui` to verify the project state.**
