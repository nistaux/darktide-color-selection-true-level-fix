local adapter = {}
local unpack_values = unpack or table.unpack

local function pack_values(...)
    return { n = select("#", ...), ... }
end

local function weak_key_table()
    return setmetatable({}, { __mode = "k" })
end

local function split_at_name(composed_nameplate, profile_name)
    local leading_tag_end = string.find(composed_nameplate, "}", 1, true)

    if not leading_tag_end then
        return nil, nil
    end

    local name_start, name_end = string.find(composed_nameplate, profile_name, leading_tag_end + 1, true)

    if not name_start then
        return nil, nil
    end

    return string.sub(composed_nameplate, 1, name_end), string.sub(composed_nameplate, name_end + 1)
end

local function first_line_has_color(suffix)
    local newline = string.find(suffix, "\n", 1, true)
    local first_line = newline and string.sub(suffix, 1, newline - 1) or suffix

    return string.find(first_line, "{#color%(%d+,%d+,%d+%)}") ~= nil
end

local function visible_suffix(suffix)
    local newline = string.find(suffix, "\n", 1, true)
    local first_line = newline and string.sub(suffix, 1, newline - 1) or suffix
    local later_lines = newline and string.sub(suffix, newline) or ""

    first_line = string.gsub(first_line, "{#color%(%d+,%d+,%d+%)}", "")
    first_line = string.gsub(first_line, "{#reset%(%)}", "")

    return first_line .. later_lines
end

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

    local cached = context.rich_suffixes[marker]

    if cached and (cached.profile_name ~= profile_name or cached.player ~= player) then
        context.rich_suffixes[marker] = nil
        cached = nil
    end

    context.processing_stage = "replacement_build"
    local splice_ok, result = pcall(context.splice.apply, composed_nameplate, profile_name)

    if not splice_ok or type(result) ~= "table" then
        error("splice failed")
    end

    local compatible_nameplate

    if result.outcome == "splice" then
        if type(result.replacement) ~= "string" then
            error("splice replacement unavailable")
        end

        compatible_nameplate = result.replacement
    elseif result.outcome == "safe_no_change" then
        context.emit(result.reason, result.metadata)
        return
    elseif result.outcome == "already_compatible" then
        compatible_nameplate = composed_nameplate
    elseif result.outcome ~= "already_compatible" then
        error("splice outcome unavailable")
    end

    local current_prefix, current_suffix = split_at_name(compatible_nameplate, profile_name)

    if current_prefix and first_line_has_color(current_suffix) then
        context.rich_suffixes[marker] = {
            player = player,
            profile_name = profile_name,
            suffix = current_suffix,
        }
    elseif current_prefix then
        cached = context.rich_suffixes[marker]

        if cached
            and cached.player == player
            and cached.profile_name == profile_name
            and visible_suffix(cached.suffix) == visible_suffix(current_suffix)
        then
            compatible_nameplate = current_prefix .. cached.suffix
        elseif cached then
            context.rich_suffixes[marker] = nil
        end
    end

    if content.header_text ~= compatible_nameplate then
        context.processing_stage = "assignment"
        content.header_text = compatible_nameplate
    end
end

function adapter.new(services, splice)
    local registered = false
    local watching_for_class = false
    local emitted_reasons = {}
    local rich_suffixes = weak_key_table()
    local activation_was_true = false

    local function reset_caches()
        rich_suffixes = weak_key_table()
    end

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
        rich_suffixes = rich_suffixes,
    }

    local function update(nameplates)
        if not active() then
            if activation_was_true then
                reset_caches()
                candidate_context.rich_suffixes = rich_suffixes
                activation_was_true = false
            end

            return
        end

        activation_was_true = true

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

    local function register(report_failure, known_class)
        if registered then
            return
        end

        local target_ok, class = true, known_class

        if class == nil then
            target_ok, class = pcall(services.get_nameplate_class)
        end

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

    local function watch_for_class()
        if watching_for_class
            or type(services.hook_require) ~= "function"
            or type(services.hook) ~= "function"
        then
            return
        end

        local ok = pcall(
            services.hook_require,
            "scripts/ui/hud/elements/nameplates/hud_element_nameplates",
            function(class)
                if registered then
                    return
                end

                if type(class) ~= "table" then
                    emit("hook_target_unavailable", { target_stage = "class_table" })
                    return
                end

                if type(class.new) ~= "function" then
                    emit("hook_target_unavailable", { target_stage = "new_method" })
                    return
                end

                local hook_ok = pcall(services.hook, class, "new", function(func, ...)
                    local results = pack_values(func(...))

                    register(true, class)

                    return unpack_values(results, 1, results.n)
                end)

                if not hook_ok then
                    emit("hook_registration_failed")
                end
            end
        )

        if ok then
            watching_for_class = true
        end
    end

    return {
        on_all_mods_loaded = function()
            watch_for_class()

            if not watching_for_class then
                register(false)
            end
        end,
        on_game_state_changed = function(status, state_name)
            if status == "enter" and state_name == "StateGameplay" then
                emitted_reasons = {}
                reset_caches()
                candidate_context.rich_suffixes = rich_suffixes
                activation_was_true = false
                if not watching_for_class then
                    register(true)
                end
            end
        end,
    }
end

return adapter
