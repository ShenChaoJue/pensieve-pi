---
description: Write Pensieve project pipeline routes or global maxims and pipeline indexes into agent instruction files. Idempotent; does not overwrite user content.
---

# Sync Instructions Tool

> Tool boundaries: see `.src/references/tool-boundaries.md` | Shared rules: see `.src/references/shared-rules.md`

## Use when

- The user asks to write Pensieve pipelines into `AGENTS.md`, `agent.md`, or another project-level agent instruction file
- The user wants the next agent to know which pipeline to use for commit / refactor / review requests
- The project already has `.pensieve/pipelines/`, but the entry instruction files lack short routes
- The user wants global Pensieve maxims and pipeline routes available to Pi through `~/.pi/agent/AGENTS.md`

Project mode only writes short routes. It does not generate project summaries or inline full pipeline content. Global mode writes maxim conclusions and a pipeline title/path index, not the full entries.

## Failure fallback

- `.src/scripts/sync-instructions.sh` is missing: stop and report an incomplete skill installation
- `<project>/.pensieve/pipelines/` is missing: run `init` first
- The global Pensieve root is missing in `--global` mode: run `init --global` first
- Pensieve markers in the target file are unpaired or repeated: stop and ask the user to repair the markers manually; the file is left unchanged

## Standard execution

> All `.src/` paths below are relative to the skill root (the directory containing `SKILL.md`). Set `PENSIEVE_SKILL_ROOT` to that directory.

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/sync-instructions.sh" --target agents
```

To update only an existing entry file without creating a new `AGENTS.md` file:

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/sync-instructions.sh" --target auto
```

To update Pi's global instruction file (default `~/.pi/agent/AGENTS.md`):

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/sync-instructions.sh" --global
```

Set `PENSIEVE_GLOBAL_INSTRUCTIONS_FILE` to override the global target. Global mode reads `PENSIEVE_GLOBAL_ROOT` when set, otherwise `~/.pensieve`, and does not require project context.

## Written Content

The project block contains only one heading and short routes:

```markdown
## How To Use Pensieve

Use `.pensieve/` as the first source of architectural intent.

- `maxims/` are active engineering rules.
- `decisions/` are active project decisions.
- `knowledge/` explains boundary maps and debugging paths.
- `pipelines/` gives executable workflows.

Use these project pipelines directly when trigger words match; do not rediscover them through skills first.

- Commit requests (`commit`, `git commit`): use `.pensieve/pipelines/run-when-committing.md`. Check staged diff, decide whether reusable insight should be captured, then make atomic commits.
- Refactor requests (`refactor`, `large refactor`, `split code`): use `.pensieve/pipelines/run-when-refactoring.md`. Confirm the real problem, fix upstream data authority first, split large work into 2-3 user-visible steps, delete old paths when new paths work, and avoid compatibility/fallback branches.
- Review requests (`review`, `code review`, `inspect code`): use `.pensieve/pipelines/run-when-reviewing-code.md`. Start from git history and changed hot spots, verify candidate issues, and report only high-signal findings with evidence and file locations.
```

The global block uses separate markers, preserves all content outside them, and truncates each list using `global_root.entry_caps` from `schema.json`:

```markdown
<!-- pensieve:global-instructions:start -->
Maintained by `sync-instructions --global`; edit entries under the Pensieve global root, not this block.

## Global Engineering Maxims (Pensieve)

- Prefer one source of truth

## Global Pipelines (Pensieve)

- Run When Committing: `/home/user/.pensieve/pipelines/run-when-committing.md`
<!-- pensieve:global-instructions:end -->
```

Titles use frontmatter `title`, then the first H1, then the filename. Pipeline paths are absolute paths under the actual global root.
