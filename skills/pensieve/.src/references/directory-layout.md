# Directory Layout

Pensieve v2 separates system code (user-level) from project data (project-level).

## Two anchor points

- **Skill root** (the directory containing `SKILL.md`): pi-installed system files, tracked by the package
- **Project data** (`<project>/.pensieve/`): independent per project, can be version-controlled

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
```

## Notes

- `.src/` and `SKILL.md` are tracked system files updated with the pi package
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
