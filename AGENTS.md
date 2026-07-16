# AGENTS.md

## Project Purpose

Design, build, and maintain **Color Selection – True Level Compatibility Fix**, Austin's independent Darktide compatibility mod for **Color Selection (AKA Player Slot Color Picker)** and **True Level**. It should preserve True Level's character-level and Havoc-rank colors when Color Selection is active, without replacing or redistributing either dependency mod's files.

## Technical Source of Truth

The coding project is the technical source of truth. Keep canonical behavior, setup, validation, and maintenance details in repository documentation rather than the Obsidian project.

## Current Workspace

- Language: Lua
- Framework: Darktide Mod Loader (DML) and Darktide Mod Framework (DMF)
- `color_selection_true_level_fix/`: version-one implementation, offline tests, package documentation, and stable DMF mod identifier
- `reference/legacy-customized-2.6/`: preserved customized Color Selection 2.6 snapshot
- `reference/newer-2.14-with-nameplate-fixes/`: preserved Color Selection 2.14 snapshot with Austin's tested nameplate fixes
- `docs/research/`: project-specific comparison and compatibility research
- `docs/reference/`: general framework and maintenance guidance
- `docs/history/`: historical source material
- `docs/adr/`: accepted architectural decisions
- `CONTEXT.md`: canonical domain terminology

## Commands

- Build: Not established
- Test: `luajit color_selection_true_level_fix/tests/run.lua`
- Lint: Not established
- Format: Not established
- Run: Install through the normal DML/DMF workflow; in-game behavior requires validation in Austin's Windows Darktide/DMF environment

Do not invent commands or claim runtime validation from static inspection.

## Constraints

- Preserve both historical source snapshots unless Austin explicitly authorizes replacing or removing one.
- Treat everything under `reference/` as read-only evidence. New implementation belongs under `color_selection_true_level_fix/`.
- Do not copy or redistribute upstream implementation or assets into the Companion Mod without explicit permission and a documented license basis.
- Prefer stable DMF hooks, explicit cross-mod APIs, and narrow compatibility seams. Treat game internals and private upstream/DMF APIs as patch-sensitive.
- Do not assume the Companion Mod will survive every upstream release. Detect incompatible upstream changes where feasible and document the validation required after updates.
- Update canonical repository documentation before producing a handoff when technical behavior or procedures change.
- Do not edit `.hermes/project.yaml`, existing handoffs, or the Obsidian vault.

## Definition of Done

- The requested behavior or analysis is complete in the intended compatibility-mod or documentation location.
- Relevant static checks are performed and real results are reported.
- Compatibility assumptions and supported upstream behavior are explicit.
- Any required in-game validation is clearly identified and not represented as complete unless actually exercised.
- Repository documentation is updated when behavior, setup, or maintenance guidance changes.
- After meaningful implementation, debugging, research, or review work, invoke `$hermes-handoff`. Skip handoffs for trivial inspection, ordinary questions, and no-change work.
