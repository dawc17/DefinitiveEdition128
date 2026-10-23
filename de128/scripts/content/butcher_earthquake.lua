local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- The archived raid-charge Earthquake graph uses the hidden native earthquake
-- item as its child actor's weapon. Its animation bytes are unchanged core data.

local earthquake_item = sf2.items.get("core:items/magic/MAGIC_BUTCHER_EARTHQUAKE")

sf2.moves.patch { move = "ButcherEarthquakePlayer", disable = true }
sf2.moves.patch { move = "ButcherEarthquakeStart", disable = true }

-- Timing: both moves start at sample 1 with 3 frames per sample, so sample N
-- (N > 1) is game frames 3N .. 3N + 2.
local start = sf2.moves.register {
    id = "butcher_earthquake_start",
    animation = sf2.assets.binary("animations/butcher_super_attack_activ"),
    inherit = { "MagicMissileFly", "MagicMissile" },
    no_wall_repulsion = true, no_magic_recharge = true,
    first_sample = 1, priority = 500,
    face = "with_parent",
    align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" },
        position = { node = "pelvis", of = "enemy" } },
    events = { "birth" },
    when = { parent = { animation = "de128:moves/butcher_earthquake_player" } },
    only_for = { weapon = { item = "MAGIC_BUTCHER_EARTHQUAKE" }, rig = "SkeletonMagic" },
    attacks = { {
        from = 6, edges = { "Edge1" }, damage = { amount = 0.41, magic = 0, unarmed = -25 },
        impulse = { x = 150, y = -300 }, hit = "Earthquake",
        no_effect = true, no_critical = true, body_part = "body",
        defense = { "body" }, ignores_block = true,
        ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } },
    on = {
        finish = { delete_actor = "self" },
    },
}

local player = sf2.moves.register {
    id = "butcher_earthquake_player",
    animation = sf2.assets.binary("animations/butcher_super_attack"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    no_wall_repulsion = true, first_sample = 1,
    priority = 110,
    -- No rig requirement here (the ability lock only), so the left-heel default does not apply.
    mirror = "left_heel",
    tactic_when = {
        enemy = { not_animation = "Jump" },
        any = {
            { distance = { axis = "x", min = 250, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
            { enemy = { animation = "Fall" } },
        },
    },
    align = "left_heel",
    when = {
        keys = "raid_charge",
        not_mod = { "EarthquakeRecharge", abilities.ready("earthquake") },
        controllable = true,
    },
    only_for = { any = abilities.lock("earthquake") },
    windows = {
        unstable = { to = 74 },
        uninterruptible = { to = 98 },
        block = { from = 99 },
        throwable = { from = 99 },
    },
    on = {
        [66] = { { projectile = {
            name = "Earthquake", core_skeleton = "SkeletonMagic", item = earthquake_item, start = start,
        } }, { effect = {
            name = "ButcherEarthquake", core_sequence = "mgc_effect_fall", scale = 1,
            time_scale = 2, looped = false, position = { node = "pelvis", of = "self", x = 40, y = -40 }, follow = false,
        } } },
        [69] = { { shake = {
            pause_time = 0, effect_time = 60, amplitude_x = 7, frequency_x = 1,
            amplitude_y = 18, frequency_y = 0.5,
        } }, { sound = "snd_bodyfall1", voice = "male" }, { sound = "snd_bodyfall1", voice = "male_low" }, { sound = { "snd_bucher_touchdown" } } },
        [12] = { { sound = "snd_bucher_jump_new", voice = "male" }, { sound = "snd_bucher_jump_new", voice = "male_low" } },
        strike = { sound = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" } },
    },
    events = "controlled",
    face = "enemy",
}

-- Seconds between earthquakes; recorded as the boss's pacing for its HUD icon.
local QUAKE_EVERY = 6
local tactic = sf2.ai.register {
    id = "butcher_earthquake", template = "Aggressive",
    on_decide = function(memory, event)
        if event.seconds < (memory.next_quake or 0) then return nil end
        for _, action in ipairs(event.actions) do
            if action.name == "de128:moves/butcher_earthquake_player" then
                memory.next_quake = event.seconds + QUAKE_EVERY
                return action
            end
        end
        return nil
    end,
}

return { player = player, start = start,
    tactic = abilities.pace(sf2.ai.name(tactic), "earthquake", 0, QUAKE_EVERY * 60,
        { "de128:moves/butcher_earthquake_player" }) }
