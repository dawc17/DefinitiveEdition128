local sf2 = require("sf2")
local words = require("content.text")

-- The final Eclipse Titan reward is a player-owned copy of these hidden
-- opponent items. Separate identities leave Titan's own loadout unchanged.
local form = sf2.items.register {
    category = "armor",
    id = "titans_form",
    display_name = words.own("titan_reward.BODY_TITAN", "BODY_TITAN"),
    icon = sf2.assets.sprite("core:UI/Items/UnknownItems.img_armor_unknown"),
    model = sf2.assets.model("models/titan/mdl_body_titan"),
    initial_stats = { body_defense = 1, unarmed_damage = 1 },
}
local helm = sf2.items.register {
    category = "helm",
    id = "titans_helm",
    display_name = words.own("titan_reward.HEAD_TITAN", "HEAD_TITAN"),
    icon = sf2.assets.sprite("core:UI/Items/UnknownItems.img_helm_unknown"),
    model = sf2.assets.model("models/titan/mdl_head_titan"),
    initial_stats = { head_defense = 1 },
}
local harpoon = sf2.items.register {
    category = "ranged",
    id = "titans_harpoon",
    display_name = words.own("titan_reward.RANGED_TITANS_HARPOON", "RANGED_TITANS_HARPOON"),
    icon = sf2.assets.sprite("core:UI/Items/UnknownItems.img_ranged_unknown"),
    model = sf2.assets.model("models/titan/mdl_ranged_titans_harpoon"),
    subtype = "TitansHarpoon",
    initial_stats = { ranged_damage = 1 },
}
local mind_throw = sf2.items.register {
    category = "magic",
    id = "titans_mind_throw",
    display_name = words.own("titan_reward.MAGIC_MIND_THROW", "MAGIC_MIND_THROW"),
    icon = sf2.assets.sprite("core:UI/Items/UnknownItems.img_magic_unknown"),
    model = sf2.assets.model("models/titan/mdl_magic_fireball"),
    subtype = "MindThrow",
    initial_stats = { magic_damage = 1 },
}

-- The dojo disciple's sparring fight never borrows Titan's gear.
for _, item in ipairs { form, helm, harpoon, mind_throw } do
    sf2.items.patch { item = item, borrowable = false }
end

-- Titan's Mind Throw is the game's MindThrowPlayer, which only Titan's sword unlocks (an item
-- lock on WEAPON_TITAN_GIANT_SWORD or WEAPON_DESOLATOR by name). DE128's reward Desolator is
-- its own item, so it is added beside that sword: the player can cast the Mind Throw only while
-- holding the Desolator. Titan himself keeps the game's sword and lock. The game's and DE's
-- MAGIC_MIND_THROW carry the MindThrow perk, which starts the throw's second phase
-- (MindThrowPlayer2); the reward copy carries it too.
sf2.moves.patch {
    move = "MindThrowPlayer",
    item_locks = { add = { {
        source_item = "core:items/weapon/WEAPON_TITAN_GIANT_SWORD",
        item = require("content.equipment").titans_desolator,
    } } },
}
sf2.items.patch { item = mind_throw, perks = { { perk = sf2.perks.get("core:perks/MindThrow") } } }

return { form = form, helm = helm, harpoon = harpoon, mind_throw = mind_throw }
