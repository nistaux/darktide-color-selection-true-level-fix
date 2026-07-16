local tests = {}

local function test(name, body)
    tests[#tests + 1] = {
        name = name,
        body = body,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assert_safe(result, reason, metadata)
    assert_equal(result.outcome, "safe_no_change")
    assert_equal(result.replacement, nil)
    assert_equal(result.reason, reason)

    if metadata then
        for key, value in pairs(metadata) do
            assert_equal(result.metadata and result.metadata[key], value, "metadata " .. key)
        end
    else
        assert_equal(result.metadata, nil)
    end
end

local splice = dofile("color_selection_true_level_fix/scripts/mods/color_selection_true_level_fix/splice.lua")
local adapter = dofile("color_selection_true_level_fix/scripts/mods/color_selection_true_level_fix/adapter.lua")

test("splices a reset after the exact profile name", function()
    local result = splice.apply("{#color(12,34,56)}Mara - Level 42", "Mara")

    assert_equal(result.outcome, "splice")
    assert_equal(result.replacement, "{#color(12,34,56)}Mara{#reset()} - Level 42")
    assert_equal(result.reason, nil)
end)

test("leaves an exact reset boundary already compatible", function()
    local original = "{#color(12,34,56)}Mara{#reset()} - Level 42"
    local result = splice.apply(original, "Mara")

    assert_equal(result.outcome, "already_compatible")
    assert_equal(result.replacement, nil)
    assert_equal(result.reason, nil)
end)

test("implements the conservative splice recognition table", function()
    local accepted = {
        {
            label = "zero-valued color at end of string",
            composed = "{#color(0,0,0)}Mara",
            name = "Mara",
            replacement = "{#color(0,0,0)}Mara{#reset()}",
        },
        {
            label = "255-valued color and literal pattern characters",
            composed = "{#color(255,255,255)}A%.-[x] - suffix",
            name = "A%.-[x]",
            replacement = "{#color(255,255,255)}A%.-[x]{#reset()} - suffix",
        },
        {
            label = "delimiter-like text inside the full profile name",
            composed = "{#color(4,5,6)}Mara - Prime - Level 42",
            name = "Mara - Prime",
            replacement = "{#color(4,5,6)}Mara - Prime{#reset()} - Level 42",
        },
        {
            label = "first-line end with opaque later lines",
            composed = "{#color(1,2,3)}Mara\n{#color(9,8,7)}Title{#reset()}",
            name = "Mara",
            replacement = "{#color(1,2,3)}Mara{#reset()}\n{#color(9,8,7)}Title{#reset()}",
        },
        {
            label = "class icon bytes before the name",
            composed = "{#color(1,2,3)}[ICON] Mara - suffix",
            name = "Mara",
            replacement = "{#color(1,2,3)}[ICON] Mara{#reset()} - suffix",
        },
    }

    for _, case in ipairs(accepted) do
        local result = splice.apply(case.composed, case.name)
        assert_equal(result.outcome, "splice", case.label)
        assert_equal(result.replacement, case.replacement, case.label)
        assert_equal(result.reason, nil, case.label)
        assert_equal(result.metadata, nil, case.label)
    end

    local rejected = {
        {
            label = "missing composed nameplate",
            composed = nil,
            name = "Mara",
            reason = "leading_color_tag_unusable",
            metadata = { tag_stage = "missing" },
        },
        {
            label = "non-string composed nameplate",
            composed = {},
            name = "Mara",
            reason = "leading_color_tag_unusable",
            metadata = { tag_stage = "syntax" },
        },
        {
            label = "missing leading tag wins precedence",
            composed = "Mara Mara",
            name = "Mara",
            reason = "leading_color_tag_unusable",
            metadata = { tag_stage = "missing" },
        },
        {
            label = "malformed leading tag",
            composed = "{#color(1, 2,3)}Mara",
            name = "Mara",
            reason = "leading_color_tag_unusable",
            metadata = { tag_stage = "syntax" },
        },
        {
            label = "out-of-range leading tag",
            composed = "{#color(256,2,3)}Mara",
            name = "Mara",
            reason = "leading_color_tag_unusable",
            metadata = { tag_stage = "range" },
        },
        {
            label = "negative component is malformed",
            composed = "{#color(-1,2,3)}Mara",
            name = "Mara",
            reason = "leading_color_tag_unusable",
            metadata = { tag_stage = "syntax" },
        },
        {
            label = "empty profile name",
            composed = "{#color(1,2,3)}Mara",
            name = "",
            reason = "profile_name_not_found",
        },
        {
            label = "profile name absent",
            composed = "{#color(1,2,3)}Mara",
            name = "Sefoni",
            reason = "profile_name_not_found",
        },
        {
            label = "missing name precedes later owned-span markup",
            composed = "{#color(1,2,3)}{#size(20)}Mara - suffix",
            name = "Sefoni",
            reason = "profile_name_not_found",
        },
        {
            label = "profile name case differs",
            composed = "{#color(1,2,3)}Mara",
            name = "mara",
            reason = "profile_name_not_found",
        },
        {
            label = "profile name occurs twice",
            composed = "{#color(1,2,3)}Mara - Mara",
            name = "Mara",
            reason = "profile_name_ambiguous",
        },
        {
            label = "ambiguous name precedes owned-span markup",
            composed = "{#color(1,2,3)}{#size(20)}Mara - Mara",
            name = "Mara",
            reason = "profile_name_ambiguous",
        },
        {
            label = "owned span has additional markup",
            composed = "{#color(1,2,3)}{#size(20)}Mara - suffix",
            name = "Mara",
            reason = "owned_span_formatting_interrupted",
        },
        {
            label = "owned-span markup precedes an unusable boundary",
            composed = "{#color(1,2,3)}{#size(20)}Mara: suffix",
            name = "Mara",
            reason = "owned_span_formatting_interrupted",
        },
        {
            label = "unrecognized boundary",
            composed = "{#color(1,2,3)}Mara: suffix",
            name = "Mara",
            reason = "post_name_boundary_unusable",
        },
        {
            label = "reset-like boundary",
            composed = "{#color(1,2,3)}Mara{#reset( )} - suffix",
            name = "Mara",
            reason = "post_name_boundary_unusable",
        },
    }

    for _, case in ipairs(rejected) do
        assert_safe(splice.apply(case.composed, case.name), case.reason, case.metadata)
    end
end)

test("registers once and corrects a supported current nameplate while active", function()
    local color_selection = { enabled = true }
    local true_level = { enabled = true, nameplates_enabled = true }
    local class = { update = function() end }
    local hook_callback
    local hook_calls = 0
    local marker = {
        type = "nameplate_party",
        data = {
            profile = function()
                return { name = "Mara" }
            end,
        },
        widget = {
            content = {
                header_text = "{#color(12,34,56)}Mara - {#color(7,8,9)}42{#reset()}",
            },
        },
    }

    function color_selection:is_enabled()
        return self.enabled
    end

    function true_level:is_enabled()
        return self.enabled
    end

    function true_level:get(setting_id)
        assert_equal(setting_id, "enable_nameplate")
        return self.nameplates_enabled
    end

    local services = {
        get_mod = function(mod_id)
            if mod_id == "ColorSelection" then
                return color_selection
            end

            if mod_id == "true_level" then
                return true_level
            end
        end,
        get_nameplate_class = function()
            return class
        end,
        hook_safe = function(target, method_name, callback)
            hook_calls = hook_calls + 1
            assert_equal(target, class)
            assert_equal(method_name, "update")
            hook_callback = callback
        end,
        get_world_marker_map = function()
            return { [17] = marker }
        end,
        log_diagnostic = function()
            error("the happy path must not log")
        end,
    }

    local callbacks = adapter.new(services, splice)
    callbacks.on_all_mods_loaded()
    callbacks.on_all_mods_loaded()

    assert_equal(hook_calls, 1)
    assert_equal(type(hook_callback), "function")

    hook_callback({ _nameplate_units = { [{}] = { marker_id = 17 } } }, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(12,34,56)}Mara{#reset()} - {#color(7,8,9)}42{#reset()}")

    true_level.nameplates_enabled = false
    marker.widget.content.header_text = "{#color(12,34,56)}Mara - Level 42"
    hook_callback({ _nameplate_units = { [{}] = { marker_id = 17 } } }, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(12,34,56)}Mara - Level 42")

    true_level.nameplates_enabled = true
    hook_callback({ _nameplate_units = { [{}] = { marker_id = 17 } } }, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(12,34,56)}Mara{#reset()} - Level 42")
end)

test("preserves the True Level suffix across Color Selection 2.15 rewrites", function()
    local class = { update = function() end }
    local safe_update
    local marker = {
        type = "nameplate",
        data = {
            profile = function()
                return { name = "Mara" }
            end,
        },
        widget = {
            content = {
                header_text = "{#color(12,34,56)}[I] Mara{#reset()} - 30",
            },
        },
    }
    local enabled_mod = {
        is_enabled = function()
            return true
        end,
    }
    local true_level = {
        is_enabled = function()
            return true
        end,
        get = function(_, setting_id)
            assert_equal(setting_id, "enable_nameplate")
            return true
        end,
    }
    local services = {
        get_mod = function(mod_id)
            return mod_id == "ColorSelection" and enabled_mod or true_level
        end,
        get_nameplate_class = function()
            return class
        end,
        hook = function()
            error("the adapter must not consume its one DMF update-hook slot before the late safe hook")
        end,
        hook_safe = function(target, method_name, callback)
            assert_equal(target, class)
            assert_equal(method_name, "update")
            safe_update = callback
        end,
        get_world_marker_map = function()
            return { [17] = marker }
        end,
        log_diagnostic = function()
        end,
    }
    local callbacks = adapter.new(services, splice)
    local nameplates = { _nameplate_units = { { marker_id = 17 } } }
    local rich_suffix = "{#reset()} - {#color(7,8,9)}42{#reset()} {#color(9,8,7)}30{#reset()}\n{#color(4,5,6)}The Title{#reset()}"
    local rich = "{#color(12,34,56)}[I] Mara" .. rich_suffix

    callbacks.on_all_mods_loaded()
    assert_equal(type(safe_update), "function")

    marker.widget.content.header_text = rich
    safe_update(nameplates, 0, 0)
    assert_equal(marker.widget.content.header_text, rich)

    marker.widget.content.header_text = "{#color(99,88,77)}[I] Mara{#reset()} - 42 30\n{#color(4,5,6)}The Title{#reset()}"
    safe_update(nameplates, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(99,88,77)}[I] Mara" .. rich_suffix)

    marker.widget.content.header_text = "{#color(99,88,77)}[I] Mara / changed"
    safe_update(nameplates, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(99,88,77)}[I] Mara / changed")

    marker.widget.content.header_text = "{#color(99,88,77)}[I] Mara{#reset()} - 42 30\n{#color(4,5,6)}The Title{#reset()}"
    safe_update(nameplates, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(99,88,77)}[I] Mara{#reset()} - 42 30\n{#color(4,5,6)}The Title{#reset()}")

    marker.widget.content.header_text = rich
    safe_update(nameplates, 0, 0)

    marker.widget.content.header_text = "{#color(99,88,77)}[I] Mara{#reset()} - 43 30\n{#color(4,5,6)}The Title{#reset()}"
    safe_update(nameplates, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(99,88,77)}[I] Mara{#reset()} - 43 30\n{#color(4,5,6)}The Title{#reset()}")

    marker.widget.content.header_text = "{#color(99,88,77)}[I] Mara{#reset()} - 42 30\n{#color(4,5,6)}The Title{#reset()}"
    safe_update(nameplates, 0, 0)
    assert_equal(marker.widget.content.header_text, "{#color(99,88,77)}[I] Mara{#reset()} - 42 30\n{#color(4,5,6)}The Title{#reset()}")
end)

test("does not reuse a cached rich suffix after a marker changes profile", function()
    local class = { update = function() end }
    local safe_update
    local profile_name = "Mara"
    local marker = {
        type = "nameplate",
        data = {
            profile = function()
                return { name = profile_name }
            end,
        },
        widget = { content = {} },
    }
    local enabled_mod = { is_enabled = function() return true end }
    local callbacks = adapter.new({
        get_mod = function(mod_id)
            if mod_id == "ColorSelection" then
                return enabled_mod
            end

            return { is_enabled = function() return true end, get = function() return true end }
        end,
        get_nameplate_class = function()
            return class
        end,
        hook_safe = function(_, _, callback)
            safe_update = callback
        end,
        get_world_marker_map = function()
            return { [17] = marker }
        end,
        log_diagnostic = function()
        end,
    }, splice)
    local nameplates = { _nameplate_units = { { marker_id = 17 } } }

    callbacks.on_all_mods_loaded()
    marker.widget.content.header_text = "{#color(1,2,3)}Mara{#reset()} - {#color(7,8,9)}42{#reset()}"
    safe_update(nameplates)

    marker.data = { profile = function() return { name = "Mara" } end }
    marker.widget.content.header_text = "{#color(1,2,3)}Mara{#reset()} - 42"
    safe_update(nameplates)
    assert_equal(marker.widget.content.header_text, "{#color(1,2,3)}Mara{#reset()} - 42")

    profile_name = "Sefoni"
    marker.data = { profile = function() return { name = profile_name } end }
    marker.widget.content.header_text = "{#color(1,2,3)}Sefoni{#reset()} - 42"
    safe_update(nameplates)

    profile_name = "Mara"
    marker.widget.content.header_text = "{#color(1,2,3)}Mara{#reset()} - 42"
    safe_update(nameplates)
    assert_equal(marker.widget.content.header_text, "{#color(1,2,3)}Mara{#reset()} - 42")
end)

test("restores a numeric profile name without matching the leading color tag", function()
    local safe_update
    local marker = {
        type = "nameplate",
        data = { profile = function() return { name = "12" } end },
        widget = { content = {} },
    }
    local enabled_mod = { is_enabled = function() return true end }
    local callbacks = adapter.new({
        get_mod = function(mod_id)
            if mod_id == "ColorSelection" then
                return enabled_mod
            end

            return { is_enabled = function() return true end, get = function() return true end }
        end,
        get_nameplate_class = function()
            return { update = function() end }
        end,
        hook_safe = function(_, _, callback)
            safe_update = callback
        end,
        get_world_marker_map = function()
            return { [1] = marker }
        end,
        log_diagnostic = function()
        end,
    }, splice)
    local nameplates = { _nameplate_units = { { marker_id = 1 } } }

    callbacks.on_all_mods_loaded()
    marker.widget.content.header_text = "{#color(12,34,56)}[I] 12{#reset()} - {#color(7,8,9)}42{#reset()}"
    safe_update(nameplates)
    marker.widget.content.header_text = "{#color(99,88,77)}[I] 12{#reset()} - 42"
    safe_update(nameplates)

    assert_equal(marker.widget.content.header_text, "{#color(99,88,77)}[I] 12{#reset()} - {#color(7,8,9)}42{#reset()}")
end)

test("isolates candidates and suppresses redacted diagnostics per World Visit", function()
    local class = { update = function() end }
    local hook_callback
    local diagnostics = {}
    local good_content = {
        header_text = "{#color(1,2,3)}Mara - Level 42",
    }
    local markers = {
        [1] = {
            type = "nameplate_party",
            data = {
                profile = function()
                    error("SECRET_PLAYER_DERIVED_FAILURE")
                end,
            },
            widget = { content = { header_text = "{#color(1,2,3)}Hidden - Level 1" } },
        },
        [2] = {
            type = "nameplate",
            data = {
                profile = function()
                    error("ANOTHER_SECRET")
                end,
            },
            widget = { content = { header_text = "{#color(1,2,3)}Private - Level 2" } },
        },
        [3] = {
            type = "nameplate_party",
            data = {
                profile = function()
                    return { name = "Mara" }
                end,
            },
            widget = { content = good_content },
        },
    }
    local enabled_mod = {
        is_enabled = function()
            return true
        end,
    }
    local true_level = {
        is_enabled = function()
            return true
        end,
        get = function(_, setting_id)
            assert_equal(setting_id, "enable_nameplate")
            return true
        end,
    }
    local services = {
        get_mod = function(mod_id)
            return mod_id == "ColorSelection" and enabled_mod or true_level
        end,
        get_nameplate_class = function()
            return class
        end,
        hook_safe = function(_, _, callback)
            hook_callback = callback
        end,
        get_world_marker_map = function()
            return markers
        end,
        log_diagnostic = function(reason, metadata)
            diagnostics[#diagnostics + 1] = { reason = reason, metadata = metadata }
        end,
    }
    local callbacks = adapter.new(services, splice)
    local nameplates = {
        _nameplate_units = {
            { marker_id = 1 },
            { marker_id = 2 },
            { marker_id = 3 },
        },
    }

    callbacks.on_all_mods_loaded()
    local ok = pcall(hook_callback, nameplates, 0, 0)
    assert_equal(ok, true, "candidate failure escaped the adapter")
    assert_equal(good_content.header_text, "{#color(1,2,3)}Mara{#reset()} - Level 42")
    assert_equal(#diagnostics, 1)
    assert_equal(diagnostics[1].reason, "candidate_processing_exception")
    assert_equal(diagnostics[1].metadata.processing_stage, "profile_lookup")

    hook_callback(nameplates, 0, 0)
    assert_equal(#diagnostics, 1, "same reason logged twice in one World Visit")

    callbacks.on_game_state_changed("enter", "StateGameplay")
    hook_callback(nameplates, 0, 0)
    assert_equal(#diagnostics, 2, "new World Visit did not reset suppression")
    assert_equal(diagnostics[2].reason, "candidate_processing_exception")
end)

test("retries direct hook registration at gameplay entry without stacking hooks", function()
    local target
    local hook_should_throw = false
    local hook_attempts = 0
    local diagnostics = {}
    local services = {
        get_mod = function()
        end,
        get_nameplate_class = function()
            return target
        end,
        hook_safe = function(_, _, _)
            hook_attempts = hook_attempts + 1

            if hook_should_throw then
                error("PRIVATE_REGISTRATION_FAILURE")
            end
        end,
        get_world_marker_map = function()
            return {}
        end,
        log_diagnostic = function(reason, metadata)
            diagnostics[#diagnostics + 1] = { reason = reason, metadata = metadata }
        end,
    }
    local callbacks = adapter.new(services, splice)

    assert_equal(pcall(callbacks.on_all_mods_loaded), true)
    assert_equal(hook_attempts, 0)
    assert_equal(#diagnostics, 0, "initial registration miss must be silent")

    callbacks.on_game_state_changed("enter", "StateGameplay")
    assert_equal(#diagnostics, 1)
    assert_equal(diagnostics[1].reason, "hook_target_unavailable")
    assert_equal(diagnostics[1].metadata.target_stage, "class_table")

    target = { update = false }
    callbacks.on_game_state_changed("enter", "StateGameplay")
    assert_equal(#diagnostics, 2)
    assert_equal(diagnostics[2].reason, "hook_target_unavailable")
    assert_equal(diagnostics[2].metadata.target_stage, "update_method")

    target.update = function() end
    hook_should_throw = true
    callbacks.on_game_state_changed("enter", "StateGameplay")
    assert_equal(hook_attempts, 1)
    assert_equal(#diagnostics, 3)
    assert_equal(diagnostics[3].reason, "hook_registration_failed")

    hook_should_throw = false
    callbacks.on_game_state_changed("enter", "StateGameplay")
    assert_equal(hook_attempts, 2)
    assert_equal(#diagnostics, 3)

    callbacks.on_all_mods_loaded()
    callbacks.on_game_state_changed("enter", "StateGameplay")
    assert_equal(hook_attempts, 2, "successful registration was attempted again")
    assert_equal(#diagnostics, 3)
end)

test("registers after the delayed nameplate class becomes ready", function()
    local class = { new = function() end, update = function() end }
    local require_callback
    local new_callback
    local new_hook_calls = 0
    local safe_hook_calls = 0
    local prior_new_called = false
    local diagnostics = {}
    local services = {
        get_mod = function()
        end,
        get_nameplate_class = function()
            return class
        end,
        hook_require = function(path, callback)
            assert_equal(path, "scripts/ui/hud/elements/nameplates/hud_element_nameplates")
            require_callback = callback
        end,
        hook = function(target, method_name, callback)
            assert_equal(target, class)

            if method_name == "new" then
                new_hook_calls = new_hook_calls + 1
                new_callback = callback
            else
                error("unexpected hook method")
            end
        end,
        hook_safe = function(target, method_name, _)
            assert_equal(prior_new_called, true, "update hook registered before dependency hooks drained")
            assert_equal(target, class)
            assert_equal(method_name, "update")
            safe_hook_calls = safe_hook_calls + 1
        end,
        get_world_marker_map = function()
            return {}
        end,
        log_diagnostic = function(reason)
            diagnostics[#diagnostics + 1] = reason
        end,
    }
    local callbacks = adapter.new(services, splice)

    callbacks.on_all_mods_loaded()
    assert_equal(type(require_callback), "function")
    assert_equal(safe_hook_calls, 0)

    callbacks.on_game_state_changed("enter", "StateGameplay")
    assert_equal(#diagnostics, 0, "expected class readiness delay emitted a diagnostic")

    require_callback(class)
    require_callback(class)
    assert_equal(type(new_callback), "function")
    assert_equal(new_hook_calls, 1, "same delivered class installed more than one constructor watcher")
    assert_equal(safe_hook_calls, 0)

    local instance = {}
    local function pack(...)
        return { n = select("#", ...), ... }
    end
    local returns = pack(new_callback(function()
        prior_new_called = true
        return instance, nil, "constructor sentinel"
    end))
    assert_equal(returns.n, 3)
    assert_equal(returns[1], instance)
    assert_equal(returns[2], nil)
    assert_equal(returns[3], "constructor sentinel")
    assert_equal(safe_hook_calls, 1)

    new_callback(function()
        return {}
    end)
    assert_equal(safe_hook_calls, 1, "class-ready registration stacked hooks")
end)

test("registers the late update hook for a replacement nameplate class", function()
    local first_class = { new = function() end, update = function() end }
    local second_class = { new = function() end, update = function() end }
    local require_callback
    local new_callbacks = {}
    local safe_targets = {}
    local callbacks = adapter.new({
        get_mod = function()
        end,
        hook_require = function(_, callback)
            require_callback = callback
        end,
        hook = function(target, method_name, callback)
            assert_equal(method_name, "new")
            new_callbacks[target] = callback
        end,
        hook_safe = function(target, method_name)
            assert_equal(method_name, "update")
            safe_targets[#safe_targets + 1] = target
        end,
        get_world_marker_map = function()
            return {}
        end,
        log_diagnostic = function()
        end,
    }, splice)

    callbacks.on_all_mods_loaded()
    require_callback(first_class)
    new_callbacks[first_class](function() return {} end)
    require_callback(second_class)
    assert_equal(type(new_callbacks[second_class]), "function")
    new_callbacks[second_class](function() return {} end)

    assert_equal(#safe_targets, 2)
    assert_equal(safe_targets[1], first_class)
    assert_equal(safe_targets[2], second_class)
end)

test("reports and retries a class-ready update-hook registration failure", function()
    local class = { new = function() end, update = function() end }
    local require_callback
    local new_callback
    local safe_hook_calls = 0
    local diagnostics = {}
    local services = {
        get_mod = function()
        end,
        hook_require = function(_, callback)
            require_callback = callback
        end,
        hook = function(_, method_name, callback)
            assert_equal(method_name, "new")
            new_callback = callback
        end,
        hook_safe = function()
            safe_hook_calls = safe_hook_calls + 1

            if safe_hook_calls == 1 then
                error("PRIVATE_REGISTRATION_FAILURE")
            end
        end,
        get_world_marker_map = function()
            return {}
        end,
        log_diagnostic = function(reason)
            diagnostics[#diagnostics + 1] = reason
        end,
    }
    local callbacks = adapter.new(services, splice)

    callbacks.on_all_mods_loaded()
    require_callback(class)
    new_callback(function() return {} end)
    assert_equal(safe_hook_calls, 1)
    assert_equal(diagnostics[1], "hook_registration_failed")

    new_callback(function() return {} end)
    assert_equal(safe_hook_calls, 2)

    new_callback(function() return {} end)
    assert_equal(safe_hook_calls, 2, "successful retry was attempted again")
end)

test("evaluates every Activation Condition input from current public mod state", function()
    local cases = {
        { label = "Color Selection absent", color_state = "absent" },
        { label = "Color Selection disabled", color_state = false },
        { label = "Color Selection state invalid", color_state = "invalid", reason_stage = "color_selection_state" },
        { label = "Color Selection state throws", color_state = "throws", reason_stage = "color_selection_state" },
        { label = "True Level absent", color_state = true, true_level_state = "absent" },
        { label = "True Level disabled", color_state = true, true_level_state = false },
        { label = "True Level state invalid", color_state = true, true_level_state = "invalid", reason_stage = "true_level_state" },
        { label = "True Level state throws", color_state = true, true_level_state = "throws", reason_stage = "true_level_state" },
        { label = "nameplate setting false", color_state = true, true_level_state = true, setting = false },
        { label = "nameplate setting invalid", color_state = true, true_level_state = true, setting = "invalid", reason_stage = "nameplate_setting" },
        { label = "nameplate setting throws", color_state = true, true_level_state = true, setting = "throws", reason_stage = "nameplate_setting" },
    }

    for _, case in ipairs(cases) do
        local diagnostics = {}
        local hook_callback
        local header = "{#color(1,2,3)}Mara - Level 42"
        local color_selection
        local true_level

        if case.color_state ~= "absent" then
            color_selection = {
                is_enabled = function()
                    if case.color_state == "throws" then
                        error("PRIVATE_COLOR_STATE")
                    end

                    if case.color_state == "invalid" then
                        return "yes"
                    end

                    return case.color_state
                end,
            }
        end

        if case.true_level_state ~= "absent" then
            true_level = {
                is_enabled = function()
                    if case.true_level_state == "throws" then
                        error("PRIVATE_TRUE_LEVEL_STATE")
                    end

                    if case.true_level_state == "invalid" then
                        return 1
                    end

                    return case.true_level_state
                end,
                get = function()
                    if case.setting == "throws" then
                        error("PRIVATE_SETTING")
                    end

                    if case.setting == "invalid" then
                        return "true"
                    end

                    return case.setting
                end,
            }
        end

        local callbacks = adapter.new({
            get_mod = function(mod_id)
                if mod_id == "ColorSelection" then
                    return color_selection
                end

                return true_level
            end,
            get_nameplate_class = function()
                return { update = function() end }
            end,
            hook_safe = function(_, _, callback)
                hook_callback = callback
            end,
            get_world_marker_map = function()
                return {
                    [1] = {
                        type = "nameplate",
                        data = { profile = function() return { name = "Mara" } end },
                        widget = { content = setmetatable({}, {
                            __index = function(_, key)
                                if key == "header_text" then
                                    return header
                                end
                            end,
                            __newindex = function(_, key, value)
                                if key == "header_text" then
                                    header = value
                                end
                            end,
                        }) },
                    },
                }
            end,
            log_diagnostic = function(reason, metadata)
                diagnostics[#diagnostics + 1] = { reason = reason, metadata = metadata }
            end,
        }, splice)

        callbacks.on_all_mods_loaded()
        local ok = pcall(hook_callback, { _nameplate_units = { { marker_id = 1 } } }, 0, 0)
        assert_equal(ok, true, case.label)
        assert_equal(header, "{#color(1,2,3)}Mara - Level 42", case.label)

        if case.reason_stage then
            assert_equal(#diagnostics, 1, case.label)
            assert_equal(diagnostics[1].reason, "activation_state_unreadable", case.label)
            assert_equal(diagnostics[1].metadata.activation_stage, case.reason_stage, case.label)
        else
            assert_equal(#diagnostics, 0, case.label)
        end
    end
end)

test("classifies unusable structures and skips normal unresolved candidates", function()
    local enabled_mod = { is_enabled = function() return true end }
    local true_level = {
        is_enabled = function() return true end,
        get = function() return true end,
    }

    local function run_case(marker, nameplate_units, marker_map_override)
        local diagnostics = {}
        local hook_callback
        local callbacks = adapter.new({
            get_mod = function(mod_id)
                if mod_id == "ColorSelection" then
                    return enabled_mod
                end

                return true_level
            end,
            get_nameplate_class = function()
                return { update = function() end }
            end,
            hook_safe = function(_, _, callback)
                hook_callback = callback
            end,
            get_world_marker_map = function()
                if marker_map_override ~= nil then
                    return marker_map_override
                end

                return { [1] = marker }
            end,
            log_diagnostic = function(reason, metadata)
                diagnostics[#diagnostics + 1] = { reason = reason, metadata = metadata }
            end,
        }, splice)

        callbacks.on_all_mods_loaded()
        local ok = pcall(hook_callback, {
            _nameplate_units = nameplate_units == nil and { { marker_id = 1 } } or nameplate_units,
        }, 0, 0)

        return ok, diagnostics
    end

    local cases = {
        {
            label = "unresolved marker",
            marker = nil,
        },
        {
            label = "unresolved player data",
            marker = { type = "nameplate", data = nil, widget = {} },
        },
        {
            label = "unfinished widget",
            marker = { type = "nameplate", data = {}, widget = nil },
        },
        {
            label = "missing header",
            marker = { type = "nameplate", data = {}, widget = { content = {} } },
        },
        {
            label = "empty header",
            marker = { type = "nameplate", data = {}, widget = { content = { header_text = "" } } },
        },
        {
            label = "companion marker",
            marker = { type = "nameplate_companion", data = {}, widget = false },
        },
        {
            label = "non-nameplate marker",
            marker = { type = "objective", data = {}, widget = false },
        },
        {
            label = "non-string header",
            marker = { type = "nameplate", data = {}, widget = { content = { header_text = 42 } } },
            reason = "composed_nameplate_unusable",
        },
        {
            label = "missing profile accessor",
            marker = { type = "nameplate", data = {}, widget = { content = { header_text = "{#color(1,2,3)}Mara" } } },
            reason = "profile_name_unavailable",
            metadata_key = "profile_stage",
            metadata_value = "profile_accessor",
        },
        {
            label = "missing profile record",
            marker = { type = "nameplate", data = { profile = function() end }, widget = { content = { header_text = "{#color(1,2,3)}Mara" } } },
            reason = "profile_name_unavailable",
            metadata_key = "profile_stage",
            metadata_value = "profile_record",
        },
        {
            label = "invalid profile name",
            marker = { type = "nameplate", data = { profile = function() return { name = 42 } end }, widget = { content = { header_text = "{#color(1,2,3)}Mara" } } },
            reason = "profile_name_unavailable",
            metadata_key = "profile_stage",
            metadata_value = "name_value",
        },
        {
            label = "core Safe No-Change",
            marker = { type = "nameplate", data = { profile = function() return { name = "Mara" } end }, widget = { content = { header_text = "Mara" } } },
            reason = "leading_color_tag_unusable",
            metadata_key = "tag_stage",
            metadata_value = "missing",
        },
    }

    for _, case in ipairs(cases) do
        local ok, diagnostics = run_case(case.marker)
        assert_equal(ok, true, case.label)

        if case.reason then
            assert_equal(#diagnostics, 1, case.label)
            assert_equal(diagnostics[1].reason, case.reason, case.label)

            if case.metadata_key then
                assert_equal(diagnostics[1].metadata[case.metadata_key], case.metadata_value, case.label)
            end
        else
            assert_equal(#diagnostics, 0, case.label)
        end
    end

    local units_ok, units_diagnostics = run_case({}, "wrong")
    assert_equal(units_ok, true)
    assert_equal(units_diagnostics[1].reason, "nameplate_structure_unusable")
    assert_equal(units_diagnostics[1].metadata.structure_stage, "nameplate_units")

    local markers_ok, marker_diagnostics = run_case({}, {}, "wrong")
    assert_equal(markers_ok, true)
    assert_equal(marker_diagnostics[1].reason, "nameplate_structure_unusable")
    assert_equal(marker_diagnostics[1].metadata.structure_stage, "world_marker_map")
end)

test("assigns only Splice results and reuses current candidate state", function()
    local hook_callback
    local assignments = 0
    local header = "{#color(1,2,3)}Mara - Level 42"
    local profile_name = "Mara"
    local content = setmetatable({}, {
        __index = function(_, key)
            if key == "header_text" then
                return header
            end
        end,
        __newindex = function(_, key, value)
            if key == "header_text" then
                assignments = assignments + 1
                header = value
            end
        end,
    })
    local marker = {
        type = "nameplate_party",
        data = {
            profile = function()
                return { name = profile_name }
            end,
        },
        widget = { content = content },
    }
    local enabled_mod = { is_enabled = function() return true end }
    local callbacks = adapter.new({
        get_mod = function(mod_id)
            if mod_id == "ColorSelection" then
                return enabled_mod
            end

            return {
                is_enabled = function() return true end,
                get = function() return true end,
            }
        end,
        get_nameplate_class = function()
            return { update = function() end }
        end,
        hook_safe = function(_, _, callback)
            hook_callback = callback
        end,
        get_world_marker_map = function()
            return { [1] = marker }
        end,
        log_diagnostic = function()
        end,
    }, splice)
    local nameplates = { _nameplate_units = { { marker_id = 1 } } }

    callbacks.on_all_mods_loaded()
    hook_callback(nameplates, 0, 0)
    hook_callback(nameplates, 0, 0)
    assert_equal(assignments, 1, "Already Compatible result assigned again")

    header = "{#color(4,5,6)}Sefoni - Level 30"
    profile_name = "Sefoni"
    hook_callback(nameplates, 0, 0)
    assert_equal(assignments, 2, "current profile/header state was not reevaluated")
    assert_equal(header, "{#color(4,5,6)}Sefoni{#reset()} - Level 30")

    header = "unrecognized"
    hook_callback(nameplates, 0, 0)
    assert_equal(assignments, 2, "Safe No-Change result assigned")

    profile_name = "Mara"
    header = "{#color(1,2,3)}Mara{#reset()} - {#color(7,8,9)}42{#reset()}"
    hook_callback(nameplates, 0, 0)
    local assignments_before_restore = assignments

    header = "{#color(4,5,6)}Mara - 42"
    hook_callback(nameplates, 0, 0)
    assert_equal(assignments, assignments_before_restore + 1, "one restore frame assigned more than once")
    assert_equal(header, "{#color(4,5,6)}Mara{#reset()} - {#color(7,8,9)}42{#reset()}")
end)

local passed = 0
local failures = {}

for _, case in ipairs(tests) do
    local ok, failure = pcall(case.body)

    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = case.name .. ": " .. tostring(failure)
    end
end

if #failures > 0 then
    for _, failure in ipairs(failures) do
        io.stderr:write("FAIL: " .. failure .. "\n")
    end

    io.stderr:write(string.format("%d passed, %d failed\n", passed, #failures))
    os.exit(1)
end

print(string.format("%d passed, 0 failed", passed))
