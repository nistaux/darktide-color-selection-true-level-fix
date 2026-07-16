local adapter = {}

local function process_candidate(context, entry, markers)
    if type(entry) ~= "table" then
        return
    end

    local marker = markers[entry.marker_id]

    if marker == nil or type(marker) ~= "table" then
        return
    end

    local marker_type = marker.type

    if type(marker_type) ~= "string"
        or not string.find(marker_type, "nameplate", 1, true)
        or string.find(marker_type, "companion", 1, true)
    then
        return
    end

    local player = marker.data

    if player == nil then
        return
    end

    local widget = marker.widget

    if type(widget) ~= "table" or type(widget.content) ~= "table" then
        return
    end

    local content = widget.content
    local composed_nameplate = content.header_text

    if composed_nameplate == nil or composed_nameplate == "" then
        return
    end

    if type(composed_nameplate) ~= "string" then
        context.emit("composed_nameplate_unusable")
        return
    end

    context.processing_stage = "profile_lookup"
    local profile_accessor = player.profile

    if type(profile_accessor) ~= "function" then
        context.emit("profile_name_unavailable", { profile_stage = "profile_accessor" })
        return
    end

    local profile_ok, profile = pcall(profile_accessor, player)

    if not profile_ok then
        error("profile accessor call failed")
    end

    if type(profile) ~= "table" then
        context.emit("profile_name_unavailable", { profile_stage = "profile_record" })
        return
    end

    local profile_name = profile.name

    if type(profile_name) ~= "string" or #profile_name == 0 then
        context.emit("profile_name_unavailable", { profile_stage = "name_value" })
        return
    end

    context.processing_stage = "replacement_build"
    local splice_ok, result = pcall(context.splice.apply, composed_nameplate, profile_name)

    if not splice_ok or type(result) ~= "table" then
        error("splice failed")
    end

    if result.outcome == "splice" then
        if type(result.replacement) ~= "string" then
            error("splice replacement unavailable")
        end

        context.processing_stage = "assignment"
        content.header_text = result.replacement
    elseif result.outcome == "safe_no_change" then
        context.emit(result.reason, result.metadata)
    elseif result.outcome ~= "already_compatible" then
        error("splice outcome unavailable")
    end
end

function adapter.new(services, splice)
    local registered = false
    local emitted_reasons = {}

    local function emit(reason, metadata)
        if emitted_reasons[reason] then
            return
        end

        emitted_reasons[reason] = true
        local diagnostic_metadata = {}

        if metadata then
            for key, value in pairs(metadata) do
                diagnostic_metadata[key] = value
            end
        end

        pcall(services.log_diagnostic, reason, diagnostic_metadata)
    end

    local function read_enabled_mod(mod_id, activation_stage)
        local discovery_ok, dependency_mod = pcall(services.get_mod, mod_id)

        if not discovery_ok then
            emit("activation_state_unreadable", { activation_stage = activation_stage })
            return nil
        end

        if dependency_mod == nil then
            return nil
        end

        if type(dependency_mod) ~= "table" or type(dependency_mod.is_enabled) ~= "function" then
            emit("activation_state_unreadable", { activation_stage = activation_stage })
            return nil
        end

        local state_ok, enabled = pcall(dependency_mod.is_enabled, dependency_mod)

        if not state_ok or type(enabled) ~= "boolean" then
            emit("activation_state_unreadable", { activation_stage = activation_stage })
            return nil
        end

        if not enabled then
            return nil
        end

        return dependency_mod
    end

    local function active()
        if not read_enabled_mod("ColorSelection", "color_selection_state") then
            return false
        end

        local true_level = read_enabled_mod("true_level", "true_level_state")

        if not true_level then
            return false
        end

        if type(true_level.get) ~= "function" then
            emit("activation_state_unreadable", { activation_stage = "nameplate_setting" })
            return false
        end

        local setting_ok, nameplates_enabled = pcall(true_level.get, true_level, "enable_nameplate")

        if not setting_ok or type(nameplates_enabled) ~= "boolean" then
            emit("activation_state_unreadable", { activation_stage = "nameplate_setting" })
            return false
        end

        return nameplates_enabled
    end

    local candidate_context = {
        emit = emit,
        splice = splice,
        processing_stage = "structure_validation",
    }

    local function update(nameplates)
        if not active() then
            return
        end

        if type(nameplates) ~= "table" or type(nameplates._nameplate_units) ~= "table" then
            emit("nameplate_structure_unusable", { structure_stage = "nameplate_units" })
            return
        end

        local markers_ok, markers = pcall(services.get_world_marker_map)

        if not markers_ok or type(markers) ~= "table" then
            emit("nameplate_structure_unusable", { structure_stage = "world_marker_map" })
            return
        end

        for _, entry in pairs(nameplates._nameplate_units) do
            candidate_context.processing_stage = "structure_validation"
            local ok = pcall(process_candidate, candidate_context, entry, markers)

            if not ok then
                emit("candidate_processing_exception", { processing_stage = candidate_context.processing_stage })
            end
        end
    end

    local function register(report_failure)
        if registered then
            return
        end

        local target_ok, class = pcall(services.get_nameplate_class)

        if not target_ok or type(class) ~= "table" then
            if report_failure then
                emit("hook_target_unavailable", { target_stage = "class_table" })
            end

            return
        end

        if type(class.update) ~= "function" then
            if report_failure then
                emit("hook_target_unavailable", { target_stage = "update_method" })
            end

            return
        end

        local ok = pcall(services.hook_safe, class, "update", update)

        if not ok then
            if report_failure then
                emit("hook_registration_failed")
            end

            return
        end

        registered = true
    end

    return {
        on_all_mods_loaded = function()
            register(false)
        end,
        on_game_state_changed = function(status, state_name)
            if status == "enter" and state_name == "StateGameplay" then
                emitted_reasons = {}
                register(true)
            end
        end,
    }
end

return adapter
