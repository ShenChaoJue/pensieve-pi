# Shared Rules

## Root Rules

1. `.src/` is the system files directory (located in the skill root); never write user data or runtime state into it.
2. `.pensieve/.state/` is the hidden runtime state directory; write reports, markers, caches, and other transient data here.
3. The project data root contains `<project>/.pensieve/{maxims,decisions,knowledge,pipelines}` plus the mirrored `<project>/.pensieve/short-term/{maxims,decisions,knowledge,pipelines}` staging area. The global data root contains `~/.pensieve/{maxims,knowledge,pipelines}` plus the mirrored `~/.pensieve/short-term/{maxims,knowledge,pipelines}` staging area; it has no `decisions/`. Apart from these, only `<project>/.pensieve/state.md` and files under the global root's `.state/` may be rewritten by maintenance scripts.
4. Before writing user data, use S1/S2 in `.src/references/scope.md` to select the target root. Enforce the global entry caps, use the `[[global:...]]` prefix for cross-root links, and never link from a global entry to a project entry.
5. `SKILL.md` in the skill root is a static, tracked file -- do not modify it.
6. Confirm before executing. Do not automatically run long workflows unless the user explicitly requests it.
7. Read the spec before writing data: before writing a maxim/decision/knowledge/pipeline, read `.src/references/scope.md` and the corresponding spec in `.src/references/`. New entries go into `short-term/` by default (see `.src/references/short-term.md`).
8. Keep links connected: every `decision/pipeline` must have at least one `[[...]]` link.
9. `[[...]]` links must not include the `short-term/` prefix -- always use the target-layer path (e.g. `[[decisions/foo]]`).

## Path conventions

- System skill root: directory containing `SKILL.md` (set as `$PENSIEVE_SKILL_ROOT`)
- Tool specs: `.src/tools/*.md`
- Execution scripts: `.src/scripts/*.sh`
- Hidden templates: `.src/templates/**`
- Project user data: `<project>/.pensieve/`
- Global user data: `~/.pensieve/` (override with `PENSIEVE_GLOBAL_ROOT`)
- Hidden runtime state: `<project>/.pensieve/.state/**`
- Long-term user data:
  - `.pensieve/maxims/*.md`
  - `.pensieve/decisions/*.md`
  - `.pensieve/knowledge/*/content.md`
  - `.pensieve/pipelines/run-when-*.md`
- Short-term staging (mirrored structure):
  - `.pensieve/short-term/{maxims,decisions,knowledge,pipelines}/*`

## Semantic layers

- `knowledge` = IS (facts)
- `decision` = WANT (trade-offs)
- `maxim` = MUST (hard rules)
- `pipeline` = HOW (workflows)
- `short-term` = STAGING (staging area, flagged for review based on created + 7-day TTL)

Scope is a second dimension orthogonal to the semantic layer; use `.src/references/scope.md` to choose `project` or `global`.

## When to use migrate / upgrade

- Old paths, key file drift, legacy graph remnants: `migrate`
- Updating skill source code or refreshing installation: `upgrade`
