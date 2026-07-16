# Color Selection customized 2.6 vs. patched 2.14 snapshot

> **Historical scope:** This report was written before the decision to build an independent Companion Mod. Its merge language is retained as evidence of the earlier maintenance approach; use its behavioral findings to identify companion requirements and compatibility risks, not as authorization to edit or redistribute the Upstream Mod.

## Purpose and comparison direction

This report compares these two complete mod folders:

- **Older customized copy (`OLD_CUSTOM`)**: `reference/legacy-customized-2.6/`
  - `meta.ini:4` reports installed version `2.6.0.0`.
- **Newer patched copy (`NEWER_PATCHED`)**: `reference/newer-2.14-with-nameplate-fixes/`
  - `meta.ini:4` reports installed version `2.14.0.0`.

The comparison direction throughout this document is **OLD_CUSTOM 2.6 -> NEWER_PATCHED 2.14**.

**Current working-copy status (2026-07-14):** The newer 2.14 working copy now includes the two narrow nameplate fixes identified in this comparison: it removes only a leading name-part color tag and searches for the raw `player_name` with `plain = true`. It retains 2.14's separate cleanup of formatting embedded in `player_name`. Austin subsequently confirmed that this implementation works in game. Descriptions below of the unanchored cleanup and escaped literal search refer to the original upstream 2.14 baseline, not the now-modified working copy. When adopting a later upstream release, recheck this nameplate path and reapply both fixes if upstream still uses the unanchored cleanup or escapes a name before a plain-string search.

> **Evidence boundary:** The folder names, version metadata, and code differences are verified. The repository does not provide a common source-control ancestor or upstream changelog. [`docs/history/nameplate-fix-message.txt`](../history/nameplate-fix-message.txt) supplies a first-person explanation of the nameplate problems and proposed fixes; this report therefore treats that message as evidence of the user's reasoning and, as requested, assumes that the matching customized code is the resulting user-authored change. Other descriptions of *why* code changed remain explicitly labeled as inferred intent.

## Scope and high-level result

Both folders contain the same eight relative file paths; 2.14 adds no new files and removes no files. A read-only `git diff --no-index` reported six changed files with 656 insertions and 649 deletions.

### Byte-identical files

- `ColorSelection/ColorSelection.mod`
- `ColorSelection/scripts/mods/ColorSelection/color_presets.lua`

### Changed files

- `meta.ini`
- `ColorSelection/scripts/mods/ColorSelection/ColorSelection.lua`
- `ColorSelection/scripts/mods/ColorSelection/ColorSelection_data.lua`
- `ColorSelection/scripts/mods/ColorSelection/ColorSelection_localization.lua`
- `ColorSelection/scripts/mods/ColorSelection/views/color_customizer_view/color_customizer_view.lua`
- `ColorSelection/scripts/mods/ColorSelection/views/color_customizer_view/color_customizer_view_definitions.lua`

## Verified additions and changes in 2.14

Paths and line references in this section are relative to `NEWER_PATCHED` unless otherwise stated.

### 1. Class-based player colors

2.14 adds independently configurable colors for these archetype identifiers:

- `veteran`
- `zealot`
- `psyker`
- `ogryn`
- `broker` (Hive Scum)
- `adamant` (Arbites)
- `cryptic` (Skitarii)

Verified implementation points:

- Default RGB values and generated DMF widgets: `ColorSelection_data.lua:45-80` and `:133-136`.
- Defaults exposed through `mod.get_default_color_value`: `ColorSelection.lua:73-79`.
- Player archetype lookup: `ColorSelection.lua:242-252`.
- `color_by_class` selection after per-account overrides but before slot fallback: `ColorSelection.lua:271-314`.
- Localized class names/defaults: `ColorSelection_localization.lua:243-249`, `:344-389`, and `:410-422`.
- Seven class buttons in the customizer layout: `color_customizer_view_definitions.lua:114-170` and widget definitions beginning at `:1141`.
- Class-button callbacks and swatch updates: `color_customizer_view.lua:213-219` and `:977-1012`.
- Apply, reset, reset-all, load, and notification paths accept string class identifiers: `color_customizer_view.lua:1176-1181`, `:1231-1240`, `:1434-1457`, `:1572-1590`, `:1609-1614`, and `:1680-1712`.

**Verified precedence:** The local player is resolved first, saved per-account colors are checked before class colors, and class colors are checked before slot colors (`ColorSelection.lua:254-337`).

### 2. New settings and tabbed DMF layout

2.14 adds these settings:

- `color_by_class`, default `false`: `ColorSelection_data.lua:103-108`.
- `color_outlines`, default `true`: `ColorSelection_data.lua:110-115`.
- `color_bots`, default `true`: `ColorSelection_data.lua:117-122`.

Settings are grouped into DMF tabs:

- `Colors`: `ColorSelection_data.lua:20` and `:142`.
- `Class Colors`: `ColorSelection_data.lua:62`.
- `General`: `ColorSelection_data.lua:90`.
- `Debug`: `ColorSelection_data.lua:169`.

The corresponding English localization is at `ColorSelection_localization.lua:10-34` and `:130-139`.

### 3. Player-outline recoloring

2.14 can recolor already-rendered player outlines:

- Reset helper restores the material color to the game's pale-green outline value: `ColorSelection.lua:1409-1426`.
- `OutlineSystem.update` hook applies the selected player color: `ColorSelection.lua:1428-1457`.
- Disabling the mod resets outlines: `ColorSelection.lua:1459-1466`.
- Turning only the outline option off also resets outlines: `ColorSelection.lua:1671-1674`.
- `CareerColourOutlines` conflict warning: `ColorSelection.lua:1546-1549`.
- The tooltip states that a mod such as PlayerOutlines is needed to force outlines to render: `ColorSelection_localization.lua:21-26`.

**Inferred intent:** This feature is meant to color the holographic silhouettes visible through walls without taking responsibility for making those silhouettes visible.

### 4. Bot-color toggle

- Bot settings are now conditional on `color_bots`: `ColorSelection.lua:194-203` and `:265-269`.
- The setting-change handler refreshes colors when the toggle changes: `ColorSelection.lua:1645-1668`.

The localization promises that disabling this setting makes bots use the default game color (`ColorSelection_localization.lua:132-139`). See the potential-regression section below because the runtime fallthrough does not clearly guarantee that behavior.

### 5. Simplified slot-color resolution and SlotFix expectation

2.14 removes the custom allocator and resolves colors with `get_slot_color` and `get_color_for_account_id`:

- Local-slot lookup and direct slot selection: `ColorSelection.lua:180-215`.
- Account/custom/class/slot resolution: `ColorSelection.lua:254-337`.
- The local account always receives configured `slot1` color: `ColorSelection.lua:259-263`.
- If the local player's engine slot is not 1, the real slot-1 player receives the local player's original engine-slot color: `ColorSelection.lua:205-211`.
- Missing `SlotFix` produces a warning after all mods load: `ColorSelection.lua:1610-1613`.

`ColorSelection.mod` remains byte-identical and does **not** declare SlotFix as a dependency.

**Inferred intent:** 2.14 expects SlotFix to stabilize the game's slot assignments, allowing Color Selection to remove its own complex slot remapper.

### 6. In-place update of the shared slot-color table

Instead of always replacing `UISettings.player_slot_colors` with a new table, 2.14 clears and repopulates the current table before attaching its metatable:

- Metatable fallback: `ColorSelection.lua:1277-1291`.
- In-place clear and explicit population of indices 1 through 5: `ColorSelection.lua:1293-1314`.

**Inferred intent:** Preserving the table object is likely a compatibility fix for game code or other mods that retain a reference to the original table.

### 7. Refresh and compatibility fixes

- Player colors are reapplied on player unit spawn/respawn through `GameModeManager.on_player_unit_spawn`: `ColorSelection.lua:1601-1608`.
- Chat participant hook now returns safely when the original display name is nil: `ColorSelection.lua:867-872`.
- Color tags are stripped from `player_name` before nameplate matching in case another hook returned formatted text: `ColorSelection.lua:698-699`. This is a 2.14 addition. In the original baseline it did not compensate for the separate name-part cleanup and plain-string matching regressions described below; the preserved patched snapshot now also contains those two fixes.
- The TrueLevel-related panel flag is actively cleared rather than left commented out: `ColorSelection.lua:1190`.
- The player grid is no longer rebuilt every update tick. Event-driven calls remain at `color_customizer_view.lua:77`, `:1343`, `:1420`, `:1543`, `:1660`, and `:1716`.
- Stray `polo`, `marco`, `test`, and per-row debug echoes were removed from the player-list code near `color_customizer_view.lua:1730-1840`.

**Inferred intent:** These changes reduce redundant work, remove log noise, and improve cooperation with text-formatting mods.

### 8. Shooting-range context behavior changed

The old function treated `shooting_range` and `training_grounds` as non-mission contexts. The new function records those modes and deliberately skips the onboarding/mechanism fallback, ultimately treating them like mission contexts:

- New behavior: `ColorSelection.lua:217-240`.
- Old behavior: `OLD_CUSTOM/ColorSelection/scripts/mods/ColorSelection/ColorSelection.lua:270-295`.

**Inferred intent:** Slot/class coloring is now intended to be testable or visible in the shooting range.

## Verified TheFuckening-only work absent from the original 2.14 baseline

Paths in this section are relative to `OLD_CUSTOM` unless labeled otherwise.

### 1. Custom `ColorAllocator`

The largest custom subsystem is absent from 2.14:

- Allocator state, reset, and setup: `ColorSelection.lua:179-268`.
- `ColorAllocator:color_for`: `ColorSelection.lua:297-416`.
- Stable `player_to_slot_mapping`, account-ID mapping, bot-ID tracking, and index reservation: `ColorSelection.lua:179-195`.
- Mission resolution through the allocator: `ColorSelection.lua:418-485`.
- Player-removal cleanup: `ColorSelection.lua:488-506`.
- Full player discovery, mapping cleanup, local slot-1 reservation, remote allocation to 2-4, hash fallback, and diagnostic logging: `ColorSelection.lua:1414-1651`.
- Allocator-backed `UISettings.player_slot_colors`: `ColorSelection.lua:1653-1689`.
- Allocator reset after load/settings changes: `ColorSelection.lua:1863` and `:1987`.

Verified behavior in the old custom code:

- The local player reserves configured color index 1.
- Remote human players are assigned available color indices 2 through 4.
- Assignments persist in `player_to_slot_mapping` while players remain present.
- Departed players free their assignments.
- When no unique remote index remains, a deterministic account/unique-ID byte-sum selects index 2 through 4.
- `account_id_color_map` can override mission slot allocation.

**Inferred intent:** This is the user's earlier fix for unstable engine slots, duplicate colors, or remote players receiving the local player's color. It is the highest-risk functionality to lose during an update.

### 2. Dynamic DMF preset dropdowns

TheFuckening builds a deduplicated, alphabetized option list from `Color.list` and exposes dropdowns for each slot and bots:

- Dynamic option construction and deduplication: `ColorSelection_data.lua:3-29`.
- Slot dropdowns: `ColorSelection_data.lua:49-58`.
- Bot dropdown: `ColorSelection_data.lua:103-112`.
- Runtime `Color.list` preset table: `ColorSelection.lua:21-27`.
- Preset-to-RGB setting handler: `ColorSelection.lua:1933-1983`.

These DMF dropdowns and their handler are absent from 2.14.

**Important verified nuance:** Presets were not removed wholesale. `color_presets.lua` is byte-identical, and both versions still load it at `color_customizer_view.lua:11` and use the customizer preset grid. Only the additional DMF dropdown workflow disappeared.

### 3. Hub guard in slot-table application

The old `apply_slot_colors_internal` exits immediately in the hub at `ColorSelection.lua:1417-1420`. That explicit guard is absent in 2.14, although the account-resolution function still returns nil for non-custom remote players in non-mission contexts.

**Inferred intent:** The newer implementation centralizes hub behavior in `get_color_for_account_id` instead of skipping the entire shared-table update.

### 4. Nameplate formatting and literal-name matching fixes

TheFuckening contains two targeted nameplate behaviors that were absent from the original 2.14 code reviewed for this comparison. Austin's preserved `newer-2.14-with-nameplate-fixes` snapshot now contains both corrections, so the paths below describe the historical contrast rather than the current contents of that patched snapshot:

- It removes a `{#color(...)}` tag from `name_part` only when that tag is at the start of the string, using `^` in the pattern at `ColorSelection.lua:870`. The original 2.14 baseline used an unanchored expression and therefore removed every matching color tag in the first line; the preserved patched snapshot now uses the anchored form at `NEWER_PATCHED/ColorSelection/scripts/mods/ColorSelection/ColorSelection.lua:710`. Both preserved versions separately split and reattach `title_part`, so title formatting after the newline remains intact while the anchored cleanup protects later inline tags in the name/level line.
- It locates the player with `clean_name_part:find(player_name, 1, true)` at `ColorSelection.lua:875`. Because `plain = true` disables Lua-pattern interpretation, the raw `player_name` is the correct literal search text. TheFuckening still computes `escaped_name` at `:860`, with a character class that no longer contains `-`, but that variable is unused by this nameplate path.

**Assumed historical intent, supported by [`docs/history/nameplate-fix-message.txt`](../history/nameplate-fix-message.txt):** The leading tag belongs to the color that this mod may replace for the class icon/name. Anchoring its removal preserves later inline formatting, including the colored level text supplied by True Level, rather than flattening every color tag on the nameplate's first line. The message also identifies the mismatch created by escaping pattern characters and then asking `find` to perform a plain-string search: for example, 2.14 transforms `Haken-Veil` into `Haken%-Veil`, then searches literally for the inserted `%`, so `name_start` is nil and the recoloring block is skipped. Searching for raw `player_name` in plain mode resolves the whole class of names containing Lua pattern characters; merely removing `-` from the escape class would address the hyphen example but leave the same defect for `.`, `(`, `)`, `%`, and the other escaped characters.

## Behavioral comparison relevant to a merge

| Area | TheFuckening 2.6 | Upstream 2.14 | Merge implication |
|---|---|---|---|
| Local player | Explicitly reserves allocator index 1 | Local account directly returns `slot1` | Preserve the direct local-account check; decide whether allocator reservation is still needed with SlotFix. |
| Remote slot colors | Stable custom mapping to indices 2-4 | Primarily uses engine slot, with a local-slot swap | Reintroducing the allocator wholesale will collide with class and bot resolution. |
| Saved account colors | Checked before ordinary mission slot colors | Checked before class and slot colors | Preserve this precedence. |
| Class colors | Not present | Optional, seven archetypes | Allocator must not bypass class-color selection. |
| Bots | Always custom gray/bot color in allocator paths | Optional toggle | Any allocator port needs an explicit disabled-bot result, not unconditional bot color. |
| Hub | Remote players normally retain game defaults unless custom | Same broad policy, implemented differently | Do not restore the old top-level hub return without checking class/custom UI consumers. |
| Shooting range | Treated as non-mission | Treated as mission-like | Choose desired behavior explicitly. |
| Shared UI color table | Replaced with a new allocator-backed table | Existing table is cleared/reused | Preserve 2.14's table identity unless testing proves it unnecessary. |
| Presets | Customizer grid plus DMF dropdowns | Customizer grid only | Port only the dropdown UI/handler if still desired. |
| Outlines | Not present | Optional outline recoloring | Ensure the selected color comes from the final merged precedence function. |
| Nameplate formatting | Removes only a leading name-part color tag and uses raw `player_name` for a plain search | Original 2.14 removed all name-part color tags and searched for a pattern-escaped name as literal text; the preserved patched snapshot now uses the corrected forms | Preserve the anchored cleanup and raw-name/plain-search pairing; retain 2.14's separate cleanup of color tags returned inside `player_name`. |

## Likely merge-conflict hotspots

These are verified overlapping code regions where a direct copy is unsafe:

1. **Color resolution core**
   - Old allocator: `OLD_CUSTOM/.../ColorSelection.lua:179-485`.
   - New resolver/class/bot logic: `NEWER_PATCHED/.../ColorSelection.lua:180-337`.
   - A merge must define one authoritative precedence chain.

2. **Player removal and cache lifecycle**
   - Old allocator frees indices at `OLD_CUSTOM/.../ColorSelection.lua:488-506`.
   - New code only clears per-player custom cache at `NEWER_PATCHED/.../ColorSelection.lua:339-346`.

3. **`apply_slot_colors_internal`**
   - Old discovery/remapping block: `OLD_CUSTOM/.../ColorSelection.lua:1414-1651`.
   - New in-place shared-table population: `NEWER_PATCHED/.../ColorSelection.lua:1260-1314`.
   - Retain 2.14 table reuse while feeding it merged color results.

4. **Settings handler**
   - Old preset and allocator-reset logic: `OLD_CUSTOM/.../ColorSelection.lua:1933-1993`.
   - New class/bot/outline update triggers: `NEWER_PATCHED/.../ColorSelection.lua:1645-1675`.

5. **DMF widget schema**
   - Old dropdown generation: `OLD_CUSTOM/.../ColorSelection_data.lua:3-58`, `:103-112`.
   - New tabs, toggles, and class groups: `NEWER_PATCHED/.../ColorSelection_data.lua:14-174`.
   - Port the dropdown sub-widgets into the appropriate 2.14 tabs rather than replacing the new widget table.

6. **Customizer layout**
   - New class-button row shifts all controls below it by 40 pixels: `NEWER_PATCHED/.../color_customizer_view_definitions.lua:114-233`.
   - Preserve these offsets if modifying the customizer.

7. **Nameplate text processing**
   - Old formatting-preserving cleanup and literal search: `OLD_CUSTOM/.../ColorSelection.lua:860-875`.
   - New colored-`player_name` cleanup plus the corrected name-part/search expressions: `NEWER_PATCHED/.../ColorSelection.lua:698-717`.
   - The preserved patched snapshot keeps 2.14's cleanup of formatting embedded in `player_name` and now uses the anchored leading-tag removal and raw-name plain search.

## Potential regressions and bugs requiring runtime validation

These are code-review findings, not confirmed in-game failures.

### 1. Disabling bot colors may still produce slot/class colors

When an account ID is missing and `color_bots` is false, `get_color_for_account_id` does not return a sentinel meaning "leave the game default untouched." It continues, can find a bot by slot, can apply a class color, and finally calls `get_slot_color(slot, is_local, false)`:

- `ColorSelection.lua:194-215`
- `ColorSelection.lua:265-336`

This appears inconsistent with `color_bots_tooltip`, which promises the default game color. Test with `color_bots = false` in missions, hub, and shooting range.

### 2. Original 2.14 regressed TheFuckening's nameplate fixes; the preserved patched snapshot corrects them

Two verified expression changes in the original 2.14 source could break formatting or recoloring. The preserved `newer-2.14-with-nameplate-fixes` snapshot has already replaced both expressions with the corrected anchored and raw-literal forms:

- The original 2.14 baseline used an unanchored color-tag pattern on `name_part`, which could remove later inline color tags on the first line, including True Level's level color. The preserved patched snapshot now uses the anchored expression at `ColorSelection.lua:710`, matching the behavior at `OLD_CUSTOM/ColorSelection/scripts/mods/ColorSelection/ColorSelection.lua:870`.
- The original 2.14 baseline inserted `%` escapes into Lua pattern characters in `player_name`, then passed that transformed text to `find(..., true)`. Plain mode made those inserted percent signs literal. The preserved patched snapshot now searches raw `player_name` at `ColorSelection.lua:715`, matching the internally consistent pairing at `OLD_CUSTOM/.../ColorSelection.lua:875`.

These historical code-review findings are supported by the user's contemporaneous reasoning. Austin has already tested the two fixes in the preserved patched snapshot, but the new independent compatibility seam still requires its own validation with current True Level and game nameplates. Keep 2.14's separate stripping of tags embedded in `player_name` at `:698-699` together with the corrected anchored cleanup and raw literal search. TheFuckening's `escaped_name` declaration at old line 860 is dead code in this path.

### 3. SlotFix is runtime-required but undeclared

2.14 warns that SlotFix is required (`ColorSelection.lua:1610-1613`), but the identical `ColorSelection.mod` lists only optional `true_level` and `who_are_you` dependencies. Load order and user installation are therefore not enforced.

### 4. Outline reset uses a hard-coded color

`reset_character_outlines` restores `Vector3(163/255, 255/255, 185/255)` at `ColorSelection.lua:1416`. Confirm that this remains the correct game/default outline color across classes, states, and other outline mods.

### 5. Allocator removal may reintroduce the original slot issue

This is an inferred risk based on the size and behavior of TheFuckening's custom allocator. Test joins, leaves, reconnects, bots replacing players, local engine slot not equal to 1, and late spawns before deciding that SlotFix fully supersedes the custom logic.

## Suggested merge checklist

### Preparation

- [ ] Preserve untouched copies of both folders.
- [ ] Treat 2.14 as the merge base so its new class, outline, bot, tab, refresh, and compatibility work remains intact.
- [ ] Record the exact original problem TheFuckening fixed before porting the allocator; its intent cannot be proven from the code alone.
- [ ] Verify the installed SlotFix version and document what slot guarantees it provides.

### Core color-resolution design

- [ ] Write down the desired precedence. Recommended starting point: local player -> saved account color -> bot policy -> optional class color -> stable slot color -> no override.
- [ ] Decide whether SlotFix makes `ColorAllocator` unnecessary.
- [ ] If stable remapping is still required, port only the mapping state/lifecycle into 2.14's resolver rather than replacing `get_color_for_account_id` wholesale.
- [ ] Keep local-player detection account-ID-based.
- [ ] Keep saved account colors above class and slot colors.
- [ ] Ensure `color_by_class` works for all seven 2.14 archetypes.
- [ ] Make `color_bots = false` return an explicit "do not override" result.
- [ ] Decide and document whether shooting range should use mission colors.

### Shared UI state and hooks

- [ ] Preserve 2.14's in-place `UISettings.player_slot_colors` update.
- [ ] Ensure player removal frees any merged allocator mapping.
- [ ] Ensure spawn/respawn refresh remains installed.
- [ ] Ensure outline, chat, nameplate, HUD panel, world-marker, and social-popup hooks all consume the same final resolver.
- [x] Restore the anchored leading-tag cleanup and raw-`player_name` plain search in the nameplate path while retaining 2.14's cleanup of formatted `player_name` values.
- [ ] Preserve the TrueLevel/WhoAreYou load-order entries in `ColorSelection.mod`.
- [ ] Decide whether SlotFix should become a formal dependency or remain a runtime warning.

### Settings and customizer

- [ ] Preserve the four 2.14 DMF tabs and all three new toggles.
- [ ] Preserve the seven class settings and class buttons.
- [ ] If desired, port TheFuckening's DMF preset dropdowns into the `Colors` tab.
- [ ] Keep the existing categorized customizer preset grid; do not duplicate or replace `color_presets.lua`.
- [ ] Merge both old preset triggers and new class/bot/outline triggers in `mod.on_setting_changed`.
- [ ] Preserve the 2.14 customizer layout offsets and class swatches.

### Targeted validation matrix

- [ ] Local player in engine slots 1, 2, 3, and 4.
- [ ] Three remote humans joining in different orders.
- [ ] Remote leave, replacement, reconnect, and late join.
- [ ] Bot-only team, bot-to-human replacement, and `color_bots` both on and off.
- [ ] `color_by_class` on and off for every supported archetype.
- [ ] Saved account color overriding class and slot colors.
- [ ] Hub, mission, shooting range, loading transitions, death/respawn, and reconnect.
- [ ] HUD panels, nameplates, chat, world markers, social popup, and outlines.
- [ ] Player names containing hyphens and each Lua pattern character escaped by 2.14 (`(`, `)`, `.`, `%`, `+`, `-`, `*`, `?`, `[`, `]`, `^`, and `$`).
- [ ] Nameplates with a leading Color Selection tag, later inline level tags, and a separately colored title after the newline; confirm only the leading name-part tag is replaced, title formatting remains intact, and True Level colors survive in the hub.
- [ ] TrueLevel, WhoAreYou, PlayerOutlines, CareerColourOutlines, and SlotFix compatibility.
- [ ] Settings changed mid-mission and between missions.
- [ ] Disable/re-enable the mod and confirm all game colors/outlines restore correctly.

## Bottom line

The 2.14 folder is not merely the old code plus small additions. It replaces the legacy custom slot-allocation architecture with a much simpler SlotFix-dependent resolver while adding class colors, outline coloring, a bot toggle, tabbed settings, new customizer controls, and several refresh/compatibility fixes. It also dropped the anchored nameplate tag cleanup and raw-name literal search found in the customized snapshot; those two fixes have since been applied to the preserved newer snapshot and confirmed in game by Austin. Under the current Companion Mod decision, the remaining behaviors must be evaluated as independent integrations rather than merged wholesale into Color Selection.
