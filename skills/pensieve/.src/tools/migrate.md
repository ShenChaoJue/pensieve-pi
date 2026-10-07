---
description: Migration tool. Automatically migrates legacy user data to the v2 directory structure and aligns critical seed files. Does not perform version upgrades or doctor grading.
---

# Migrate Tool

> Tool boundaries: see `.src/references/tool-boundaries.md` | Shared rules: see `.src/references/shared-rules.md`

## Use when

- Migrating from v1 (project-level install) to v2 (user-level system + project-level data)
- Doctor reports critical file missing or critical file drift
- Need to fill in directory structure or re-align seed files

Critical pipeline seeds are sourced from `.src/templates/pipelines/run-when-*.md`; the migration script only keeps compatibility with historical `pipeline.run-when-*` names when reading old user data.

## Standard execution

> All `.src/` paths below are relative to the skill root (the directory containing `SKILL.md`). Set `PENSIEVE_SKILL_ROOT` to that directory.

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-migrate.sh"
```

Optional dry-run:

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-migrate.sh" --dry-run
```
