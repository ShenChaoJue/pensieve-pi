---
description: Read-only scan of the current project's .pensieve/ user-data directory. Checks frontmatter, links, directory structure, critical seed files, auto memory, and Pensieve short-route alignment in project instruction files, then emits a fixed-format report.
---

# Doctor Tool

> Tool boundaries: see `.src/references/tool-boundaries.md` | Shared rules: see `.src/references/shared-rules.md` | Directory conventions: see `.src/references/directory-layout.md`

## Use when

- Rechecking after init
- Rechecking after upgrade
- Confirming MUST_FIX is cleared after migration
- Suspected drift in the graph, frontmatter, directory structure, memory guidance, or `AGENTS.md` short routes

## Standard execution

> All `.src/` paths below are relative to the skill root (the directory containing `SKILL.md`). Set `PENSIEVE_SKILL_ROOT` to that directory.

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-doctor.sh" --strict
```

Doctor only maintains:

- `<project>/.pensieve/state.md` (lifecycle state + Graph)
- Runtime graph output such as `.pensieve/.state/pensieve-user-data-graph.md`
- Claude auto memory `~/.claude/projects/<project>/memory/MEMORY.md`

Doctor reports missing or drifted `AGENTS.md` Pensieve short routes as MUST_FIX, but it does not modify them automatically. Use `sync-instructions` to fix them.

It does not modify business code.
