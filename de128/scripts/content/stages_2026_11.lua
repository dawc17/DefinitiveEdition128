local sf2 = require("sf2")

-- Changes in the owner's November 2026 stages.xml (against the archived DExml/stages.xml)
-- that apply to core battles. Only the deltas the public API can express live here.

-- Punching bag training, second fight: the Dojo_Disciple sparring partner now fights with
-- the Aggressive tactic (was Standard). Its stats and rules are unchanged, so the whole
-- warrior is restated with only the tactic changed.
sf2.battles.patch {
    fight = "core:fights/punchbag/training/2",
    opponents = { {
        fighter = "core:warrior-templates/dojo_disciple", tactic = "Aggressive",
        attributes = { WeaponDamage = 2, UnarmedDamage = 2, BodyDefense = 2, HeadDefense = -3, CriticalChance = 0 },
        attribute_alignments = {
            { factor = 0, shift = 0, priority = 1 },
            { factor = 1, shift = -10, priority = 1 },
        },
    } },
}

-- Hot ground: every core hot-ground rule also counts LegFall (DE128's leg-sweep fall) as an
-- airborne animation, so a fighter knocked down that way is not burned while falling.
local HOT_GROUND = {
    kind = "hot_ground",
    animations = {
        expected = { "ThrowFall", "Jump", "PhysicalFall" },
        value = { "ThrowFall", "LegFall", "Jump", "PhysicalFall" },
    },
}

-- No falls: in the Duel, Duel_INTERMISSION and C3_Duel fights, ThrowForwardV is replaced by
-- ThrowThroughTheBackV and ThrowLegPushV. The list is kept exactly as the owner's file has it,
-- ThrowThroughTheBackV twice included; the game reads the list as a set.
local LOSE_FALL = {
    kind = "lose_fall",
    animations = {
        expected = { "Fall", "Physical", "ThrowThroughTheBackV", "ThrowForwardV" },
        value = { "Fall", "Physical", "ThrowThroughTheBackV", "ThrowThroughTheBackV", "ThrowLegPushV" },
    },
}

-- Core fights (and the four Eclipse-mode challenge battles, whose hot ground is a battle rule)
-- whose rules the owner's file changes. `true` marks the fights that also change their no-falls rule.
local rule_fights = {
    { "zone_1/duel_intermission/1", true },
    { "zone_2/challenge/6" }, { "zone_2/challenge/19" }, { "zone_2/duel_intermission/1", true },
    { "zone_3/challenge/11" }, { "zone_3/duel/1" }, { "zone_3/duel_intermission/1", true },
    { "zone_4/challenge/3" }, { "zone_4/duel/1", true }, { "zone_4/challenge_intermission/1" },
    { "zone_4/duel_intermission/1", true },
    { "zone_5/challenge/16" }, { "zone_5/duel/1", true }, { "zone_5/duel_intermission/1", true },
    { "zone_6/final_battle/1" }, { "zone_6/challenge/22" }, { "zone_6/duel/1", true },
    { "zone_6/duel_intermission/1", true }, { "zone_6/final_battle_eclipsemode/1" },
    { "zone_7/challenge/6" }, { "zone_7/challenge1_1/4" }, { "zone_7/duel/1", true },
    { "zone_7/c3_challenge/5" }, { "zone_7/c3_challenge/24" }, { "zone_7/c3_duel/1", true },
}

for _, entry in ipairs(rule_fights) do
    sf2.battles.patch {
        fight = "core:fights/" .. entry[1],
        edit_rules = entry[2] and { HOT_GROUND, LOSE_FALL } or { HOT_GROUND },
    }
end

for _, zone in ipairs({ "zone_2", "zone_3", "zone_5", "zone_6" }) do
    sf2.battles.patch { battle = "core:battles/" .. zone .. "/challenge_eclipsemode", edit_rules = { HOT_GROUND } }
end

-- Fighter blueprints. Master (Titan battle, fight 2) takes the Shadow Lord sword and Corsair
-- (fight 4) the Aztec armor, in both modes. Fury's blueprint takes the regular Shuang Gou, but
-- every core fight that uses her lists its own items, so only fights relying on the blueprint
-- (none in core) would show it.
local fighter_items = {
    { "girl_shuang_gou", "core:items/weapon/WEAPON_CEREMONIAL_SHUANG_GOU", "core:items/weapon/WEAPON_SHUANG_GOU" },
    { "man_z7_master", "core:items/weapon/WEAPON_SUPER_COMPOSITE_SWORD", "core:items/weapon/WEAPON_SWORD_SHADOW_LORD_25" },
    { "man_z7_corsair", "core:items/armor/ARMOR_BARBARIAN", "core:items/armor/ARMOR_AZTEC_24" },
}

for _, swap in ipairs(fighter_items) do
    sf2.fighters.patch {
        fighter = "core:warrior-templates/" .. swap[1],
        items = { { expected = swap[2], value = swap[3] } },
    }
end
