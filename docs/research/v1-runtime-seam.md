# V1 runtime seam static revalidation

Static review date: 2026-07-15. This record supports implementation issues #2–#6. It confirms source shapes only and does not claim that the installed game build, hook order, rendering, transitions, or performance have been validated in game.

## Confirmed current source evidence

- Darktide defines `HudElementNameplates` in [`hud_element_nameplates.lua`](https://github.com/Aussiemon/Darktide-Source-Code/blob/master/scripts/ui/hud/elements/nameplates/hud_element_nameplates.lua). Its `update(self, dt, t)` method maintains `_nameplate_units`; entries carry `marker_id`, and current player marker types include `nameplate`, `nameplate_party_hud`, and `nameplate_party`. Companion nameplates use a separate collection and `nameplate_companion*` types.
- The current world-marker template is [`world_marker_template_nameplate.lua`](https://github.com/Aussiemon/Darktide-Source-Code/blob/master/scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate.lua). The adapter-visible composed field remains `marker.widget.content.header_text`.
- True Level's current [`elements/nameplate.lua`](https://github.com/zombine04/darktide-mods/blob/main/true_level/scripts/mods/true_level/elements/nameplate.lua) uses `CLASS.HudElementNameplates`, `hook_safe`, `_nameplate_units`, `Managers.ui:get_hud():element("HudElementWorldMarkers")._markers_by_id`, `marker.data:profile()`, and `marker.widget.content.header_text`. Its safe hook writes the True Level contribution after the original game update.
- True Level's current [`true_level.lua`](https://github.com/zombine04/darktide-mods/blob/main/true_level/scripts/mods/true_level/true_level.lua) identifies the mod as `true_level`, reports version `1.10.1` in the reviewed source, gates features with `mod:is_enabled()` plus `mod:get("enable_" .. ref)`, and emits exact `{#color(R,G,B)}` / `{#reset()}` markup. [`true_level_data.lua`](https://github.com/zombine04/darktide-mods/blob/main/true_level/scripts/mods/true_level/true_level_data.lua) therefore confirms `enable_nameplate`.
- The preserved Color Selection 2.14 patched evidence uses the public identifier `ColorSelection`, reads `marker.type`, `marker.data`, and `marker.widget.content.header_text`, and registers its `HudElementNameplates.update` safe hook during ordinary script loading. Its corrected nameplate path is at `reference/newer-2.14-with-nameplate-fixes/ColorSelection/scripts/mods/ColorSelection/ColorSelection.lua:608` and its hook is at line 842. The leading color tag is built at lines 679–680, the first line is isolated at lines 701–706, literal player-name matching occurs at lines 712–715, and the reset is inserted without rebuilding the suffix at lines 717–729.
- DMF's documented `hook_safe` callback runs after the original method. Because both reviewed Dependency Mods register during ordinary loading and this mod registers its direct class-table hook from `on_all_mods_loaded`, the expected callback order is game → True Level → Color Selection → compatibility fix.

## Implemented seam

The V1 adapter registers only against the actual `CLASS.HudElementNameplates` table and callable `update` method. Every callback reevaluates `get_mod("ColorSelection")`, `get_mod("true_level")`, both public `is_enabled()` states, and `true_level:get("enable_nameplate")`; it then resolves only current `_nameplate_units` entries through the current world-marker map. Marker types must contain `nameplate` and must not contain `companion`.

The adapter obtains the clean name from `marker.data:profile().name`, reads and conditionally assigns only `marker.widget.content.header_text`, and delegates string recognition to the pure splice module. Missing transient marker/widget/header state is skipped, unexpected structures are isolated per candidate, and only a `splice` result assigns.

## Patch-sensitive and unresolved assumptions

- The expected direct class table is actually available by `on_all_mods_loaded` or a later `StateGameplay` entry in Austin's installed build.
- Safe-hook callback registration order matches the static load-order reasoning and the compatibility callback sees the final Composed Nameplate.
- Mission and Mourningstar collections, marker IDs/types, player/profile access, and widget/header shapes match the reviewed sources for local and remote players.
- Austin's installed Color Selection version/source matches the preserved 2.14 patched behavior. A current creator-maintained source/version was not independently available in this repository, so the installed copy must be checked before recording a version tuple.
- `enable_nameplate`, inline tag syntax, and True Level's reported version match Austin's installed copy.
- `on_game_state_changed("enter", "StateGameplay")` begins each mission and Mourningstar World Visit, including the return transition.
- Rendering preserves Color Selection's class-icon/name ownership and True Level's character-level/Havoc ownership on both Supported Surfaces.
- Per-frame iteration has no obvious populated-surface performance cost.

These items are mandatory checks for issue #7. `VALIDATION.md` must not be created until Austin performs a real run with exact Darktide, DML, DMF, Color Selection, True Level, and compatibility-mod versions.
