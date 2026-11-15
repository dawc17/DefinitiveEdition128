local sf2 = require("sf2")
local words = require("content.text")

-- The name is the game's own, from Eclipse's English text.
local title = words.own("item.titans_desolator", "WEAPON_TITAN_GIANT_SWORD")

local desolator = sf2.items.register {
    category = "weapon",
    id = "titans_desolator",
    display_name = title,
    icon = sf2.assets.sprite("core:UI/Items/Weapon17.img_weapon_boss_giant_sword"),
    model = sf2.assets.model("core:gamedata/models/mdl_weapon_giant_sword"),
    subtype = "TitanGiantSword",
}

sf2.items.patch {
    item = desolator,
    perks = {
        { perk = sf2.perks.get("core:perks/PERK_TITAN") },
        { perk = sf2.perks.get("core:perks/PERK_ANTI_SHOCK") },
    },
    -- The dojo disciple's sparring fight never borrows Titan's gear.
    borrowable = false,
}

-- Nor the story bosses' weapons, the ones the SE dojo shows on its stands (Seby, 2026-11-15).
for _, name in ipairs({
    "weapon_lynx_claws", "weapon_lynx_claws_paid", "weapon_butcher_knives", "weapon_butcher_knives_paid",
    "weapon_widow_fans", "weapon_wasp_naginata", "weapon_shogun_katana",
    "weapon_hermit_swords", "weapon_hermit_swords_paid", "weapon_titan_giant_sword",
}) do
    sf2.items.patch { item = sf2.items.get("core:items/weapon/" .. name), borrowable = false }
end

-- The final Eclipse Titan reward configures the level and Lifesteal on acquisition.
-- Equipment remains unlisted and has no purchase price.
return { titans_desolator = desolator }
