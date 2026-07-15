# Darktide Modding: Programmer Reference

> Research date: **2026-07-13**  
> Audience: Codex, Darktide Lua mod authors, and maintainers using the community [Darktide Mod Loader (DML)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader) and [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework).

This reference distinguishes evidence levels:

- **Documented** — stated by DML, DMF, or Fatshark documentation/source.
- **Inferred** — a maintenance or design conclusion drawn from current framework code and representative large mods. It is a convention, not an API guarantee.

Darktide and DMF are moving targets. Before designing against a game object or private method, inspect the current [decompiled Darktide Lua source](https://github.com/Aussiemon/Darktide-Source-Code), current [DMF source](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework), and existing mods updated for the same game patch.

## Development bootstrap

**Documented:** DML is the bootstrap loader. It reads `mods/mod_load_order.txt`, loads DMF first, executes each `<folder>/<folder>.mod`, and then calls the manifest's `run` function. DMF supplies hooks, lifecycle events, settings, Mod Options, localization, commands, logging, safe calls, and HUD registration. See the [DML loader implementation](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader/blob/master/mods/base/mod_manager.lua) and [DMF documentation](https://dmf-docs.darkti.de/).

For development only:

1. Install current DML and DMF using the [maintained installation page](https://dmf-docs.darkti.de/#/installing-mods).
2. Generate a skeleton with [Darktide Mod Builder](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Builder): `dmb create <mod_name>`.
3. Put the mod after DMF and any hard dependencies in `mod_load_order.txt`.
4. Enable DMF Developer Mode. `Ctrl+Shift+R` reloads mods without restarting the game ([creating mods](https://dmf-docs.darkti.de/#/creating-mods)). A reload is not a substitute for a clean-launch test.

After a game update, DML must usually be re-patched. Fatshark notes that large updates commonly invalidate mods until their authors update them ([Fatshark crash guidance](https://support.fatshark.se/hc/en-us/articles/7709661288733--PC-How-to-Resolve-Crashes-in-Darktide)).

## Canonical mod anatomy

**Documented:** DMF defines this minimum layout ([creating mods](https://dmf-docs.darkti.de/#/creating-mods)):

```text
ExampleMod/
├─ ExampleMod.mod
└─ scripts/mods/ExampleMod/
   ├─ ExampleMod.lua
   ├─ ExampleMod_data.lua
   └─ ExampleMod_localization.lua
```

- `.mod`: DML entry point; registers the DMF mod.
- `.lua`: runtime composition root and behavior.
- `_data.lua`: immutable metadata and Mod Options widget definitions.
- `_localization.lua`: text IDs and translations.

The folder and `.mod` basename must agree because DML resolves `<mod_name>/<mod_name>.mod`. The internal `new_mod` name must be globally unique and is the value later passed to `get_mod` ([DMF globals](https://dmf-docs.darkti.de/#/globals)). Treat paths and names as case-sensitive even when developing on Windows.

### Manifest behavior

```lua
-- ExampleMod/ExampleMod.mod
return {
    run = function()
        fassert(rawget(_G, "new_mod"), "ExampleMod requires DMF")

        new_mod("ExampleMod", {
            mod_script = "ExampleMod/scripts/mods/ExampleMod/ExampleMod",
            mod_data = "ExampleMod/scripts/mods/ExampleMod/ExampleMod_data",
            mod_localization = "ExampleMod/scripts/mods/ExampleMod/ExampleMod_localization",
        })
    end,

    -- Distribution metadata used by some current mods/tools:
    version = "1.0.0",
    mod_id = "123",
}
```

**Documented:** `new_mod(name, resources)` accepts tables, functions, or file-path strings for its resources. The data and localization definitions become fixed when the mod is created ([globals](https://dmf-docs.darkti.de/#/globals), [mod data](https://dmf-docs.darkti.de/#/mod-data)). DML executes `run` in a protected call; a manifest error prevents that mod from loading but is logged by the loader.

**Inferred:** `version` and `mod_id` appear in current manifests such as [Numeric UI's](https://github.com/danreeves/darktide-mods/blob/main/NumericUI/NumericUI.mod), but they are not part of DMF's documented four-file minimum. Do not assume undocumented metadata performs dependency resolution. Declare dependencies and load-order constraints in author documentation and fail clearly when a hard dependency is absent.

### Composition-root pattern

```lua
-- ExampleMod.lua
local mod = get_mod("ExampleMod")

mod.runtime = {
    enabled_for_state = false,
    dirty = true,
}

mod:io_dofile("ExampleMod/scripts/mods/ExampleMod/features/team_panel")
mod:io_dofile("ExampleMod/scripts/mods/ExampleMod/features/nameplates")
mod:io_dofile("ExampleMod/scripts/mods/ExampleMod/features/commands")
```

**Inferred:** Keep the entry point small. Split by game system or UI surface, not by arbitrary file size. Numeric UI uses feature-per-file modules; True Level uses an `elements/` module per UI surface; Scoreboard separates collection, rows, rendering, views, and history. This makes post-patch failures attributable and minimizes overlapping edits.

## Discovering game APIs

### Source-first workflow

1. Search the current [Darktide source mirror](https://github.com/Aussiemon/Darktide-Source-Code) for the class, method, event, view, HUD element, extension name, or data field.
2. Trace who constructs the object and who calls the method. A correct method name is insufficient if the object exists only in a particular state or view.
3. Inspect current mods that target the same surface. They reveal load timing and real object shapes, but are examples—not authority.
4. Log or `mod:dump` the runtime value at a low frequency to verify the decompiled shape.
5. Record the game source path and method signature beside non-obvious hooks. This drastically shortens patch repair.

**Documented:** DMF links the source mirror as the principal game-code reference. The source is decompiled Lua; server/backend implementation and native Stingray behavior are not necessarily present.

**Inferred:** Treat all decompiled game APIs as unstable, especially names beginning with `_`, positional RPC parameters, UI definition tables, backend promises, and manager internals. Preserve unknown arguments with `...`; avoid copying entire game methods; prefer a narrow observation or transformation around the smallest relevant method.

### Loading game and mod files

```lua
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local Definitions = mod:io_dofile(
    "ExampleMod/scripts/mods/ExampleMod/ui/example_definitions"
)
```

**Source-documented:** `mod:original_require(path)` calls the unhooked game `require`. `mod:io_dofile(path)` loads a mod-side Lua file under a protected call. `add_require_path` allows a mod file to be resolved through the game's `require` pipeline. See DMF's [require module](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/core/require.lua) and [I/O module](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/core/io.lua).

Prefer `original_require` for game modules and `io_dofile` for your own modules. Do not globally hook `require` or `dofile` unless no narrower integration exists.

## Hooks and file-load interception

**Documented:** DMF maintains compatible hook chains ([hooks](https://dmf-docs.darkti.de/#/hooks)).

| API | Semantics | Use when | Main risk |
|---|---|---|---|
| `mod:hook_safe` | Runs after the original returns; protected; cannot replace returns | Observing lifecycle/data and updating derived state | Handler may run often; modifying arguments is unsafe |
| `mod:hook` | Unprotected wrapper; receives next `func`; can alter arguments/returns | Behavior must be changed | An error crashes; a hook can terminate the chain |
| `mod:hook_origin` | Unprotected total replacement; only one origin hook per function | There is no chain-compatible alternative | Maximum conflict and patch risk |
| `mod:hook_require` | Callback for past and future instances of a required file | Local tables/functions are exposed only when a file loads | The file hook itself cannot be disabled |

### Observation

```lua
mod:hook_safe("HudElementTeamPanelHandler", "_add_panel", function(self, ...)
    if not mod:is_enabled() then
        return
    end

    mod.runtime.dirty = true
end)
```

String class paths are resolved later by DMF, which is useful when the class does not exist during initial mod load.

### Transformation

```lua
mod:hook("SomeClass", "format_value", function(func, self, value, ...)
    if not mod:is_enabled() then
        return func(self, value, ...)
    end

    local formatted = func(self, value, ...)
    return formatted .. mod:localize("suffix")
end)
```

Always call and return `func` unless deliberately suppressing original behavior. Forward `...` to tolerate appended parameters. Never assume regular hooks are protected.

### File-load interception

```lua
local path = "scripts/ui/hud/elements/team_panel/hud_element_team_panel_definitions"

mod:hook_require(path, function(instance)
    -- The same file may be required more than once. Make the patch idempotent.
    if not instance or instance.ExampleMod_added then
        return
    end

    instance.ExampleMod_added = true
    -- Narrowly amend the returned module table here.
end)
```

**Documented:** `hook_require` applies to past and future instances in load-order sequence and cannot itself be disabled. Hooks created inside its callback can be toggled normally.

**Inferred:** Any direct mutation performed in `hook_require` must be idempotent and either reversible or semantically harmless while disabled. Store original values before replacement. Avoid sentinel keys if downstream code enumerates the table; a private weak-key registry may be safer.

### Choosing an integration mechanism

Use this order of preference:

1. Public game/DMF event or explicit cross-mod API.
2. `hook_safe` on the narrow event-like method.
3. `hook_require` to amend a definition/local function when it is created.
4. Regular `hook` that calls the chain.
5. `hook_origin` only with a documented incompatibility rationale.

## Lifecycle and restoration

**Documented:** DMF exposes `update`, `on_unload`, `on_game_state_changed`, `on_setting_changed`, `on_enabled`, `on_disabled`, and `on_all_mods_loaded` ([events](https://dmf-docs.darkti.de/#/events)). Event callbacks still execute while a mod is disabled; check `mod:is_enabled()` when needed. Ordinary hooks and commands are automatically disabled for a toggleable mod before `on_disabled` runs.

```lua
function mod.on_all_mods_loaded()
    mod.runtime.other_mod = get_mod("OptionalMod")
end

function mod.on_game_state_changed(status, state_name)
    if status == "enter" and state_name == "StateGameplay" then
        mod.runtime.enabled_for_state = true
        mod.runtime.dirty = true
    elseif status == "exit" and state_name == "StateGameplay" then
        mod.runtime.enabled_for_state = false
        mod.runtime.cached_unit = nil
        mod.runtime.cached_view = nil
    end
end

function mod.on_setting_changed(setting_id)
    if setting_id == "show_value" then
        mod.runtime.show_value = mod:get(setting_id)
        mod.runtime.dirty = true
    end
end

function mod.on_disabled()
    mod.restore_mutated_game_tables()
    mod.close_owned_view_if_open()
end

function mod.on_unload(exit_game)
    mod.restore_mutated_game_tables()
    mod.release_owned_resources()
end
```

**Inferred lifecycle contract:**

- Module load: definitions, constants, hooks, and cheap registration only.
- `on_all_mods_loaded`: optional-mod discovery and cross-mod registration.
- state/view/HUD creation hooks: acquire ephemeral runtime objects.
- `on_setting_changed`: update cached settings and mark affected data dirty.
- `on_disabled`: restore every direct mutation not managed by DMF and hide owned UI.
- `on_unload`: unregister external callbacks, restore tables, release packages/views/files, and clear references.

Hot reload preserves more engine state than a clean launch. Every initializer must tolerate existing widgets, injected definitions, cached state, and already-loaded game files.

## Safe access to managers, players, units, and extensions

Managers and objects appear and disappear across splash, character selection, hub, loading, gameplay, disconnect, death, and teardown. A nil check performed one frame does not make an object safe in a later asynchronous callback.

```lua
local function local_player_and_unit()
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player_safe(1)
    local unit = player and player.player_unit
    local alive_lookup = rawget(_G, "ALIVE")

    if not unit or not alive_lookup or not alive_lookup[unit] then
        return nil, nil
    end

    return player, unit
end

local function extension_if_alive(unit, system_name)
    local alive_lookup = rawget(_G, "ALIVE")
    if not unit or not alive_lookup or not alive_lookup[unit] then
        return nil
    end

    return ScriptUnit.has_extension(unit, system_name)
end
```

**Inferred:** Use `ScriptUnit.has_extension` for optional extensions. Use `ScriptUnit.extension` only when the relevant unit template guarantees the extension and you have already validated context. Do not retain units/extensions/widgets between missions or view recreation; retain stable IDs and reacquire.

Guard chains explicitly:

```lua
local game_mode_manager = Managers.state and Managers.state.game_mode
local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

local ui = Managers.ui
if not ui or not ui._hud then
    return
end
```

### Async/backend work

**Inferred:** Backend promises may finish after the originating view, character, or state is gone. Capture an account/character ID and generation token, then validate both before applying the result. Cache successful data by stable ID, clear it on relevant state/profile changes, and implement failure paths. True Level is a useful example of backend progression caching and UI resynchronization ([source](https://github.com/zombine04/darktide-mods/blob/main/true_level/scripts/mods/true_level/true_level.lua)).

### Authority and multiplayer

Never infer server authority merely because an object exists. For mutations, confirm the current game mode and session authority:

```lua
local session = Managers.state and Managers.state.game_session
if not session or not session:is_server() then
    return
end
```

Creature Spawner restricts actions by server state, game mode, and input context ([source](https://github.com/Aussiemon/Darktide-Mods/blob/master/creature_spawner/scripts/mods/creature_spawner/creature_spawner.lua)).

**Source-documented limitation:** DMF's current `network.lua` still marks its network dictionary and DMF-user discovery as `TODO` ([network source](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/core/network.lua)). Do not design around a presumed DMF RPC API. Use only verified game networking patterns, validate authority, and assume other players do not have the mod unless an explicitly implemented protocol proves otherwise.

## UI, views, HUD elements, and widgets

### Custom HUD element

**Documented:** `register_hud_element` is the preferred DMF injection API ([HUD elements](https://dmf-docs.darkti.de/#/hud-elements)).

```lua
mod:register_hud_element({
    class_name = "HudElementExampleMod",
    filename = "ExampleMod/scripts/mods/ExampleMod/ui/hud_element_example_mod",
    use_hud_scale = true,
    visibility_groups = { "alive" },
    validation_function = function(params)
        return mod:is_enabled() and params ~= nil
    end,
})
```

The element class should derive from the current `HudElementBase`, keep scenegraph definitions separate, create widgets during initialization, update only dirty content, and release any owned renderer/resources in `destroy`. Use globally unique class and view names; DMF rejects HUD class collisions ([HUD implementation](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/gui/custom_hud_elements.lua)).

### Patching existing UI

**Inferred:**

- Amend a specific definition through `hook_require` when possible.
- Check for an existing pass/widget/class before inserting; reload and multiple mods can otherwise duplicate it.
- Preserve existing text, visibility logic, callbacks, and styles. Append or modify the smallest owned segment.
- Clone shared style/color/size tables before changing them unless the change is intentionally global.
- Never assume `_widgets_by_name.foo`, a renderer, or a view is present during `update` or teardown.
- Cache references only for the lifetime of that view/HUD instance and clear them in its `destroy`/`on_exit` hook.
- Respect HUD scale, resolution, localization length, retained-mode behavior, and visibility groups.

Numeric UI's modular HUD integration and guarded HUD rebuild are useful study material ([source](https://github.com/danreeves/darktide-mods/tree/main/NumericUI/scripts/mods/NumericUI)). Healthbars demonstrates a dedicated world-marker implementation with bounded active-target work ([source](https://github.com/danreeves/darktide-mods/tree/main/Healthbars/scripts/mods/Healthbars)).

### Custom views

DMF contains `register_view` support in source, but its public documentation is less complete than the HUD API ([custom view implementation](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/gui/custom_views.lua)).

**Inferred:** Before using custom views, study a current working mod and current DMF implementation. Treat view transitions, input services, renderer ownership, `on_enter`, `on_exit`, and `destroy` as one lifecycle. Close owned views on disable/unload and avoid opening during another closing transition.

### Mod Options widgets

```lua
-- ExampleMod_data.lua
local mod = get_mod("ExampleMod")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "show_value",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "font_size",
                type = "numeric",
                default_value = 18,
                range = { 10, 40 },
            },
            {
                setting_id = "toggle_view",
                type = "keybind",
                default_value = {},
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                function_name = "toggle_view",
            },
        },
    },
}
```

**Documented:** Widget settings require valid defaults. Keybinds should normally ship unassigned; DMF does not detect duplicate bindings. Use `require_restart` only when live application is impossible ([widgets](https://dmf-docs.darkti.de/#/widgets)).

## Settings, localization, and persistence

### Settings

**Documented:** Settings are namespaced and stored in `%AppData%\Fatshark\Darktide\user_settings.config`. Only JSON-serializable values are supported; map keys must be strings. Table-valued settings are cloned on access and are slow relative to locals ([settings](https://dmf-docs.darkti.de/#/settings)).

```lua
local cached_show_value = mod:get("show_value")

function mod.on_setting_changed(setting_id)
    if setting_id == "show_value" then
        cached_show_value = mod:get(setting_id)
    end
end
```

Use scalar settings where possible. Read table settings once, validate/migrate their shape, and write only at meaningful boundaries. `mod:set(id, value, true)` triggers `on_setting_changed`; persistence is flushed later on state change, mod reload, or closing Mod Options.

For in-session data that should survive a mod reload but not a game restart, use `mod:persistent_table(name, default)` ([debugging](https://dmf-docs.darkti.de/#/debugging)). Version its contents if the shape may change.

### Localization

```lua
-- ExampleMod_localization.lua
return {
    mod_name = { en = "Example Mod" },
    mod_description = { en = "Shows an example value." },
    show_value = { en = "Show Value" },
    show_value_description = { en = "Show or hide the value." },
    value_format = { en = "Value: %d" },
}
```

**Documented:** English is the fallback. `mod:localize(id, ...)` supports `string.format`-style parameters and returns `<id>` for a missing ID ([localization](https://dmf-docs.darkti.de/#/localization)).

Persist localization IDs and raw values, not rendered English. Localize metadata, settings, commands, notifications, UI labels, and plugin-supplied display text. Test long strings and missing translations.

### Files

**Source-documented:** DMF exposes protected read/execute helpers (`io_dofile`, `io_read_content`, and related functions) rooted under `mods` ([I/O source](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/master/dmf/scripts/mods/dmf/modules/core/io.lua)). There is no equally documented high-level persistence API for arbitrary mod files.

**Inferred:** Prefer DMF settings for small user configuration. If substantial history/export data requires direct file I/O, isolate it behind one module, use a mod-owned path, version the schema, validate reads, avoid I/O in hooks/update, handle partial/corrupt files, and close handles on all paths. Never execute user-editable content as Lua merely to parse data.

## Commands and keybind handlers

**Documented:** Chat commands are local messages prefixed with `/`; other players do not receive the command text. Commands are automatically disabled with a toggleable mod ([commands](https://dmf-docs.darkti.de/#/commands)).

```lua
mod:command("example_status", mod:localize("command_description"), function(...)
    local args = { ... }
    mod:echo("enabled=%s args=%d", tostring(mod:is_enabled()), #args)
end)
```

Validate and bound every argument. Commands and keybind functions can run in menus, chat, loading, or teardown depending on configuration; re-check state inside the handler. Keep destructive/test commands behind an explicit developer/debug option.

## Cross-mod compatibility

```lua
local optional

function mod.on_all_mods_loaded()
    optional = get_mod("OptionalMod")
end

local function optional_available()
    return optional and optional:is_enabled() and optional.public_api ~= nil
end
```

**Documented:** `get_mod(name)` returns the DMF mod or `nil` ([globals](https://dmf-docs.darkti.de/#/globals)).

**Inferred compatibility rules:**

- Detect optional mods after all mods load; absence must disable only the integration.
- Expose an explicit, versioned public API or registry rather than requiring plugins to hook private functions.
- Namespace registry entries and make registration idempotent.
- Do not overwrite an entire shared UI string/table when a narrow append or extra pass works.
- Restore direct game-table mutations on disable/unload. DMF can disable hooks, but it cannot infer or undo arbitrary table changes made by the mod.
- If two mods cannot coexist, detect and explain the exact overlap. Do not silently win by load order.
- Treat load order as an explicit dependency mechanism, not a universal conflict solution.

Scoreboard illustrates a plugin registry for externally supplied rows ([row source](https://github.com/grasmann/darktide-mods/blob/main/scoreboard/scripts/mods/scoreboard/scoreboard_rows.lua)). True Level conditionally integrates with Who Are You instead of assuming it is installed ([source](https://github.com/zombine04/darktide-mods/blob/main/true_level/scripts/mods/true_level/true_level.lua)).

## Performance and hot paths

**Documented:** DMF's [Fatshark Lua optimization guide](https://dmf-docs.darkti.de/#/Fatshark-%E2%80%90-Lua-Optimizing-Guide) says to profile before and after optimizing. It identifies table allocation/GC, repeated lookups, string creation, and engine-boundary calls as relevant costs. DMF warns that `update` runs every tick and table settings are cloned.

Hot-path rules:

- Exit immediately if disabled, hidden, outside the target game mode, or missing required state.
- Prefer event-driven dirty flags over recomputing every frame.
- Cache scalar settings, localized strings, game definitions, and stable functions outside loops.
- Reuse tables/widgets; avoid per-frame closures, concatenation, JSON, file I/O, backend calls, and full unit/player scans.
- Bound work per frame and collection sizes. Use weak-key tables for unit caches when appropriate, but still clear state on transitions.
- Update widget content only when the value changes.
- Profile in a real mission with teammates and hordes, not only the Psykanium.
- Optimize measured hot code without making lifecycle ownership unreadable.

## Debugging and diagnosis

### Logging and stack traces

**Documented:** DMF provides `debug`, `info`, `warning`, `error`, `echo`, and `notify`; destinations are controlled in DMF options ([logging](https://dmf-docs.darkti.de/#/logging)). `hook_safe` and `mod:pcall` log errors and stack traces without propagating ordinary Lua failures; regular/origin hooks remain unprotected ([safe calls](https://dmf-docs.darkti.de/#/safe-calls), [hooks](https://dmf-docs.darkti.de/#/hooks)). Some Stingray/native failures remain fatal even inside protected calls.

Steam logs:

```text
%AppData%\Fatshark\Darktide\console_logs\
%AppData%\Fatshark\Darktide\darktide_launcher.log
%AppData%\Fatshark\Darktide\user_settings.config
```

Microsoft Store logs:

```text
%AppData%\Fatshark\MicrosoftStore\Darktide\console_logs\
```

These paths are documented by [Fatshark's log collection guide](https://support.fatshark.se/hc/en-us/articles/360017633918--PC-How-to-Provide-a-Crash-Report-Console-Log-Launcher-Log-or-user-settings-config).

Use stable searchable prefixes and include mod version, state, hook/method, relevant stable IDs, and feature mode. Do not log every frame or expose account/private data.

```lua
mod:debug("[sync] generation=%d character=%s", generation, tostring(character_id))
mod:warning("[team_panel] widget missing; deferring rebuild")
```

### Runtime inspection

**Documented:** `mod:dump(value, name, depth)` writes a table to the game log. `mod:dump_to_file`/`mod:dtf` writes a JSON dump. `mod:persistent_table` retains a table through reloads in the same session ([debugging](https://dmf-docs.darkti.de/#/debugging)).

Use shallow dumps first. Dumping managers or large cyclic tables can flood logs and stall the game.

### Diagnosis workflow

1. Reproduce with current DML/DMF and only the target mod plus hard dependencies.
2. Record game version, mod version, state/view, character/class, and exact action.
3. Read the first relevant error and full stack trace in the session's console log; later errors may be cascades.
4. Map the failing line to the hook target and current game source signature.
5. Decide whether the cause is missing state, stale object, renamed field/method, reordered parameters, changed return shape, duplicated reload injection, or a cross-mod collision.
6. Add one low-volume diagnostic at the ownership boundary; do not blanket-wrap the feature in `pcall`.
7. Test the fix after hot reload, then on a clean game launch and a complete state transition.
8. Re-test with common mods touching the same surface.

## Architecture lessons from representative large mods

The [Nexus all-time list](https://www.nexusmods.com/warhammer40kdarktide/mods/topalltime?adult=2) places Numeric UI, Scoreboard, True Level, and Healthbars among the highest-endorsed Darktide files. Creature Spawner is a long-lived tool from core community contributors. Nexus did not expose anonymous download totals during this research, so popularity here uses visible endorsement ranking, longevity, prominence, and source scale rather than an exact download ordering.

| Mod | Reusable architecture lesson | Maintenance warning |
|---|---|---|
| [Numeric UI source](https://github.com/danreeves/darktide-mods/tree/main/NumericUI) / [Nexus](https://www.nexusmods.com/warhammer40kdarktide/mods/14) | Composition root plus module per HUD feature; guarded delayed HUD reconstruction; separate custom elements | Many mods touch the same definitions/nameplates; insertion must be idempotent and preserve other text/passes |
| [Scoreboard source](https://github.com/grasmann/darktide-mods/tree/main/scoreboard) / [Nexus](https://www.nexusmods.com/warhammer40kdarktide/mods/22) | Data collection, row model, view, history, and plugin registry are separate | Broad hook surface and persisted history make patches/schema compatibility expensive |
| [True Level source](https://github.com/zombine04/darktide-mods/tree/main/true_level) / [Nexus](https://www.nexusmods.com/warhammer40kdarktide/mods/156) | Module per UI surface; stable-ID caches; async backend work; optional integration | Backend/view readiness and object recreation require generation checks and resync |
| [Healthbars source](https://github.com/danreeves/darktide-mods/tree/main/Healthbars) / [Nexus](https://www.nexusmods.com/warhammer40kdarktide/mods/16) | Dedicated marker class; context/feature gates; active-target limits; weak-key unit caches | World-marker, buff, and unit APIs are volatile and run under horde load |
| [Creature Spawner source](https://github.com/Aussiemon/Darktide-Mods/tree/master/creature_spawner) / [Nexus](https://www.nexusmods.com/warhammer40kdarktide/mods/25) | Commands/keybinds delegate to validated functions; explicit server/game-mode/chat guards; trials split out | Gameplay mutations require authority checks and controlled contexts; unsupported units can crash |

**Inferred synthesis:** Large durable mods converge on feature modules, cached runtime state, explicit lifecycle resynchronization, narrow public integration points, and guards around ephemeral game objects. Size alone is not sophistication: the most expensive maintenance burden is the number and volatility of integration surfaces.

## Anti-patterns

- `hook_origin` for convenience when a safe or regular hook works.
- Copying a whole decompiled game method into the mod.
- Calling `ScriptUnit.extension` before proving unit lifetime/template guarantees.
- Caching units, extensions, widgets, views, or manager-owned objects across state transitions.
- Mutating shared definition tables without storing/restoring originals or making the change idempotent.
- Repeated `mod:get`, localization, string construction, table allocation, file I/O, backend requests, or unit scans in `update`.
- Assuming callback events stop when a toggleable mod is disabled.
- Assuming hot reload recreates the same state as a clean launch.
- Assuming another player has DMF/the mod or that local state is authoritative.
- Depending on undocumented fields without a source-path comment and failure fallback.
- Using load order to silently overwrite another mod's UI or hook behavior.
- Persisting rendered localized text, raw units, functions, userdata, or non-string map keys.
- Shipping assigned keybinds, debug spam, stale files, or a nested archive root.
- Treating `pcall` as a substitute for state validation and ownership cleanup.

## Implementation checklist

- [ ] Identify the current game-source owner, construction timing, call signature, and teardown path.
- [ ] Choose event → safe hook → `hook_require` → regular hook → origin hook in that order.
- [ ] Define ownership for every hook, mutated table, package, view, widget, callback, cache, command, and file.
- [ ] Make initialization and file patches idempotent under reload/re-require.
- [ ] Guard manager, player, unit, extension, view, widget, renderer, backend, and authority access.
- [ ] Use stable IDs across async/state boundaries and generation-check late callbacks.
- [ ] Cache scalar settings and update caches through `on_setting_changed`.
- [ ] Add English fallback localization and persist IDs/raw values.
- [ ] Build disable and unload restoration before declaring the feature complete.
- [ ] Test absent/disabled optional mods and common mods touching the same surface.
- [ ] Profile the actual hot path in a real mission.

## Patch-update checklist

- [ ] Update/re-patch DML and update DMF before diagnosing the mod.
- [ ] Diff every hooked game file/class against the previously supported source revision.
- [ ] Verify method existence, parameters, return values, extension names, component fields, and UI definitions.
- [ ] Search current maintained mods for migrations on the same integration surface.
- [ ] Clean-launch with only hard dependencies; inspect the first stack trace.
- [ ] Exercise character select, hub, loading, mission, death, reconnect, mission end, and exit as relevant.
- [ ] Exercise enable/disable, setting changes, reload, and repeated UI/view creation.
- [ ] Test teammates, bots/companions, join/leave, missing backend results, and changed character/profile.
- [ ] Test popular co-installed UI/gameplay mods and multiple resolutions/HUD scales.
- [ ] Update compatibility notes, tested game/DMF versions, changelog, and known limitations.

## Author packaging and versioning checklist

- [ ] Archive root contains exactly one correctly named mod folder.
- [ ] That folder directly contains `<name>.mod` and `scripts/`; no stale source/build files.
- [ ] Folder, manifest, `new_mod`, `get_mod`, and resource path casing agree.
- [ ] Version follows one stable scheme; release notes name the tested Darktide and DMF versions.
- [ ] Breaking public API or persisted-schema changes are versioned and migrated or explicitly reset.
- [ ] Hard/optional dependencies and load order are explicit; missing hard dependencies fail clearly.
- [ ] Keybinds default unassigned; debug mode/log volume default off.
- [ ] Clean install and delete-old-folder update paths are tested.
- [ ] License, third-party code/assets, attribution, and redistribution permissions are explicit.
- [ ] User data lives outside the replaceable mod directory or has a documented migration/export path.

## Primary sources

- [DMF documentation](https://dmf-docs.darkti.de/)
- [Creating mods](https://dmf-docs.darkti.de/#/creating-mods)
- [Globals and `new_mod`/`get_mod`](https://dmf-docs.darkti.de/#/globals)
- [Hooks](https://dmf-docs.darkti.de/#/hooks)
- [Events](https://dmf-docs.darkti.de/#/events)
- [HUD elements](https://dmf-docs.darkti.de/#/hud-elements)
- [Settings](https://dmf-docs.darkti.de/#/settings)
- [Widgets](https://dmf-docs.darkti.de/#/widgets)
- [Localization](https://dmf-docs.darkti.de/#/localization)
- [Commands](https://dmf-docs.darkti.de/#/commands)
- [Logging](https://dmf-docs.darkti.de/#/logging)
- [Safe calls](https://dmf-docs.darkti.de/#/safe-calls)
- [Debugging](https://dmf-docs.darkti.de/#/debugging)
- [Fatshark Lua optimization guide](https://dmf-docs.darkti.de/#/Fatshark-%E2%80%90-Lua-Optimizing-Guide)
- [DML source](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader)
- [DMF source](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework)
- [Darktide Mod Builder](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Builder)
- [Current decompiled Darktide Lua source](https://github.com/Aussiemon/Darktide-Source-Code)
- [Fatshark console-log locations and crash reports](https://support.fatshark.se/hc/en-us/articles/360017633918--PC-How-to-Provide-a-Crash-Report-Console-Log-Launcher-Log-or-user-settings-config)

Representative mod sources are linked in the architecture table. Inspect their current branches and licenses before reusing code; public source visibility does not grant redistribution permission.
