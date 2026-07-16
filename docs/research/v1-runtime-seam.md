# V1 runtime seam static and live revalidation

Initial static review date: 2026-07-15. Failed live observation: 2026-07-16. This record supports implementation issues #2–#7. It keeps the failed observation separate from the corrected implementation, which has offline coverage but has not yet been retested in game.

## Exact observed environment

- Darktide `1.12.0-b753204`, Steam build `24006134`, content revision `133319`
- DML `26.6.24.0`; DMF `26.6.24.0`
- Color Selection `2.15.0.0`, unmodified archive installation
- True Level `1.10.1.0`
- Color Selection – True Level Compatibility Fix manifest `1.0.0`
- LuaJIT `2.1.1779665312-1`

The failed run used `console-2026-07-16-00.28.58-65e5580c-321d-4c1d-a1f1-c576fc0f5f34.log`. True Level loaded as mod ID 9, the compatibility fix as ID 11, and Color Selection as ID 12. At log line 1556, the compatibility fix emitted `Compatibility Diagnostic: hook_target_unavailable (target_stage=class_table)`. `HudElementNameplates` became available at lines 2001–2005 about 4.4 seconds later; DMF then installed only Color Selection and True Level's delayed update hooks. The compatibility hook never registered. No relevant stack trace or compatibility-mod log spam occurred.

## Failed Mourningstar observation

Unhyphenated remote names lost True Level's character-level and Havoc-rank colors. Hyphenated names looked correct only because Color Selection 2.15's literal-search defect skipped its destructive rewrite. This is a failed validation observation. It establishes no passing Supported Surface, in-game check, or Validated Version Combination.

## Installed-source diagnosis

- Installed Color Selection builds an exact RGB prefix at `ColorSelection.lua:690-691`, strips all color and reset tags from the complete first line at `:715-723`, then rebuilds the line at `:730-742`. That removes True Level's character-level and Havoc-rank formatting before reconstruction.
- Color Selection escapes Lua pattern characters in the profile name at `ColorSelection.lua:712-713` but passes that escaped value to `find(..., true)` at `:725-728`. Plain-string mode searches for the inserted percent signs literally. Names containing hyphens or other escaped pattern characters therefore fail to match and bypass the destructive rewrite; ordinary names match and lose True Level formatting.
- Installed True Level initializes `marker.tl_modified = false` when creating character text at `elements/nameplate.lua:15-43`, writes the rich suffix and sets the flag true at `:108-136`, and normally does not rewrite that marker again. Color Selection continues rewriting its nameplate path every update.
- Installed DMF runs the complete normal-hook chain before all safe hooks (`dmf/modules/core/hooks.lua:122-205`) and records only one hook per mod per target function regardless of hook type (`:227-254`). A normal and safe hook from this compatibility mod cannot coexist on `HudElementNameplates.update`, and a normal hook cannot run after the dependency safe hooks.
- DMF's delayed-class wrapper drains string-target delayed hooks inside the class's first `new` call (`dmf/modules/core/hooks.lua:548-559`). Delayed hooks are applied in reverse queue order (`:262-280`). In the observed load, Color Selection's safe update hook was installed before True Level's; a compatibility safe hook appended after that drain will run last.

The preserved Color Selection 2.14 patched snapshot remains historical evidence only. Its corrected path searches the raw player name literally and avoids rebuilding the True Level-owned suffix, but it does not describe the installed unmodified 2.15 behavior.

## Corrected implemented seam

The adapter registers `hook_require` for `scripts/ui/hud/elements/nameplates/hud_element_nameplates` and wraps the delivered class's first `new` call. The wrapper calls DMF's preceding constructor chain first, preserving every return value, then registers exactly one compatibility hook on `HudElementNameplates.update`: a late `hook_safe` appended after the dependency hooks.

On the first relevant clean-launch frame, the expected installed order is game/normal chain → Color Selection → True Level → compatibility fix. The compatibility callback observes and caches True Level's formatted suffix as a Rich Suffix Snapshot. On later frames, Color Selection removes those tags, True Level normally no-ops because `tl_modified` is already true, and the compatibility callback restores the cached suffix only after a Visible Suffix Match. Restoration reuses the current Color Selection-owned prefix, so live player-color changes remain authoritative.

Snapshots are weak-keyed by marker and guarded by the exact profile name and current player-record identity. A visible-suffix mismatch, guard change, inactive Activation Condition, or World Visit clears the applicable snapshot. Title/newline content must match exactly because formatting-insensitive comparison is limited to exact RGB color and reset tags on the first suffix line. The final compatible value is assigned at most once per candidate callback, although a destructive rewrite can still require restoration on every frame.

The adapter continues to use only public DMF hook services and current marker/profile/widget data. It does not edit, redistribute, or wrap either Dependency Mod's formatting functions and does not inspect or mutate True Level's private `tl_modified` flag.

## Toggle behavior and evidence boundary

Installed True Level's `on_setting_changed` calls `desync_all` (`true_level.lua:407-410`). Turning `enable_nameplate` off makes the nameplate hook inert; turning it back on removes and recreates nameplate markers (`elements/nameplate.lua:85-105`), which should provide a fresh rich suffix for snapshot capture. This exact off/on sequence remains a mandatory live check.

Whole-mod disable/enable cycles are different. Installed True Level does not desynchronize existing nameplate state on mod re-enable, and installed Color Selection's active `on_disabled` definition does not reset the affected headers. Because the compatibility fix deliberately clears snapshots while inactive, neither whole-mod cycle reliably reseeds rich formatting within the same World Visit. Such cycles are outside the current validated contract; restart Darktide before relying on restored compatibility after toggling an entire Dependency Mod.

## Required next validation

Do not create `VALIDATION.md`. First replace the external MO2 compatibility-mod copy only after Austin approves that external write, restart Darktide, and repeat the Mourningstar remote-nameplate check with both an unhyphenated name and a hyphenated name. Both must preserve Color Selection's current class-icon/name color and True Level's character-level, Havoc-rank, and later formatting. Also confirm the log shows the compatibility safe update hook registering after the dependency hooks with no compatibility diagnostic.

Only after that focused retest passes should issue #7 continue through the remaining mandatory mission, return-transition, `enable_nameplate` off/on reseed, local-candidate-if-exposed, performance, assignment, and log-spam checks. Until both Supported Surfaces and every mandatory check pass, no in-game success or Validated Version Combination is claimed.
