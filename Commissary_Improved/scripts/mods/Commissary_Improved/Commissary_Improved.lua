local mod = get_mod("Commissary_Improved")

local CosmeticsVendorView = require("scripts/ui/views/cosmetics_vendor_view/cosmetics_vendor_view")
local CosmeticsVendorBackgroundView = require("scripts/ui/views/cosmetics_vendor_background_view/cosmetics_vendor_background_view")
local ProfileUtils = require("scripts/utilities/profile_utils")
local Items = require("scripts/utilities/items")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Definitions = require("scripts/ui/views/cosmetics_vendor_view/cosmetics_vendor_view_definitions")

local CHARACTER_ITEM_TYPES = {
	GEAR_UPPERBODY = true,
	GEAR_LOWERBODY = true,
	GEAR_HEAD = true,
	GEAR_EXTRA_COSMETIC = true,
	END_OF_ROUND = true,
	SET = true,
}

local function is_character_item(item)
	return item ~= nil and CHARACTER_ITEM_TYPES[item.item_type] == true
end

mod.current_profiles = nil
mod.selected_profile = nil

local function item_allowed_profiles(previewed_item)
	local profiles = mod.current_profiles
	local result = {}

	if not profiles then
		return result
	end

	local archetypes = previewed_item and previewed_item.archetypes

	for i = 1, #profiles do
		local profile = profiles[i]

		if not archetypes or #archetypes == 0 or table.contains(archetypes, profile.archetype.name) then
			result[#result + 1] = profile
		end
	end

	return result
end

local function has_multiple_allowed_profiles(previewed_item)
	local profiles = mod.current_profiles

	if not profiles then
		return false
	end

	local archetypes = previewed_item and previewed_item.archetypes
	local count = 0

	for i = 1, #profiles do
		local profile = profiles[i]
		local archetype_name = profile and profile.archetype and profile.archetype.name

		if not archetypes or #archetypes == 0 or table.contains(archetypes, archetype_name) then
			count = count + 1

			if count > 1 then
				return true
			end
		end
	end

	return false
end

local function profile_in_list(profile, profiles)
	if not profile or not profiles then
		return false
	end

	for i = 1, #profiles do
		local other = profiles[i]

		if profile.character_id and other.character_id and profile.character_id == other.character_id then
			return true
		end
	end

	return false
end

mod._refresh_profiles = function(view)
	Managers.data_service.profiles
		:fetch_all_profiles()
		:next(function(profile_data)
			mod.current_profiles = profile_data.profiles

			if view and view._ci_element then
				mod.preview_current(view)
			end
		end)
		:catch(function()
			-- keep going without multi-profile support
		end)
end

mod.preview_current = function(view)
	if view._ci_element then
		view:_preview_element(view._ci_element)
	end
end

local function ensure_selected_profile(view, previewed_item)
	local profiles = mod.current_profiles

	if not profiles or #profiles == 0 then
		return
	end

	local allowed = item_allowed_profiles(previewed_item)

	if #allowed == 0 then
		if view._preview_profile then
			mod.selected_profile = view._preview_profile
		end

		return
	end

	if profile_in_list(mod.selected_profile, allowed) then
		return
	end

	local own_profile = view._preview_profile
	local chosen = allowed[1]

	if own_profile and own_profile.archetype then
		for i = 1, #allowed do
			if allowed[i].archetype.name == own_profile.archetype.name then
				chosen = allowed[i]

				break
			end
		end
	end

	mod.selected_profile = chosen
end

mod.switch_profile = function(view, delta)
	local allowed = item_allowed_profiles(view._previewed_item)

	if #allowed == 0 then
		return
	end

	local index = 1

	for i = 1, #allowed do
		if profile_in_list(allowed[i], { mod.selected_profile }) then
			index = i

			break
		end
	end

	index = index + delta

	if index < 1 then
		index = #allowed
	elseif index > #allowed then
		index = 1
	end

	mod.selected_profile = allowed[index]
	view._ci_switched_profile = true

	mod.preview_current(view)
end

CosmeticsVendorView._get_profiles = function(self, previewed_item)
	local player_profile = mod.selected_profile or self._preview_profile

	if not player_profile then
		player_profile = self._preview_profile
	end

	local mannequin_profile = ProfileUtils.create_mannequin_profile(previewed_item, player_profile)

	return mannequin_profile, player_profile
end

CosmeticsVendorView._setup_side_panel = function(self, item)
	self:_destroy_side_panel()

	local y_offset = 0
	local scenegraph_id = "side_panel_area"
	local max_width = self._ui_scenegraph[scenegraph_id].size[1]
	local widgets = {}

	self._side_panel_widgets = widgets

	if not item then
		return
	end

	local function _add_text_widget(pass_template, text)
		local widget_definition = UIWidget.create_definition(pass_template, scenegraph_id, nil, {
			max_width,
			0,
		})
		local widget = self:_create_widget(string.format("side_panel_widget_%d", #widgets), widget_definition)

		widget.content.text = text
		widget.offset[2] = y_offset

		local widget_text_style = widget.style.text
		local _, text_height = self:_text_size(text, widget_text_style, {
			max_width,
			math.huge,
		})

		y_offset = y_offset + text_height
		widget.content.size[2] = text_height
		widgets[#widgets + 1] = widget
	end

	local function _add_spacing(height)
		y_offset = y_offset + height
	end

	local function _add_section(header_loc, text)
		if not text then
			return
		end

		if #widgets > 0 then
			_add_spacing(24)
		end

		_add_text_widget(Definitions.item_sub_title_pass, Utf8.upper(Localize(header_loc)))
		_add_spacing(8)
		_add_text_widget(Definitions.item_text_pass, text)
	end

	local properties_text = Items.item_property_text(item, true)
	local restrictions_text, present_restrictions = Items.restriction_text(item)

	if not present_restrictions then
		restrictions_text = nil
	end

	local showing_text

	if self._previewed_with_gear ~= false and is_character_item(item) and mod.selected_profile and mod.current_profiles then
		local archetype_name = mod.selected_profile.archetype and mod.selected_profile.archetype.name
		local symbol = archetype_name and UISettings.archetype_font_icon and UISettings.archetype_font_icon[archetype_name] or ""
		local profile_name = mod.selected_profile.name or ""

		showing_text = string.format("%s %s", symbol, profile_name)
	end

	if not (properties_text or restrictions_text or showing_text) then
		return
	end

	_add_section("loc_item_property_header", properties_text)
	_add_section("loc_item_equippable_on_header", restrictions_text)
	_add_section("loc_CVI_currently_showing", showing_text)

	for i = 1, #widgets do
		local widget_offset = widgets[i].offset

		widget_offset[1] = 0
		widget_offset[2] = widget_offset[2] - y_offset
	end
end

CosmeticsVendorView.cb_next_profile = function(self)
	mod.switch_profile(self, 1)
end

CosmeticsVendorView.cb_prev_profile = function(self)
	mod.switch_profile(self, -1)
end

CosmeticsVendorView.cb_toggle_gear = function(self)
	self:cb_on_preview_with_gear_toggled()
end

mod:hook(CLASS.CosmeticsVendorView, "_preview_element", function(func, self, element)
	local item = element and (element.real_item or element.item)

	self._ci_element = element
	self._ci_item = item

	ensure_selected_profile(self, item)

	return func(self, element)
end)

mod:hook_safe(CLASS.CosmeticsVendorView, "_preview_item", function(self)
	local item = self._previewed_item

	self.can_preview_with_gear = is_character_item(item)

	-- Don't spawn the companion (dog) while previewing character cosmetics.
	if is_character_item(item) then
		if self._gear_profile and self._gear_profile.loadout then
			self._gear_profile.loadout["slot_companion_gear_full"] = nil
		end

		if self._mannequin_profile and self._mannequin_profile.loadout then
			self._mannequin_profile.loadout["slot_companion_gear_full"] = nil
		end
	end

	if is_character_item(item) and self._previewed_with_gear and self._gear_profile and self._store_presentation_profile ~= self._gear_profile then
		self._store_presentation_profile = self._gear_profile
		self._keep_current_rotation = true
		self._spawn_player = true
	end

	if self._ci_switched_profile then
		self._ci_switched_profile = nil
		self._keep_current_rotation = true
		self._spawn_player = true
	end
end)

mod:hook_safe(CLASS.CosmeticsVendorView, "on_enter", function(self)
	self._previewed_with_gear = true

	mod.selected_profile = self._preview_profile
	mod._refresh_profiles(self)
end)

mod:hook_safe(CLASS.CosmeticsVendorView, "cb_on_preview_with_gear_toggled", function(self)
	if self._previewed_item then
		self:_setup_side_panel(self._previewed_item)
	end
end)

local function active_view_instance(parent)
	local active_view = parent and parent._active_view
	local ui = Managers and Managers.ui

	if not active_view or not ui or type(ui.view_instance) ~= "function" then
		return nil
	end

	return ui:view_instance(active_view)
end

mod:hook_safe(CLASS.CosmeticsVendorBackgroundView, "_setup_input_legend", function(self)
	local input_legend = self._input_legend_element

	if not input_legend then
		return
	end

	local entries = {
		{
			display_name = "loc_CVI_swap_operative",
			input_action = "cycle_chat_channel",
			on_pressed_callback = "cb_next_profile",
			visibility_function = function(parent)
				local view = active_view_instance(parent)

				if not view then
					return false
				end

				-- Only show when previewing on operative (not mannequin)
				if view._previewed_with_gear == false then
					return false
				end

				local previewed_item = view._previewed_item

				return mod.current_profiles
					and previewed_item ~= nil
					and is_character_item(previewed_item)
					and previewed_item.item_type ~= "WEAPON_SKIN"
					and has_multiple_allowed_profiles(previewed_item)
			end,
		},
	}

	for i = 1, #entries do
		local entry = entries[i]

		self:add_input_legend_entry({
			alignment = "right_alignment",
			display_name = entry.display_name,
			input_action = entry.input_action,
			on_pressed_callback = entry.on_pressed_callback,
			visibility_function = entry.visibility_function,
		})
	end
end)

return mod
