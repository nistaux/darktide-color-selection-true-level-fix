local mod = get_mod("color_selection_true_level_fix")
local root = "color_selection_true_level_fix/scripts/mods/color_selection_true_level_fix/"
local splice = mod:io_dofile(root .. "splice")
local adapter = mod:io_dofile(root .. "adapter")

local metadata_order = {
    "activation_stage",
    "structure_stage",
    "profile_stage",
    "tag_stage",
    "processing_stage",
    "target_stage",
    "first_observed_surface",
}

local function get_world_marker_map()
    local managers = rawget(_G, "Managers")
    local ui_manager = managers and managers.ui
    local hud = ui_manager and ui_manager:get_hud()
    local world_markers = hud and hud:element("HudElementWorldMarkers")

    return world_markers and world_markers._markers_by_id
end

local function log_diagnostic(reason, metadata)
    local fields = {}

    for _, key in ipairs(metadata_order) do
        local value = metadata and metadata[key]

        if value ~= nil then
            fields[#fields + 1] = key .. "=" .. tostring(value)
        end
    end

    local suffix = #fields > 0 and " (" .. table.concat(fields, ", ") .. ")" or ""
    mod:info("Compatibility Diagnostic: %s%s", reason, suffix)
end

local services = {
    get_mod = get_mod,
    get_nameplate_class = function()
        local class_registry = rawget(_G, "CLASS")

        return class_registry and class_registry.HudElementNameplates
    end,
    hook_safe = function(class, method_name, callback)
        mod:hook_safe(class, method_name, callback)
    end,
    get_world_marker_map = get_world_marker_map,
    log_diagnostic = log_diagnostic,
}

local callbacks = adapter.new(services, splice)

mod.on_all_mods_loaded = callbacks.on_all_mods_loaded
mod.on_game_state_changed = callbacks.on_game_state_changed
