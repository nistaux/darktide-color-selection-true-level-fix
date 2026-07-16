return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`color_selection_true_level_fix` requires the Darktide Mod Framework.")

        new_mod("color_selection_true_level_fix", {
            mod_script = "color_selection_true_level_fix/scripts/mods/color_selection_true_level_fix/color_selection_true_level_fix",
            mod_data = "color_selection_true_level_fix/scripts/mods/color_selection_true_level_fix/color_selection_true_level_fix_data",
            mod_localization = "color_selection_true_level_fix/scripts/mods/color_selection_true_level_fix/color_selection_true_level_fix_localization",
        })
    end,
    packages = {},
    dependencies = {
        { mod_name = "true_level", optional = true },
        { mod_name = "ColorSelection", optional = true },
    },
    version = "1.0.0",
    mod_id = "color_selection_true_level_fix",
}
