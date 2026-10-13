local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- DE's ShadowCloakPlayer: the RaidCharge cast of PERK_SHADOW_CLOAK (Special Recipe I).
-- It reuses Lynx's smoke bomb (core InvisibilityCloakPlayer, a Super-button move), with
-- the archive's own conditions and lock. The animation bytes are unchanged core data.
-- The cloak itself (tint, unblockable hits, recharge) is the perk's behavior in
-- content.boss_abilities, which starts it on frame 13 of this move.

local function smoke(name, sequence, scale, x, y)
    return { effect = {
        name = name, core_sequence = sequence, scale = scale, time_scale = 2, looped = false,
        position = { node = "NPivot", player = "Me", x = x, y = y }, follow = false,
    } }
end

local function distance(min)
    return { distance = "X", min = min, from = { pivot = "Me" }, to = { node = "NPivot", player = "Enemy" } }
end

local move = sf2.moves.register {
    id = "shadow_cloak_player",
    animation = sf2.assets.binary("animations/smoke_bomb"),
    core_templates = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    type = "ATTACK", mid_frames = 2, first_frame = 1, priority = 110,
    mirror_node = "NHeel_1",
    tactic_conditions = {
        { any = {
            distance(400),
            { all = {
                distance(100),
                { any = { { animation = "Fall", player = "Enemy" }, { animation = "Physical", player = "Enemy" } } },
            } },
        } },
    },
    align = { axes = { "X", "Z" }, pivot = { node = "NHeel_2" }, position = { pivot = "Me" } },
    conditions = {
        { keys = { "RaidCharge" } },
        abilities.ready("shadow_cloak"),
        abilities.uncloaked(),
        { not_interval = "SemiUninterrupt" },
        { not_interval = "Uninterrupt" },
        { stage = "Fight" },
        { not_all = {
            { animation = "$Move" },
            { interval = "SemiUninterrupt" },
        } },
        { not_animation = "Physical" },
    },
    locks = {
        { perk = abilities.perks.shadow_cloak },
        { item = "Skeleton", subtype = "Skeleton" },
    },
    intervals = { { name = "Uninterrupt", to = 13 } },
    timeline = {
        [1] = smoke("InvisibilityCloakStart", "mgc_magic_invisible_start", 1.0, -30, 110),
        [8] = smoke("InvisibilityCloakEnd", "mgc_magic_invisible_end", 1.6, 40, 100),
        [12] = {
            { sound = "snd_smoke_bomb" },
            { play_sound = "snd_m_pl_attack6", voice = "Male" },
            { play_sound = "snd_low_pl_attack6", voice = "MaleLow" },
            { play_sound = "snd_f_pl_attack6", voice = "Female" },
        },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = { "key_pressed", { interval_end = "Uninterrupt" }, "animation_end" },
    direction = { from = { node = "NPivot", player = "Me" }, to = { node = "NPivot", player = "Enemy" } },
}

return { move = move }
