# Tool Boundaries

| Tool | Responsible for | Not responsible for |
|---|---|---|
| `init` | Initialize the project `.pensieve/` directory, seed default content, and produce first-round exploration input | Does not write business conclusions directly |
| `upgrade` | Update the installed Pensieve pi package | Does not migrate structure or emit PASS/FAIL |
| `migrate` | Migrate legacy data, align directory structure, and align critical files | Does not update versions or emit PASS/FAIL |
| `doctor` | Run structural and format health checks, then emit a fixed report | Does not modify business code |
| `self-improve` | Create new entries under `short-term/` and update existing files in place | Does not replace init/migrate/doctor |
| `refine` | Refine the knowledge base through triage review and compression | New entries produced by compression go through short-term |
| `sync-instructions` | Write existing pipeline short routes into `AGENTS.md` | Does not generate project summaries, inline full pipelines, or replace `.pensieve/` |

## Common redirects

| User request | Correct tool |
|---|---|
| "How do I install/reinstall Pensieve?" | Read `.src/references/skill-lifecycle.md` first, then run `init` |
| "Upgrade Pensieve" | `upgrade` |
| "How do I update Pensieve?" | Read `.src/references/skill-lifecycle.md` first, then run `upgrade` |
| "Migrate to v2 / clean legacy paths" | `migrate` |
| "Check whether the data has issues" | `doctor` |
| "Capture this experience" | `self-improve` |
| "Organize/deduplicate/compress/refine knowledge" | `refine` |
| "Write pipelines into AGENTS.md" | `sync-instructions` |
