---
description: Detect OpenUI project state and suggest next action
---

Analyze the current project for OpenUI configuration.

**Steps:**
1. Check if package.json exists and contains @openuidev dependencies
2. Search for createLibrary calls to find the component library
3. Search for system-prompt.txt files
4. Search for API routes handling /api/chat
5. Check for FullScreen, Copilot, or ChatProvider usage in pages
6. Check root layout for CSS imports (@openuidev/react-ui/components.css)

**Output a status table:**
| Check | Status | Path |
|-------|--------|------|
| Dependencies | ... | ... |
| Component Library | ... | ... |
| System Prompt | ... | ... |
| Backend Route | ... | ... |
| Frontend Page | ... | ... |
| CSS Imports | ... | ... |

Then recommend the appropriate /openui:* command for the next step.
