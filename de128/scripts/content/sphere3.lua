local sf2 = require("sf2")
-- Complete archived Sphere3 graph, authored with typed Lua definitions.
-- Game frames: the player and shop moves have 3 frames per sample from sample 1 (sample N
-- is frames 3N .. 3N + 2); the start move has 4 frames per sample from sample 1 (sample 2 is
-- frames 8-11); the middle move has 4 frames per sample from sample 9 (sample 10 is frames
-- 8-11, sample 22 is frames 56-59).
local animation = {
    player = sf2.assets.binary("animations/big_sphere_player"),
    start = sf2.assets.binary("animations/magic_fire_aura_bullet"),
    middle = sf2.assets.binary("animations/magic_fire_aura_bullet"),
}
local family = sf2.moves.register_template { id = "sphere3" }
local moves = {}

-- Equipment the fighter (player) or the spawned sphere actor must carry.
local function only_for(player, shop)
    return {
        screen = shop and "shop_magic" or nil,
        [player and "magic" or "weapon"] = "Sphere3",
        rig = player and "Skeleton" or "SkeletonMagic",
    }
end

local function register(id, definition)
    definition.id = id
    moves[id] = sf2.moves.register(definition)
    return moves[id]
end

register("sphere3_player", {
    animation = animation.player, inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 1, priority = 110,
    tactic_distance = { axis = "x", min = 400, max = 700, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    align = "right_heel",
    when = {
        keys = "magic",
        bullets = { type = "magic", min = 1 },
        not_mod = { "Concussion", "Stun" },
        controllable = true,
    }, only_for = only_for(true), windows = { uninterruptible = true },
    on = {
        [15] = { projectile = {
        name = "Sphere3", core_skeleton = "SkeletonMagic", copy_parent_type = "magic",
    } },
        [21] = { add_bullets = "magic", amount = -1 },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = "controlled", face = "enemy",
})
register("sphere3_start", {
    animation = animation.start, inherit = { "MagicMissileStart", "MagicMissile", "MissileStart", "MagicMissileFly", family },
    frames_per_sample = 4, first_sample = 1, last_sample = 5, priority = 600, no_magic_recharge = true,
    align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "pelvis", of = "enemy" } },
    events = { "birth" }, on = {
        [8] = { effect = {
        name = "Sphere3Start", core_sequence = "mgc_magic_big_sphere_" .. string.lower("Start"),
        scale = 0.75, time_scale = 4, position = { node = "Magic-Node2_1", of = "self", x = 0, y = -150 }, follow = false,
    } },
    },
    when = { parent = { not_animation = "StanceShop" }, actor = "Sphere3" }, only_for = only_for(false),
})
register("sphere3_middle", {
    animation = animation.middle, inherit = { "MagicMissile", "MagicMissileFly", family },
    frames_per_sample = 4, first_sample = 9, priority = 600, no_magic_recharge = true,
    align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "Magic-Node2_1", of = "self" } },
    events = { "animation_end" }, attacks = { {
        from = 56,
        -- Repeated edges are present in the archive and retain its ordering.
        edges = { "Magic-Edge4_1", "Magic-Edge1_1", "Magic-Edge2_1", "Magic-Edge1_1", "Magic-Edge2_1" },
        damage = { amount = 0.6, magic = 0, unarmed = -25 },
        impulse = { y = -1000 }, hit = "Physycal",
        no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } }, on = {
        [8] = { effect = {
        name = "Sphere3End", core_sequence = "mgc_magic_big_sphere_" .. string.lower("End"),
        scale = 2, time_scale = 2, position = { node = "Magic-Node2_1", of = "self", x = 0, y = -150 }, follow = false,
    } },
        finish = { delete_actor = "self" },
        [0] = { sound = { "snd_bigsphere_end" } },
    },
    when = { parent = { not_animation = "StanceShop" }, actor = "Sphere3" }, only_for = only_for(false),
})
for _, row in ipairs({ { "shop_magic_sphere3_player", "ShopPeacefulStart", "peaceful_start" },
    { "shop_magic_try_on_sphere3_player", "ShopTryOn", "try_on" } }) do
    register(row[1], {
        animation = animation.player, inherit = { row[2], "StanceShop", "StageStance", "Stance" },
        first_sample = 1, priority = 1, no_interpolation_frames = true, ends_stage = true,
        align = { axes = { "x", "z" }, pivot = { node = "right_heel" }, position = { pivot = "self", x = -80 } },
        only_for = only_for(true, true), on = {
        [66] = { effect = {
        name = "Sphere3Start", core_sequence = "mgc_magic_big_sphere_" .. string.lower("Start"),
        scale = 0.75, time_scale = 4, position = { wall = "back", of = "self", x = 415, y = 160 }, follow = false,
    } },
        [81] = { effect = {
        name = "Sphere3End", core_sequence = "mgc_magic_big_sphere_" .. string.lower("End"),
        scale = 2, time_scale = 1.5, position = { wall = "back", of = "self", x = 400, y = 150 }, follow = false,
    } },
        [63] = { sound = { "snd_bigsphere_end" } },
        finish = { try_on_end = true },
    }, events = { { round_stage_start = row[3] } }, face = "enemy",
    })
end
return moves
