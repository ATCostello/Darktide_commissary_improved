return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Commissary_Improved` encountered an error loading the Darktide Mod Framework.")

		new_mod("Commissary_Improved", {
			mod_script       = "Commissary_Improved/scripts/mods/Commissary_Improved/Commissary_Improved",
			mod_data         = "Commissary_Improved/scripts/mods/Commissary_Improved/Commissary_Improved_data",
			mod_localization = "Commissary_Improved/scripts/mods/Commissary_Improved/Commissary_Improved_localization",
		})
	end,
	packages = {},
}
