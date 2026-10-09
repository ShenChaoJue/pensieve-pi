# Scope

Every Pensieve entry carries two dimensions: a **semantic layer** (`knowledge/decision/maxim/pipeline`, see `.src/references/shared-rules.md`) and a **scope**. This spec decides the scope: *project* or *global*.

Principle: **the project root stores differences; the global root stores commonalities.**

## Two data roots

| Scope | Root | Holds |
|---|---|---|
| project | `<project>/.pensieve/` | What makes this repo unique |
| global | `~/.pensieve/` (override: `PENSIEVE_GLOBAL_ROOT`) | What holds across all of the user's projects |

The global root mirrors the project layout, **minus `decisions/`**:

```text
~/.pensieve/
├── maxims/
├── knowledge/
├── pipelines/
├── short-term/          # mirrors global long-term structure, same 7-day TTL
│   ├── maxims/
│   ├── knowledge/
│   └── pipelines/
└── .state/              # runtime artifacts (gitignored by convention)
```

`decisions/` stays project-level: an architecture trade-off is bound to the repo that made it. A "we no longer use tool X anywhere" style conclusion is written as a `maxim` (rule) or `knowledge` (fact), not as a global decision.

## The scope decision

Answer in order; stop at the first terminal answer.

| # | Question | No -> | Yes -> |
|---|---|---|---|
| S1 | Does it reference repo-bound context: file paths, module names, boundaries, or a trade-off made in this repo? | S2 | **project** |
| S2 | Does it still hold in another one of your projects — ideally in a different language or stack? | **project** | **global** |

After the scope is decided, the semantic layer is chosen as usual (rule -> `maxims`, fact -> `knowledge`, workflow -> `pipelines`).

## Evidence rule

S2 is not answered by intuition alone; it is answered by evidence:

- Evidence from **one project only** -> write to that project, even if the wording sounds universal. Optionally tag `scope-candidate`.
- The same conclusion appears in **two or more projects** -> global candidate. Promote during refine.
- Exceptions that may go global immediately: entries seeded from `.src/templates/`, or the user explicitly says "this is global".

This is the mechanism by which many projects accumulate global knowledge: **single occurrence stays local; cross-project recurrence promotes.**

## Defaults per type

| type | default | global when | project signals |
|---|---|---|---|
| `maxim` | global candidate | Holds when switching project and language; violating it raises risk everywhere | Only this project's regression risk depends on it |
| `decision` | project | (no global layer) | Always |
| `knowledge` | split | Tool/platform/ecosystem facts; user-environment facts (OS, package manager paths) that follow the user, not the repo | Structure caches: file locations, module boundaries, call chains |
| `pipeline` | split | Remains complete after stripping project-specific paths and commands (parameterize them) | Any step depends on repo paths or project-only commands |

## Boundary examples

| Entry | Verdict | Why |
|---|---|---|
| "Read the module in full before wide-ranging edits" | global `maxims/` | Holds in any repo, any language |
| "All external APIs must be idempotent" | global `maxims/` (after recurrence) or project until then | Cross-project rule; follow the evidence rule on first occurrence |
| "Node lives under `/opt/homebrew` on this machine" | global `knowledge/` | User-environment fact, follows the user |
| "This repo uses pnpm; never run `npm install`" | project `knowledge/` | Toolchain choice is repo-bound |
| "Run `npm run check` after every change" | project `pipeline/` | Command exists only in this repo |
| "Run the full test suite after dependency upgrades" | global `pipelines/` with a parameterized command slot | Complete once the command is parameterized |
| "State lives in `packages/tui/src/state/`" | project `knowledge/` | Repo-bound structure cache |
| "Vitest e2e tests activate when endpoint env vars are present" | project `knowledge/` first | Ecosystem fact, but verify recurrence in a second project before promoting |

## Write targets

`self-improve` runs S1/S2 before writing:

- project -> existing rules: `short-term/{type}/...` under `<project>/.pensieve/`
- global -> `short-term/{type}/...` under `~/.pensieve/` (same naming conventions as the project layer)

Editing an existing entry happens in place, in whichever root already holds it.

## Frontmatter

- New field `scope: project | global`; omitting it means `project`
- Optional tag `scope-candidate` marks one-project entries whose wording looks global; doctor reports them as promotion hints

## Promotion paths

```text
~/.pensieve/short-term/{type}/x.md  ->  ~/.pensieve/{type}/x.md          (refine, as today)
<project>/.pensieve/short-term/...  ->  <project>/.pensieve/{type}/...   (refine, as today)
<project>/.pensieve/{type}/x.md     ->  ~/.pensieve/{type}/x.md          (refine Q-scope: cross-project recurrence confirmed)
```

Refine gains one question before Q5: **"Does this entry now hold in a second project?"** Yes with evidence -> promote to the global root; No -> keep project-level.

## Cross-root links

- Links inside the same root are unchanged: `[[maxims/foo]]`, no `short-term/` prefix
- Links from project entries into the global root use the `global:` prefix: `[[global:maxims/foo]]`
- Links from global entries into project entries are **forbidden** — global entries must not depend on repo-bound context (that dependence is exactly what S1 excludes)
- The graph resolver treats both roots as link sources; `global:` disambiguates the target root

## Deduplication and override

- When an entry is promoted to global, duplicate project-level entries are deleted, or reduced to a one-line pointer plus project-specific deltas
- On conflict, **the more specific scope wins**: project overrides global. An overriding entry must declare `Overrides: [[global:maxims/foo]]` so doctor can surface the conflict pair
- Never maintain the same sentence in both roots

## Size budget

The global root is injected into every session; it must stay small:

| layer | hard cap | on overflow |
|---|---|---|
| `maxims/` | 20 entries | mandatory refine (compress technique A/C) before adding new |
| `knowledge/` | 30 entries | compress or archive to project scope |
| `pipelines/` | 20 entries | merge or demote repo-dependent steps to project pipelines |

## Injection contract

- At session start, the **one-line conclusions** of global `maxims/` plus a title-only index of global `pipelines/` and `knowledge/` are injected as a compact block (global first, project state after)
- Full entry bodies are never injected; the agent reads them on demand
- The project-level `state.md` behavior is unchanged
- Only projects containing a `.pensieve/` directory receive the global block; projects that never opted into Pensieve stay untouched
