---
name: OpenUI Forge
alwaysApply: true
---

# OpenUI Forge

This repo is **openui-forge**, a cross-IDE agent skill for [OpenUI](https://www.openui.com), the Open Standard for Generative UI. The full skill is at `skills/openui-forge/SKILL.md` — read it before any OpenUI work. Stack-specific variants live in `skills/openui-forge-*/`.

Commands: `/openui`, `/openui:scaffold`, `/openui:component`, `/openui:integrate`, `/openui:prompt`, `/openui:validate`.

Match the frontend `streamProtocol` to the backend body: SSE pairs with `openAIAdapter()`; NDJSON pairs with `openAIReadableStreamAdapter()`.
