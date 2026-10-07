# pensieve-pi

A pi package containing the Pensieve project knowledge-base skill. Ported from [kingkongshot/Pensieve](https://github.com/kingkongshot/Pensieve) v1.3.0, licensed under MIT.

## Package layout

```text
pensieve-pi/
├── package.json
├── README.md
├── skills/
│   └── pensieve/
│       ├── SKILL.md
│       └── .src/
└── extensions/       # pi lifecycle integration
```

## Install

From a local checkout:

```bash
pi install ./pensieve-pi
```

After publishing the repository:

```bash
pi install git:https://github.com/<owner>/<repository>.git
```

## Project data

Pensieve keeps user-owned data under each project's `.pensieve/` directory:

- `maxims/` — durable engineering rules and standards.
- `decisions/` — architecture decisions and their trade-offs.
- `pipelines/` — reusable workflows for recurring tasks.
- `knowledge/` — cached project structure, boundaries, and exploration results.
- `short-term/` — staging for new conclusions before promotion or deletion.

## Tools

- **init** — initialize `.pensieve/` and seed its default content.
- **upgrade** — explain how to update the installed pi package.
- **migrate** — migrate legacy data and align the current directory structure.
- **doctor** — check project data, links, generated state, and instruction routes.
- **self-improve** — capture reusable conclusions from completed work.
- **refine** — triage, deduplicate, and compress the knowledge base.
- **sync-instructions** — add Pensieve pipeline routes to `AGENTS.md`.

The original Claude Code distribution uses `.src/scripts/install-hooks.sh`; pi users do not need to run it because the pi extension provides lifecycle integration. If Claude Code is also installed, maintenance can synchronize its `MEMORY.md`; set `PENSIEVE_DISABLE_AUTO_MEMORY=1` to disable that compatibility behavior.
