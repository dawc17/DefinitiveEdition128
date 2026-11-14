local sf2 = require("sf2")
local words = require("content.text")

-- Optional: story fights use the Shadow Fight 2 Special Edition version of their stage.
-- The SE stages ship with the game as core:locations/<name>_se (versus offers them as well);
-- the switch only redirects fights outside versus, and the dojo backdrop when the player
-- keeps the default dojo.
local se_locations = sf2.settings.toggle {
    id = "se_locations",
    label = words.read("de128.se_locations.label"),
    description = words.read("de128.se_locations.description"),
    group = "Visuals",
    default = false,
}

local stages = {
    "arena", "autumn", "bamboo_grove", "castle_and_bridge", "chess_yard", "dojo", "eggs",
    "emerald_forest", "flooded_village", "flowers_field", "fuji", "ice_cave", "lamps_on_water",
    "moon", "mountain", "night_bridge", "pink_lake", "ruins_village", "ruins_village_small",
    "sakura", "shadow_gate", "skyport", "swamp", "village", "waterfall",
}

for _, stage in ipairs(stages) do
    sf2.world.replace {
        location = "core:locations/" .. stage,
        replacement = "core:locations/" .. stage .. "_se",
        setting = se_locations,
    }
end

-- The owner's Special Edition battle previews (core <atlas>_se.<member>, 2026-11 drop), shown
-- on the map while the same switch is on.
local se_previews = {
    "preview_bosses.butcher", "preview_bosses.hermit", "preview_bosses.huntress", "preview_bosses.samurai",
    "preview_bosses.titan", "preview_bosses.wasp",
    "preview_main.autumn", "preview_main.bamboo_grove", "preview_main.battlefield", "preview_main.castle_and_bridge",
    "preview_main.cave", "preview_main.dark_room", "preview_main.emerald_forest", "preview_main.flowers_field",
    "preview_main.flying_rocks", "preview_main.graveyard_ships", "preview_main.heaven", "preview_main.ice_cave",
    "preview_main.lamps_on_water", "preview_main.mountain", "preview_main.night_bridge", "preview_main.pink_lake",
    "preview_main.ruins_village", "preview_main.sakura", "preview_main.shadow_gate", "preview_main.snowy_peak",
    "preview_main.swamp", "preview_main.volcano", "preview_main.waterfall",
    "preview_main_i.capsules", "preview_main_i.eggs", "preview_main_i.factory", "preview_main_i.spaceship",
    "preview_main_i.stone_forest",
    "preview_start.arena", "preview_start.lynx",
}

for _, preview in ipairs(se_previews) do
    local atlas, member = preview:match("^([^.]+)%.(.+)$")
    sf2.battles.replace_preview {
        preview = preview,
        replacement = atlas .. "_se." .. member,
        setting = se_locations,
    }
end
