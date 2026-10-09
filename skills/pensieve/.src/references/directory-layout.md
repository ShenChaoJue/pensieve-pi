# Directory Layout

Pensieve v2 separates system code from project-level and global user data.

## Three anchor points

- **Skill root** (the directory containing `SKILL.md`): pi-installed system files, tracked by the package
- **Project data root** (`<project>/.pensieve/`): independent per project, can be version-controlled
- **Global data root** (`~/.pensieve/`, overridden by `PENSIEVE_GLOBAL_ROOT`): user-maintained data shared across projects

## Layout

```text
<pi-package>/skills/pensieve/       # Installed skill root
├── SKILL.md                        #   Static: frontmatter + routing (tracked)
└── .src/                           #   System scripts, templates, specs (tracked)
    ├── core/
    ├── scripts/
    ├── templates/
    │   ├── agents/
    │   ├── knowledge/
    │   ├── maxims/
    │   └── pipelines/
    ├── references/
    └── tools/

<project>/.pensieve/                # Project-level (per-project, can be version-controlled)
├── maxims/                         #   Engineering maxims (long-term)
├── decisions/                      #   Architecture decisions (long-term)
├── knowledge/                      #   Cached exploration results (long-term)
├── pipelines/                      #   Reusable workflows (long-term)
├── short-term/                     #   Staging area for new conclusions (mirrors long-term structure)
│   ├── maxims/
│   ├── decisions/
│   ├── knowledge/
│   └── pipelines/
├── state.md                        #   Dynamic: lifecycle state + knowledge graph (generated)
├── .gitignore                      #   Only ignores .state/
└── .state/                         #   Runtime artifacts (gitignored)

~/.pensieve/                        # Global user data (override with PENSIEVE_GLOBAL_ROOT)
├── maxims/                         #   Shared engineering maxims (long-term)
├── knowledge/                      #   Shared facts (long-term)
├── pipelines/                      #   Shared reusable workflows (long-term)
├── short-term/                     #   Staging area (mirrors global long-term structure)
│   ├── maxims/
│   ├── knowledge/
│   └── pipelines/
└── .state/                         #   Runtime artifacts (gitignored by convention)
```

## Notes

- `.src/` and `SKILL.md` are tracked system files updated with the pi package
- The global data root is maintained by the user at `~/.pensieve/` by default; `PENSIEVE_GLOBAL_ROOT` overrides that path
- The global root has no `decisions/` and enforces entry caps of 20 `maxims`, 30 `knowledge` entries, and 20 `pipelines`
- Default content seeded into user projects lives under `.src/templates/`
- `SKILL.md` is a **static, tracked** file: the skill interface declaration; scripts do not generate it
- `state.md` is a **dynamic, generated** file at `<project>/.pensieve/state.md`, refreshed by `init/doctor/migrate/upgrade/self-improve/sync`
- `maxims/decisions/knowledge/pipelines` are long-term user data, created locally after initialization
- `short-term/` is the staging area for new conclusions; it mirrors the long-term directory structure and uses `created` + 7-day TTL reminders for triage
- `.state/` lives inside `.pensieve/` and stores runtime artifacts such as doctor reports, migration backups, session markers, and generated graphs
- `maintain-project-state.sh` rewrites `state.md`
- `generate-user-data-graph.sh` / `doctor` output the graph to `.pensieve/.state/pensieve-user-data-graph.md` by default
- Any directory containing `.src/manifest.json` is the current system skill root
- `init` seeds `.src/templates/pipelines/run-when-*.md` into `<project>/.pensieve/pipelines/`
