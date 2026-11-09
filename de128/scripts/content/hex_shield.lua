local sf2 = require("sf2")
local words = require("content.text")

-- Hex Shield (medium enchantment, not a special): one hit is absorbed completely and
-- cannot knock the wearer back, then the shield recharges. The recharge follows the
-- enchantment's forge tier: 15 s low, 10 s mid, 7 s high. Offered by the forge after the
-- first win against Titan (content.forge_choice).
-- Plan: Hex Shield Enchantment Concept Plan.

local RECHARGE = { 900, 600, 420 }        -- frames for low, mid, high

-- The forge tier reaches the behavior as self.strength: low 0, mid 0.5, high 1.
local function recharge_frames(strength)
    return RECHARGE[strength < 0.25 and 1 or strength < 0.75 and 2 or 3]
end

local behavior = {
    state = { lifetime = "round", fields = { absorbing = false } },
    -- One charge: the hit that meets a ready shield consumes it and starts the recharge, and
    -- the same hit is zeroed when its damage is resolved.
    on_hit_pre_crit = function(self, fighter, event)
        if event.target ~= "self" or event.blocked or fighter:has_flag("down") then return end
        self.state.absorbing = true
        fighter:set_hit_armored(true)
        fighter:set_flag("down", recharge_frames(self.strength))
    end,
    on_damage_resolving = function(self, fighter)
        if not self.state.absorbing then return end
        self.state.absorbing = false
        fighter:scale_incoming_damage(0)
    end,
}

local icon = sf2.assets.sprite("sprites/abilities/titans_shield")
local name = words.own("special.hex_shield.name", "TitanShield")
local description = words.own("special.hex_shield.description", "special.hex_shield.description")
local perk = sf2.perks.register {
    id = "hex_shield",
    display_name = name,
    description = description,
    icon = icon,
    behavior = behavior,
}
local enchantment = sf2.perks.register {
    id = "hex_shield_enchantment",
    display_name = name,
    description = description,
    icon = icon,
    enchantment = { recipe = "medium", item_types = { "armor", "helm" }, perk = perk },
}

sf2.perks.patch { perk = perk, recharge_indicator = {
    flags = { sf2.mod.id .. ":behaviors/hex_shield:down" },
    ready = icon, cooldown = sf2.assets.sprite("sprites/abilities/titans_shield_cooldown") } }

return enchantment
