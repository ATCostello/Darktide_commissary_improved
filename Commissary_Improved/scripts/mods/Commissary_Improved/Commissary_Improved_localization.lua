local mod = get_mod("Commissary_Improved")
mod.version = "1.0"

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function utf8_chars(s)
	local chars = {}
	for char in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
		table.insert(chars, char)
	end
	return chars
end

mod.gradientText = function(text, startColor, endColor, colorSpaces)
	local result = ""
	local chars = utf8_chars(text)
	local visibleIndex = 0

	for _, char in ipairs(chars) do
		if colorSpaces or char ~= " " then
			visibleIndex = visibleIndex + 1
		end
	end

	local currentIndex = 0

	for _, char in ipairs(chars) do
		if not colorSpaces and char == " " then
			result = result .. char
		else
			currentIndex = currentIndex + 1
			local t = (visibleIndex <= 1) and 0 or (currentIndex - 1) / (visibleIndex - 1)

			local r = math.floor(lerp(startColor[1], endColor[1], t))
			local g = math.floor(lerp(startColor[2], endColor[2], t))
			local b = math.floor(lerp(startColor[3], endColor[3], t))

			result = result .. string.format("{#color(%d,%d,%d)}%s", r, g, b, char)
		end
	end

	result = "{#color(" .. colours.title .. ")}" .. result .. "{#reset()}"
	return result
end

local mod_name = {
	en = "Commissary Improved",
}
mod:info(mod_name["en"] .. " is installed, using version: " .. tostring(mod.version))

mod.localisation = {

	mod_name = {
		en = mod_name["en"],
	},
	mod_name_pizazz = {
		en = mod.gradientText(mod_name["en"], { 255, 140, 0 }, { 255, 255, 0 }, true),
	},
	mod_name_boring = {
		en = mod_name["en"],
	},

	mod_description = {
		en = "{#color("
			.. colours.text
			.. ")}"
			.. "Adds multi-operative preview and ownership info to the commissary."
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Author: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Version: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},

	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
		ru = "Включить красочные имена",
		["zh-cn"] = "启用名称特效",
		["zh-tw"] = "啟用名稱特效",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
		ru = "Включает радужный эффект для текста имени мода. Требуется перезагрузка.\nЕсли включено, вы будете получать небольшой эйфорический опыт каждый раз, когда прокручиваете меню модов.\nЕсли выключено - вы будете Джоном Дарктайдом и без радужных посыпок (но я все равно буду вас любить).",
		["zh-cn"] = "切换模组名称的彩虹颜色效果。需要重新加载。\n启用后，每次滚动模组菜单时你都会获得小小的愉悦体验。\n禁用后，你将失去彩虹点缀（但我仍然爱你）。",
		["zh-tw"] = "切換模組名稱的彩虹顏色效果。需要重新載入。\n啟用後，每次滾動模組選單時你都會獲得小小的愉悅體驗。\n停用後，你將成為一般的黑暗潮汐玩家，失去彩虹點綴（但我仍然愛你）。",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Основные настройки{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}通用设置{#reset()}",
		["zh-tw"] = "{#color(" .. colours.title .. ")}一般設定{#reset()}",
	},
	placeholder = {
		en = "",
		["zh-cn"] = "",
		["zh-tw"] = "",
	},
	placeholder_tooltip = {
		en = "A placeholder entry to initialise the mod menu, does not do anything yet.\nMore features may be added at some point.",
		ru = "Заглушка для инициализации меню мода, пока ничего не делает.\nВозможно, в будущем будут добавлены дополнительные функции.",
		["zh-cn"] = "用于初始化模组菜单的占位符，目前没有任何功能。\n后续可能会添加更多功能。",
		["zh-tw"] = "用於初始化模組選單的佔位符，目前沒有任何功能。\n後續可能會添加更多功能。",
	},
}

mod.toggle_pizazz = function()
	for key, values in pairs(mod.localisation) do
		if key == "mod_name" then
			for language, text in pairs(values) do
				if mod:get("mod_name_pizazz_toggle") then
					mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
				else
					mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
				end
			end
		end
	end
end

mod.toggle_pizazz()

mod.localisation.loc_CVI_swap_operative = {
	en = "Change Operative",
	ru = "Сменить оперативника",
	["zh-cn"] = "变更特工",
	["zh-tw"] = "變更特工",
}
mod.localisation.loc_CVI_toggle_equipment = {
	en = "Toggle Equipment",
	ru = "Переключить снаряжение",
	["zh-cn"] = "切换装备",
	["zh-tw"] = "切換裝備",
}
mod.localisation.loc_CVI_currently_showing = {
	en = "Currently showing on Operative:",
	ru = "Сейчас на оперативнике отображается:",
	["zh-cn"] = "已在特工身上显示",
	["zh-tw"] = "已在特工身上顯示",
}
mod.localisation.loc_CVI_weapon_header = {
	en = "Compatible Weapons",
	ru = "Совместимое оружие",
	["zh-cn"] = "兼容武器",
	["zh-tw"] = "相容武器",
}
mod.localisation.loc_CVI_cycle_weapon = {
	en = "Cycle Weapon",
	ru = "Сменить оружие",
	["zh-cn"] = "切换武器",
	["zh-tw"] = "切換武器",
}

-- Register the strings used with the game's global Localize() so they resolve
-- outside of mod:localize() (e.g. side panel headers and legend labels).
mod:add_global_localize_strings({
	loc_CVI_swap_operative = mod.localisation.loc_CVI_swap_operative,
	loc_CVI_toggle_equipment = mod.localisation.loc_CVI_toggle_equipment,
	loc_CVI_currently_showing = mod.localisation.loc_CVI_currently_showing,
	loc_CVI_weapon_header = mod.localisation.loc_CVI_weapon_header,
	loc_CVI_cycle_weapon = mod.localisation.loc_CVI_cycle_weapon,
})

return mod.localisation
