-- Authored combat data of the archived ChineseSwordsSuperSlash.
-- Registered by content.chinese_swords; archive checks compare the native projection.
-- Window, attack and timeline positions are game frames. The slash starts at sample 4
-- with 3 frames per sample (sample N is frames (N - 3) * 3 .. (N - 3) * 3 + 2); the
-- shop preview starts at sample 2 (sample N is frames (N - 1) * 3 .. (N - 1) * 3 + 2).
local function attack(from, to, edges, hit, x, y)
    return {
        from = from, to = to,
        edges = edges, damage = { amount = 0.06, weapon = 0, unarmed = -10 },
        impulse = { x = x, y = y, z = 0 }, hit = hit,
    }
end

return {
    profile = { rank = 4, core_icon = "Trick7.super_slash" },
    tactic_distance = { axis = "x", min = 200, max = 800, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } },
    on = {
        [15] = { sound = { "snd_swish_sword1" } },
        [42] = { sound = { "snd_swish_sword1" } },
        [75] = { sound = { "snd_swish_sword3" } },
        [90] = { sound = { "snd_swish_sword2" } },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    item_lock_extensions = {
        "SaiStartStanceIdle", "SaiStartStance-Left", "SaiStartStance-Right", "Win_Sai",
        "SaiSpit", "SaiDoubleSpit", "SaiHeavySpit", "SaiSpinningSpit", "SaiUpperSpit", "SaiLowSpit",
    },
    only_for = { weapon = "ChineseSwords", rig = "Skeleton" },
    transitions = {{ sample_shift = 2, when = { animation = "SaiHeavySpit", window = "semi_uninterruptible" } }},
    align = "right_heel",
    face = "enemy",
    preview = {
        no_wall_repulsion = true, no_interpolation_frames = true,
        on = {
        [21] = { sound = { "snd_swish_sword1" } },
        [48] = { sound = { "snd_swish_sword1" } },
        [81] = { sound = { "snd_swish_sword3" } },
        [96] = { sound = { "snd_swish_sword2" } },
        finish = { try_on_end = true },
    },
        only_for = { screen = "shop_weapon", weapon = "ChineseSwords", rig = "Skeleton" },
        align = {
            axes = { "x", "z" },
            pivot = { node = "left_heel" },
            position = { pivot = "self", x = -57 },
        },
    },
    when = {
        keys = { "punch", "punch", { "forward", press = "hold" } },
        not_window = "uninterruptible", stage = "fight",
        not_all = { { animation = "$Move" }, { window = "semi_uninterruptible" } },
        not_animation = "Physical",
        not_mod = "MOD_TITAN",
        all = {
            { any = { { animation = "1key" }, { animation = "2key" }, { not_window = "semi_uninterruptible" } } },
            { any = { { animation = "Forward" }, { not_window = "semi_uninterruptible" } } },
        },
    },
    windows = {
        unstable = { from = 63, to = 80 },
        uninterruptible = { to = 143 },
        block = { from = 144 },
        throwable = { from = 144 },
    },
    attacks = {
        attack(24, 35, { "WEAPON_SAI-Edge30_2", "WEAPON_SAI-Edge31_2" }, "Middle", 175, -100),
        attack(48, 62, { "WEAPON_SAI-Edge30_2", "WEAPON_SAI-Edge31_1", "WEAPON_SAI-Edge31_2" }, "Spinning", 25, -100),
        attack(72, 83, { "WEAPON_SAI-Edge30_1", "WEAPON_SAI-Edge31_1", "WEAPON_SAI-Edge31_2" }, "HighHeavy", 25, -120),
        attack(87, 98, { "WEAPON_SAI-Edge30_2", "WEAPON_SAI-Edge31_1", "WEAPON_SAI-Edge31_2" }, "HighHeavy", 25, -150),
    },
    preview_screen = { screen = "shop_weapon" },
}
