local sf2 = require("sf2")
-- Historical MindThrowNormal graph and innate perk; no runtime XML loading.
local function name(id) return "de128:moves/mind_throw_" .. id end
local flag = "de128:behaviors/mind_throw:pending"

-- Equipment the fighter (caster) or the spawned sphere actor must carry.
local function only_for(caster)
    return {
        [caster and "magic" or "weapon"] = "MindThrowNormal",
        rig = caster and "Skeleton" or "SkeletonMagic",
    }
end

local function damage(amount) return { amount = amount, magic = 0, unarmed = -25 } end
local moves = {}
local function register(id, value)
    value.id = "mind_throw_" .. id
    moves[id] = sf2.moves.register(value)
    return moves[id]
end
-- Game frames: every move here has 3 frames per sample; with first_sample F, sample N
-- (N > F) is frames (N - F + 1) * 3 .. (N - F + 1) * 3 + 2, and the first sample is frames 0-5.
local victim = register("hit", {
    inherit = { "Recoil", "Hit" }, animation = sf2.assets.binary("animations/mind_suffocation"),
    first_sample = 2, priority = 500,
    align = "pelvis",
    events = { { hit = name("hit") } },
    when = { not_mod = "MOD_TITAN", stage = "fight", not_animation = "Physical",
        not_window = "TitanUnhittable" },
    windows = { uninterruptible = { to = 251 }, throwable = { from = 18 } },
    only_for = { rig = "Skeleton" },
    face = "reverse_impulse",
})
register("player", {
    inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    animation = sf2.assets.binary("animations/mind_throw_1_normal"), type = "attack",
    first_sample = 1, priority = 110, tactic_weapon = "MindThrow",
    tactic_distance = { axis = "x", min = 400, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    align = "left_heel",
    when = { keys = "magic",
        bullets = { type = "magic", min = 1 },
        not_mod = { "Concussion", "Stun" },
        controllable = true },
    only_for = only_for(true), windows = { uninterruptible = true },
    on = {
        [0] = { projectile = { name = "MindThrowNormal", core_skeleton = "SkeletonMagic", copy_parent_type = "magic" } },
        [18] = { add_bullets = "magic", amount = -1 },
        [36] = { { sound = "snd_m_pl_attack6", voice = "male" }, { sound = "snd_low_pl_attack6", voice = "male_low" }, { sound = "snd_f_pl_attack6", voice = "female" } },
        [9] = { sound = { "snd_magic_bomb_start" } },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    }, events = "controlled",
    face = "enemy",
})
register("player2", {
    inherit = { "MagicMissile" }, animation = sf2.assets.binary("animations/mind_throw_2_normal"), type = "attack",
    first_sample = 1, priority = 110, tactic_weapon = "MindThrow",
    events = { { mod_expires = flag, of = "self" } },
    align = "left_heel",
    when = { enemy = { animation = name("hit") } },
    only_for = { magic = "MindThrowNormal" },
    windows = { uninterruptible = true },
    attacks = { { from = 144, to = 149, direct = true, damage = damage(0.15), hit = "NoReaction",
        no_critical = true, body_part = "body", defense = { "body" } } },
    on = {
        [0] = { effect = { name = "MindThrowStart",
        core_sequence = "mgc_magic_mind_throw_start", scale = 0.6,
        time_scale = 2, position = { node = "NFingertipsS_1", of = "self" }, follow = true } },
        [6] = { effect = { name = "MindThrowMiddle",
        core_sequence = "mgc_magic_mind_throw_middle", scale = 0.6,
        time_scale = 3.5, position = { node = "neck", of = "enemy", x = 5, y = 10 }, follow = true } },
        [141] = { { effect = { name = "MindThrowEnd",
        core_sequence = "mgc_magic_mind_throw_end", scale = 1.5,
        time_scale = 2, position = { node = "pelvis", of = "enemy", x = -52, y = 63 }, follow = false } }, { sound = { "snd_bucher_touchdown" } } },
        [144] = { shake = { pause_time = 0, effect_time = 30, amplitude_x = 7, frequency_x = 1, amplitude_y = 9, frequency_y = 0.3 } },
        [39] = { sound = { "snd_magic_lightningarrow_start" } },
        strike = { sound = "snd_magic_lightningarrow_end" },
    },
})
for _, phase in ipairs({ "start", "middle" }) do
    local startup = phase == "start"
    register(phase, {
        inherit = startup and { "MagicMissileStart", "MindThrow", "MissileStart", "MagicMissileFly" } or { "MindThrow", "MagicMissileFly" },
        animation = sf2.assets.binary("animations/mind_suffocation_" .. phase), first_sample = 1, priority = 500,
        no_magic_recharge = true, no_wall_repulsion = startup, no_interpolation_frames = startup,
        velocity = not startup and { x = 40 } or nil,
        align = startup and { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } }
            or { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "Magic-Node2_1", of = "self" } },
        face = startup and "with_parent" or nil,
        events = { startup and "birth" or "finish" },
        when = startup and { parent = { not_animation = "StanceShop" }, actor = "MindThrowNormal" }
            or { any = { { animation = name("start") }, { animation = name("middle") } }, actor = "MindThrowNormal" },
        only_for = only_for(false),
        attacks = { {
            from = startup and 30 or nil,
            edges = startup and { "Fireball-Edge1" } or { "Fireball-Edge1", "Magic-Edge2_1" },
            damage = damage(startup and 0.3 or 0.35), impulse = { x = 450 }, hit = victim,
            no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
            ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
        } },
        on = startup and {
        [0] = { effect = { name = "MindThrowStart",
        core_sequence = "mgc_magic_mind_throw_start", scale = 0.6,
        time_scale = 0.9, position = { node = "Magic-Node2_1", of = "self", x = -75, y = -25 }, follow = true } },
        finish = { stop_follow_effect = "MindThrowStart" },
        [39] = { sound = { "snd_magic_lightningarrow_start" } },
        strike = { { sound = "snd_magic_lightningarrow_end" }, { delete_actor = "self" } },
    } or {
        [0] = { effect = { name = "MindThrowStart",
        core_sequence = "mgc_magic_mind_throw_middle", scale = 0.6,
        time_scale = 1, position = { node = "Magic-Node2_1", of = "self", x = -75, y = -25 }, follow = true } },
        [30] = { sound = { "snd_magic_lightningarrow_middle" } },
        strike = { { delete_actor = "self" }, { sound = "snd_magic_lightningarrow_end" } },
    },
    })
end
register("wall", {
    inherit = { "MindThrow", "MagicMissileFly", "MagicMissile" },
    animation = sf2.assets.binary("animations/mind_suffocation_middle"), first_sample = 1, priority = 500, no_magic_recharge = true,
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "Magic-Node2_1", of = "self" } },
    events = { "every_frame" }, when = { animation = name("middle"),
        distance = { axis = "x", max = -250, from = { node = "Magic-Node2_1" }, to = { wall = "front" } },
        actor = "MindThrowNormal" }, only_for = only_for(false),
    on = {
        [0] = { { stop_effect = "MindThrowStart" }, { delete_actor = "self" } },
    },
})
return moves
