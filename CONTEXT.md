# Color Selection – True Level Compatibility Fix

This context defines the language used while developing Austin's compatibility fix for Color Selection and True Level and preserving the evidence that led to it.

## Language

**Color Selection – True Level Compatibility Fix**:
The user-facing product that preserves True Level's character-level and Havoc-rank colors when Color Selection is active.
_Avoid_: Companion Mod, patch mod, Color Picker fix

**Companion Mod**:
The architectural category of an independently maintained Darktide mod that changes or extends another mod without replacing its distributed files. This describes the product's relationship to its dependencies, not its public name.
_Avoid_: Patch mod, fork, customized upstream

**Color Selection**:
The creator-maintained Darktide mod that assigns and applies configurable player colors.
_Avoid_: Color Picker, upstream mod, base mod

**True Level**:
The independently maintained Darktide mod whose character-level and Havoc-rank color formatting must remain intact when Color Selection is active.
_Avoid_: Level mod, level colors

**Dependency Mod**:
Either Color Selection or True Level when discussing their shared relationship to the compatibility fix.
_Avoid_: Upstream Mod, original mod

**Legacy Customized Snapshot**:
The preserved Color Selection 2.6 copy containing Austin's earlier custom behavior and fixes; it is evidence for the Companion Mod, not the product being maintained.
_Avoid_: Old mod, TheFuckening

**Reference Snapshot**:
A preserved source copy used as evidence when studying behavior and compatibility; it is never the Companion Mod's working implementation.
_Avoid_: Working copy, vendored dependency

**Newer Patched Snapshot**:
The preserved Color Selection 2.14 copy containing Austin's two tested nameplate fixes. It descends from a creator-maintained release but is not an unmodified Color Selection release.
_Avoid_: Upstream reference, current upstream, working copy
