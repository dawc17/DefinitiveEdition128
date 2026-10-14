local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- The four archived Wasp Fly ranges replace the old core Super-button moves.
-- All animation bytes are copied unchanged from recovered Resources. DE128
-- never loads move XML at runtime.

local edges = {
    "EArm_1", "EArm_2", "EHead", "EChest", "EForearm_1", "EForearm_2",
    "EHand_2", "EFingers_2", "EForearm_1", "EHand_1", "EFingers_1",
}
-- Window and attack bounds are game frames. Every variant starts at sample 1 with 3 frames
-- per sample, so a window "from sample N" starts on frame 3N and one "to sample N" ends on
-- frame 3N + 2. The comments give the samples the archive uses.
local variants = {
    { suffix = "150", binary = "naginata_boss_1", wall_min = 1, wall_max = 150,
      align_x = -160, uninterruptible_to = 152, unstable_to = 137, block_from = 153,
      attack_from = 57, attack_to = 95, effect_end = 96 },       -- samples 50, 45, 51, 19-31, 32
    { suffix = "200", binary = "naginata_boss", wall_min = 150, wall_max = 230,
      align_x = -70, uninterruptible_to = 152, unstable_to = 137, block_from = 153,
      attack_from = 57, attack_to = 95, effect_end = 96,
      effect_start = { "WaspSpeedSplitWingsStart", "mgc_wasp_speed_split_wings_start", -70, 65 } },
    { suffix = "300", binary = "naginata_boss_2", wall_min = 230, wall_max = 300,
      align_x = 0, uninterruptible_to = 152, unstable_to = 137, block_from = 153,
      attack_from = 57, attack_to = 95, effect_end = 96,
      effect_start = { "WaspSpeedSplitWingsStartTwo", "mgc_wasp_speed_split_wings_start_2", -75, 90 } },
    { suffix = "370", binary = "naginata_boss_3", wall_min = 300, wall_max = 370,
      align_x = 75, uninterruptible_to = 188, unstable_to = 167, block_from = 189,
      attack_from = 78, attack_to = 119, effect_end = 117 },     -- samples 62, 55, 63, 26-39, 39
}
local moves = {}
for _, variant in ipairs(variants) do
    sf2.moves.patch { move = "WaspFly_" .. variant.suffix, disable = true }
    local timeline = {
        [0] = { sound = { "snd_wasp_fly_start" } },
        [12] = {
            { sound = "snd_m_pl_attack3", voice = "male" },
            { sound = "snd_low_pl_attack3", voice = "male_low" },
            { sound = "snd_f_pl_attack3", voice = "female" },
        },
        [42] = { { sound = { "snd_swish2" } }, { sound = { "snd_wasp_fly_mid" } } },
        [78] = { sound = { "snd_wasp_fly_end" } },
        [variant.effect_end] = { effect = {
            name = "WaspSpeedSplitWingsEnd", core_sequence = "mgc_wasp_speed_split_wings_end",
            scale = 1.35, time_scale = 1.9,
            position = { node = "pelvis", of = "self", x = 140, y = 14 }, follow = false,
        } },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    }
    if variant.effect_start then
        local start = variant.effect_start
        table.insert(timeline[12], 1, { effect = {
            name = start[1], core_sequence = start[2], scale = 1.35, time_scale = 1.9,
            position = { node = "pelvis", of = "self", x = start[3], y = start[4] }, follow = false,
        } })
    end
    moves[variant.suffix] = sf2.moves.register {
        id = "wasp_fly_" .. variant.suffix,
        animation = sf2.assets.binary("animations/" .. variant.binary),
        inherit = { "1key", "WaspFly", "BossAbility", "Controlled", "SoundStrike" },
        no_wall_repulsion = true, first_sample = 1, priority = 110,
        align = { axes = { "x", "z" }, pivot = { animation = true },
            position = { wall = "back", of = "self", x = variant.align_x } },
        when = {
            keys = "raid_charge",
            not_mod = { "WaspFlyRecharge", abilities.ready("wasp_fly") },
            distance = { axis = "x", min = variant.wall_min, max = variant.wall_max,
                from = { wall = "back", of = "self" }, to = { node = "left_heel", of = "self" } },
            enemy = { not_mod = "CurseBomb" },
            controllable = true,
        },
        only_for = { any = abilities.lock("wasp_fly"), rig = "Skeleton" },
        windows = {
            invulnerable = { name = "Boss" },
            unstable = { to = variant.unstable_to },
            uninterruptible = { to = variant.uninterruptible_to },
            block = { from = variant.block_from },
            throwable = { from = variant.block_from },
        },
        attacks = { { from = variant.attack_from, to = variant.attack_to, edges = edges, damage = { amount = 0.3, weapon = 0, unarmed = -10 },
            impulse = { x = 350 }, hit = "WaspFly", ignores_block = true, ignores_invulnerable = true } },
        on = timeline,
        events = "controlled",
        face = "enemy",
    }
end

-- The recovered Aggressive tactic can leave Fly unused for an entire survival
-- wave. Keep its normal decisions, but choose an eligible archived Fly move once
-- the boss has fought for two seconds. Native cooldown and distance conditions
-- still decide whether the move appears in event.actions.
-- Opening wait and seconds between flights; recorded as the boss's pacing for its HUD icon.
local FLY_DELAY, FLY_EVERY = 2, 5
local tactic = sf2.tactics.register {
    id = "wasp_fly",
    template = "Aggressive",
    on_decide = function(memory, event)
        if event.seconds < FLY_DELAY or event.seconds < (memory.next_fly or 0) then return nil end
        for _, action in ipairs(event.actions) do
            if action.name:sub(1, 21) == "de128:moves/wasp_fly_" then
                memory.next_fly = event.seconds + FLY_EVERY
                return action
            end
        end
        return nil
    end,
}

local fly_moves = {}
for _, range in ipairs({ "150", "200", "300", "370" }) do fly_moves[#fly_moves + 1] = "de128:moves/wasp_fly_" .. range end
return { moves = moves,
    tactic = abilities.pace(sf2.tactics.name(tactic), "wasp_fly", FLY_DELAY * 60, FLY_EVERY * 60, fly_moves) }
