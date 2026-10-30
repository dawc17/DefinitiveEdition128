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
