local sf2 = require("sf2")
-- Complete archived Sphere2 graph, authored with typed Lua definitions.
-- Game frames: every move has 3 frames per sample. With first_sample F, the first sample
-- is frames 0-5 and sample N > F is frames (N - F + 1) * 3 .. (N - F + 1) * 3 + 2.
local animation = {
    player = sf2.assets.binary("animations/fireball_player"),
    start = sf2.assets.binary("animations/fireball_start"),
    middle = sf2.assets.binary("animations/fireball_middle"),
}
local family = sf2.moves.register_template { id = "sphere2" }
local moves = {}
local function name(id) return "de128:moves/" .. id end

-- Equipment the fighter (player) or the spawned sphere actor must carry.
local function only_for(player, shop)
    return {
        screen = shop and "shop_magic" or nil,
        [player and "magic" or "weapon"] = "Sphere2",
        rig = player and "Skeleton" or "SkeletonMagic",
    }
end

-- from: first game frame of the attack window (nil: the whole move).
local function attack(from, shroud)
    local ignores = { "Evade", "Recovery", "Dash" }
    if shroud then table.insert(ignores, "ShroudInterval") end
    return {
        from = from,
        edges = { "Magic-Edge2_1", "lightningEdge2", "lightningEdge1" }, damage = { amount = 0.45, magic = 0, unarmed = -25 },
        impulse = { x = 600 }, hit = "High",
        no_effect = true, no_critical = true, body_part = "body",
        defense = { "body" }, ignores_block = true, ignores_invulnerable = ignores,
    }
end

local function register(id, definition)
    definition.id = id
    moves[id] = sf2.moves.register(definition)
    return moves[id]
end

register("sphere2_player", {
    animation = animation.player, inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 2, priority = 110, tactic_weapon = "Sphere2",
    tactic_distance = { axis = "x", min = 400, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    align = "right_heel",
    when = {
        keys = "magic",
        bullets = { type = "magic", min = 1 },
        not_mod = { "Concussion", "Stun" },
        controllable = true,
    },
    only_for = only_for(true), windows = { uninterruptible = { to = 92 } },
    on = {
        [0] = { projectile = {
        name = "Sphere2", core_skeleton = "SkeletonMagic", copy_parent_type = "magic",
    } },
        [18] = { add_bullets = "magic", amount = -1 },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = "controlled", face = "enemy",
})
local start_actions = {
        [6] = { effect = {
            name = "EnergyballStart", core_sequence = ("mgc_magic_mid_sphere_" .. string.lower("Start")),
            scale = 1, time_scale = 1.1, looped = false,
            position = { node = "Magic-Node2_1", of = "self", x = 25, y = 0 }, follow = true,
        } },
        finish = { effect = {
            name = "EnergyballMiddle", core_sequence = ("mgc_magic_mid_sphere_" .. string.lower("Middle")),
            scale = 1, time_scale = 1, looped = true,
            position = { node = "Magic-Node2_1", of = "self", x = 5, y = 0 }, follow = true,
        } },
        [0] = { sound = { "snd_midsphere_start" } },
        [33] = { sound = { "snd_midsphere_middle" } },
    }
start_actions.strike = {
    { sound = { "snd_midsphere_end" } }, { delete_actor = "self" },
    { effect = { name = "EnergyballEnd", core_sequence = "mgc_magic_mid_sphere1_end",
        scale = 1.5, time_scale = 1, looped = false,
        position = { node = "Magic-Node2_1", of = "self", x = 5, y = 0 }, follow = false } },
}

register("sphere2_start", {
    animation = animation.start,
    inherit = { "MagicMissileStart", "MagicMissile", "MissileStart", "MagicMissileFly", family },
    first_sample = 2, priority = 500, no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    face = "with_parent",
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } },
    events = { "birth" }, attacks = { attack(36, true) }, on = start_actions,
    when = { parent = { not_animation = "StanceShop" }, actor = "Sphere2" }, only_for = only_for(false),
})
register("sphere2_middle", {
    animation = animation.middle, inherit = { "MagicMissileFly", "MagicMissile", family },
    first_sample = 1, priority = 500, no_magic_recharge = true, velocity = { x = 30 },
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "Magic-Node2_1", of = "self" } },
    events = { "animation_end" }, when = { any = {
        { animation = name("sphere2_start") }, { animation = name("sphere2_middle") },
    }, actor = "Sphere2" }, attacks = { attack(nil, true) }, on = {
        strike = { { sound = { "snd_midsphere_end" } }, { delete_actor = "self" }, { effect = {
            name = "EnergyballEnd", core_sequence = ("mgc_magic_mid_sphere1_end"),
            scale = 1.5, time_scale = 1, looped = false,
            position = { node = "Magic-Node2_1", of = "self", x = 5, y = 0 }, follow = false,
        } } },
    }, only_for = only_for(false),
})
register("sphere2_wall", {
    animation = animation.middle, inherit = { "MagicMissileFly", "MagicMissile", family },
    first_sample = 1, priority = 500, no_magic_recharge = true,
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "Magic-Node2_1", of = "self" } },
    events = { "every_frame" }, when = { animation = name("sphere2_middle"),
        distance = { axis = "x", max = -250, from = { node = "Magic-Node2_1" }, to = { wall = "front" } }, actor = "Sphere2" },
    on = {
        [0] = { delete_actor = "self" },
    }, only_for = only_for(false),
})
register("shop_magic_sphere2", {
    animation = animation.start, inherit = { "MagicShop", "MagicMissileFly", "MagicMissile", family },
    first_sample = 2, priority = 1, no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    on = {
        [6] = { effect = {
            name = "EnergyballStart", core_sequence = ("mgc_magic_mid_sphere_" .. string.lower("Start")),
            scale = 1, time_scale = 1.1, looped = false,
            position = { node = "Magic-Node2_1", of = "self", x = 25, y = 0 }, follow = true,
        } },
        finish = { { effect = {
            name = "EnergyballMiddle", core_sequence = ("mgc_magic_mid_sphere_" .. string.lower("Middle")),
            scale = 1, time_scale = 1, looped = true,
            position = { node = "Magic-Node2_1", of = "self", x = 5, y = 10 }, follow = true,
        } }, { delete_actor = "self" } },
        [0] = { sound = { "snd_midsphere_start" } },
        [33] = { sound = { "snd_midsphere_middle" } },
    },
    events = { "birth" }, when = { parent = { animation = "ShopPeacefulStart" }, actor = "Sphere2" }, only_for = only_for(false),
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } },
})
for _, row in ipairs({ { "shop_magic_sphere2_player", "ShopPeacefulStart", "peaceful_start" },
    { "shop_magic_try_on_sphere2_player", "ShopTryOn", "try_on" } }) do
    register(row[1], {
        animation = animation.player, inherit = { row[2], "StanceShop", "StageStance", "Stance" },
        first_sample = 2, priority = 1, no_interpolation_frames = true, ends_stage = true,
        align = { axes = { "x", "z" }, pivot = { node = "right_heel" }, position = { pivot = "self", x = -80 } },
        only_for = only_for(true, true), on = {
        [0] = { projectile = {
        name = "Sphere2", core_skeleton = "SkeletonMagic", copy_parent_type = "magic", start = row[4],
    } },
    }, events = { { round_stage_start = row[3] } }, face = "enemy",
    })
end
register("shop_magic_try_on_sphere2_start", {
    animation = animation.start, inherit = { "MagicShopTryOn", "MagicMissileFly", "MagicMissile", family },
    first_sample = 2, priority = 1, no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    on = {
        [6] = { effect = {
            name = "EnergyballStart", core_sequence = ("mgc_magic_mid_sphere_" .. string.lower("Start")),
            scale = 1, time_scale = 1.1, looped = false,
            position = { node = "Magic-Node2_1", of = "self", x = 25, y = 0 }, follow = true,
        } },
        finish = { effect = {
            name = "EnergyballMiddle", core_sequence = ("mgc_magic_mid_sphere_" .. string.lower("Middle")),
            scale = 1, time_scale = 1, looped = true,
            position = { node = "Magic-Node2_1", of = "self", x = 5, y = 10 }, follow = true,
        } },
        [0] = { sound = { "snd_midsphere_start" } },
        [33] = { sound = { "snd_midsphere_middle" } },
    },
    events = { "birth" }, when = { parent = { animation = "ShopTryOn" }, actor = "Sphere2" }, only_for = only_for(false),
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } },
})
register("shop_magic_try_on_sphere2_end", {
    animation = animation.middle, inherit = { "MagicMissileEnd", "MagicMissileFly", "MagicMissile", family },
    first_sample = 1, priority = 500, no_magic_recharge = true, velocity = { x = 30 },
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "Magic-Node2_1", of = "self" } },
    events = { "animation_end" }, when = { animation = name("shop_magic_try_on_sphere2_start"), actor = "Sphere2" },
    on = {
        [6] = { { stop_effect = "EnergyballMiddle" }, { effect = {
            name = "EnergyballEnd", core_sequence = ("mgc_magic_mid_sphere1_end"),
            scale = 1.5, time_scale = 1, looped = false,
            position = { node = "Magic-Node2_1", of = "self", x = 5, y = 10 }, follow = false,
        } }, { sound = { "snd_midsphere_end" } } },
    }, only_for = only_for(false),
})
return moves
