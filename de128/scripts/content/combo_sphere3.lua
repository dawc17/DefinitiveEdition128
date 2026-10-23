local sf2 = require("sf2")
-- Complete archived ComboSphere3 graph, authored with typed Lua definitions.
-- Game frames: the player and shop moves have 2 frames per sample from sample 1 (sample
-- 7 is frames 14-15, 15 is 30-31, 22 is 44-45, and the cast's sample 34 ends on frame 69);
-- the start move has 4 frames per sample from sample 9 (sample 10 is frames 8-11, sample
-- 12 is 16-19, sample 22 is 56-59).
local animation = {
    player = sf2.assets.binary("animations/big_sphere_player"),
    start = sf2.assets.binary("animations/magic_fire_aura_bullet"),
    middle = sf2.assets.binary("animations/magic_fire_aura_bullet"),
}
local family = sf2.moves.register { kind = "template", id = "combo_sphere3" }
local moves = {}

-- Equipment the fighter (player) or the spawned sphere actor must carry.
local function only_for(player, shop)
    return {
        screen = shop and "shop_magic" or nil,
        [player and "magic" or "weapon"] = "ComboSphere3",
        rig = player and "Skeleton" or "SkeletonMagic",
    }
end

local function register(id, definition)
    definition.id = id
    moves[id] = sf2.moves.register(definition)
    return moves[id]
end

register("combo_sphere3_player", {
    animation = animation.player, inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    type = "attack", frames_per_sample = 2, first_sample = 1, priority = 110,
    tactic_distance = { axis = "x", min = 400, max = 700, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    align = "right_heel",
    when = {
        keys = "magic",
        bullets = { type = "magic", min = 1 },
        not_mod = { "Concussion", "Stun" },
        controllable = true,
    }, only_for = only_for(true), windows = { uninterruptible = { to = 69 } },
    on = {
        [44] = { effect = {
        name = "ComboSphere3Start", core_sequence = "mgc_magic_big_sphere_" .. string.lower("Start"),
        scale = 0.75, time_scale = 4, position = { node = "pelvis", of = "self", x = 95, y = 15 }, follow = false,
    } },
        [30] = { { projectile = {
        name = "ComboSphere3", core_skeleton = "SkeletonMagic", copy_parent_type = "magic",
    } }, { sound = { "snd_bigsphere_end" } } },
        [14] = { add_bullets = "magic", amount = -1 },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = "controlled", face = "enemy",
})
register("combo_sphere3_start", {
    animation = animation.start, inherit = { "MagicMissileStart", "MagicMissile", "MissileStart", "MagicMissileFly", family },
    frames_per_sample = 4, first_sample = 9, priority = 600, no_magic_recharge = true,
    align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "pelvis", of = "enemy" } },
    face = "with_parent",
    events = { "birth" }, attacks = { {
        from = 16, to = 59,
        -- Preserve the archive's repeated edge names and order.
        edges = { "Magic-Edge4_1", "Magic-Edge1_1", "Magic-Edge2_1", "Magic-Edge1_1", "Magic-Edge2_1" },
        damage = { amount = 0.3, magic = 0, unarmed = -25 },
        impulse = { x = -1, y = -600 }, hit = "HighLong",
        no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } }, on = {
        [8] = { effect = {
        name = "ComboSphere3End", core_sequence = "mgc_magic_big_sphere_" .. string.lower("End"),
        scale = 1.5, time_scale = 2, position = { node = "Magic-Node2_1", of = "self", x = 0, y = -150 }, follow = false,
    } },
        strike = { delete_actor = "self" },
        finish = { delete_actor = "self" },
    },
    when = { parent = { not_animation = "StanceShop" }, actor = "ComboSphere3" }, only_for = only_for(false),
})
for _, row in ipairs({ { "shop_magic_combo_sphere3_player", "ShopPeacefulStart", "peaceful_start" },
    { "shop_magic_try_on_combo_sphere3_player", "ShopTryOn", "try_on" } }) do
    register(row[1], {
        animation = animation.player, inherit = { row[2], "StanceShop", "StageStance", "Stance" },
        frames_per_sample = 2, first_sample = 1, priority = 1, no_interpolation_frames = true, ends_stage = true,
        align = { axes = { "x", "z" }, pivot = { node = "right_heel" }, position = { pivot = "self", x = -80 } },
        only_for = only_for(true, true), on = {
        [44] = { { effect = {
        name = "ComboSphere3Start", core_sequence = "mgc_magic_big_sphere_" .. string.lower("Start"),
        scale = 0.75, time_scale = 4, position = { node = "pelvis", of = "self", x = 95, y = 15 }, follow = false,
    } }, { effect = {
        name = "ComboSphere3End", core_sequence = "mgc_magic_big_sphere_" .. string.lower("End"),
        scale = 2, time_scale = 1.5, position = { wall = "back", of = "self", x = 400, y = 150 }, follow = false,
    } } },
        [30] = { sound = { "snd_bigsphere_end" } },
        finish = { try_on_end = true },
    }, events = { { round_stage = row[3] } }, face = "enemy",
    })
end
return moves
