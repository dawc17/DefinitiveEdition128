local sf2 = require("sf2")
local words = require("content.text")

-- Underworld elixirs (owner, 2026-11-18): stackable consumables the shop sells by the piece and
-- every Underworld win drops, one at random (content.underworld adds `drop` to each win). They are
-- drunk in a sealed boss fight's Prepare menu, and content.underworld_seals applies their effects.
-- Prices, the shop level and every number here are placeholders, to be tuned later.
--
-- The shop lists them from level 3, the level the Underworld's first boss (Volcano, BOSS_1) asks
-- for; the Underworld itself opens after Lynx's second fight in Act 1, so they need no shop group.
local SHOP_LEVEL = 3
local STACK = 9

-- effect: what content.underworld_seals does when the elixir is drunk.
--   heal        restores HEAL of the player's health as the fight resumes;
--   iron_skin   removes IRON_SKIN of the damage the player takes,   } for SECONDS of fight time,
--   fury        multiplies the player's damage by FURY,             } from the start of the
--   clear_mind  lifts the seal's rule (the seal's rule-free phase). } next seal.
-- They carry the names and pictures of the original game's elixirs (owner, 2026-11-19), though
-- their effects are DE128's: `vanilla` is the game's text key for the name (Healing Vine, Crag,
-- The Explosive Vigor, Star Clarity). Words: de128.uw_seals.elixir.<text>.name, .description and
-- .short in Eclipse's English text.
local ELIXIRS = {
    { id = "healing_elixir", text = "healing", vanilla = "PotionLife", effect = "heal", coins = 300 },
    { id = "iron_skin_elixir", text = "iron_skin", vanilla = "PotionRock", effect = "iron_skin", coins = 450 },
    { id = "fury_elixir", text = "fury", vanilla = "PotionBomb", effect = "fury", coins = 450 },
    { id = "clear_mind_elixir", text = "clear_mind", vanilla = "PotionResistance", effect = "clear_mind", coins = 600 },
}
local HEAL = 0.3
local IRON_SKIN = 0.5
local FURY = 1.3
local SECONDS = 10

-- Icons: the game's raid potion pictures (RaidItems3.potion_life, potion_rock, potion_blood_bomb,
-- potion_resistance) in assets/textures/elixirs, from Tools/Recovery/ImportDE128ElixirIcons.py.
local candidates = {}
for index, elixir in ipairs(ELIXIRS) do
    local key = "de128.uw_seals.elixir." .. elixir.text
    elixir.name = words.read(key .. ".name")
    -- One line for the game's Prepare screen.
    elixir.short = words.read(key .. ".short")
    elixir.icon = sf2.assets.sprite("sprites/elixirs/" .. elixir.id)
    elixir.item = sf2.items.register {
        category = "consumable", id = elixir.id,
        display_name = words.own("item." .. elixir.id, elixir.vanilla),
        description = words.own("item." .. elixir.id .. ".description", key .. ".description"),
        icon = elixir.icon, stack = STACK,
        shop = { level = SHOP_LEVEL, price = { coins = elixir.coins } },
    }
    candidates[index] = { item = elixir.item }
end

local by_id = {}
for _, elixir in ipairs(ELIXIRS) do by_id[elixir.id] = elixir end

return {
    list = ELIXIRS,
    by_id = by_id,
    -- A reward's `choices`: one elixir, each as likely as the others.
    drop = { { items = candidates } },
    heal = HEAL,
    iron_skin = IRON_SKIN,
    fury = FURY,
    frames = SECONDS * 60,
}
