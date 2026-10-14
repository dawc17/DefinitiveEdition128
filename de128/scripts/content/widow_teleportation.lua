local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- Reviewed owner moves.xml: WidowTeleportationStart/End. Keep their native
-- identities so the perk trigger and the start-to-end transition still work.
-- This is typed content; DE128 never loads XML while the game runs.

local excluded_enemy_moves = {
    "WallRunUp", "WallJump_50", "WallJump_100", "WallJump_200", "WallJump_250",
    "WallHit", "WallHitFall", "WaspFly_150", "WaspFly_200", "WaspFly_300", "WaspFly_370",
    "HunterFly_150", "HunterFly_200", "HunterFly_300", "HunterFly_370",
    -- wasp_fly.lua disables the native WaspFly selectors and plays these instead.
    "de128:moves/wasp_fly_150", "de128:moves/wasp_fly_200",
    "de128:moves/wasp_fly_300", "de128:moves/wasp_fly_370",
}
local hits = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" }

-- Both moves start at sample 1 with 3 frames per sample, so sample N (N > 1) is game
-- frames 3N .. 3N + 2.
local start = sf2.moves.replace {
    id = "widow_teleportation_start", target = "WidowTeleportationStart",
    expected_file = "widow_teleportation_start.bytes",
    animation = sf2.assets.binary("animations/widow_teleportation_start"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    no_wall_repulsion = true, first_sample = 1, priority = 110,
    -- No rig requirement here (the ability lock only), so the left-heel default does not apply.
    mirror = "left_heel",
    align = "left_heel",
    when = {
        keys = "raid_charge",
        not_mod = { "TeleportationRecharge", abilities.ready("teleportation") },
        enemy = {
            not_animation = excluded_enemy_moves,
            direction = { from = { node = "pelvis", of = "enemy" }, to = { node = "pelvis", of = "self" } },
        },
        controllable = true,
    },
    only_for = { any = abilities.lock("teleportation") },
    windows = {
        uninterruptible = { to = 41 },
        block = { from = 42 },
        throwable = { from = 42 },
    },
    on = {
        [39] = { effect = {
        name = "WidowTeleportationStart", core_sequence = "mgc_widow_teleportation_start", scale = 1.3, time_scale = 1.5,
        position = { node = "pelvis", of = "self", x = 54, y = 73 }, follow = false,
    } },
        [12] = { sound = { "snd_widow_teleport_start" } },
        hit = { stop_sound = "snd_widow_teleport_start" },
        strike = { sound = hits },
    },
    events = "controlled",
    face = "enemy",
}

local finish = sf2.moves.replace {
    id = "widow_teleportation_end", target = "WidowTeleportationEnd",
    expected_file = "widow_teleportation_end.bytes",
    animation = sf2.assets.binary("animations/widow_teleportation_end"),
    inherit = { "ChangeDirection" },
    no_wall_repulsion = true, first_sample = 1, priority = 450,
    mirror = "left_heel",
    face = "opposite_enemy",
    align = { axes = { "x", "z" }, shift_model_node = "pelvis",
        pivot = { node = "left_heel" }, position = { pivot = "enemy", x = 100 } },
    events = { "animation_end" },
    when = { animation = "WidowTeleportationStart", enemy = { not_animation = excluded_enemy_moves } },
    only_for = { any = abilities.lock("teleportation") },
    windows = {
        uninterruptible = { to = 59 },
        block = { from = 60 },
        throwable = { from = 60 },
    },
    attacks = { {
        from = 9, to = 14,
        edges = { "EForearm_1", "EHand_1", "EFingers_1", "EArm_1", "EArm_2",
            "EForearm_2", "EHand_2", "EFingers_2", "EChest" },
        damage = { amount = 0.28, weapon = 0, unarmed = -10 },
        impulse = { x = -245, y = -245 }, hit = "High",
        ignores_block = true,
    } },
    on = {
        [0] = { effect = {
        name = "WidowTeleportEnd", core_sequence = "mgc_widow_teleportation_end", scale = 1.5, time_scale = 1.5,
        position = { node = "pelvis", of = "self", x = 65, y = 95 }, follow = false,
    } },
        [18] = { { sound = { "snd_swish2" } }, { sound = { "snd_widow_teleport_end" } } },
        strike = { sound = hits },
        hit = { stop_sound = "snd_widow_teleport_end" },
    },
}

local function tactic(id, initial, cooldown)
    return abilities.pace(sf2.tactics.name(sf2.tactics.register {
        id = id, template = "Aggressive",
        on_decide = function(memory, event)
            local ready = event.frame >= initial and event.frame >= (memory.next_teleport_frame or 0)
            local retreat, attacks = nil, {}
            for _, action in ipairs(event.actions) do
                if ready and action.name == "WidowTeleportationStart" then
                    memory.next_teleport_frame = event.frame + cooldown
                    return action
                end
                if action.name == "StepBack" then retreat = action end
                if action.type == "attack" and action.name ~= "WidowTeleportationStart" then
                    attacks[#attacks + 1] = action
                end
            end
            if #attacks > 0 then
                memory.other_attack = (memory.other_attack or 0) % #attacks + 1
                return attacks[memory.other_attack]
            end
            return retreat or "wait"
        end,
    }), "teleportation", initial, cooldown, { "WidowTeleportationStart" })
end

return {
    start = start, finish = finish,
    normal = tactic("widow_teleportation", 600, 600),
    fast = tactic("widow_teleportation_fast", 300, 300),
    power = tactic("widow_teleportation_power", 480, 480),
    slow = tactic("widow_teleportation_slow", 660, 660),
}
