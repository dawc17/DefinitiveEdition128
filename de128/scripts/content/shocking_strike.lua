local sf2 = require("sf2")
local words = require("content.text")

-- Shocking Strike (medium weapon enchantment): a chance on a landed weapon hit to shock
-- the enemy, set by the enchantment's power alone. A normal enemy is knocked down and disarmed. An enemy with Anti
-- Shock (bosses) can be shocked only by this: it is disarmed too, but the weapon returns
-- by itself after 10 s and the AI never walks to pick it up. The shock must not trigger
-- crit-based perks; the engine's force_hit_shock does not.
-- TODO(owner): behaviour against Titan, who has no knockdown animation, is undecided, so
-- nothing here treats him specially.
-- Plan: Shocking Strike Enchantment Concept Plan.

-- The chance follows the enchantment's power (its aspect), not the hit's damage: scaling by
-- damage shocked on about every second hit of a strong weapon (Seby, 2026-11-14). Power
-- runs from LOW to HIGH, so a landed weapon hit shocks 3.75% of the time on a low roll and
-- 7.5% on a high one. First-pass numbers, awaiting playtest.
local CHANCE_PER_POWER = 0.025
local POWER_LOW, POWER_HIGH = 1.5, 3.0
local RETURN_FRAMES = 600

-- The forge tier reaches the behavior as self.strength: low 0, mid 0.5, high 1.
local function chance(strength)
    return CHANCE_PER_POWER * (POWER_LOW + (POWER_HIGH - POWER_LOW) * strength)
end

local shock_roll = sf2.random.stream("de128", "shocking_strike")

local behavior = {
    -- A state table makes self.strength available.
    state = { lifetime = "round", fields = { shocks = 0 } },
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or event.blocked or not event.weapon or event.damage <= 0 then return end
        -- Already knocked down: another shock would only waste the chance.
        if fighter:animation_is("Fall", "opponent") then return end
        if shock_roll:number() >= chance(self.strength) then return end
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
    -- The transparent glyph the shop and forge show for every enchantment, not the framed skill card.
    icon = sf2.assets.sprite("core:ui/Enchantments/EnchantmentShock"),
    behavior = behavior,
    enchantment = { recipe = "medium", item_types = { "weapon" } },
}
