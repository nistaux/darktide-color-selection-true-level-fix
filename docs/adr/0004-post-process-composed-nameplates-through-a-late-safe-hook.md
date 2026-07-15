# Post-process composed nameplates through a late safe hook

The compatibility fix will register a DMF `hook_safe` on `HudElementNameplates.update` during `on_all_mods_loaded`, then post-process only the Composed Nameplate after both Dependency Mods have contributed. This avoids wrapping either mod's formatting functions and avoids relying on a special user-managed load order; the seam remains coupled to a patch-sensitive game HUD method and therefore requires static checks and in-game validation after relevant updates.
