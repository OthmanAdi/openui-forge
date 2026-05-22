# ADOPTERS.md PR for thesysdev/openui — ready to submit

This file contains the exact diff and PR body you need. Run the commands at the end to submit.

## The row to add (paste into `ADOPTERS.md` after the Standard Metrics row)

```
| [openui-forge](https://github.com/OthmanAdi/openui-forge) | [@OthmanAdi](https://github.com/OthmanAdi) | Cross-IDE agent skill for OpenUI. Templates for OpenAI, Anthropic, LangChain, Vercel AI SDK, plus FastAPI / Go / Rust backends. Mirrors to 11 agent platforms. |
```

## PR title
```
Add openui-forge to ADOPTERS.md
```

## PR body
```
Adding openui-forge as a community adopter of OpenUI.

What it is: a cross-IDE agent skill that targets areas the canonical scaffold does not cover.
- Adds OpenUI to existing projects (the CLI is create-only)
- Ships non-JS backend templates for Python (FastAPI), Go (net/http), and Rust (Axum)
- Wires up any LLM provider directly: OpenAI, Anthropic, LangChain, Vercel AI SDK
- Routes via OPENAI_BASE_URL for any OpenAI-compatible endpoint (Gemini, OpenRouter, xAI, DeepSeek)
- Mirrors skill content to 11 agent platforms beyond Claude Code (Cursor, Gemini CLI, Codex, Kiro, Continue, Factory, OpenCode, Pi, Mastra, CodeBuddy)

Repo: https://github.com/OthmanAdi/openui-forge
skills.sh: https://skills.sh/OthmanAdi/openui-forge
```

## Commands to submit

```bash
# 1. Fork thesysdev/openui under your account
gh repo fork thesysdev/openui --clone=false --remote=false

# 2. Clone the fork locally to a scratch dir
git clone https://github.com/OthmanAdi/openui.git /tmp/openui-adopters-pr
cd /tmp/openui-adopters-pr

# 3. Create a branch
git checkout -b add-openui-forge-adopter

# 4. Append the row (manual edit recommended; ADOPTERS.md has tight column alignment)
#    Open ADOPTERS.md in your editor and paste the row above after the Standard Metrics row.
#    Or use this one-liner if you don't mind unaligned column widths:
python -c "
content = open('ADOPTERS.md').read()
row = '| [openui-forge](https://github.com/OthmanAdi/openui-forge) | [@OthmanAdi](https://github.com/OthmanAdi) | Cross-IDE agent skill for OpenUI. Templates for OpenAI, Anthropic, LangChain, Vercel AI SDK, plus FastAPI / Go / Rust backends. Mirrors to 11 agent platforms. |\n'
needle = 'transform portfolio management |'
content = content.replace(needle, needle + '\n' + row.rstrip())
open('ADOPTERS.md', 'w').write(content)
"

# 5. Commit
git add ADOPTERS.md
git commit -m 'Add openui-forge to ADOPTERS.md'

# 6. Push to your fork
git push -u origin add-openui-forge-adopter

# 7. Open the PR (from the scratch dir)
gh pr create --repo thesysdev/openui \
  --title "Add openui-forge to ADOPTERS.md" \
  --body-file -  <<'BODY'
Adding openui-forge as a community adopter of OpenUI.

What it is: a cross-IDE agent skill that targets areas the canonical scaffold does not cover.
- Adds OpenUI to existing projects (the CLI is create-only)
- Ships non-JS backend templates for Python (FastAPI), Go (net/http), and Rust (Axum)
- Wires up any LLM provider directly: OpenAI, Anthropic, LangChain, Vercel AI SDK
- Routes via OPENAI_BASE_URL for any OpenAI-compatible endpoint (Gemini, OpenRouter, xAI, DeepSeek)
- Mirrors skill content to 11 agent platforms beyond Claude Code (Cursor, Gemini CLI, Codex, Kiro, Continue, Factory, OpenCode, Pi, Mastra, CodeBuddy)

Repo: https://github.com/OthmanAdi/openui-forge
skills.sh: https://skills.sh/OthmanAdi/openui-forge
BODY
```

## Notes

- This is a public action on an external repo under your identity. Auto-mode classifier blocks me from submitting this for you (correct call). Run the commands when ready.
- Tone is sachlich per your guideline. No dashes as pauses. No performative warmth.
- If the maintainer asks for a tweak (different description, link to a demo), one quick edit, force-push, done.
