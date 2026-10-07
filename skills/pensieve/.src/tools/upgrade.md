---
description: Update the installed Pensieve pi package. Does not perform structural migration or doctor grading.
---

# Upgrade Tool

> Tool boundaries: see `.src/references/tool-boundaries.md` | Shared rules: see `.src/references/shared-rules.md`

## Use when

- User requests a Pensieve upgrade
- Need to confirm version changes before and after upgrade

If the user first asks "how to update Pensieve", read `.src/references/skill-lifecycle.md` first, then run this tool.

This tool is only responsible for updating the installed pi package. It does not install Claude Code hooks.

## Standard execution

For an installation sourced from git, run:

```bash
pi update
```

Alternatively, reinstall from its git source:

```bash
pi install git:https://github.com/<owner>/<repository>.git
```

After upgrading, run doctor from the project being checked. The skill root is the directory containing `SKILL.md`; set `PENSIEVE_SKILL_ROOT` to that directory.

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-doctor.sh" --strict
```
