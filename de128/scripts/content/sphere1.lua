local sf2 = require("sf2")
-- Complete archived Sphere1 graph: the player cast, the flying sphere (start,
-- middle and wall hit) and the shop preview and try-on moves.
-- Game frames: every move has 3 frames per sample. With first_sample F, the first sample
-- is frames 0-5 and sample N > F is frames (N - F + 1) * 3 .. (N - F + 1) * 3 + 2.
local family = sf2.moves.register { kind = "template", id = "sphere1" }
local moves = {}

local HITS = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" }
local SPHERE_NODE = { node = "Magic-Node2_1", of = "self" }

-- Equipment the fighter (player) or the spawned sphere actor must carry.
local function only_for(player, shop)
    return {
        screen = shop and "shop_magic" or nil,
        [player and "magic" or "weapon"] = "Sphere1",
        rig = player and "Skeleton" or "SkeletonMagic",
    }
end

-- SmallSphereStart / Middle / End effects on the sphere's node.
local function sphere_effect(stage, x, y, options)
    options = options or {}
    return { effect = {
        name = "SmallSphere" .. stage, core_sequence = "mgc_magic_small_sphere_" .. string.lower(stage),
        scale = options.scale or 0.75, time_scale = options.time_scale or 1, looped = options.looped,
        position = { node = "Magic-Node2_1", of = "self", x = x, y = y }, follow = options.follow ~= false,
    } }
end

local function spawn(start_move)
    return { projectile = { name = "Sphere1", core_skeleton = "SkeletonMagic", copy_parent_type = "magic", start = start_move } }
end

-- from: first game frame of the attack window (nil: the whole move).
local function attack(from, shroud)
    local ignores = { "Evade", "Recovery", "Dash" }
    if shroud then table.insert(ignores, "ShroudInterval") end
    return {
        from = from,
        edges = { "Fireball-Edge1" }, damage = { amount = 0.45, magic = 0, unarmed = -25 },
        impulse = { x = 500 }, hit = "High",
        no_effect = true, no_critical = true, body_part = "body",
        defense = { "body" }, ignores_block = true, ignores_invulnerable = ignores,
    }
end

-- The sphere bursts and removes itself when it strikes.
local STRIKE = {
    { sound = { "snd_smallsphere_end" } },
    { delete_actor = "self" },
    sphere_effect("End", 100, 80, { scale = 1.5, follow = false }),
}

local function register(id, definition)
    definition.id = id
    moves[id] = sf2.moves.register(definition)
    return moves[id]
end

register("sphere1_player", {
    animation = "animations/fireball_player",
    inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 2, priority = 110, tactic_weapon = "Sphere1",
    events = "controlled", face = "enemy",
    align = "right_heel",
    tactic_distance = { axis = "x", min = 400, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    when = {
        keys = "magic",
        bullets = { type = "magic", min = 1 },
        not_mod = "Concussion",
        controllable = true,
    },
    only_for = only_for(true),
    windows = { uninterruptible = { to = 92 } },
    on = {
        [0] = spawn(),
        [18] = { add_bullets = "magic", amount = -1 },
        strike = { sound = HITS },
    },
})

register("sphere1_start", {
    animation = "animations/fireball_start",
    inherit = { "MagicMissileStart", "MagicMissile", "MissileStart", "MagicMissileFly", family },
    first_sample = 2, priority = 500, no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    events = { "birth" },
    face = "with_parent",
    align = { axes = { "x", "y", "z" }, pivot = { animation = true }, position = { animation = "parent", y = 45 } },
    when = { parent = { not_animation = "StanceShop" }, actor = "Sphere1" },
    only_for = only_for(false),
    attacks = { attack(36, true) },
    on = {
        [0] = { { sound = { "snd_smallsphere_start" } }, sphere_effect("Start", 0, 80, { time_scale = 1.45 }),
            { sound = { "snd_magic_fireball_start" } } },
        finish = { { sound = { "snd_smallsphere_middle" } }, sphere_effect("Middle", -70, 55, { looped = true }) },
        strike = STRIKE,
    },
})

register("sphere1_middle", {
    animation = "animations/fireball_middle", inherit = { "MagicMissileFly", "MagicMissile", family },
    first_sample = 1, priority = 500, no_magic_recharge = true, velocity = { x = 30 },
    events = { "finish" },
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = SPHERE_NODE },
    when = {
        any = { { animation = "de128:moves/sphere1_start" }, { animation = "de128:moves/sphere1_middle" } },
        actor = "Sphere1",
    },
    only_for = only_for(false),
    attacks = { attack() },
    on = { strike = STRIKE },
})

register("sphere1_wall", {
    animation = "animations/fireball_middle", inherit = { "MagicMissileFly", "MagicMissile", family },
    first_sample = 1, priority = 500, no_magic_recharge = true,
    events = { "every_frame" },
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = SPHERE_NODE },
    when = {
        animation = "de128:moves/sphere1_middle",
        distance = { axis = "x", max = -250, from = { node = "Magic-Node2_1" }, to = { wall = "front" } },
        actor = "Sphere1",
    },
    only_for = only_for(false),
    on = { [0] = { delete_actor = "self" } },
})

-- Shop preview: the fighter casts a sphere that plays its effects and vanishes.
local preview = register("shop_magic_sphere1", {
    animation = "animations/fireball_start", inherit = { "MagicShop", "MagicMissileFly", "MagicMissile", family },
    first_sample = 2, priority = 1, no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    events = { "birth" },
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } },
    when = { parent = { animation = "ShopPeacefulStart" }, actor = "Sphere1" },
    only_for = only_for(false),
    on = {
        [6] = sphere_effect("Start", 15, 25, { time_scale = 1.45 }),
        [9] = { sound = { "snd_smallsphere_start" } },
        finish = { sphere_effect("Middle", -60, 40, { looped = true }), { sound = { "snd_smallsphere_middle" } },
            { delete_actor = "self" } },
    },
})

for _, shop in ipairs({
    { id = "shop_magic_sphere1_player", template = "ShopPeacefulStart", stage = "peaceful_start", start = preview },
    { id = "shop_magic_try_on_sphere1_player", template = "ShopTryOn", stage = "try_on" },
}) do
    register(shop.id, {
        animation = "animations/fireball_player", inherit = { shop.template, "StanceShop", "StageStance", "Stance" },
        first_sample = 2, priority = 1, no_interpolation_frames = true, ends_stage = true,
        events = { { round_stage = shop.stage } }, face = "enemy",
        align = { axes = { "x", "z" }, pivot = { node = "right_heel" }, position = { pivot = "self", x = -80 } },
        only_for = only_for(true, true),
        on = { [0] = spawn(shop.start) },
    })
end

register("shop_magic_try_on_sphere1_start", {
    animation = "animations/fireball_start", inherit = { "MagicShopTryOn", "MagicMissileFly", "MagicMissile", family },
    first_sample = 2, priority = 1, no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    events = { "birth" },
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } },
    when = { parent = { animation = "ShopTryOn" }, actor = "Sphere1" },
    only_for = only_for(false),
    on = {
        [0] = { sphere_effect("Start", 0, 25, { time_scale = 1.45 }), { sound = { "snd_smallsphere_start" } } },
        finish = { sphere_effect("Middle", -70, 0.5, { looped = true }), { sound = { "snd_smallsphere_middle" } } },
    },
})

register("shop_magic_try_on_sphere1_end", {
    animation = "animations/fireball_middle", inherit = { "MagicMissileEnd", "MagicMissileFly", "MagicMissile", family },
    first_sample = 1, priority = 500, no_magic_recharge = true, velocity = { x = 30 },
    events = { "finish" },
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = SPHERE_NODE },
    when = { animation = "de128:moves/shop_magic_try_on_sphere1_start", actor = "Sphere1" },
    only_for = only_for(false),
    on = {
        [6] = { { stop_effect = "SmallSphereMiddle" }, sphere_effect("End", 100, 0.5, { scale = 1.5, follow = false }),
            { sound = { "snd_smallsphere_end" } } },
    },
})

return moves
