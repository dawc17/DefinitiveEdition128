local sf2 = require("sf2")
-- Pending map definitions. Registration alone does not reveal these entries.
local places = {
    { x = 45, y = -200, location = "core:locations/statue", preview = "preview_main.statue", music = "halls_of_the_dead_heroes" },
    { x = 130, y = -180, location = "core:locations/stone_dragon", preview = "preview_pvp_stone_dragon", music = "stone_dragon" },
    { x = -400, y = -20, location = "core:locations/village", preview = "preview_pvp_village", music = "sparring" },
    { x = -400, y = -20, location = "core:locations/ships", preview = "preview_pvp_ships", music = "ship_battle" },
    { x = -400, y = 20, location = "core:locations/flooded_village", preview = "preview_pvp_flooded_village", music = "fight38_sakura_forest" },
    { x = -400, y = -30, location = "core:locations/magic_rocks", preview = "preview_pvp_magic_rocks", music = "flying_rocks" },
}
local function register()
    local text = require("content.sensei_battle_text")
    local art = require("content.sensei_art")
    local result = { normal = {}, eclipse = {} }
    for act, place in ipairs(places) do
        local zone = sf2.zones.get("core:zones/zone_" .. act)
        for _, mode in ipairs({ "normal", "eclipse" }) do
            result[mode][act] = sf2.battles.register {
                id = "sensei_act_" .. act .. "_" .. mode, zone = zone,
                type = mode == "normal" and "story" or "final",
                x = place.x, y = place.y, location = place.location, preview = art.preview(place.preview), music = place.music,
                alias = text.alias, title = text.title, icon = "sensei",
                description = mode == "normal" and text.locked or text.description,
                eclipse_toggle_name = mode == "normal" and (sf2.mod.id .. ":battles/sensei_act_" .. act .. "_eclipse") or nil,
            }
        end
    end
    return result
end
return { register = register }
