local sf2 = require("sf2")
local words = require("content.text")

-- Seby's Rifle and Musket plan (2026-11-08): each Super Slash then recharges for 3 seconds,
-- shown as a ring filling round the punch button, and the Musket's ball flies 1.5x faster.
-- The recharge is an innate perk on both weapons, so opponents wielding them wait too.

local KEY = "super_slash_recharge"
local FRAMES = 180
-- Flag names seen by native move conditions: <qualified behavior ID>:<key>.
local FLAG = sf2.mod.id .. ":behaviors/" .. KEY .. ":" .. KEY
local SUPER_SLASHES = { RifleSuperSlash = true, MusketSuperSlash = true }

local recharge = sf2.perks.register {
    id = KEY,
    display_name = words.own("perk." .. KEY .. ".name", "de128." .. KEY .. ".name"),
    description = words.own("perk." .. KEY .. ".description", "de128." .. KEY .. ".description"),
    behavior = {
        on_animation_start = function(self, fighter, event)
            if event.target ~= "self" or not SUPER_SLASHES[event.animation_name] then return end
            fighter:clear_flag(KEY)
            fighter:set_flag(KEY, FRAMES)
            fighter:set_button_cooldown("punch", FRAMES)
        end,
    },
}

-- Both weapons carry enchantments, not innate perks, so this list replaces nothing.
for _, name in ipairs { "WEAPON_RIFLE", "WEAPON_NY2024_MUSKET" } do
    sf2.items.patch { item = sf2.items.get("core:items/weapon/" .. name), perks = { recharge } }
end

for move in pairs(SUPER_SLASHES) do
    sf2.moves.patch { move = move, when = { not_mod = FLAG } }
end

-- vanillaXml moves.xml: MusketShotMiddle carries <Velocity X="30"/>.
sf2.moves.patch { move = "MusketShotMiddle", speed = { expected = 30, value = 45 } }
