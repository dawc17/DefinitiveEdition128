local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- The archived storm keeps the native child actor's four unchanged moves, but
-- changes the caster, idle continuation and victory transition.

local storm_item = sf2.items.get("core:items/magic/HERMIT_STORM")

sf2.moves.patch { move = "HermitStormPlayer", disable = true }
sf2.moves.patch { move = "HermitStormPlayerIdle", disable = true }
sf2.moves.patch { move = "Win_HermitStorm", disable = true }

-- Frames: hermit_storm_idle starts at sample 3 and the player move at sample 1, both
-- with 3 frames per sample. Sample N is game frames (N - first + 1) * 3 .. +2, and the
-- first sample is frames 0-5.
--
-- Once the storm is up, only a hit or the raid charge button ends it (Seby, 2026-11-24): the
-- levitation loops and nothing else may cut it. The cast and the idle are uninterruptible to
-- their end, so other key presses, buffered ones included, are refused. (The cast used to turn
-- semi-uninterruptible at frame 108, where 2key follow-ups could cut it and leave the looped
-- levitation effect running; the idle at frame 102.) hermit_storm_cancel asks for no
-- controllable state, so its raid charge press still gets through.
-- The victory pose outranks the idle (999): with no uninterruptible end inside the idle any
-- more, a round won during the cast reaches it at the idle's end instead (archive: 100).
local win = sf2.moves.register {
    id = "hermit_storm_win", animation = sf2.assets.binary("animations/hermit_super_attack_idle"),
    inherit = { "Win", "EndStance", "StageStance", "Stance" },
    last_sample = 54, priority = 1000,
    ends_stage = true,
    align = "right_heel",
    transitions = { { sample_shift = 0, when = { all = { { animation = "de128:moves/hermit_storm_idle" }, { animation = "de128:moves/hermit_storm_win" } } } } },
    only_for = { rig = "Skeleton" },
    when = {
        any = { { animation = "de128:moves/hermit_storm_win" }, { animation = "de128:moves/hermit_storm_idle" } },
        round_result = "victory",
        stage = "end_stance",
    },
    windows = { uninterruptible = true, block = true, throwable = true },
    events = { { round_stage = "end_stance" },
        { interval_end = "uninterruptible" }, "finish" },
    face = "enemy",
}

local idle_actions = {
        [69] = { projectile = {
        name = "HermitStorm", core_skeleton = "SkeletonMagic", item = storm_item,
    } },
        [114] = { projectile = {
        name = "HermitStorm", core_skeleton = "SkeletonMagic", item = storm_item,
    } },
        hit = { stop_effect = "HermitStormLevitation" },
    }
for _, frame in ipairs({ 0, 24, 48, 72, 96, 120, 144 }) do
    idle_actions[frame] = { sound = { "snd_hermit_storm_idle" } }
end
local idle = sf2.moves.register {
    id = "hermit_storm_idle", animation = sf2.assets.binary("animations/hermit_super_attack_idle"),
    first_sample = 3, last_sample = 54, priority = 999,
    -- No rig requirement here (the ability lock only), so the left-heel default does not apply.
    mirror = "left_heel", tactic_equivalent = "StanceIdle", ends_stage = true,
    align = "right_heel",
    events = { "finish" },
    when = { any = { { animation = "de128:moves/hermit_storm_player" }, { animation = "de128:moves/hermit_storm_idle" }, { animation = "de128:moves/hermit_storm_win" } } },
    only_for = { any = abilities.lock("hermit_storm") },
    windows = { unstable = true, uninterruptible = true },
    on = idle_actions,
}

local edges = { "EArm_1", "EArm_2", "EChest", "EForearm_1", "EForearm_2",
    "EHand_2", "EFingers_2", "EForearm_1", "EHand_1", "EFingers_1" }
local damage = { amount = 0.05, weapon = 0, unarmed = -10 }
local function attack(from, to, hit)
    return { from = from, to = to,
        edges = edges, damage = damage,
        impulse = { x = 345, y = -205, z = -350 }, hit = hit,
    }
end
-- Raid charge while levitating: the fighter drops to the ground into the cast's first,
-- standing samples (blended in over the first 10 frames), the levitation effect and the
-- storm's hum stop, and the stance idle takes over when it ends. In the cast it counts from
-- frame 84, after the last attack. Its start begins the recharge (content.boss_abilities).
sf2.moves.register {
    id = "hermit_storm_cancel", animation = sf2.assets.binary("animations/hermit_super_attack"),
    first_sample = 0, last_sample = 1, frames_per_sample = 5, priority = 120,
    align = "left_heel",
    events = { "key_pressed" },
    when = {
        keys = "raid_charge",
        stage = "fight",
        any = { { animation = "de128:moves/hermit_storm_idle" },
            { animation = "de128:moves/hermit_storm_player", window = "HermitStormHover" } },
    },
    only_for = { any = abilities.lock("hermit_storm"), rig = "Skeleton" },
    windows = { unstable = true, uninterruptible = { to = 9 } },
    on = { [0] = { { stop_effect = "HermitStormLevitation" }, { stop_sound = "snd_hermit_storm_idle" } } },
    face = "enemy",
}

local player = sf2.moves.register {
    id = "hermit_storm_player", animation = sf2.assets.binary("animations/hermit_super_attack"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    no_wall_repulsion = true, first_sample = 1,
    priority = 110,
    tactic_when = { all = {
        { distance = { axis = "x", min = 100, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
        { distance = { axis = "x", min = 200, from = { wall = "back", of = "self" }, to = { node = "left_heel", of = "self" } } },
        { distance = { axis = "x", min = 200, from = { node = "left_heel", of = "self" }, to = { wall = "front", of = "self" } } },
    } },
    align = "left_heel",
    when = {
        keys = "raid_charge",
        not_mod = { "HermitStormRecharge", abilities.ready("hermit_storm"), abilities.paced("hermit_storm"), "SilenceIcon" },
        not_animation = "de128:moves/hermit_storm_idle",
        controllable = true,
    },
    only_for = { any = abilities.lock("hermit_storm"), rig = "Skeleton" },
    windows = { unstable = true, uninterruptible = true, HermitStormHover = { from = 84 } },
    attacks = { attack(24, 29, "High"), attack(33, 59, "Low"), attack(60, 83, "Low") },
    on = {
        [60] = { projectile = {
        name = "HermitStorm", core_skeleton = "SkeletonMagic", item = storm_item,
    } },
        [57] = { effect = {
            name = "HermitStormLevitation", core_sequence = "mgc_effect_levitation_middle",
            scale = 1.5, time_scale = 2, looped = true, on_background = true,
            position = { node = "stomach", of = "self", x = 3, y = 15 }, follow = true,
        } },
        hit = { stop_effect = "HermitStormLevitation" },
        [0] = { sound = { "snd_hermit_storm_start" } },
        [93] = { sound = { "snd_hermit_storm_idle" } },
        [117] = { sound = { "snd_hermit_storm_idle" } },
        strike = { sound = {
            "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = "controlled",
    face = "enemy",
}

-- Seconds between storms; recorded as the boss's pacing for its HUD icon.
local STORM_EVERY = 6
local tactic = sf2.ai.register {
    id = "hermit_storm", template = "Aggressive",
    on_decide = function(memory, event)
        if event.seconds < (memory.next_storm or 0) then return nil end
        for _, action in ipairs(event.actions) do
            if action.name == "de128:moves/hermit_storm_player" then
                memory.next_storm = event.seconds + STORM_EVERY
                return action
            end
        end
        return nil
    end,
}

return { player = player, idle = idle, win = win,
    tactic = abilities.pace(sf2.ai.name(tactic), "hermit_storm", 0, STORM_EVERY * 60,
        { "de128:moves/hermit_storm_player" }) }
