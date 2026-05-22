# Agent A — skills.sh mechanism (completed 2026-05-22)

## TL;DR
skills.sh has no publish API, no manifest registry, no GitHub crawl. It's a **telemetry index** built from `npx skills` CLI usage. A skill page is created when someone runs `npx skills add <github-url> --skill <name>` against the public URL at least once.

The 5 missing variants have zero recorded installs, so no index entry exists.

## Required user action (one-time)

Run these 6 commands once from any Node 18+ machine to register the missing variants on skills.sh:

```bash
npx -y skills add https://github.com/OthmanAdi/openui-forge --skill openui-forge-langchain -g -y
npx -y skills add https://github.com/OthmanAdi/openui-forge --skill openui-forge-vercel -g -y
npx -y skills add https://github.com/OthmanAdi/openui-forge --skill openui-forge-python -g -y
npx -y skills add https://github.com/OthmanAdi/openui-forge --skill openui-forge-go -g -y
npx -y skills add https://github.com/OthmanAdi/openui-forge --skill openui-forge-rust -g -y
npx -y skills add https://github.com/OthmanAdi/openui-forge --skill openui-forge-zh -g -y
```

No auth required. Pages appear within minutes (real-time indexing observed).

Optional cleanup (if user doesn't want all 6 globally installed):
```bash
npx -y skills remove -g --skill openui-forge-langchain,openui-forge-vercel,openui-forge-python,openui-forge-go,openui-forge-rust,openui-forge-zh -y
```

## CI self-healing fix

Extend `.github/workflows/skill-validation.yml` to install all 9 variants (instead of just `openui-forge`) using the full GitHub URL form. This ensures telemetry registers on every CI run, making the missing-variant problem self-healing.
