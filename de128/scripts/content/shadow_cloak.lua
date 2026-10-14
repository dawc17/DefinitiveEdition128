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
        position = { node = "pelvis", of = "self", x = x, y = y }, follow = false,
    } }
end

local function distance(min)
    return { axis = "x", min = min, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } }
end

-- Game frames: the move starts at sample 1 with 3 frames per sample, so sample N is
-- frames 3N .. 3N + 2 (samples 8 and 12 are frames 24 and 36); the Uninterrupt window
-- ends with sample 13, on frame 41.
local move = sf2.moves.register {
    id = "shadow_cloak_player",
    animation = sf2.assets.binary("animations/smoke_bomb"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 1, priority = 110,
    tactic_when = {
        any = {
            { distance = distance(400) },
            { distance = distance(100),
                any = { { enemy = { animation = "Fall" } }, { enemy = { animation = "Physical" } } } },
        },
    },
    align = "right_heel",
    when = {
        keys = "raid_charge",
        not_mod = { abilities.ready("shadow_cloak"), abilities.uncloaked() },
        controllable = true,
    },
    only_for = { perk = abilities.perks.shadow_cloak, rig = "Skeleton" },
    windows = { uninterruptible = { to = 41 } },
    on = {
        [0] = smoke("InvisibilityCloakStart", "mgc_magic_invisible_start", 1.0, -30, 110),
        [24] = smoke("InvisibilityCloakEnd", "mgc_magic_invisible_end", 1.6, 40, 100),
        [36] = {
            { sound = { "snd_smoke_bomb" } },
            { sound = "snd_m_pl_attack6", voice = "male" },
            { sound = "snd_low_pl_attack6", voice = "male_low" },
            { sound = "snd_f_pl_attack6", voice = "female" },
        },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = "controlled",
    face = "enemy",
}

return { move = move }
