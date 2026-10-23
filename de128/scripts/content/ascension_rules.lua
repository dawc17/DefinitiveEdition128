-- Ascension prototype disabled by the owner on 2026-09-18.
--[==[
local sf2 = require("sf2")

-- Rules are plain tables, written inline in a fight's `rules`.
local function damage(_, target, amount)
    return { kind = "attributes", target = target, values = { DamageFactor = amount } }
end

local base = {
    damage("baseline", "player", -5000),
    { kind = "no_button", name = "RaidCharge", target = "player" },
}

-- These are the six challenge families in the archived Ascension battle.
-- Native rules own their timer, collision, animation and healing behavior.
local challenges = {
    {
        name = "No weapons", text = "Fight unarmed. Neither fighter may use a weapon.",
        rules = {
            { kind = "equip_item", item = sf2.items.get("core:items/weapon/Fists") },
            damage("unarmed_player", "player", 7000),
            damage("unarmed_opponent", "opponent", -7000),
        },
    },
    {
        name = "Hot ground", text = "Jump regularly. The ground becomes lethal after seven seconds.",
        rules = {
            {
                kind = "hot_ground", frames = 420, target = "player",
                nodes = {
                    { name = "NToeTip_1", axis = "Y", max = 15 },
                    { name = "NToeTip_2", axis = "Y", max = 15 },
                    { name = "NKnee_1", axis = "Y", max = 30 },
                    { name = "NKnee_2", axis = "Y", max = 30 },
                    { name = "NPivot", axis = "Y", max = 30 },
                    { name = "NNeck", axis = "Y", max = 30 },
                    { name = "NTop", axis = "Y", max = 30 },
                },
                animations = { "ThrowFall", "Jump", "PhysicalFall" },
            },
            damage("hot_ground_player", "player", 2000),
            damage("hot_ground_opponent", "opponent", -2000),
        },
    },
    {
        name = "Ring out", text = "Stay inside the arena boundaries. Crossing either edge loses the round.",
        rules = {
            {
                kind = "ring_out", node = "NPivot", axis = "X", min = -600, max = 600,
                target = "player",
            },
            damage("ring_out_player", "player", 3000),
            damage("ring_out_opponent", "opponent", -3000),
        },
    },
    {
        name = "No blocks", text = "You cannot block attacks. Use movement to avoid damage.",
        rules = {
            { kind = "remove_interval", type = "Block", target = "player" },
            damage("no_blocks_player", "player", 1000),
            damage("no_blocks_opponent", "opponent", -1000),
        },
    },
    {
        name = "Enemy regenerates", text = "Keep attacking. The opponent regenerates after three seconds without a hit.",
        rules = {
            {
                kind = "regeneration", rate = 0.001, frames_after_hit = 180, target = "opponent",
            },
            damage("regeneration_player", "player", 1000),
            damage("regeneration_opponent", "opponent", -1000),
        },
    },
    {
        name = "No jumps", text = "Neither fighter may jump.",
        rules = { { kind = "no_animation", name = "Jump" } },
    },
}

local perk_names = {
    "PRECISION_WEAPON", "OVERHEAT_WEAPON", "INTOXICATION_WEAPON", "WEAKNESS_WEAPON",
    "BLOODRAGE_WEAPON", "REJUVENATION_ARMOR", "DAMAGE_ABSORPTION_BODY_ARMOR", "LIFESTEAL_WEAPON",
    "BLEEDING_WEAPON", "ENFEEBLE_WEAPON", "FRENZY_WEAPON", "STUN_WEAPON",
    "TIME_BOMB_WEAPON", "REGENERATION_ARMOR", "DAMAGE_RETURN_ARMOR", "SHIELDING_ARMOR",
}
local buffs = {}
for i, name in ipairs(perk_names) do
    buffs[i] = {
        kind = "perk",
        perk = sf2.perks.get("core:perks/PERK_ITEM_SPECIAL_" .. name),
        aspect = 100000, target = "opponent",
    }
end

return { base = base, challenges = challenges, buffs = buffs }
]==]
return {}
