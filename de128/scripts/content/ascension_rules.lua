local sf2 = require("sf2")
local words = require("content.text")

-- Ascension's battle rules, from Marmalade SF2 1.9.38 stages.xml (ZONE_2 Battle Ascension,
-- its battle-level <Rules>). Every fight gets the same two native random rules:
--   1. one enchantment set for the opponent (each perk at Aspect 100000), re-rolled each round;
--   2. one challenge for the player (NoDoubles), each with its rule description and the
--      damage-factor balance the archive pairs with it.
-- The archive's SetTactic Standard is the opponents' tactic (content.ascension). Its
-- RatingEvaluation lines only fed the map's difficulty estimate and are left out; the
-- commented-out challenges (RING_OUT_NO_BLOCKS, ENDURANCE, TIMEOUT_HOT_GROUND) stay out.
-- Rule tables are reused by every fight, so each is registered once.

local function perk(name)
    return { kind = "perk", perk = sf2.perks.get("core:perks/" .. name), aspect = 100000, target = "opponent" }
end

local function set(...)
    local rules = {}
    for index, name in ipairs({ ... }) do rules[index] = perk("PERK_ITEM_SPECIAL_" .. name) end
    return { kind = "group", rules = rules }
end

local enchantments = {
    kind = "random", refresh = "each_round",
    rules = {
        set("PRECISION_WEAPON", "PRECISION_RANGED"),
        set("OVERHEAT_WEAPON", "OVERHEAT_RANGED", "OVERHEAT_MAGIC"),
        set("INTOXICATION_WEAPON", "INTOXICATION_RANGED", "INTOXICATION_MAGIC"),
        set("WEAKNESS_WEAPON", "WEAKNESS_RANGED", "WEAKNESS_MAGIC"),
        set("BLOODRAGE_WEAPON", "BLOODRAGE_RANGED", "BLOODRAGE_MAGIC"),
        set("OVERHEAT_DEFENSE_ARMOR", "OVERHEAT_DEFENSE_HELM"),
        set("REJUVENATION_ARMOR", "REJUVENATION_HELM"),
        set("DAMAGE_ABSORPTION_BODY_ARMOR", "DAMAGE_ABSORPTION_HEAD_HELM"),
        set("LIFESTEAL_WEAPON", "LIFESTEAL_RANGED", "LIFESTEAL_MAGIC"),
        set("BLEEDING_WEAPON", "BLEEDING_RANGED", "BLEEDING_MAGIC"),
        set("ENFEEBLE_WEAPON", "ENFEEBLE_RANGED", "ENFEEBLE_MAGIC"),
        set("FRENZY_WEAPON", "FRENZY_RANGED", "FRENZY_MAGIC"),
        set("STUN_WEAPON", "STUN_RANGED", "STUN_MAGIC"),
        set("TIME_BOMB_WEAPON", "TIME_BOMB_RANGED", "TIME_BOMB_MAGIC"),
        set("REGENERATION_ARMOR", "REGENERATION_HELM"),
        set("DAMAGE_RETURN_ARMOR", "DAMAGE_RETURN_HELM"),
        set("SHIELDING_ARMOR", "SHIELDING_HELM"),
        set("FRENZY_DEFENSE_ARMOR", "FRENZY_DEFENSE_HELM"),
    },
}

-- One challenge: its description alias (the game's own text), its rules and the archive's
-- DamageFactor balance (+balance for the player, -balance for the opponent).
local function challenge(alias, rules, balance)
    if balance then
        rules[#rules + 1] = { kind = "attributes", target = "player", values = { DamageFactor = balance } }
        rules[#rules + 1] = { kind = "attributes", target = "opponent", values = { DamageFactor = -balance } }
    end
    return { kind = "group", description = words.get(alias), rules = rules }
end

local fists = sf2.items.get("core:items/weapon/Fists")
local hot_nodes = {
    { name = "NToeTip_1", axis = "Y", max = 15 }, { name = "NToeTip_2", axis = "Y", max = 15 },
    { name = "NKnee_1", axis = "Y", max = 30 }, { name = "NKnee_2", axis = "Y", max = 30 },
    { name = "NPivot", axis = "Y", max = 30 }, { name = "NNeck", axis = "Y", max = 30 },
    { name = "NTop", axis = "Y", max = 30 },
}

-- The archive's EquipItem rules carry no ApplyTo; the native default is the player.
local challenges = {
    kind = "random", refresh = "each_round", no_doubles = true,
    rules = {
        challenge("NO_WEAPON", { { kind = "equip_item", item = fists, target = "player" } }, 7000),
        challenge("KICKS_ONLY", {
            { kind = "no_button", name = "Punch", target = "player" },
            { kind = "equip_item", item = fists, target = "player" },
            { kind = "equip_item", item = sf2.items.get("core:items/ranged/NoRanged"), target = "player" },
            { kind = "equip_item", item = sf2.items.get("core:items/magic/NoMagic"), target = "player" },
        }, 2000),
        challenge("HOT_GROUND", {
            { kind = "hot_ground", frames = 420, target = "player", nodes = hot_nodes,
              animations = { "ThrowFall", "Jump", "PhysicalFall" } },
        }, 2000),
        challenge("RING_OUT", {
            { kind = "ring_out", node = "NPivot", axis = "X", min = -600, max = 600, target = "player" },
        }, 3000),
        challenge("NO_BLOCKS", { { kind = "remove_interval", type = "Block", target = "player" } }, 1000),
        challenge("ENEMY_REGENERATES", {
            { kind = "regeneration", rate = 0.001, frames_after_hit = 180, target = "opponent" },
        }, 1000),
        challenge("NO_JUMPS", { { kind = "no_animation", name = "Jump" } }),
        challenge("HEAD_HIT", {
            { kind = "attributes", target = "player", values = { DamageFactor = 12600 } },
            { kind = "attributes", target = "opponent", values = { BodyDefense = 10000 } },
        }),
    },
}

-- Each fight's immunity threshold (native ResistanceRule on Resistance_2): fight 1 is free,
-- then 250, 500, 750 and 1000. Below it the player hits softer and is hit harder.
local THRESHOLDS = { 0, 250, 500, 750, 1000 }
local resistance = {}
for step, value in ipairs(THRESHOLDS) do
    resistance[step] = { kind = "resistance", name = "Resistance_2", value = value }
end

local function rules(step)
    return { resistance[step], enchantments, challenges }
end

return { rules = rules }
