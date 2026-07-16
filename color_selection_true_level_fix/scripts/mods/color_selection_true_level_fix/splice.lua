local RESET_TAG = "{#reset()}"

local splice = {}

local function safe_no_change(reason, metadata)
    return {
        outcome = "safe_no_change",
        reason = reason,
        metadata = metadata,
    }
end

local function leading_tag(composed_nameplate)
    if composed_nameplate == nil then
        return nil, safe_no_change("leading_color_tag_unusable", { tag_stage = "missing" })
    end

    if type(composed_nameplate) ~= "string" then
        return nil, safe_no_change("leading_color_tag_unusable", { tag_stage = "syntax" })
    end

    if string.sub(composed_nameplate, 1, 7) ~= "{#color" then
        return nil, safe_no_change("leading_color_tag_unusable", { tag_stage = "missing" })
    end

    local _, tag_end, red, green, blue = string.find(composed_nameplate, "^{#color%((%d+),(%d+),(%d+)%)%}")

    if not tag_end then
        return nil, safe_no_change("leading_color_tag_unusable", { tag_stage = "syntax" })
    end

    if tonumber(red) > 255 or tonumber(green) > 255 or tonumber(blue) > 255 then
        return nil, safe_no_change("leading_color_tag_unusable", { tag_stage = "range" })
    end

    return tag_end, nil
end

function splice.apply(composed_nameplate, profile_name)
    local tag_end, tag_failure = leading_tag(composed_nameplate)

    if tag_failure then
        return tag_failure
    end

    if type(profile_name) ~= "string" or #profile_name == 0 then
        return safe_no_change("profile_name_not_found")
    end

    local newline_start = string.find(composed_nameplate, "\n", 1, true)
    local first_line_end = newline_start and newline_start - 1 or #composed_nameplate
    local name_start, name_end = string.find(composed_nameplate, profile_name, tag_end + 1, true)

    if not name_start or name_end > first_line_end then
        return safe_no_change("profile_name_not_found")
    end

    local next_name_start, next_name_end = string.find(composed_nameplate, profile_name, name_start + 1, true)

    if next_name_start and next_name_end <= first_line_end then
        return safe_no_change("profile_name_ambiguous")
    end

    local extra_markup_start = string.find(composed_nameplate, "{#", tag_end + 1, true)

    if extra_markup_start and extra_markup_start <= name_end then
        return safe_no_change("owned_span_formatting_interrupted")
    end

    local boundary_start = name_end + 1

    if string.sub(composed_nameplate, boundary_start, boundary_start + #RESET_TAG - 1) == RESET_TAG then
        return {
            outcome = "already_compatible",
        }
    end

    if boundary_start <= first_line_end and string.sub(composed_nameplate, boundary_start, boundary_start + 2) ~= " - " then
        return safe_no_change("post_name_boundary_unusable")
    end

    return {
        outcome = "splice",
        replacement = string.sub(composed_nameplate, 1, name_end) .. RESET_TAG .. string.sub(composed_nameplate, boundary_start),
    }
end

return splice
