# pensieve-pi

[English](README.md) | [简体中文](README.zh-CN.md)

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

## Global data

Pensieve also supports a shared data root at `~/.pensieve/`. Set `PENSIEVE_GLOBAL_ROOT` to use a different location.

```text
~/.pensieve/
├── maxims/              # Shared engineering rules (maximum 20)
├── knowledge/           # Shared facts (maximum 30)
├── pipelines/           # Shared workflows (maximum 20)
├── short-term/          # Staging mirror for the three long-term layers
│   ├── maxims/
│   ├── knowledge/
│   └── pipelines/
└── .state/              # Runtime artifacts
```

The project root stores differences; the global root stores commonalities. Global data has no `decisions/` layer because architecture trade-offs remain bound to the project that made them.

Before writing an entry, Pensieve applies two scope questions: S1 asks whether it references repository-bound context; if not, S2 asks whether it still holds in another project. Evidence from only one project stays at project scope and may receive the `scope-candidate` tag. Recurrence in two or more projects can be promoted by `refine`. Project entries link to shared entries with `[[global:maxims/example]]`-style links, and every entry may declare `scope: project | global` in its frontmatter.

For projects that contain `.pensieve/`, session startup prepends global maxim titles and global pipeline/knowledge indexes to `additionalContext`; full entry bodies remain available on demand. Projects without `.pensieve/` are unaffected.

## Tools

- **init** — initialize project data and seed its default content; `init --global` idempotently initializes the global root with four maxims and three pipelines.
- **upgrade** — explain how to update the installed pi package.
- **migrate** — migrate legacy data and align the current directory structure.
- **doctor** — check project and global data, links, generated state, instruction routes, and frontmatter `scope`; missing global directories or exceeded 20/30/20 caps are `MUST_FIX`, while `scope-candidate` entries are `INFO`, and the generated graph includes a Global subgraph.
- **self-improve** — capture reusable conclusions from completed work.
- **refine** — apply a six-question review, including Q5 cross-project recurrence, then promote eligible entries across roots and delete duplicates or reduce them to `[[global:...]]` pointers with project-specific deltas.
- **sync-instructions** — add project pipeline routes to `AGENTS.md`; `sync-instructions --global` writes global maxims and a pipeline index to `~/.pi/agent/AGENTS.md` inside `<!-- pensieve:global-instructions:start -->` / `<!-- pensieve:global-instructions:end -->`, making them available to all pi sessions.

The original Claude Code distribution uses `.src/scripts/install-hooks.sh`; pi users do not need to run it because the pi extension provides lifecycle integration. If Claude Code is also installed, maintenance can synchronize its `MEMORY.md`; set `PENSIEVE_DISABLE_AUTO_MEMORY=1` to disable that compatibility behavior.
