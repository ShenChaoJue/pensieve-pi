---
name: pensieve
description: >-
  Project knowledge base and workflow router. knowledge/ caches explored file
  locations, module boundaries, and call chains for reuse; decisions/maxims are
  established architecture decisions and coding standards to follow, not
  relitigate; pipelines are reusable workflows; short-term/ stages new
  conclusions until promotion or deletion. Use self-improve after completing
  work to capture new insights. Provides seven tools: init, upgrade, migrate,
  doctor, self-improve, refine, and sync-instructions.
---

# Pensieve

Route user requests to the correct tool. When in doubt, confirm first.

## Routing
- Init: Initialize the current project user-data directory and seed files. Tool spec: `.src/tools/init.md`.
- Upgrade: Update the installed Pensieve pi package. Tool spec: `.src/tools/upgrade.md`.
- Migrate: Run structural migration and legacy cleanup. Tool spec: `.src/tools/migrate.md`.
- Doctor: Read-only scan of the current project user-data directory. Tool spec: `.src/tools/doctor.md`.
- Self-Improve: Extract reusable conclusions and write them into user data. Tool spec: `.src/tools/self-improve.md`.
- Refine: Refine the knowledge base with triage review and compression. Tool spec: `.src/tools/refine.md`.
- Sync Instructions: Write existing pipeline short routes into `AGENTS.md`. Tool spec: `.src/tools/sync-instructions.md`.
- Graph View: Read `<project-root>/.pensieve/.state/pensieve-user-data-graph.md`.

## Skill Root

The skill root is the directory containing this `SKILL.md`. Set `PENSIEVE_SKILL_ROOT` to that directory before running scripts referenced by the tool specs.

## Project Data
Project-level user data is stored in `<project-root>/.pensieve/`.
See `.pensieve/state.md` for the current project's lifecycle state; see `.pensieve/.state/pensieve-user-data-graph.md` for the knowledge graph (read on demand).
