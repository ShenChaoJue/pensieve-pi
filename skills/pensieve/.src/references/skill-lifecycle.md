---
id: skill-lifecycle
type: knowledge
title: Pensieve Installation and Updates
status: active
created: 2026-03-06
updated: 2026-03-10
tags: [pensieve, install, update, operations]
---

# Pensieve Installation and Updates

When the user asks how to install, initialize, update, reinstall, or uninstall Pensieve itself, read this file first.

## Installation

### Step 1: Install the pi package (one-time)

From a local checkout:

```bash
pi install ./pensieve-pi
```

After the package is published in a git repository:

```bash
pi install git:https://github.com/<owner>/<repository>.git
```

Notes:

- pi discovers `skills/` and `extensions/` through package conventions
- `SKILL.md` is a static, tracked file — the skill interface declaration
- A single installation serves all projects
- pi users do not run `.src/scripts/install-hooks.sh`; the extension provides lifecycle integration

### Step 2: Initialize project data (per project)

From the project directory, have the agent run `init`, or set `PENSIEVE_SKILL_ROOT` to the directory containing `SKILL.md` and run:

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/init-project-data.sh"
```

This creates `maxims/decisions/knowledge/pipelines/short-term` under `<project>/.pensieve/` and seeds default content.

## Post-initialization verification

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-doctor.sh" --strict
```

PASS conditions:

- Skill root contains `.src/`
- Skill root contains `SKILL.md` (static, tracked)
- `<project>/.pensieve/{maxims,decisions,knowledge,pipelines}` directories are all present
- `<project>/.pensieve/.state/` has been generated
- `<project>/.pensieve/state.md` has been generated
- Default pipeline and taste-review knowledge have been seeded

## Updates

For a git-sourced installation, update the pi package:

```bash
pi update
```

Alternatively, reinstall it from the git source:

```bash
pi install git:https://github.com/<owner>/<repository>.git
```

A single update takes effect for all projects. After updating, run from the project being checked:

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-doctor.sh" --strict
```

If `doctor` reports structural migration issues:

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-migrate.sh"
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/run-doctor.sh" --strict
```

## Reinstallation

If system files are corrupted:

1. Back up project user data: `<project>/.pensieve/` (for each project)
2. Remove the pi package through the normal pi package workflow
3. Install it again (Step 1)
4. Run `init` for each project (Step 2)
5. Run `doctor`

If this is a normal upgrade, do not reinstall — use `pi update`.

## Uninstallation

Remove the package through the normal pi package workflow. Project data under `<project>/.pensieve/` remains user-owned and may be deleted separately if no longer needed.

## Lifecycle automation

With the pi extension installed, session checks and project-state refreshes are triggered automatically. Without the extension, run `.src/scripts/maintain-project-state.sh` manually after changing Pensieve user data.

## Routing rules

- Ask "How do I install/reinstall Pensieve":
  Read this file first, then direct to `init`
- Ask "How do I update Pensieve":
  Read this file first, then direct to `upgrade`
- Ask "How do I clean up old structures/old graph":
  Read this file first, then direct to `migrate`
- Ask "How do I verify everything is working after installation":
  Read this file first, then direct to `doctor`
