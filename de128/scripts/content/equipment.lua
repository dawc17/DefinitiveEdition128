local sf2 = require("sf2")
local words = require("content.text")

-- The name is the game's own, from Eclipse's English text.
local title = words.get("WEAPON_TITAN_GIANT_SWORD")

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
}

-- The final Eclipse Titan reward configures the level and Lifesteal on acquisition.
-- Equipment remains unlisted and has no purchase price.
return { titans_desolator = desolator }
