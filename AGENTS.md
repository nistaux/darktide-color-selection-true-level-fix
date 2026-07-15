# AGENTS.md

## Project Purpose

Design, build, and maintain Austin's independent Darktide companion mod for **Color Selection (AKA Player Slot Color Picker)**. The companion should layer selected behavior onto the creator-maintained upstream mod without replacing or redistributing its files.

## Technical Source of Truth

The coding project is the technical source of truth. Keep canonical behavior, setup, validation, and maintenance details in repository documentation rather than the Obsidian project.

## Current Workspace

- Language: Lua
- Framework: Darktide Mod Loader (DML) and Darktide Mod Framework (DMF)
- `companion-mod/`: reserved for the new mod; do not invent its mod ID or scaffold until the design session settles them
- `reference/legacy-customized-2.6/`: preserved customized Color Selection 2.6 snapshot
- `reference/newer-2.14-with-nameplate-fixes/`: preserved Color Selection 2.14 snapshot with Austin's tested nameplate fixes
- `docs/research/`: project-specific comparison and compatibility research
- `docs/reference/`: general framework and maintenance guidance
- `docs/history/`: historical source material
- `docs/adr/`: accepted architectural decisions
- `CONTEXT.md`: canonical domain terminology

## Commands

- Build: Not established
- Test: Not established
- Lint: Not established
- Format: Not established
- Run: Not established; in-game behavior requires validation in Austin's Windows Darktide/DMF environment

Do not invent commands or claim runtime validation from static inspection.

## Constraints

- Preserve both historical source snapshots unless Austin explicitly authorizes replacing or removing one.
- Treat everything under `reference/` as read-only evidence. New implementation belongs under `companion-mod/`.
- Do not copy or redistribute upstream implementation or assets into the Companion Mod without explicit permission and a documented license basis.
- Prefer stable DMF hooks, explicit cross-mod APIs, and narrow compatibility seams. Treat game internals and private upstream/DMF APIs as patch-sensitive.
- Do not assume the Companion Mod will survive every upstream release. Detect incompatible upstream changes where feasible and document the validation required after updates.
- Update canonical repository documentation before producing a handoff when technical behavior or procedures change.
- Do not edit `.hermes/project.yaml`, existing handoffs, or the Obsidian vault.

## Definition of Done

- The requested behavior or analysis is complete in the intended companion-mod or documentation location.
- Relevant static checks are performed and real results are reported.
- Compatibility assumptions and supported upstream behavior are explicit.
- Any required in-game validation is clearly identified and not represented as complete unless actually exercised.
- Repository documentation is updated when behavior, setup, or maintenance guidance changes.
- After meaningful implementation, debugging, research, or review work, invoke `$hermes-handoff`. Skip handoffs for trivial inspection, ordinary questions, and no-change work.
