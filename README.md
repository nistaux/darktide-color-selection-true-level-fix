# Color Selection – True Level Compatibility Fix

## Purpose

Design and build **Color Selection – True Level Compatibility Fix**, an independently maintained Darktide mod intended to preserve True Level's character-level and Havoc-rank colors when **Color Selection (AKA Player Slot Color Picker)** is also active. It must integrate without replacing the distributed files of either dependency mod.

The version-one design contract is settled in `color_selection_true_level_fix/README.md`. No implementation has been scaffolded yet, and implementation, LuaJIT provisioning, and in-game changes require a separate explicit request.

The initial Supported Surface is player world nameplates in missions and the Mourningstar. Team HUD panels and other views are outside version-one scope until separately researched and validated; this boundary does not claim that those views are either broken or compatible.

## Repository layout

- `color_selection_true_level_fix/`: implementation home and intended DMF mod identifier
- `reference/legacy-customized-2.6/`: preserved customized Color Selection 2.6 snapshot
- `reference/newer-2.14-with-nameplate-fixes/`: preserved Color Selection 2.14 snapshot containing Austin's two tested nameplate fixes
- `docs/research/`: project-specific investigation and comparison reports
- `docs/reference/`: general Darktide, DML, and DMF maintenance guidance
- `docs/history/`: contemporaneous notes retained as historical evidence
- `docs/adr/`: durable architectural decisions
- `CONTEXT.md`: canonical project terminology

See [`docs/README.md`](docs/README.md) for the documentation map and [`docs/adr/0001-build-an-independent-companion-mod.md`](docs/adr/0001-build-an-independent-companion-mod.md) for the decision that established this project direction.

## Development status

- Language: Lua
- Runtime: Darktide Mod Loader (DML) and Darktide Mod Framework (DMF)
- Build, test, lint, format, and run commands: not established
- Runtime validation: requires Austin's Windows Darktide/DMF environment

The reference snapshots are evidence, not working copies. Companion behavior and compatibility assumptions must be documented and statically checked here, then validated in game where required.
