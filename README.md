# Color Selection – True Level Compatibility Fix

## Purpose

**Color Selection – True Level Compatibility Fix** is an independently maintained Darktide mod that preserves True Level's character-level and Havoc-rank colors when **Color Selection (AKA Player Slot Color Picker)** is also active. It integrates without replacing the distributed files of either Dependency Mod.

The version-one implementation and its full behavior contract live under `color_selection_true_level_fix/`. Offline checks exercise the shipped pure splice and game-facing adapter; they do not establish in-game compatibility.

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
- Offline test: `luajit color_selection_true_level_fix/tests/run.lua`
- Build, lint, and format commands: not established
- Runtime validation: see the first exact [Validated Version Combination](color_selection_true_level_fix/VALIDATION.md)

The reference snapshots are unchanged evidence, not working copies. The first exact environment-scoped Validated Version Combination is recorded in [`color_selection_true_level_fix/VALIDATION.md`](color_selection_true_level_fix/VALIDATION.md); other combinations remain unvalidated until separately recorded.
