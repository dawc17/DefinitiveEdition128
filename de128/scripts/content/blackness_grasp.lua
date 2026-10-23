local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- The archived Grasp casts a hidden BlackHand, then tells that same child to
-- enter its attacking phase eight frames later. Keep the full native graph.

local hand_item = sf2.items.get("core:items/magic/MAGIC_ACID_CLOUD")
-- Spawned Eclipse actors carry the two hidden items but not parent perk slots;
-- BlackHand's actor name and hidden item still keep both phases exclusive.
local hand_only_for = {
    rig = { item = "SkeletonMagic" },
    weapon = { item = "MAGIC_ACID_CLOUD" },
}

for _, name in ipairs({ "BlacknessGraspAbilityPlayer", "BlacknessGraspAbilityHandStart",
    "BlacknessGraspAbilityHandMove" }) do
    sf2.moves.patch { move = name, disable = true }
end

-- Frames: hand_attack starts at sample 3 with 5 frames per sample (sample 7 is frame 25,
-- sample 12 is frame 50); hand_start and the cast start at sample 2 with 3 frames per
-- sample (sample 3 is frame 6, 6 is 15, 9 is 24, 17 is 48, and the cast's sample 39 ends on frame 116).
local hand_attack = sf2.moves.register {
    id = "blackness_grasp_hand_attack",
    animation = sf2.assets.binary("animations/magic_empty"),
    inherit = { "BossAbility", "MagicMissileFly", "MagicMissile" },
    frames_per_sample = 5, first_sample = 3, last_sample = 14, priority = 500,
    no_interpolation_frames = true, no_magic_recharge = true,
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "self" } },
    when = {
        animation = "de128:moves/blackness_grasp_hand_start",
        actor = "BlackHand",
    },
    only_for = hand_only_for,
    velocity = { ax = -0.4 },
    attacks = { {
        from = 25, edges = { "lightningEdge1" }, damage = { amount = 0.4, magic = 0, unarmed = -25 },
        impulse = { x = -600 }, hit = "Physycal",
        no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } },
    on = {
        [50] = { delete_actor = "self" },
    },
}

local hand_start = sf2.moves.register {
    id = "blackness_grasp_hand_start",
    animation = sf2.assets.binary("animations/magic_empty"),
    inherit = { "BossAbility", "MagicMissileFly", "MagicMissile" },
    first_sample = 2, priority = 500, no_magic_recharge = true,
    align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" },
        position = { node = "pelvis", of = "enemy", x = 100 } },
    face = "with_parent",
    when = { actor = "BlackHand" },
    only_for = hand_only_for,
    on = {
        [6] = { effect = {
            name = "BlackHandEFX", core_sequence = "mgc_effect_black_hand",
            time_scale = 3, scale = 1.5,
            position = { node = "Magic-Node2_1", of = "self", x = 0, y = -10 }, follow = true,
        } },
        [15] = { sound = { "snd_shadow_grasp" } },
    },
}

local cast = sf2.moves.register {
    id = "blackness_grasp_player",
    animation = sf2.assets.binary("animations/darkness_hug_player"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 2, priority = 200,
    no_wall_repulsion = true,
    only_for = { any = abilities.lock("grasp_of_darkness"), rig = "Skeleton" },
    face = "enemy",
    align = "right_heel",
    events = { "key_pressed" },
    when = {
        keys = "raid_charge",
        not_mod = { "GraspOfDarknessCD", abilities.ready("grasp_of_darkness") },
        controllable = true,
    },
    tactic_when = { distance = { axis = "x", min = 450, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
    windows = { uninterruptible = { to = 116 } },
    on = {
        [24] = { projectile = {
            name = "BlackHand", core_skeleton = "SkeletonMagic", item = hand_item,
            start = hand_start,
        } },
        [48] = { play = hand_attack, target = "child", child = "BlackHand" },
    },
}

local function register_tactic(id, cooldown)
    return sf2.ai.register {
        id = id, template = "Aggressive",
        on_decide = function(memory, event)
            -- The archived perk sets GraspOfDarknessCD for the warrior's _Frames
            -- at fight start and again on each cast (800 normal, 700 Power Mode).
            local ready = event.frame >= cooldown and event.frame >= (memory.next_grasp_frame or 0)
            local retreat, attacks = nil, {}
            for _, action in ipairs(event.actions) do
                if ready and action.name == "de128:moves/blackness_grasp_player" then
                    memory.next_grasp_frame = event.frame + cooldown
                    return action
                end
                if action.name == "StepBack" then retreat = action end
                if action.type == "attack" and action.name ~= "de128:moves/blackness_grasp_player" then
                    attacks[#attacks + 1] = action
                end
            end
            -- Grasp's native AI gate requires 450 X units. Back away while it is
            -- ready instead of letting Aggressive close that window, unless the
            -- back wall leaves no room to open it.
            local back_wall = event.back_wall_distance
            if ready and retreat and (not back_wall or back_wall > 120) then return retreat end
            if #attacks > 0 then
                memory.other_attack = (memory.other_attack or 0) % #attacks + 1
                return attacks[memory.other_attack]
            end
            if ready then return nil end
            return retreat or "wait"
        end,
    }
end

return { cast = cast, hand_start = hand_start, hand_attack = hand_attack,
    tactic = abilities.pace(sf2.ai.name(register_tactic("blackness_grasp", 800)),
        "grasp_of_darkness", 800, 800, { "de128:moves/blackness_grasp_player" }),
    power_tactic = abilities.pace(sf2.ai.name(register_tactic("blackness_grasp_power", 700)),
        "grasp_of_darkness", 700, 700, { "de128:moves/blackness_grasp_player" }) }
