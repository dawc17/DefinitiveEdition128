local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- The archived War boss replaces the older Super-button whirlwind with a
-- RaidCharge cast. Its animation is copied unchanged from packaged core data.
sf2.moves.patch { move = "MagicWarAbilityPlayer", disable = true }

local HITS = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" }

local function whirl(name, sequence, looped, time_scale)
    return { effect = {
        name = name, core_sequence = sequence, scale = 1.5, time_scale = time_scale, looped = looped,
        position = { node = "stomach", of = "self", x = 3, y = 15 }, follow = true,
    } }
end

-- Game frames: the move starts at sample 1 with 3 frames per sample, so sample N is frames
-- 3N .. 3N + 2 (sample 3 is frame 9, 13 is 39, 14 is 42, 60 is 180, 70 ends on frame 212,
-- 80 on frame 242).
local move = sf2.moves.register {
    id = "war_whirl_player",
    animation = "animations/boss_war_ability",
    inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    first_sample = 1, last_sample = 81, priority = 110,
    events = "controlled",
    face = "enemy",
    align = "left_heel",

    when = {
        keys = "raid_charge",
        not_mod = { "WarRecharge", abilities.ready("war_whirl"), "Concussion", "Stun" },
        controllable = true,
    },
    only_for = { any = abilities.lock("war_whirl"), rig = "Skeleton" },
    tactic_when = { all = {
        { distance = { axis = "x", max = 600, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
        { distance = { axis = "x", min = 400, from = { node = "pelvis", of = "self" }, to = { wall = "front", of = "self" } } },
    } },

    windows = { uninterruptible = { to = 242 } },
    attacks = { {
        from = 42, to = 212,
        edges = { "EHand_1", "EFingers_1", "EArm_1", "EArm_2", "EForearm_2", "EHand_2", "EFingers_2", "EChest" },
        damage = { amount = 0.40, magic = 0, unarmed = -25 },
        impulse = { x = 150, y = -600 }, hit = "Physycal",
        no_critical = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } },

    on = {
        [9] = { whirl("MagicWarWhirlffectStart", "mgc_war_ability_start", false, 3), { sound = { "snd_blade_fury" } } },
        [39] = whirl("MagicWarWhirlffectMiddle", "mgc_war_ability_middle", true, 1),
        [180] = { { stop_effect = "MagicWarWhirlffectMiddle" },
            whirl("MagicWarWhirlffectMiddle", "mgc_war_ability_end", false, 3) },
        hit = { { stop_effect = "MagicWarWhirlffectMiddle" }, { stop_sound = "snd_blade_fury" } },
        finish = { { stop_effect = "MagicWarWhirlffectMiddle" }, { stop_sound = "snd_blade_fury" } },
        strike = { sound = HITS },
    },
}

-- Opening wait and seconds between whirls; recorded as the boss's pacing for its HUD icon.
local WHIRL_DELAY, WHIRL_EVERY = 2, 6
local tactic = sf2.tactics.register {
    id = "war_whirl", template = "Aggressive",
    on_decide = function(memory, event)
        if event.seconds < WHIRL_DELAY or event.seconds < (memory.next_whirl or 0) then return nil end
        for _, action in ipairs(event.actions) do
            if action.name == "de128:moves/war_whirl_player" then
                memory.next_whirl = event.seconds + WHIRL_EVERY
                return action
            end
        end
        return nil
    end,
}

return { move = move,
    tactic = abilities.pace(sf2.tactics.name(tactic), "war_whirl", WHIRL_DELAY * 60, WHIRL_EVERY * 60,
        { "de128:moves/war_whirl_player" }) }
