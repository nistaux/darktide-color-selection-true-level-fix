# Color Selection Companion

## Purpose

Design and build Austin's independently maintained Darktide companion mod for **Color Selection (AKA Player Slot Color Picker)**. The companion should preserve selected custom behavior without replacing the upstream mod's distributed files.

The project is currently in design and compatibility research. No companion-mod implementation has been scaffolded yet.

## Repository layout

- `companion-mod/`: home of the new mod once its identity and integration boundary are settled
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
