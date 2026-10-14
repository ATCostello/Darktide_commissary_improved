local mod = get_mod("Commissary_Improved")

local CosmeticsVendorView = require("scripts/ui/views/cosmetics_vendor_view/cosmetics_vendor_view")
local CosmeticsVendorBackgroundView = require("scripts/ui/views/cosmetics_vendor_background_view/cosmetics_vendor_background_view")
local ProfileUtils = require("scripts/utilities/profile_utils")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Definitions = require("scripts/ui/views/cosmetics_vendor_view/cosmetics_vendor_view_definitions")

local WEAPON_ITEM_BASE = "content/items/weapons/player"

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

local function weapon_item_from_template(template_name)
	if not template_name then
		return nil
	end

	local melee_path = WEAPON_ITEM_BASE .. "/melee/" .. template_name
	local item = MasterItems.get_item(melee_path)

	if item then
		return item, melee_path
	end

	local ranged_path = WEAPON_ITEM_BASE .. "/ranged/" .. template_name
	item = MasterItems.get_item(ranged_path)

	if item then
		return item, ranged_path
	end

	return nil
end

local function build_weapon_marks(item)
	local marks = {}
	local restriction = item and item.weapon_template_restriction

	if not restriction then
		return marks
	end

	for i = 1, #restriction do
		local weapon_item, path = weapon_item_from_template(restriction[i])

		if weapon_item and path then
			local family = Items.weapon_card_display_name(weapon_item)
			local sub = Items.weapon_card_sub_display_name(weapon_item)

			if family == "n/a" then
				family = nil
			end

			if sub == "n/a" then
				sub = nil
			end

			local name = sub or family
			local label

			if family and sub then
				label = string.format("%s • %s", family, sub)
			else
				label = family or sub
			end

			marks[#marks + 1] = {
				path = path,
				name = name,
				label = label,
				template = restriction[i],
			}
		end
	end

	return marks
end

mod.refresh_weapon_marks = function(view, item)
	if not item or item.item_type ~= "WEAPON_SKIN" then
		view._ci_weapon_marks = nil
		view._ci_weapon_mark_item = nil
		view._ci_weapon_index = nil

		return
	end

	if view._ci_weapon_mark_item == item then
		return
	end

	view._ci_weapon_mark_item = item

	local marks = build_weapon_marks(item)
	view._ci_weapon_marks = marks

	local index = 1

	for i = 1, #marks do
		if marks[i].path == item.preview_item then
			index = i

			break
		end
	end

	view._ci_weapon_index = index
end

mod.current_mark_name = function(view)
	local marks = view._ci_weapon_marks
	local index = view._ci_weapon_index

	if marks and index and marks[index] then
		return marks[index].name
	end
end

mod.weapon_marks_text = function(view)
	local marks = view._ci_weapon_marks

	if not marks or #marks == 0 then
		return nil
	end

	local lines = {}

	for i = 1, #marks do
		lines[#lines + 1] = marks[i].label or marks[i].name
	end

	return table.concat(lines, "\n")
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

	local is_weapon_skin = item.item_type == "WEAPON_SKIN"

	local showing_text

	if self._previewed_with_gear ~= false and is_character_item(item) and mod.selected_profile and mod.current_profiles then
		local archetype_name = mod.selected_profile.archetype and mod.selected_profile.archetype.name
		local symbol = archetype_name and UISettings.archetype_font_icon and UISettings.archetype_font_icon[archetype_name] or ""
		local profile_name = mod.selected_profile.name or ""

		showing_text = string.format("%s %s", symbol, profile_name)
	end

	local marks_text = is_weapon_skin and mod.weapon_marks_text(self) or nil

	if not (properties_text or restrictions_text or showing_text or marks_text) then
		return
	end

	_add_section("loc_item_property_header", properties_text)
	_add_section("loc_item_equippable_on_header", restrictions_text)
	_add_section("loc_CVI_currently_showing", showing_text)
	--_add_section("loc_CVI_weapon_header", marks_text)

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

-- CosmeticsVendorView.cb_cycle_weapon_mark = function(self)
--	local item = self._previewed_item
--
--	if not item or item.item_type ~= "WEAPON_SKIN" then
--		return
--	end
--
--	mod.refresh_weapon_marks(self, item)
--
--	local marks = self._ci_weapon_marks
--
--	if not marks or #marks <= 1 then
--		return
--	end
--
--	local index = ((self._ci_weapon_index or 1) % #marks) + 1
--
--	self._ci_weapon_index = index
--
--	local mark = marks[index]
--	local weapon_item = MasterItems.get_item(mark.path)
--
--	if weapon_item and self._weapon_preview then
--		local visual_item = table.clone_instance(weapon_item)
--		visual_item.gear_id = item.gear_id
--		visual_item.slot_weapon_skin = item
--
--		self._weapon_preview:present_item(visual_item, true)
--	end
--
--	self:_setup_side_panel(item)
-- end

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

	if item and item.item_type == "WEAPON_SKIN" then
		mod.refresh_weapon_marks(self, item)
	end

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

	return active_view and Managers.ui:view_instance(active_view) or nil
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
					and #item_allowed_profiles(previewed_item) > 1
			end,
		},
		-- Cycle Weapon Mark commented out - weapon skins force specific marks/variants
		--[[
		{
			display_name = "loc_CVI_cycle_weapon",
			input_action = "character_create_randomize",
			on_pressed_callback = "cb_cycle_weapon_mark",
			visibility_function = function(parent)
				local view = active_view_instance(parent)

				if not view then
					return false
				end

				local previewed_item = view._previewed_item

				if not previewed_item or previewed_item.item_type ~= "WEAPON_SKIN" then
					return false
				end

				mod.refresh_weapon_marks(view, previewed_item)

				local marks = view._ci_weapon_marks

				return marks ~= nil and #marks > 1
			end,
		},
		]]
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
