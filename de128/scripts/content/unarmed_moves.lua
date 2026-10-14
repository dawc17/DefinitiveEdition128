local sf2 = require("sf2")
-- Definitive Edition's additions to the default (unarmed) moveset, restored
-- from the archived moves.xml (Assets/DExml, identical in the DE128 drop):
--   FrontJumpScissorsKick  Up-Forward + Kick, Kick
--   AxeKickOld             Forward + Kick, Kick
--   WallRunUp              Back + Kick, Kick near the back wall (or after BackKick)
--   AirPunch               Down-Forward + Punch
--   ThrowLegPush           Back + Kick (or Forward + Punch facing a wall) in throw range
-- plus the throw's victim, stand-up and profile-preview moves. All animations
-- ship with the core game. No vanilla move is replaced or rebound.
--
-- The double-kick inputs start FrontKick or BackKick on the first Kick; the
-- second Kick cancels that starter during its early cancel window (patched
-- at the end of this file).
-- tactic_equivalent lets the AI use each move wherever its tables use the
-- named native move of similar timing and range; the tables have no rows of
-- their own for these moves (nor did the Definitive Edition's).
local function name(id) return "de128:moves/" .. id end
-- Profile titles copied from the archive by Tools/GenerateDE128MoveNames.py.
local function title(archived) return sf2.localization.key("moves." .. archived) end

local moves = {}
local function register(id, value)
    value.id = id
    moves[id] = sf2.moves.register(value)
    return moves[id]
end

local hit_sounds = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" }
local function voices(sound)
    return { { sound = "snd_m_pl_" .. sound, voice = "male" }, { sound = "snd_low_pl_" .. sound, voice = "male_low" },
        { sound = "snd_f_pl_" .. sound, voice = "female" } }
end
local leg_2 = { "EThigh_2", "ECalf_2", "EInstep_2", "EToe_2", "EFoot_2" }
local leg_1 = { "EThigh_1", "ECalf_1", "EInstep_1", "EToe_1", "EFoot_1" }
local unarmed_only_for = { rig = "Skeleton", any = { { not_armor = { item = "BODY_GATEKEEPER" } } } }
local near_enemy = { axis = "x", min = 50, max = 350, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } }

-- The shared tail of every controlled attack: not mid-move, fight stage, not Titan.
-- Several "any" groups cannot share one condition map, so each group is its own map.
local function controlled(direction, two_key)
    local state = two_key and { { animation = "1key" }, { animation = "2key" }, { not_window = "semi_uninterruptible" } }
        or { { animation = "1key" }, { not_window = "semi_uninterruptible" } }
    return {
        { any = state },
        { any = { { animation = direction }, { not_window = "semi_uninterruptible" } } },
        { not_window = "uninterruptible", stage = "fight",
            not_all = { { animation = "$Move" }, { window = "semi_uninterruptible" } },
            not_animation = "Physical", not_mod = "MOD_TITAN" },
    }
end

-- Game frames below are the old sample bounds at 3 frames per sample: with
-- first_sample = F, sample N covers frames (N-F+1)*3 .. (N-F+2)*3-1 (sample F: 0 .. 5).
register("front_jump_scissors_kick", {
    inherit = { "3key", "UpForward", "Unarmed", "Kick", "Jump", "Controlled", "NotTitan", "SoundStrike" },
    animation = sf2.assets.binary("animations/front_jump_scissors_kick"), type = "attack",
    first_sample = 1, priority = 130, style_factor = 1.1,
    tactic_equivalent = "FrontJumpKick",
    profile = { rank = 209, core_icon = "Trick2.double_jump_kick", display_name = title("FrontJumpScissorsKick") },
    tactic_distance = near_enemy, align = "left_heel",
    transitions = { { sample_shift = 1, when = { animation = "FrontJumpKick", window = "semi_uninterruptible" } } },
    when = { keys = { "kick", "kick", { "up_forward", press = "hold" } }, all = controlled("UpForward", true) },
    only_for = unarmed_only_for,
    windows = { unstable = { from = 24, to = 65 }, uninterruptible = { to = 80 }, block = { from = 81 }, throwable = { from = 81 } },
    attacks = {
        { from = 27, to = 35, edges = leg_2, damage = 0.08, impulse = { x = 525, y = -175 }, hit = "HighShort" },
        { from = 42, to = 47, edges = leg_1, damage = 0.07, impulse = { x = 525, y = -175 }, hit = "HighPlus" },
    },
    on = { [27] = { sound = { "snd_swish3" } }, [42] = { sound = { "snd_swish3" } }, strike = { sound = hit_sounds } },
    events = "controlled", face = "enemy",
})

register("axe_kick_old", {
    inherit = { "3key", "Forward", "Unarmed", "Kick", "Controlled", "NotTitan", "SoundStrike" },
    animation = sf2.assets.binary("animations/axe_kick_old"), type = "attack",
    first_sample = 1, priority = 135, style_factor = 1.1,
    tactic_equivalent = "FrontKick",
    profile = { rank = 211, core_icon = "Trick3.axe_kick", display_name = title("AxeKickOld") },
    tactic_distance = near_enemy, align = "left_heel",
    -- Not in the archive: continue FrontKick's frame (native frame + 1 + shift) so
    -- the double tap reads as one axe kick, as DoublePunch does from HeavyPunch.
    transitions = { { sample_shift = -1, when = { animation = "FrontKick", window = "semi_uninterruptible" } } },
    when = { keys = { "kick", "kick", { "forward", press = "hold" } }, all = controlled("Forward", true) },
    only_for = unarmed_only_for,
    windows = { unstable = { from = 15, to = 35 }, semi_uninterruptible = { to = 17 }, uninterruptible = { to = 53 },
        block = { from = 54 }, throwable = { from = 54 } },
    attacks = {
        { from = 21, to = 32, id = 431, edges = leg_2, damage = 0.09, impulse = { x = 245, y = 245 }, hit = "Overhead" },
    },
    on = { [18] = voices("attack1"), [24] = { sound = { "snd_swish3" } }, strike = { sound = hit_sounds } },
    events = "controlled", face = "enemy",
})

register("wall_run_up", {
    inherit = { "2key", "Back", "Wall", "Jump", "Unarmed", "Kick", "Controlled", "NotTitan", "SoundStrike" },
    animation = sf2.assets.binary("animations/wall_run_up"), type = "attack",
    first_sample = 3, priority = 150,
    tactic_equivalent = "DoubleJumpKick",
    profile = { rank = 511, core_icon = "Trick5.high_punch", keys_description = "Wall_Keys", display_name = title("WallRunUp") },
    align = { axes = { "x" }, pivot = { animation = true }, position = { wall = "back", of = "self" } },
    transitions = { { sample_shift = 1, when = { animation = "BackKick", window = "semi_uninterruptible" } } },
    when = {
        any = { { keys = { { "back", press = "hold" }, "kick", "kick" } },
            { animation = "BackKick", window = "semi_uninterruptible" } },
        distance = { axis = "x", min = 150, max = 350, from = { wall = "back", of = "self" }, to = { node = "left_heel", of = "self" } },
        all = controlled("Back", true),
    },
    -- The uninterruptible window starts at sample 2, before the move's first sample (3):
    -- only a sample bound can say that.
    windows = { unstable = { from = 0, to = 101 }, uninterruptible = { from_sample = 2, to = 113 }, block = { from = 114 } },
    attacks = {
        { from = 78, to = 98, edges = { leg_1[1], leg_1[2], leg_1[3], leg_1[4], leg_1[5],
            leg_2[1], leg_2[2], leg_2[3], leg_2[4], leg_2[5] }, damage = 0.30, impulse = { x = 175, y = 245 }, hit = "Overhead" },
    },
    on = { [6] = voices("jump1"), [9] = { sound = { "snd_swish7" } }, [18] = { sound = { "snd_swish5" } },
        [33] = { sound = { "snd_swish7" } }, strike = { sound = hit_sounds } },
    events = "controlled", only_for = unarmed_only_for, face = "enemy",
})

register("air_punch", {
    inherit = { "2key", "DownForward", "Unarmed", "Jump", "Punch", "Controlled", "Arms", "NotTitan", "SoundStrike" },
    animation = sf2.assets.binary("animations/air_punch"), type = "attack",
    first_sample = 3, priority = 125, tactic_weapon = "Fists",
    tactic_equivalent = "TwoFootJumpKick",
    profile = { rank = 507, core_icon = "Trick5.high_punch", display_name = title("AirPunch") },
    tactic_distance = { axis = "x", min = 300, max = 600, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    align = "right_heel",
    when = { keys = { "punch", { "down_forward", press = "hold" } }, all = controlled("DownForward", false) },
    only_for = { rig = "Skeleton" },
    windows = { unstable = { from = 21, to = 62 }, uninterruptible = { to = 77 }, block = { from = 78 }, throwable = { from = 78 } },
    attacks = {
        { from = 33, to = 47, edges = { "EForearm_2", "EHand_2", "EFingers_2" }, damage = 0.16,
            impulse = { x = 525 }, hit = "HighHeavy" },
    },
    on = { [18] = voices("attack5"), [33] = { sound = { "snd_swish3" } }, strike = { sound = hit_sounds } },
    events = "controlled", face = "enemy",
})

-- Leg push throw: the victim move is registered first so the throw can name it.
register("throw_leg_push_v", {
    inherit = { "NotTitan" }, animation = sf2.assets.binary("animations/throw_leg_push_v"),
    first_sample = 7, priority = 9999, no_wall_repulsion = true,
    face = "with_enemy",
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "enemy" } },
    events = { { animation_start = name("throw_leg_push"), of = "enemy" } },
    on = { [9] = { sound = { "snd_bodyfall1" } } },
    when = { not_actor = "Assistant", any = { { not_animation = "Throw" }, { player_number = 2 } },
        not_mod = "MOD_TITAN", not_animation = name("throw_leg_push_v") },
    only_for = unarmed_only_for, windows = { uninterruptible = true },
})

register("throw_leg_push", {
    inherit = { "2key", "Throw", "Back", "Unarmed", "ChangeDirection", "Controlled", "NotTitan", "SoundStrike" },
    animation = sf2.assets.binary("animations/throw_leg_push_a"), type = "attack",
    first_sample = 3, priority = 220, no_wall_repulsion = true, align = "left_heel",
    when = {
        enemy = {
            direction = { from = { node = "pelvis", of = "enemy" }, to = { node = "pelvis", of = "self" } },
            window = "throwable",
            not_mod = { "CurseBomb", "ThrowFallBlock", "MOD_TITAN" },
        },
        distance = { axis = "x", max = 100, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
        not_mod = { "NoThrows", "ThrowBlock", "MOD_TITAN", "Stun" },
        not_window = "uninterruptible", stage = "fight",
        not_all = { { animation = "$Move" }, { window = "semi_uninterruptible" } },
        not_animation = "Physical",
        not_any = { { enemy = { actor = "Assistant" } }, { enemy_child = { actor = "Assistant" } } },
        all = {
            { any = {
                { keys = { "kick", { "back", press = "hold" } },
                    not_distance = { axis = "x", max = 200, from = { wall = "back", of = "self" }, to = { node = "right_heel", of = "self" } } },
                { keys = { "punch", { "forward", press = "hold" } },
                    distance = { axis = "x", max = 300, from = { node = "left_heel", of = "self" }, to = { wall = "front", of = "self" } } },
            } },
            { any = { { animation = "1key" }, { not_window = "semi_uninterruptible" } } },
            { any = { { animation = "Back" }, { not_window = "semi_uninterruptible" } } },
            { any = { { enemy = { not_animation = "Throw" } }, { enemy = { player_number = 2 } } } },
        },
    },
    windows = { uninterruptible = { to = 140 }, block = { from = 141 } },
    attacks = { { from = 66, to = 68, id = 428, direct = true, damage = 0.35, hit = "NoReaction", defense = { "body" } } },
    on = { [30] = voices("jump2"), [54] = { sound = { "snd_swish5" } }, strike = { sound = hit_sounds } },
    only_for = { screen = "fight", rig = "Skeleton" }, events = "controlled", face = "enemy",
})

-- The thrown fighter gets up with this move after the leg push lands.
register("standup_after_leg_fall", {
    inherit = { "GetUp", "AfterThrowFall" }, animation = sf2.assets.binary("animations/throw_leg_push_v_standup"),
    first_sample = 30, priority = 405,
    -- No rig lock, so the left-heel default does not apply: name it.
    mirror = "left_heel",
    face = { from = { node = "neck", of = "self" }, to = { node = "pelvis", of = "self" } },
    align = "pelvis",
    when = { not_round_result = "defeat" },
    windows = { uninterruptible = { to = 35 }, block = { from = 36 }, invulnerable = { name = "Recovery", to = 35 } },
    -- The archive matches the victim through its "LegFall" template tag; naming the move is equivalent.
    events = { { animation_end = name("throw_leg_push_v") } },
})

-- Profile screen preview: the throw performed on a spawned practice fighter.
register("throw_leg_push_v_profile", {
    animation = sf2.assets.binary("animations/throw_leg_push_v"),
    first_sample = 3, priority = 555, no_wall_repulsion = true, no_interpolation_frames = true,
    face = "opposite_parent",
    align = { axes = { "x", "z" }, shift_model_node = "pelvis", pivot = { animation = true }, position = { animation = "parent" } },
    events = { "birth" }, when = { parent = { animation = name("throw_leg_push_profile") } },
    on = { [72] = { sound = { "snd_bodyfall1" } }, [132] = { delete_actor = "self" } },
})

register("throw_leg_push_profile", {
    inherit = { "ThrowProfile" }, animation = sf2.assets.binary("animations/throw_leg_push_a"),
    first_sample = 3, priority = 225, no_wall_repulsion = true, no_interpolation_frames = true,
    profile = { rank = 404, core_icon = "Trick9.throw_suplex", keys_description = "Throw_Keys", display_name = title("ThrowLegPushProfile") },
    align = "left_heel",
    when = { keys = { "kick", { "back", press = "hold" } } },
    attacks = { { id = 428, direct = true, damage = 0.35 } },
    on = { [0] = { create_player = { rig = "Skeleton", armor = "Body", weapon = "Fists", helm = "HEAD_KENJI" } },
        [30] = voices("jump2"), [45] = { sound = { "snd_swish5" } } },
    only_for = { screen = "profile" },
})

-- Starter cancel windows. The second Kick only reaches Axe Kick or Wall Run
-- while the starter is outside Uninterrupt and inside SemiUninterrupt.
-- Vanilla FrontKick is Uninterrupt from frame 0 (the Definitive Edition gave
-- it 0-4); the owner chose a tighter 0-2 SemiUninterrupt after playtesting
-- 0-7 and 0-4. BackKick's 0-4 window is widened to 0-6 for a quick tap.
-- Those numbers are animation samples, and FrontKick (first sample 2) and BackKick
-- (first sample 1) have windows that start at sample 0, before their first sample,
-- so the bounds are written in samples.
sf2.moves.patch {
    move = "FrontKick",
    windows = {
        change = { uninterruptible = { expected = { from_sample = 0, to_sample = 17 }, value = { from_sample = 3 } } },
        add = { semi_uninterruptible = { from_sample = 0, to_sample = 2 } },
    },
}
sf2.moves.patch {
    move = "BackKick",
    windows = {
        change = {
            semi_uninterruptible = { expected = { from_sample = 0, to_sample = 4 }, value = { to_sample = 6 } },
            uninterruptible = { expected = { from_sample = 5, to_sample = 18 }, value = { from_sample = 7 } },
        },
    },
}

return moves
