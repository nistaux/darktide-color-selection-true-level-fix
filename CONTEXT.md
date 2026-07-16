# Color Selection – True Level Compatibility Fix

This context defines the language used while developing Austin's compatibility fix for Color Selection and True Level and preserving the evidence that led to it.

## Language

**Color Selection – True Level Compatibility Fix**:
The user-facing product that narrowly preserves True Level's character-level and Havoc-rank colors when Color Selection is active. It does not replace or recreate Color Selection's settings, color-selection logic, or broader behavior.
_Avoid_: Companion Mod, patch mod, Color Picker fix, Color Selection replacement

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

**Visual Ownership**:
Responsibility for the final color and inline formatting of a particular nameplate element when both Dependency Mods are active. Color Selection owns the class icon and exact player-name segment; True Level owns the suffix beginning immediately after that segment, including character-level, Havoc-rank, and later inline formatting.
_Avoid_: Color precedence, hook ownership

**Safe No-Change**:
Leaving a candidate nameplate unchanged because an unexpectedly unreadable condition or unsafe required formatting structure prevents a confident Color-Boundary Splice. Expected inactivity, normal lifecycle skips, and Already Compatible are separate outcomes and do not produce a Safe No-Change diagnostic.
_Avoid_: Best-effort recoloring, fallback recoloring

**Already Compatible**:
The outcome when the expected color reset is already positioned immediately after the exact player-name segment. The Composed Nameplate remains unchanged and no Compatibility Diagnostic is emitted because no compatibility failure occurred.
_Avoid_: Safe No-Change, successful splice, duplicate reset

**Composed Nameplate**:
The complete visible nameplate text after the game and active mods have contributed the class icon, player name, character level, Havoc rank, title, and inline formatting.
_Avoid_: Header text, raw player name

**Color-Boundary Splice**:
The narrow post-processing operation that reuses Color Selection's already-applied leading color, ends that color immediately after the exact player-name segment, and preserves the later True Level-owned suffix unchanged. It does not select a color or recreate either Dependency Mod's formatting behavior.
_Avoid_: Recoloring, color selection, suffix rebuilding

**Rich Suffix Snapshot**:
A marker-scoped, weak-keyed cache entry containing the exact True Level-owned suffix most recently observed with an exact RGB color tag on its first line, together with the exact profile name and current player-record identity that produced it. It exists only to restore formatting that Color Selection removes on a later frame; it is cleared when either identity guard changes, visible suffix content changes, the Activation Condition is not true, or a new World Visit begins.
_Avoid_: Rebuilt suffix, level cache, player identity

**Visible Suffix Match**:
The safety condition for restoring a Rich Suffix Snapshot. The cached and current suffixes must become byte-identical after exact RGB color and reset tags are removed from their first lines; the newline and all later lines must already match exactly. This comparison ignores formatting only and never authorizes restoring changed visible text.
_Avoid_: Approximate match, normalized suffix, title match

**Activation Condition**:
The state in which both Dependency Mods are enabled and True Level's nameplate feature is enabled. A clearly false condition produces silent expected inactivity. An unexpectedly unreadable condition causes Safe No-Change. Outside the condition, the compatibility fix is inert.
_Avoid_: Mod installed, dependencies present

**Supported Surface**:
For version one, player world nameplates in missions and the Mourningstar. Team HUD panels and other views are unverified and outside this scope, without implying that they are broken or compatible.
_Avoid_: All True Level views, every player-name display

**Validated Version Combination**:
An exact tuple of installed versions of Color Selection – True Level Compatibility Fix, Color Selection, and True Level for which the prescribed static review and in-game validation have passed in a recorded exact Darktide, DML, and DMF environment. Other combinations or environments may run but are not included in that validation claim.
_Avoid_: Supported version, compatible version

**Compatibility Diagnostic**:
A default-log-only record of a Safe No-Change cause. The first occurrence of every recognized, coded cause emits one record during a World Visit; later occurrences of that cause are suppressed until the next World Visit. A distinct cause is identified solely by its Diagnostic Reason Code; differences in structural metadata or Supported Surface location do not create additional causes. The record contains only non-identifying structural metadata alongside that code; it omits the raw Composed Nameplate, player names, account IDs, and other identifying values. It is not deliberately sent to chat or shown as a notification. Expected inactivity is silent.
_Avoid_: Player warning, repeated error message

**World Visit**:
One continuous stay in a loaded world, ending at the next world transition. Entering a mission or the Mourningstar begins a new World Visit, including when returning to a surface visited earlier during the same launched game.
_Avoid_: Game session, process lifetime, surface category

**Diagnostic Reason Code**:
A stable symbolic label for a condition directly observed by the compatibility fix when it uses Safe No-Change, without attributing fault to a Dependency Mod. Codes distinguish conditions only when they lead to materially different maintenance checks; minor variants with the same next action share a code. Once published, a code retains the same meaning across releases; a newly distinguished condition receives a new code.
_Avoid_: Error message, blame label, repurposed code

**Diagnostic Metadata**:
Non-identifying structural facts explicitly approved to accompany a particular Diagnostic Reason Code. Each code has its own allowlist of relevant fields; available runtime context is never included automatically. Structural classifications use a fixed, documented, human-readable vocabulary rather than generated signatures or serialized structures. Raw exception text and stack traces are excluded; unexpected processing failures may identify only an allowlisted fixed stage. Hashes, fingerprints, and other values derived from identifying text remain identifying values and are excluded.
_Avoid_: Context dump, raw runtime object, identifying value

**Legacy Customized Snapshot**:
The preserved Color Selection 2.6 copy containing Austin's earlier custom behavior and fixes; it is evidence for the Companion Mod, not the product being maintained.
_Avoid_: Old mod, TheFuckening

**Reference Snapshot**:
A preserved source copy used as evidence when studying behavior and compatibility; it is never the Companion Mod's working implementation.
_Avoid_: Working copy, vendored dependency

**Newer Patched Snapshot**:
The preserved Color Selection 2.14 copy containing Austin's two tested nameplate fixes. It descends from a creator-maintained release but is not an unmodified Color Selection release.
_Avoid_: Upstream reference, current upstream, working copy
