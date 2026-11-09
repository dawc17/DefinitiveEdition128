local sf2 = require("sf2")
local words = require("content.text")

-- Shocking Strike (medium weapon enchantment): a damage-based chance on a landed weapon
-- hit to shock the enemy. A normal enemy is knocked down and disarmed. An enemy with Anti
-- Shock (bosses) can be shocked only by this: it is disarmed too, but the weapon returns
-- by itself after 10 s and the AI never walks to pick it up. The shock must not trigger
-- crit-based perks; the engine's force_hit_shock does not.
-- TODO(owner): behaviour against Titan, who has no knockdown animation, is undecided, so
-- nothing here treats him specially.
-- Plan: Shocking Strike Enchantment Concept Plan.

-- Stun (vanillaXml/DExml perks.xml PERK_ITEM_SPECIAL_STUN) rolls ChanceFactor 1.9 x hit
-- damage x the enchantment's power. This one is a bit rarer; power runs from LOW to HIGH.
local CHANCE_FACTOR = 1.4
local POWER_LOW, POWER_HIGH = 1.5, 3.0
local RETURN_FRAMES = 600

-- The forge tier reaches the behavior as self.strength: low 0, mid 0.5, high 1.
local function chance(strength, damage)
    return CHANCE_FACTOR * damage * (POWER_LOW + (POWER_HIGH - POWER_LOW) * strength)
end

local behavior = {
    -- A state table makes self.strength available.
    state = { lifetime = "round", fields = { shocks = 0 } },
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or event.blocked or not event.weapon or event.damage <= 0 then return end
        -- Already knocked down: another shock would only waste the chance.
        if fighter:animation_is("Fall", "opponent") then return end
        if sf2.random.number("shocking_strike") >= chance(self.strength, event.damage) then return end
        if fighter:has_perk("PERK_ANTI_SHOCK", "opponent") then
            fighter:force_hit_shock { disarm = true, weapon_returns_after = RETURN_FRAMES }
        else
            fighter:force_hit_shock { disarm = true }
        end
        self.state.shocks = self.state.shocks + 1
    end,
}

return sf2.perks.register {
    id = "shocking_strike",
    display_name = words.own("special.shocking_strike.name", "ENCHANTMENT_SHOCK"),
    description = words.own("special.shocking_strike.description", "special.shocking_strike.description"),
    icon = sf2.assets.sprite("core:ui/skills/IconMasterOfStyle"),
    behavior = behavior,
    enchantment = { recipe = "medium", item_types = { "weapon" } },
}
