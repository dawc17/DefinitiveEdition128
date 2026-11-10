-- The shop preview of the archived ChineseSwordsSuperSlash, registered by content.chinese_swords.
-- Timeline positions are game frames: the preview starts at sample 2 with 3 frames per sample
-- (sample N is frames (N - 1) * 3 .. (N - 1) * 3 + 2).
return {
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
}
