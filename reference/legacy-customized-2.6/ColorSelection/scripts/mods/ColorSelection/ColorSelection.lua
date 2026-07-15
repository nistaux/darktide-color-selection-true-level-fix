local mod = get_mod("ColorSelection")

local UISettings = require("scripts/settings/ui/ui_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local CONSTANTS = {
	MAX_PLAYERS_PER_PAGE = 14,
	MAX_COLOR_VALUE = 255,
	UUID_LENGTH_WITH_HYPHENS = 36,
	UUID_LENGTH_WITHOUT_HYPHENS = 32,
	SLIDER_HOLD_DELAY = 0.5,
	PLAYER_CHECK_INTERVAL = 1.0,
	SWATCH_SIZE = {30, 20},
	LINE_HEIGHT = 30
}

-- Default hub color: terminal_text_body (pale greenish/yellowish)
-- RGB(169, 191, 153) - the default color for player names in hub panels
local DEFAULT_HUB_COLOR = {255, 169, 191, 153}

-- Build color presets table from Color.list
local color_presets = {}
for _, name in ipairs(Color.list or {}) do
    local c = Color[name](255, true) -- {a,r,g,b}
    color_presets[#color_presets+1] = { id = name, name = name, r = c[2], g = c[3], b = c[4] }
end
table.sort(color_presets, function(a,b) return a.name < b.name end)

local ColorUtils = {}

function ColorUtils.normalize_to_rgb(color)
	if not color or type(color) ~= "table" then
		return {r = CONSTANTS.MAX_COLOR_VALUE, g = CONSTANTS.MAX_COLOR_VALUE, b = CONSTANTS.MAX_COLOR_VALUE}
	end
	
	if color.r and color.g and color.b then
		return {
			r = math.clamp(color.r or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			g = math.clamp(color.g or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			b = math.clamp(color.b or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE)
		}
	elseif color[1] and color[2] and color[3] then

		return {
			r = math.clamp(color[2] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			g = math.clamp(color[3] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			b = math.clamp(color[4] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE)
		}
	end
	
	return {r = CONSTANTS.MAX_COLOR_VALUE, g = CONSTANTS.MAX_COLOR_VALUE, b = CONSTANTS.MAX_COLOR_VALUE}
end

function ColorUtils.rgb_to_argb(rgb)
	return {CONSTANTS.MAX_COLOR_VALUE, rgb.r, rgb.g, rgb.b}
end

function ColorUtils.argb_to_rgb(argb)
	return {
		r = argb[2] or CONSTANTS.MAX_COLOR_VALUE,
		g = argb[3] or CONSTANTS.MAX_COLOR_VALUE,
		b = argb[4] or CONSTANTS.MAX_COLOR_VALUE
	}
end

mod._player_custom_colors = {}
mod._local_player_account_id = nil  -- Store local player's account ID

mod.account_id_color_map = mod:persistent_table("account_id_color_map")

-- Default color values for each slot (base game colors)
function mod.get_default_color_value(prefix, component)
	local defaults = {
		slot1 = {r = 226, g = 210, b = 117},  -- Slot 1: Yellow
		slot2 = {r = 180, g = 88, b = 108},  -- Slot 2: Magenta/Pinkish-Red
		slot3 = {r = 84, g = 172, b = 121},  -- Slot 3: Green
		slot4 = {r = 126, g = 153, b = 230}, -- Slot 4: Blue
		bot = {r = 128, g = 128, b = 128},     -- Bot: Gray
	}
	
	local color_data = defaults[prefix]
	if color_data and component then
		return color_data[component] or CONSTANTS.MAX_COLOR_VALUE
	end
	
	return CONSTANTS.MAX_COLOR_VALUE
end

-- Update local player account ID (call this whenever player might be available)
local function update_local_player_id()
	local pm = Managers and Managers.player
	if pm then
		local local_player = pm:local_player_safe(1)
		if local_player then
			local success, account_id = pcall(function() return local_player:account_id() end)
			if success and account_id and account_id ~= "" then
				mod._local_player_account_id = account_id
				return true
			end
		end
	end
	return false
end

local function pcall_safe(func)
	local success, result = pcall(func)
	return success and result or nil
end

-- Forward declaration - defined after ColorAllocator
local get_color_for_account_id

local color_customizer_view_name = "color_customizer"
local color_customizer_view_path = "ColorSelection/scripts/mods/ColorSelection/views/color_customizer_view/color_customizer_view"

mod:add_require_path(color_customizer_view_path)

local registered_view = mod:register_view({
    view_name = color_customizer_view_name,
    view_settings = {
        init_view_function = function(ingame_ui_context)
            return true
        end,
        state_bound = true,
        display_name = "loc_eye_color_sienna_desc",
        path = color_customizer_view_path,
        package = "packages/ui/views/credits_goods_vendor_view/credits_goods_vendor_view",
        class = "ColorCustomizerView",
        load_in_hub = false,
        game_world_blur = 1,
        enter_sound_events = {
            "wwise/events/ui/play_ui_enter_short"
        },
        exit_sound_events = {
            "wwise/events/ui/play_ui_back_short"
        },
        wwise_states = {},
    },
    view_transitions = {},
    view_options = {
        close_all = false,
        close_previous = false,
        close_transition_time = nil,
        transition_time = nil
    }
})

function mod.open_color_customizer()

    if Managers.ui:view_active(color_customizer_view_name) then
        Managers.ui:close_view(color_customizer_view_name)
        return
    end

    if Managers.ui:has_active_view() or Managers.ui:chat_using_input() then
        return
    end

    Managers.ui:open_view(color_customizer_view_name)
end


local function color_for_slot(slot)
	if not slot or slot < 1 then
		return 1
	end
	return slot
end

local function get_color(prefix)
	return {
		mod:get(prefix .. "_a") or CONSTANTS.MAX_COLOR_VALUE,
		mod:get(prefix .. "_r") or mod.get_default_color_value(prefix, "r"),
		mod:get(prefix .. "_g") or mod.get_default_color_value(prefix, "g"),
		mod:get(prefix .. "_b") or mod.get_default_color_value(prefix, "b"),
	}
end

local ColorAllocator = {
	cfg_colors = {},
	bot_color = nil,
	slot_to_index = {},
	index_taken = {},
	player_to_slot_mapping = {},  -- Maps player unique_id to remapped slot (1-4)
	account_id_to_player_id = {},  -- Maps account_id to unique_id for lookups
	bot_player_ids = {},  -- Set of unique_ids that are bots
}

function ColorAllocator:reset()
	self.slot_to_index = {}
	self.index_taken = { false, false, false, false }
	self.player_to_slot_mapping = {}
	self.account_id_to_player_id = {}
	self.bot_player_ids = {}
end

function ColorAllocator:setup(my_slot, all_slots)
	self.cfg_colors = {
		get_color("slot1"),
		get_color("slot2"),
		get_color("slot3"),
		get_color("slot4"),
	}
	self.bot_color = get_color("bot")

	local active_slots = {}
	if my_slot and my_slot >= 1 then
		active_slots[my_slot] = true
	end
	if all_slots then
		for i = 1, #all_slots do
			local slot = all_slots[i]
			if slot and slot >= 1 then
				active_slots[slot] = true
			end
		end
	end

	local slots_to_remove = {}
	for slot, idx in pairs(self.slot_to_index) do
		if not active_slots[slot] then
			slots_to_remove[#slots_to_remove + 1] = slot
		end
	end
	for i = 1, #slots_to_remove do
		local slot = slots_to_remove[i]
		local idx = self.slot_to_index[slot]
		self.slot_to_index[slot] = nil
		if idx then
			self.index_taken[idx] = false
		end
	end

	self.index_taken = { false, false, false, false }
	for slot, idx in pairs(self.slot_to_index) do
		if idx >= 1 and idx <= 4 then
			self.index_taken[idx] = true
		end
	end

	if my_slot and my_slot >= 1 then
		if self.slot_to_index[my_slot] and self.slot_to_index[my_slot] ~= 1 then

			local old_idx = self.slot_to_index[my_slot]
			self.index_taken[old_idx] = false
		end
		self.slot_to_index[my_slot] = 1
		self.index_taken[1] = true
	end

	if all_slots then
		for i = 1, #all_slots do
			local slot = all_slots[i]
			if slot ~= my_slot and slot and slot >= 1 then
				if not self.slot_to_index[slot] then

					for idx = 1, 4 do
						if not self.index_taken[idx] then
							self.slot_to_index[slot] = idx
							self.index_taken[idx] = true
							break
						end
					end
				end
			end
		end
	end
end

-- Helper function to check if we're in a non-mission context (hub, shooting range, etc.)
-- Returns true if we're NOT in an actual mission
local function is_in_non_mission_context()
	-- Check mechanism name first (most reliable)
	if Managers.mechanism then
		local success, mechanism_name = pcall(function() return Managers.mechanism:mechanism_name() end)
		if success and mechanism_name then
			-- Hub and onboarding (which includes shooting range) are non-mission contexts
			if mechanism_name == "hub" or mechanism_name == "onboarding" then
				return true
			end
		end
	end
	
	-- Fallback: Check game mode name
	if Managers.state and Managers.state.game_mode then
		local success, game_mode_name = pcall(function() return Managers.state.game_mode:game_mode_name() end)
		if success and game_mode_name then
			if game_mode_name == "hub" or game_mode_name == "shooting_range" or game_mode_name == "training_grounds" or game_mode_name == "prologue_hub" then
				return true
			end
		end
	end
	
	return false
end

function ColorAllocator:color_for(slot, account_id)
	slot = color_for_slot(slot)

	if not account_id or account_id == "" then
		if mod:get("debug_mode") then
			mod:info(string.format("[ColorSelection] Returning bot color for slot %d (no account_id)", slot or 0))
		end
		return self.bot_color or self.cfg_colors[1]
	end

	-- Ensure local player ID is set (fallback if not initialized yet)
	if not mod._local_player_account_id then
		update_local_player_id()
	end

	-- Check if this is the local player using stored account ID
	-- Also do a live check as backup
	local is_local_player = false
	if mod._local_player_account_id and mod._local_player_account_id == account_id then
		is_local_player = true
	else
		-- Backup live check
		local pm = Managers and Managers.player
		if pm then
			local local_player = pm:local_player_safe(1)
			if local_player then
				local success, lp_account_id = pcall(function() return local_player:account_id() end)
				if success and lp_account_id and lp_account_id == account_id then
					is_local_player = true
					-- Update the cached ID
					mod._local_player_account_id = lp_account_id
				end
			end
		end
	end
	
	if is_local_player then
		-- Local player always gets slot 1 color - FETCH LIVE from settings to avoid stale data after mission
		return {
			255,
			mod:get("slot1_r"),
			mod:get("slot1_g"),
			mod:get("slot1_b"),
		}
	end

	-- Check if we're in a non-mission context (hub, shooting range, etc.)
	local in_non_mission = is_in_non_mission_context()

	-- Check for custom colors (these apply everywhere)
	-- Always fetch fresh from saved_player_colors (no caching) to ensure instant updates like local player
	if account_id then
		local saved_colors = mod:get("saved_player_colors")
		if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
			local color = saved_colors[account_id]
			if color and type(color) == "table" then
				return {255, color.r or 255, color.g or 255, color.b or 255}
			end
		end
	end

	-- In non-mission contexts: Only return colors for local player or players with custom colors
	-- Return nil for others to preserve their default appearance
	if in_non_mission then
		-- No custom color found, return nil to skip color modification
		return nil
	end

	-- Mission only: check account_id_color_map for slot-based colors
	if account_id and mod.account_id_color_map and mod.account_id_color_map[account_id] then
		local color_index = mod.account_id_color_map[account_id]
		if color_index >= 1 and color_index <= 4 then
			return self.cfg_colors[color_index]
		end
	end

	if account_id and self.account_id_to_player_id[account_id] then
		local player_id = self.account_id_to_player_id[account_id]
		
		if self.bot_player_ids[player_id] then
			return self.bot_color or self.cfg_colors[1]
		end
		
		if self.player_to_slot_mapping[player_id] then
			slot = self.player_to_slot_mapping[player_id]
		end
	end

	local idx = self.slot_to_index[slot]
	if idx then
		-- Don't return slot 1 color for non-local players
		if idx == 1 and not is_local_player then
			-- Reassign to a different slot
			for i = 2, 4 do
				if not self.index_taken[i] then
					self.slot_to_index[slot] = i
					self.index_taken[i] = true
					return self.cfg_colors[i]
				end
			end
			-- Fallback to slot 2 if all taken
			return self.cfg_colors[2]
		end
		return self.cfg_colors[idx]
	end

	-- Assign new slot - start from 2 for non-local players (slot 1 reserved for local)
	local start_idx = is_local_player and 1 or 2
	for i = start_idx, 4 do
		if not self.index_taken[i] then
			self.slot_to_index[slot] = i
			self.index_taken[i] = true
			return self.cfg_colors[i]
		end
	end

	-- Fallback - use slot 2-4 for non-local, slot 1 for local
	local fallback = is_local_player and 1 or (((slot - 1) % 3) + 2)
	return self.cfg_colors[fallback]
end

-- Helper function to get color for any account_id (works in hub and missions)
-- Returns color table or nil if no color should be applied
get_color_for_account_id = function(account_id)
	if not account_id or account_id == "" then
		return nil
	end
	
	-- Ensure local player ID is set
	if not mod._local_player_account_id then
		update_local_player_id()
	end
	
	-- Check if this is the local player
	local is_local = mod._local_player_account_id and mod._local_player_account_id == account_id
	
	if is_local then
		-- Local player always gets their slot 1 color
		return {
			255,
			mod:get("slot1_r"),
			mod:get("slot1_g"),
			mod:get("slot1_b"),
		}
	end
	
	-- Check for custom colors (works in hub and missions)
	-- Always fetch fresh from saved_player_colors (no caching) to ensure instant updates like local player
	local saved_colors = mod:get("saved_player_colors")
	if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
		local c = saved_colors[account_id]
		if c and type(c) == "table" then
			return {255, c.r or 255, c.g or 255, c.b or 255}
		end
	end
	
	-- Check if we're in a non-mission context (hub, shooting range, etc.)
	if is_in_non_mission_context() then
		-- In non-mission contexts, no slot colors for non-custom players
		return nil
	end
	
	-- In missions, use slot-based colors via ColorAllocator
	-- Try to get player's actual slot
	local player = nil
	local pm = Managers and Managers.player
	if pm then
		local human_players = pm:human_players()
		if human_players then
			for _, p in pairs(human_players) do
				local success, pid = pcall(function() return p:account_id() end)
				if success and pid == account_id then
					player = p
					break
				end
			end
		end
	end
	
	local slot = 1
	if player then
		local success, s = pcall(function() return player:slot() end)
		if success and s then
			slot = s
		end
	end
	
	-- Use ColorAllocator for mission slot colors
	return ColorAllocator:color_for(slot, account_id)
end

local function _on_player_removed(player)
	if not player then return end

	local success, account_id = pcall(function() return player:account_id() end)
	if success and account_id and mod._player_custom_colors then

		mod._player_custom_colors[account_id] = nil
	end
	
	local slot_success, slot = pcall(function() return player:slot() end)
	if not slot_success or not slot then
		return
	end
	local idx = ColorAllocator.slot_to_index[slot]
	if idx then
		ColorAllocator.slot_to_index[slot] = nil
		ColorAllocator.index_taken[idx] = false
	end
end

local _player_cache = {
	by_slot = {},
	by_account_id = {},
	last_update = 0
}

local function update_player_cache()
	local pm = Managers and Managers.player
	if not pm then
		return
	end
	
	table.clear(_player_cache.by_slot)
	table.clear(_player_cache.by_account_id)
	
	local human_players = pm:human_players()
	if human_players then
		for unique_id, player in pairs(human_players) do
			if player then

				local human_success, is_human = pcall(function() return player:is_human_controlled() end)
				local bot_success, is_bot = pcall(function() return player:is_bot() end)
				local id_success, account_id = pcall(function() return player:account_id() end)

				if not (human_success and is_human) then goto skip_cache end
				if bot_success and is_bot then goto skip_cache end
				if not (id_success and account_id and account_id ~= "") then goto skip_cache end

				local slot_success, slot = pcall(function() return player:slot() end)
				if slot_success and slot then _player_cache.by_slot[slot] = player end
				if id_success and account_id then _player_cache.by_account_id[account_id] = player end
				
				::skip_cache::
			end
		end
	end
	
	_player_cache.last_update = os.clock()
end

local function get_player_by_slot(slot)
	if not slot then return nil end

	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end
	
	return _player_cache.by_slot[slot]
end

local function get_player_by_account_id(account_id)
	if not account_id then return nil end

	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end
	
	return _player_cache.by_account_id[account_id]
end


local function apply_color_to_name_only(text, color)
	if not text or type(text) ~= "string" or not color then
		return text
	end
	
	local c = color
	local target_color_tag = string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])

	-- Simple approach: Strip existing color tags and reapply our color
	-- This works because ColorSelection loads AFTER TrueLevel and WhoAreYou
	-- Their text additions (like level info and account names) are preserved,
	-- we just change the color of the entire text
	local stripped_text = text:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}$", "")

	return target_color_tag .. stripped_text .. "{#reset()}"
end

local function apply_widget_color(panel)
	if not panel or not panel._widgets_by_name then
		return
	end

	local player = panel._player
	if not player and panel._data then
		player = panel._data.player
	end

	local slot = nil
	local account_id = nil
	
	if player then

		local success, result = pcall(function() return player:slot() end)
		if success and result then
			slot = result
		end

		local id_success, id_result = pcall(function() return player:account_id() end)
		if id_success and id_result then
			account_id = id_result
		end

		if slot and not panel._player_slot then
			panel._player_slot = slot
		end
	else

		slot = panel._player_slot
		if slot then
			player = get_player_by_slot(slot)
			if player then
				local success, result = pcall(function() return player:account_id() end)
				if success then
					account_id = result
				end
			end
		end
	end
	
	if not slot then
		return
	end
	
	local color = ColorAllocator:color_for(slot, account_id)
	
	local widget = panel._widgets_by_name.player_name
	if not widget or not widget.style or not widget.style.text then
		return
	end
	
	if not color then
		-- No custom color - apply default based on context
		local in_non_mission = is_in_non_mission_context()
		
		if in_non_mission then
			-- In hub: apply default terminal_text_body color
			color = DEFAULT_HUB_COLOR
		else
			-- In mission: try to get slot color from ColorAllocator
			-- This should normally return a slot color, but if it doesn't, fallback to hub default
			color = ColorAllocator:color_for(slot, account_id)
			if not color then
				color = DEFAULT_HUB_COLOR
			end
		end
	end

	-- Only color the text content (like nameplates), don't modify widget style colors
	-- The icon will color automatically via UISettings.player_slot_colors
	if widget.content and widget.content.text then
		local current_text = widget.content.text
		local new_text = apply_color_to_name_only(current_text, color)
		widget.content.text = new_text
		widget.dirty = true
	end
end

local function alias_ability_bar_widget(panel)
	local w = panel and panel._widgets_by_name
	if not w then
		return
	end
	if w.ability_bar then
		w.ability_bar_widget = w.ability_bar
	elseif not w.ability_bar_widget then
		w.ability_bar_widget = { visible = false, dirty = false, style = { texture = { color = { 255, 255, 255, 255 }, size = { 0, 0 } } } }
	end
end

mod:hook_safe("HudElementPersonalPlayerPanel", "init", function(self) alias_ability_bar_widget(self) end)
mod:hook_safe("HudElementTeamPlayerPanel",     "init", function(self) alias_ability_bar_widget(self) end)

mod:hook_safe("HudElementPlayerPanelBase",     "destroy", function(self) alias_ability_bar_widget(self) end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "update", function(self)
	if mod:is_enabled() then
		-- Personal panel in hub is always local player
		local color = {
			255,
			mod:get("slot1_r") or 226,
			mod:get("slot1_g") or 210,
			mod:get("slot1_b") or 117,
		}
		
		local widget = self._widgets_by_name and self._widgets_by_name.player_name
		if widget and widget.content and widget.content.text then
			local current_text = widget.content.text
			local new_text = apply_color_to_name_only(current_text, color)
			widget.content.text = new_text
			widget.dirty = true
		end
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "_set_player_name", function(self) 
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanel", "update", function(self)
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementTeamPlayerPanel", "update", function(self)
	if mod:is_enabled() then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementTeamPlayerPanelHub", "update", function(self)
	if mod:is_enabled() then
		-- In hub, only color local player or players with custom colors
		local player = self._player
		if not player and self._data then
			player = self._data.player
		end
		
		if player then
			local account_id = nil
			local id_success, id_result = pcall(function() return player:account_id() end)
			if id_success and id_result then
				account_id = id_result
			end
			
			-- Check if local player or has custom color
			local color = get_color_for_account_id(account_id)
			
			-- In hub, if no custom color, use default terminal_text_body color
			if not color then
				color = DEFAULT_HUB_COLOR
			end
			
			local widget = self._widgets_by_name and self._widgets_by_name.player_name
			
			-- Only color the text content (like nameplates), don't modify widget style colors
			if widget and widget.content and widget.content.text and not self.tl_modified and not self.wru_modified then
				local current_text = widget.content.text
				local new_text = apply_color_to_name_only(current_text, color)
				widget.content.text = new_text
				widget.dirty = true
			end
		end
	end
end)

local function colourise_team_panels(handler)
	if not mod:is_enabled() then return end
	local panels = handler and handler._player_panels_array
	if not panels then return end
	for i = 1, #panels do
		local p = panels[i] and panels[i].panel
		if p then apply_widget_color(p) end
	end
end

local function apply_nameplate_color(marker)
    if not marker or not marker.widget or not mod:is_enabled() then
        return
    end

    local player = marker.data
    local marker_type = marker.type
    local is_companion = marker_type and marker_type:match("companion")
    
    -- For companions, refresh colors from UISettings.player_slot_colors
    -- Only apply colors if the nameplate is visible (header_text is not empty)
    -- Empty header_text means the game has hidden it based on settings
    if is_companion then
        local widget = marker.widget
        local content = widget and widget.content
        if not content or not player then return end
        
        -- Check if nameplate is visible - empty header_text means it's hidden
        local current_header = content.header_text or ""
        if current_header == "" then
            -- Nameplate is hidden by game settings, don't modify it
            return
        end
        
        local player_slot = pcall_safe(function() return player:slot() end) or 1
        local player_slot_color = UISettings and UISettings.player_slot_colors and UISettings.player_slot_colors[player_slot]
        
        if player_slot_color then
            local color_string = "{#color(" .. player_slot_color[2] .. "," .. player_slot_color[3] .. "," .. player_slot_color[4] .. ")}"
            local companion_glyph = ""
            
            if content.icon_text then
                content.icon_text = color_string .. companion_glyph .. "{#reset()}"
            end
            
            if content.header_text and content.header_text ~= "" then
                local companion_name = pcall_safe(function() return player:companion_name() end) or content.header_text:match(companion_glyph .. "%s*(.-)$") or content.header_text:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", ""):gsub(companion_glyph, ""):match("%s*(.-)$")
                if companion_name then
                    local is_player_blocked = pcall_safe(function() return player:is_player_blocked() end) or false
                    local companion_name_text = not is_player_blocked and companion_name or Localize("loc_blocking_player")
                    content.header_text = color_string .. companion_glyph .. "{#reset()} " .. companion_name_text
                end
            end
            
            widget.dirty = true
            if content then
                content.dirty = true
            end
        end
        return
    end
    
    if not player then
        return
    end

    -- Fetch account_id and slot
    local slot = pcall_safe(function() return player:slot() end) or 1
    local account_id = pcall_safe(function() return player:account_id() end)

    -- Determine colour (use custom colour first, then allocator, then default hub)
    local color = get_color_for_account_id(account_id)
    if not color then
        local in_non_mission = is_in_non_mission_context()
        if in_non_mission then
            color = DEFAULT_HUB_COLOR
        else
            color = ColorAllocator:color_for(slot, account_id) or DEFAULT_HUB_COLOR
        end
    end

    -- Build colour tag
    local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])

    local widget = marker.widget
    local content = widget.content
    if not content or not content.header_text then
        return
    end

    local header = content.header_text

    -- Determine player name; prefer data from player object
    local player_name = pcall_safe(function() return player:name() end)
    if not player_name or player_name == "" then
        -- Fallback: extract first word from header (before newline if present)
        local name_part = header:match("^([^\n]*)")
        player_name = name_part and name_part:match("%w+") or header:match("%w+") or header
    end

    -- Escape magic chars for gsub
    local escaped_name = player_name:gsub("([%(%)%.%%%+%*%?%[%]%^%$])", "%%%1")

    -- Split header by newline to preserve title colors
    local name_part, title_part = header:match("^([^\n]*)\n?(.*)$")
    if not name_part then
        name_part = header
        title_part = ""
    end
    
    -- Strip color tags only from the name part (before newline)
    local clean_name_part = name_part:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}", "")
    
    -- Find where the player name starts in the clean text
    -- The format is typically: icon " " name " - " level " icon"
    -- We want to color both the icon and the name
    local name_start, name_end = clean_name_part:find(player_name, 1, true)
    
    if name_start then
        -- Color everything from the start (icon) through the player name
        local before_name = clean_name_part:sub(1, name_start - 1)
        local after_name = clean_name_part:sub(name_end + 1)
        local new_name_part = color_tag .. before_name .. player_name .. "{#reset()}" .. after_name
        
        -- Recombine: colored icon+name+rest + preserved title (with its colors intact)
        local new_header = new_name_part
        if title_part and title_part ~= "" then
            new_header = new_header .. "\n" .. title_part
        end
        
        content.header_text = new_header
        marker._cs_last_header = nil  -- Clear cache to force update
        -- Mark widget as dirty to force immediate redraw
        if widget then
            widget.dirty = true
            if widget.content then
                widget.content.dirty = true
            end
        end
    end
end

mod:hook_require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler", function(H)
	if not H.__cs_hooked then
		H.__cs_hooked = true
		mod:hook_safe(H, "update", function(self) colourise_team_panels(self) end)
	end
end)

local nameplate_template_path = "scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate"
mod:hook_require(nameplate_template_path, function(template)
	if not template then return end
	
	-- Hook on_enter to apply colors after nameplate is created
	if template.on_enter then
		local original_on_enter = template.on_enter
		template.on_enter = function(widget, marker)
			original_on_enter(widget, marker)
			
			if mod:is_enabled() and marker and marker.data then
				-- Apply color after _create_character_text runs (called in on_enter)
				-- Try immediately, update hook will catch it if header_text isn't ready yet
				if marker.widget and marker.widget.content and marker.widget.content.header_text then
					apply_nameplate_color(marker)
				end
			end
		end
	end
end)

local companion_templates = {
	"scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate_companion",
	"scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate_companion_hub",
}

for _, template_path in ipairs(companion_templates) do
	mod:hook_require(template_path, function(template)
		if not template or not template.on_enter then return end
		
		local original_on_enter = template.on_enter
		template.on_enter = function(widget, marker)
			original_on_enter(widget, marker)
			
			if not mod:is_enabled() or not marker or not marker.data then return end
			
			local data = marker.data
			local content = widget.content
			if not content then return end
			
			local player_slot = pcall_safe(function() return data:slot() end) or 1
			local player_slot_color = UISettings and UISettings.player_slot_colors and UISettings.player_slot_colors[player_slot]
			
			-- Check if nameplate is visible - empty header_text means it's hidden
			local current_header = content.header_text or ""
			if current_header == "" then
				-- Nameplate is hidden by game settings, don't modify it
				return
			end
			
			if player_slot_color then
				local color_string = "{#color(" .. player_slot_color[2] .. "," .. player_slot_color[3] .. "," .. player_slot_color[4] .. ")}"
				local companion_glyph = ""
				
				if content.icon_text then
					content.icon_text = color_string .. companion_glyph .. "{#reset()}"
				end
				
				if content.header_text and content.header_text ~= "" then
					local header = content.header_text
					local companion_name = header:match(companion_glyph .. "%s*(.-)$") or header:match("%s*(.-)$")
					if companion_name then
						content.header_text = color_string .. companion_glyph .. "{#reset()} " .. companion_name
					end
				end
				
				widget.dirty = true
				if content then
					content.dirty = true
				end
			end
		end
	end)
end

mod:hook_safe("HudElementWorldMarkers", "event_add_world_marker_unit", function(self, marker_type, unit, callback, data)
	if not mod:is_enabled() then return end

	if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
		if self._markers_by_id then
			for marker_id, marker in pairs(self._markers_by_id) do
				if marker.unit == unit then
					-- Try to apply color immediately if header_text is ready
					-- The update hook will catch it on the next frame if not ready yet
					if marker.widget and marker.widget.content and marker.widget.content.header_text then
						apply_nameplate_color(marker)
					end
					break
				end
			end
		end
	end
end)

mod:hook_safe("HudElementNameplates", "update", function(self, dt, t, ui_renderer)
	if not mod:is_enabled() then return end

	if not Managers or not Managers.ui then return end
	
	local ui_manager = Managers.ui
	local hud = ui_manager._hud
	if not hud then return end

	local success, world_markers = pcall(function() return hud:element("HudElementWorldMarkers") end)
	if not success or not world_markers or not world_markers._markers_by_id then return end
	
	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type
		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			apply_nameplate_color(marker)
		end
	end
end)




mod:hook(CLASS.ConstantElementChat, "_participant_displayname", function(func, self, participant)
	local display_name = func(self, participant)
	
	if not mod:is_enabled() then
		return display_name
	end
	
	local account_id = participant and participant.account_id
	if not account_id then
		return display_name
	end

	local slot = 1  -- Default to slot 1
	local player = get_player_by_account_id(account_id)
	if player then
		slot = pcall_safe(function() return player:slot() end) or 1
	end
	
	local color = ColorAllocator:color_for(slot, account_id)
	if not color then
		return display_name  -- Skip color modification (hub without custom color)
	end
	
	if color then
		local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
		local result = color_tag .. display_name .. "{#reset()}"
		return result
	end
	
	return display_name
end)

local function apply_color_to_player_name(name, player)
	if not name or name == "" or not player then
		return name
	end
	
	local account_id = pcall_safe(function() return player:account_id() end)
	if not account_id or account_id == "" then
		return name
	end

	local color = get_color_for_account_id(account_id)
	
	if color then
		local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
		return color_tag .. name .. "{#reset()}"
	end
	
	return name
end

mod:hook(CLASS.HumanPlayer, "name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end

	return apply_color_to_player_name(name, self)
end)

mod:hook(CLASS.RemotePlayer, "name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	return apply_color_to_player_name(name, self)
end)

mod:hook(CLASS.PlayerInfo, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	local account_id = self._account_id
	if account_id then
		local color = get_color_for_account_id(account_id)
		if color then
			local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
			return color_tag .. name .. "{#reset()}"
		end
	end
	
	return name
end)

mod:hook(CLASS.RemotePlayer, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	return apply_color_to_player_name(name, self)
end)

mod:hook(CLASS.PresenceEntryMyself, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	local color = {
		255,
		mod:get("slot1_r"),
		mod:get("slot1_g"),
		mod:get("slot1_b"),
	}
	local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
	return color_tag .. name .. "{#reset()}"
end)

mod:hook(CLASS.PresenceEntryImmaterium, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	local account_id = self._immaterium_entry and self._immaterium_entry.account_id
	if account_id then
		local color = get_color_for_account_id(account_id)
		if color then
			local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
			return color_tag .. name .. "{#reset()}"
		end
	end
	
	return name
end)

mod:hook_require("scripts/utilities/profile_utils", function(instance)
	mod:hook(instance, "character_name", function(func, profile)
		local name = func(profile)
		
		if not mod:is_enabled() then
			return name
		end
		
		local account_id = profile and profile.account_id
		if account_id then
			local color = get_color_for_account_id(account_id)
			if color then
				local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
				return color_tag .. name .. "{#reset()}"
			end
		end
		
		return name
	end)
end)

local function install_player_panel_hooks(base)
	if not base or base.__cs_hooks then return end
	base.__cs_hooks = true

	mod:hook_safe(base, "update", function(self, dt, t, ui_renderer)

		if mod:is_enabled() and self._widgets_by_name and self._widgets_by_name.player_name then
			apply_widget_color(self)
		end
	end)
	
	mod:hook_safe(base, "_update_player_name_prefix", function(self)
		if not mod:is_enabled() then return end
		if self._colors_revision ~= mod._colors_revision then
			self._colors_revision = mod._colors_revision
			self._player_slot = nil

			apply_widget_color(self)
		end
	end)
	
	mod:hook_safe(base, "_set_player_name", function(self)
		if not mod:is_enabled() then return end
		apply_widget_color(self) 
	end)
	
	mod:hook_safe(base, "_update_player_features", function(self, dt, t, player, ui_renderer)

		if player then
			self._player = player

			local success, slot = pcall(function() return player:slot() end)
			if success and slot then
				self._player_slot = slot
			end
		end
		apply_widget_color(self) 
	end)

	mod:hook_safe(base, "init", function(self, parent, draw_layer, scale, data)
		if data and data.player then
			local player = data.player
			if player then
				local success, slot = pcall(function() return player:slot() end)
				if success and slot then
					self._player_slot = slot
				end
			end
		end

		apply_widget_color(self)
	end)
end

mod:hook_require("scripts/ui/hud/elements/player_panel_base/hud_element_player_panel_base", function(B) install_player_panel_hooks(B) end)

mod._colors_revision = 0
local previous_slot_colors

local function deep_clone(tbl)
	if not tbl then return nil end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deep_clone(v) or v
	end
	return copy
end

local function restore_previous()
	if previous_slot_colors then
		UISettings.player_slot_colors = previous_slot_colors
		previous_slot_colors = nil
		mod._colors_revision = mod._colors_revision + 1
	end
end

mod.on_unload = restore_previous

local function update_world_markers()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then return false end
	
	local hud = ui_manager:get_hud()
	if not hud then return false end
	
	local world_markers = hud:element("HudElementWorldMarkers")
	if not world_markers or not world_markers._markers_by_id then return false end
	
	local nameplates_element = hud:element("HudElementNameplates")
	if not nameplates_element then return false end
	
	local nameplate_units = nameplates_element._nameplate_units
	local companion_nameplates = nameplates_element._companion_nameplates
	
	-- Force immediate scan by bypassing delay and calling scan methods directly
	nameplates_element._scan_delay_duration = 0
	if nameplates_element._nameplate_extension_scan then
		pcall_safe(function() nameplates_element:_nameplate_extension_scan() end)
	end
	-- Don't force companion scan - let game handle visibility based on settings
	
	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type

		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			marker.wru_modified = false
			marker.tl_modified = false
			marker._cs_last_header = nil
			apply_nameplate_color(marker)
			
			-- Force resync for player nameplates
			if nameplate_units and marker.unit then
				local unit_data = nameplate_units[marker.unit]
				if unit_data then
					unit_data.synced = false
				end
			end
			
			-- Don't force resync for companion nameplates - let game handle visibility
			-- Only apply colors if they're already visible (respects game settings)
		end
	end
	
	-- Trigger another immediate scan to process the synced=false changes
	if nameplates_element._nameplate_extension_scan then
		pcall_safe(function() nameplates_element:_nameplate_extension_scan() end)
	end
	-- Don't force companion scan - let game handle visibility based on settings	
	
	return true
end

local function update_player_panel_colors()

	local ui_manager = Managers and Managers.ui
	if not ui_manager or not ui_manager._hud then return false end
	
	local hud = ui_manager._hud
	local elements_array = hud._elements_array
	if not elements_array then return false end
	
	for i = 1, #elements_array do
		local element = elements_array[i]
		if element then
			local class_name = element.__class_name
			if class_name == "HudElementPersonalPlayerPanel" or class_name == "HudElementPersonalPlayerPanelHub" then
				-- Reset mod compatibility flags so who_are_you and true_level re-apply
				element.wru_modified = false
				element.tl_modified = false
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPlayerPanel" or class_name == "HudElementTeamPlayerPanelHub" then
				-- Reset mod compatibility flags so who_are_you and true_level re-apply
				element.wru_modified = false
				element.tl_modified = false
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPanelHandler" then
				-- Reset flags on all panels in handler
				if element._player_panels_array then
					for _, data in ipairs(element._player_panels_array) do
						if data.panel then
							data.panel.wru_modified = false
							-- data.panel.tl_modified = false
						end
					end
				end
				colourise_team_panels(element)
			end
		end
	end

	update_world_markers()
	
	return true
end

local last_debug_state = ""  -- Track last debug output to prevent spam
local logged_reassignments = {}  -- Track which players we've logged reassignments for

local apply_slot_colors_internal

local color_assignment_queue = {}
local is_processing_queue = false

local function process_next_in_queue()
	if is_processing_queue or #color_assignment_queue == 0 then
		return
	end
	
	is_processing_queue = true
	local queue_size = #color_assignment_queue
	local debug_mode = mod:get("debug_mode")
	
	if queue_size > 1 then
		local msg = string.format("[ColorSelection] Processing queue with %d operations (RACE CONDITION PREVENTED!)", queue_size)
		mod:info(msg)  -- Always log to file
		if debug_mode then
			mod:echo(msg)  -- Also show in chat if debug mode
		end
	end

	local operation_count = 0
	while #color_assignment_queue > 0 do
		local operation = table.remove(color_assignment_queue, 1)
		operation_count = operation_count + 1
		
		if debug_mode then
			local msg = string.format("[ColorSelection] Executing queued operation %d/%d", operation_count, queue_size)
			mod:info(msg)
			mod:echo(msg)
		end

		operation()
	end

	is_processing_queue = false
end

local function queue_color_assignment()
	local queue_position = #color_assignment_queue + 1
	local debug_mode = mod:get("debug_mode")
	
	if debug_mode then
		local msg = string.format("[ColorSelection] Queueing color assignment (position %d)", queue_position)
		mod:info(msg)
		mod:echo(msg)
	end
	
	table.insert(color_assignment_queue, function() apply_slot_colors_internal() end)
	process_next_in_queue()
end

apply_slot_colors_internal = function()
	if not UISettings then
		return
	end
	
	if Managers.mechanism and Managers.mechanism:mechanism_name() == "hub" then
		return
	end
	
	if is_in_non_mission_context() then
		return
	end
	
	if not UISettings.player_slot_colors then
		UISettings.player_slot_colors = {}
	end
	
	if not previous_slot_colors then
		previous_slot_colors = deep_clone(UISettings.player_slot_colors)
	end

	local my_slot
	local all_slots = {}
	local pm = Managers and Managers.player
	if not pm then
		return
	end


	local player_to_slot = ColorAllocator.player_to_slot_mapping or {}
	local used_slots = {false, false, false, false}  -- Track which 1-4 slots are used

	local player_slots = {}  -- Store {unique_id, original_slot, player}
	local current_players = {}  -- Track which players are currently in game
	local local_player_id = nil
	local human_players = pm:human_players()
	local lp = pm:local_player_safe(1)
	
	if human_players then
		for unique_id, player in pairs(human_players) do
			if player then

				local human_success, is_human = pcall(function() return player:is_human_controlled() end)
				local bot_success, is_bot = pcall(function() return player:is_bot() end)
				local account_success, account_id_check = pcall(function() return player:account_id() end)




				if not (human_success and is_human) then
					if mod:get("debug_mode") then
						mod:echo(string.format("[ColorSelection] Skipping player %s - not human controlled", unique_id:sub(1, 8)))
					end
					goto skip_player
				end
				if bot_success and is_bot then
					if mod:get("debug_mode") then
						mod:echo(string.format("[ColorSelection] Skipping player %s - is_bot returned true", unique_id:sub(1, 8)))
					end
					goto skip_player
				end
				if not (account_success and account_id_check and account_id_check ~= "") then
					if mod:get("debug_mode") then
						mod:echo(string.format("[ColorSelection] Skipping player %s - no valid account_id (BOT)", unique_id:sub(1, 8)))
					end
					goto skip_player
				end
				
				local success, slot = pcall(function() return player:slot() end)
				if success and slot and slot >= 1 then
					table.insert(player_slots, {unique_id = unique_id, slot = slot, player = player})
					current_players[unique_id] = true

					if lp and player == lp then
						local_player_id = unique_id
					end
				end
				
				::skip_player::
			end
		end
	end
	
	if #player_slots == 0 then
		if mod:get("debug_mode") then
			mod:echo("[ColorSelection] No players with valid slots found, skipping color application")
		end
		return
	end
	
	local local_player_has_slot = false
	if local_player_id then
		for _, data in ipairs(player_slots) do
			if data.unique_id == local_player_id then
				local_player_has_slot = true
				break
			end
		end
	end
	
	if not local_player_has_slot then
		if mod:get("debug_mode") then
			mod:echo("[ColorSelection] Local player slot not ready, skipping color application")
		end
		return
	end

	for player_id in pairs(player_to_slot) do
		if not current_players[player_id] then
			local old_slot = player_to_slot[player_id]
			player_to_slot[player_id] = nil

			if old_slot >= 1 and old_slot <= 4 then
				used_slots[old_slot] = false
			end

			for key in pairs(logged_reassignments) do
				if key:sub(1, 8) == player_id:sub(1, 8) then
					logged_reassignments[key] = nil
				end
			end
		end
	end

	for player_id, slot in pairs(player_to_slot) do
		if player_id ~= local_player_id and slot >= 1 and slot <= 4 then
			used_slots[slot] = true
		end
	end

	if local_player_id then
		player_to_slot[local_player_id] = 1
		used_slots[1] = true  -- Reserve slot 1 for local player
	end


	local account_id_to_player_id = {}
	for _, data in ipairs(player_slots) do
		local slot = data.slot
		local unique_id = data.unique_id
		local player = data.player

		local acct_success, account_id = pcall(function() return player:account_id() end)
		if acct_success and account_id then
			account_id_to_player_id[account_id] = unique_id
		end

		if unique_id == local_player_id then
			goto continue
		end

		if not player_to_slot[unique_id] then

			local assigned = false
			for i = 2, 4 do  -- Start from 2, not 1
				if not used_slots[i] then
					player_to_slot[unique_id] = i
					used_slots[i] = true
					if slot ~= i then

						local reassignment_key = string.format("%s:%d:%d", unique_id, slot, i)
						if not logged_reassignments[reassignment_key] then
							logged_reassignments[reassignment_key] = true
							local msg = string.format("[ColorSelection] Player %s: slot %d → slot %d (reassigned)", 
								unique_id:sub(1, 8), slot, i)
							if mod:get("debug_mode") then
								mod:echo(msg)
							else
								mod:info(msg)
							end
						end
					end
					assigned = true
					break
				end
			end

			if not assigned then

				local hash_source = account_id or unique_id

				local hash = 0
				for i = 1, #hash_source do
					hash = hash + string.byte(hash_source, i)
				end

				local reassigned_slot = (hash % 3) + 2  -- Maps to 2, 3, or 4
				player_to_slot[unique_id] = reassigned_slot
			end
		end
		
		::continue::
	end

	ColorAllocator.player_to_slot_mapping = player_to_slot
	ColorAllocator.account_id_to_player_id = account_id_to_player_id

	local current_state = {}
	for player_id, slot in pairs(player_to_slot) do
		table.insert(current_state, player_id:sub(1, 8) .. "=" .. slot)
	end
	table.sort(current_state)
	local state_hash = table.concat(current_state, ",")

	if state_hash ~= last_debug_state then
		last_debug_state = state_hash
		local debug_enabled = mod:get("debug_mode")
		local log_func = debug_enabled and mod.echo or mod.info
		
		log_func(mod, "[ColorSelection] === Final slot assignments ===")
		for player_id, slot in pairs(player_to_slot) do
			log_func(mod, string.format("[ColorSelection]   Player %s → slot %d", player_id:sub(1, 8), slot))
		end
	end

	if local_player_id and player_to_slot[local_player_id] then
		my_slot = player_to_slot[local_player_id]  -- Should always be 1
	end

	for _, data in ipairs(player_slots) do
		local unique_id = data.unique_id
		local remapped_slot = player_to_slot[unique_id]
		
		if remapped_slot then
			local found = false
			for i = 1, #all_slots do
				if all_slots[i] == remapped_slot then
					found = true
					break
				end
			end
			if not found and remapped_slot ~= my_slot then
				all_slots[#all_slots + 1] = remapped_slot
			end
		end
	end

	ColorAllocator:setup(my_slot, all_slots)

	local color_metatable = {
		__index = function(_, k)
			if type(k) ~= "number" or k < 1 then return nil end

			local account_id = nil
			local player = get_player_by_slot(k)
			if player then
				local success, result = pcall(function() return player:account_id() end)
				if success then
					account_id = result
				end
			end
			return ColorAllocator:color_for(k, account_id)
		end,
	}

	UISettings.player_slot_colors = setmetatable({}, color_metatable)

	mod._colors_revision = mod._colors_revision + 1
	UISettings._colors_revision = (UISettings._colors_revision or 0) + 1
	update_player_panel_colors()

	local debug_enabled = mod:get("debug_mode")
	if debug_enabled then
		mod:echo("[ColorSelection] Slot colors applied successfully")
	else
		mod:info("[ColorSelection] Slot colors applied successfully")
	end
end

local function apply_slot_colors()
	queue_color_assignment()
end

mod.apply_slot_colors = apply_slot_colors
mod.update_player_panel_colors = update_player_panel_colors
mod.ColorAllocator = ColorAllocator
mod.ColorUtils = ColorUtils
mod.CONSTANTS = CONSTANTS
mod.get_player_by_account_id = get_player_by_account_id
mod.get_player_by_slot = get_player_by_slot
mod.get_color_for_account_id = get_color_for_account_id

-- Reset helpers: remove ColorSelection colour when the mod is disabled
local function _strip_cs_color_tags(text)
    if not text or type(text) ~= "string" then
        return text
    end
    -- Remove a leading CS color tag (four numbers) and trailing reset
    local cleaned = text:gsub("^{#color%(%d+,%d+,%d+,%d+%)}", ""):gsub("{#reset%(%)}$", "")
    return cleaned
end

local function reset_team_panel_colors()
    local ui_manager = Managers and Managers.ui
    if not ui_manager then
        return
    end

    local hud = ui_manager:get_hud()
    if not hud then
        return
    end

    local handler = hud:element("HudElementTeamPanelHandler")
    if not handler or not handler._player_panels_array then
        return
    end

    for i = 1, #handler._player_panels_array do
        local p = handler._player_panels_array[i] and handler._player_panels_array[i].panel
        if p and p._widgets_by_name and p._widgets_by_name.player_name then
            local widget = p._widgets_by_name.player_name
            local header_style = widget.style and widget.style.text
            if header_style and header_style.text_color then
                header_style.text_color = table.clone(DEFAULT_HUB_COLOR)
                if header_style.default_text_color then
                    header_style.default_text_color = table.clone(DEFAULT_HUB_COLOR)
                end
            end
            if widget.content and widget.content.text then
                widget.content.text = _strip_cs_color_tags(widget.content.text)
                widget.dirty = true
            end
        end
    end
end

local function reset_nameplate_colors()
    local ui_manager = Managers and Managers.ui
    if not ui_manager then
        return
    end
    local hud = ui_manager._hud
    if not hud then
        return
    end
    local world_markers = hud:element("HudElementWorldMarkers")
    if not world_markers or not world_markers._markers_by_id then
        return
    end
    for _, marker in pairs(world_markers._markers_by_id) do
        local marker_type = marker.type
        if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
            if marker.widget and marker.widget.content and marker.widget.content.header_text then
                marker.widget.content.header_text = _strip_cs_color_tags(marker.widget.content.header_text)
                marker._cs_last_header = nil
            end
        end
    end
end

-- Override on_disabled to clear stale colors
mod.on_disabled = function()
    -- Restore slot colors already handled in restore_previous
    restore_previous()
    -- Reset panels & nameplates to default hub colors
    reset_team_panel_colors()
    reset_nameplate_colors()
end

local in_gameplay_state = false

mod:hook_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup_content_list", function(module)
	if module.from_player_info then
		local original_from_player_info = module.from_player_info
		
		module.from_player_info = function(parent, player_info)
			local popup_menu_items, num_menu_items = original_from_player_info(parent, player_info)

			if not player_info:is_own_player() and player_info:account_id() then
				local account_id = player_info:account_id()

				local _add_divider = function(at_index)
					local _get_next_list_item = function(at_index)
						local last_item_index = num_menu_items + 1
						local new_item = popup_menu_items[last_item_index]
						
						if new_item then
							table.clear(new_item)
						else
							new_item = {}
							popup_menu_items[last_item_index] = new_item
						end
						
						if at_index then
							popup_menu_items[last_item_index] = nil
							table.insert(popup_menu_items, at_index, new_item)
						end
						
						num_menu_items = last_item_index
						return new_item, last_item_index
					end
					
					local item, num_items = _get_next_list_item(at_index)
					item.blueprint = "group_divider"
					item.label = "divider_" .. num_items
				end
				
				local _get_next_list_item = function(at_index)
					local last_item_index = num_menu_items + 1
					local new_item = popup_menu_items[last_item_index]
					
					if new_item then
						table.clear(new_item)
					else
						new_item = {}
						popup_menu_items[last_item_index] = new_item
					end
					
					if at_index then
						popup_menu_items[last_item_index] = nil
						table.insert(popup_menu_items, at_index, new_item)
					end
					
					num_menu_items = last_item_index
					return new_item, last_item_index
				end

				_add_divider()

				local copy_button = _get_next_list_item()
				copy_button.blueprint = "button"
				copy_button.label = mod:localize("copy_account_id_button")
				copy_button.callback = function()
					if account_id then
						Clipboard.put(account_id)
						mod:notify(mod:localize("account_id_copied"))
					end
				end
				copy_button.on_pressed_sound = UISoundEvents.social_menu_see_player_profile
			end
			
			return popup_menu_items, num_menu_items
		end
	end
end)

mod.on_all_mods_loaded = function()
	-- Register localization strings for ViewElementGrid titles
	mod:add_global_localize_strings({
		players_list_title = {
			en = "Customized Players",
		},
		preset_colors_title = {
			en = "Preset Colors",
		}
	})
	
	update_local_player_id()  -- Try to get local player ID early
	ColorAllocator:reset()
	if mod.command then
		mod:command("cs_menu", "open color customizer menu", function() mod.open_color_customizer() end)
		mod:command("cs_sync", "sync/apply color settings", function()
			if UISettings and in_gameplay_state then
				apply_slot_colors()
				mod:notify("Colors synced")
			else
				mod:notify("Cannot sync colors outside of gameplay")
			end
		end)
	end

	local dmf = get_mod("DMF")
	if dmf then

		mod:hook(dmf, "check_keybinds", function(func)

			if Managers.ui and Managers.ui:view_active(color_customizer_view_name) then

				return
			end

			return func()
		end)
	end
	
	-- Hook player removal to clean up color allocations and reapply colors
	mod:hook_safe("HumanGameplay", "on_player_removed", function(self, player)
		_on_player_removed(player)
		
		-- Reapply colors after a short delay to allow for reassignment
		if in_gameplay_state then
			mod:pcall(function()
				apply_slot_colors()
				update_player_panel_colors()
			end)
		end
	end)
end

mod.on_game_state_changed = function(status, state_name)
	update_local_player_id()  -- Update local player ID on state change
	
	if status == "enter" and state_name == "StateGameplay" then
		in_gameplay_state = true
		apply_slot_colors()
	elseif status == "exit" and state_name == "StateGameplay" then
		in_gameplay_state = false
		restore_previous()
	end
end

mod.on_enabled = function()
	update_local_player_id()  -- Update local player ID when mod enabled
	if UISettings and in_gameplay_state then
		apply_slot_colors()
	end
end

mod.on_disabled = function()
	if previous_slot_colors and UISettings and UISettings.player_slot_colors then
		restore_previous()

		if in_gameplay_state then
			update_player_panel_colors()
		end
	end
end

mod.on_setting_changed = function(setting_id)
	-- Handle preset dropdown changes - update RGB sliders
	if setting_id:match("_preset$") then
		if setting_id == "bot_preset" then
			-- Bot preset
			local preset_id = mod:get(setting_id)
			if preset_id == "default" then
				mod:set("bot_r", 128)
				mod:set("bot_g", 128)
				mod:set("bot_b", 128)
			else
				for _, p in ipairs(color_presets) do
					if p.id == preset_id then
						mod:set("bot_r", p.r)
						mod:set("bot_g", p.g)
						mod:set("bot_b", p.b)
						break
					end
				end
			end
		else
			-- Slot preset
			local slot = tonumber(setting_id:match("slot(%d+)_preset"))
			if slot then
				local preset_id = mod:get(setting_id)
				if preset_id == "default" then
					local defaults = {
						{226, 210, 117}, -- Slot 1 yellow
						{180, 88, 108},  -- Slot 2 red
						{84, 172, 121},  -- Slot 3 green
						{126, 153, 230}, -- Slot 4 blue
					}
					local default_color = defaults[slot]
					if default_color then
						mod:set(string.format("slot%d_r", slot), default_color[1])
						mod:set(string.format("slot%d_g", slot), default_color[2])
						mod:set(string.format("slot%d_b", slot), default_color[3])
					end
				else
					for _, p in ipairs(color_presets) do
						if p.id == preset_id then
							mod:set(string.format("slot%d_r", slot), p.r)
							mod:set(string.format("slot%d_g", slot), p.g)
							mod:set(string.format("slot%d_b", slot), p.b)
							break
						end
					end
				end
			end
		end
	end
	
	-- Handle RGB slider changes
	if string.find(setting_id, "slot%d") or string.find(setting_id, "bot_") then
		ColorAllocator:reset()
		if UISettings and in_gameplay_state then
			apply_slot_colors()
		end
		update_player_panel_colors()
	end
end
