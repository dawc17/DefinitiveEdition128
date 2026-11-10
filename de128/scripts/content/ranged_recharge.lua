local sf2 = require("sf2")
local restored = require("content.restored_equipment")
local titan = require("content.titan_reward_equipment")

-- Ranged recharge and silence. Every throw starts a 4 s recharge on the ranged button
-- (also at the start of each round), and a ranged hit silences the opponent's magic for
-- 5 s. The rule is the game's PERK_RANGED_PLAYER (perks.xml); the throw moves in
-- moves.xml wait for its RangedRecharge flag and magic waits for SilenceIcon. Without
-- this module (saves without DE128) nothing sets those flags, so ranged and magic play
-- as in the base game.
--
-- Every throwable core ranged item. The Super Mine keeps its own PERK_MINE_PLAYER;
-- NoRanged and the hidden ability and projectile items (Saturn Blaster, Root Potion,
-- Glaivebow arrow, rifle bullet) are never thrown.
local core_items = {
    "RANGED_HW15_SKULL",
    "RANGED_HW16_SET",
    "RANGED_HW17_NEEDLES",
    "RANGED_HW20_SKULL",
    "RANGED_XMAS16_COOKIE",
    "RANGED_NY18_DONUT",
    "RANGED_HW19_SET",
    "NY20_RANGED_COOKIE",
    "NY20_RANGED_DONUT",
    "NY21_RANGED_SNOWRIKENS",
    "RANGED_CHNY20_TRADITIONAL",
    "RANGED_VAL20_AXE",
    "RANGED_IND21_KUNAI",
    "RANGED_IND21_CHAKRAM",
    "RANGED_AE21_TOMAHAWK",
    "RANGED_SUMMER21_ANCIENT_CHAKRAM",
    "RANGED_C4_Z1_WARLOCK_SHURIKEN",
    "RANGED_BP_S1_GUARDIAN",
    "RANGED_CHNY22_WEIGHED_KUNAI",
    "RANGED_BP_S2_SKANDA",
    "RANGED_BOAT_FESTIVAL_SUPER_SHURIKEN",
    "RANGED_BP_S3_WIND_MAKER",
    "RANGED_BP_S4_SCRIPTWRITER",
    "RANGED_BP_S5_TIME_SHIFTER",
    "RANGED_SUN_CHAKRAM",
    "RANGED_NY2024_AXE",
    "RANGED_AZTEC_24",
    "RANGED_FUTURIST_25",
    "RANGED_SHADES_25",
    "RANGED_BLASTER_ROGUESFORTUNE_25",
    "RANGED_NEEDLES_NEMESIS_STINGER_25",
    "RANGED_WINDS_HARMONY_25",
    "RANGED_PATH_OF_HERESY_25",
    "RANGED_FISH",
    "RANGED_WAR_AXES",
    "RANGED_XMAS14_SNOWBALLS",
    "RANGED_XMAS15_SNOWBALLS",
    "RANGED_THROWING_DAGGERS",
    "RANGED_SHURIKENS",
    "RANGED_SUPER_CHAKRAM_BLADES",
    "RANGED_KUNAI",
    "RANGED_ASSASSIN_KUNAI",
    "RANGED_HUNTERS_KNIVES",
    "RANGED_SILVER_SHURIKENS",
    "RANGED_SUPER_SHURIKEN",
    "RANGED_HUNTING_KUNAI",
    "RANGED_CHAKRAM",
    "RANGED_HEAVY_SHURIKENS",
    "RANGED_THROWING_SPIKES",
    "RANGED_SUPER_AXES",
    "RANGED_NEEDLE",
    "RANGED_SHURIKEN_OF_DARKNESS",
    "RANGED_GHOST_KUNAI",
    "RANGED_ASSASSINS_DAGGER",
    "RANGED_SUPER_KUNAI",
    "RANGED_ANCIENT_CHAKRAM",
    "RANGED_BEAST_AXES",
    "RANGED_KUNAI_OF_WIND",
    "RANGED_SUPER_DAGGERS",
    "RANGED_DRAGON_WINGS",
    "RANGED_CHAKRAM_OF_MASTER",
    "RANGED_WEIGHED_KUNAI",
    "RANGED_THROWING_SICKLES",
    "RANGED_SUPER_BOOMERANG",
    "RANGED_THROWING_AXE",
    "RANGED_CIRCULAR_SAW",
    "RANGED_BLASTER",
    "RANGED_LOTOS",
    "RANGED_THORNS",
    "RANGED_SUPER_BLADE",
    "RANGED_UNKNOWN",
    "RANGED_TITANS_HARPOON",
    "RANGED_C2_Z2_MONK_SHURIKEN",
    "RANGED_C2_Z3_SENTINEL_SHURIKEN",
    "RANGED_C1_Z4_NEO_WANDERER",
    "RANGED_ANNIVERSARY_10TH",
    "RANGED_RAID_FUNGUS_SET",
    "RANGED_RAID_VOLCANO_SET",
    "RANGED_KARCER_HUNGER_SET",
}

local perks = { { perk = sf2.perks.get("core:perks/PERK_RANGED_PLAYER") } }
for _, name in ipairs(core_items) do
    sf2.items.patch { item = sf2.items.get("core:items/ranged/" .. name), perks = perks }
end
-- DE128's own ranged items.
sf2.items.patch { item = restored.dragon_boomerangs, perks = perks }
sf2.items.patch { item = titan.harpoon, perks = perks }
