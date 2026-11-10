local sf2 = require("sf2")
local abilities = require("content.boss_abilities")
local power_field = require("content.gatekeeper_power_field")

-- Cronos (Act 7 miniboss MINIBOSS_HYPERION, template Cyborg_Hyperion) casts Gatekeeper's Power
-- Field: the same DE128 cast, core perk lock and recharge as Gatekeeper. He keeps the Standard
-- tactic between fields. The fight's opponents are restated from core stages.xml (a patch
-- replaces the whole list); only Cronos's tactic and perks differ. Its rules are untouched.
local function looter(template, power)
    return { fighter = "core:warrior-templates/" .. template, tactic = "Standard",
        attributes = { WarriorPower = power } }
end

local tactic = power_field.standard_tactic
sf2.battles.patch {
    fight = "core:fights/zone_7/miniboss_hyperion/1",
    opponents = {
        looter("looter_man_staff", 1632),
        looter("looter_man_glaive", 1642),
        looter("looter_man_knives", 1646),
        looter("looter_man_section_scythe", 1650),
        looter("looter_girl_staff", 1654),
        {
            fighter = "core:warrior-templates/cyborg_hyperion", tactic = tactic,
            attributes = { WarriorPower = 1660 },
            -- Gatekeeper's normal Underworld perk row; the pacing perk drives the cast's recharge
            -- and his HUD icon.
            perks = {
                { perk = sf2.perks.get("core:perks/PERK_POWER_FIELD"), frames = 800 },
                abilities.pace_perk_for(tactic),
            },
        },
    },
}
