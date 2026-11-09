local sf2 = require("sf2")

-- Shogun's four bodyguards, playing the native Assistant moves (moves.xml): the same clips,
-- attacks and order as the boss's ability, with the conditions that tied them to his summoning
-- animation removed. Each is a Start, an optional End, then AssistantLeave.
-- They are idle actors: only these moves run, never normal AI.
--
-- Frames: every clip has 2 frames per sample, so with first_sample F, sample N is
-- frames (N - F + 1) * 2 .. + 1.

local HITS = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" }
local INHERIT = { "SummonedAssistant", "Assistant", "BossAbility" }
local INHERIT_STRIKE = { "SummonedAssistant", "SoundStrike", "Assistant", "BossAbility" }
local DAMAGE_WEAPON, DAMAGE_UNARMED = 0, -10
local LIFETIME_FRAMES = 300     -- a limit only; each bodyguard removes itself after leaving

local function move_id(id) return sf2.mod.id .. ":moves/" .. id end

local function clip(name) return sf2.assets.binary("animations/" .. name) end

local function strike(from, to, edges, amount, impulse, hit)
    return { {
        from = from, to = to, edges = edges,
        damage = { amount = amount, weapon = DAMAGE_WEAPON, unarmed = DAMAGE_UNARMED },
        impulse = impulse, hit = hit, ignores_block = true,
    } }
end

local KATANA_EDGES = { "WEAPON_TWO-HAND_SWORD-Edge1", "WEAPON_TWO-HAND_SWORD-Edge2", "WEAPON_TWO-HAND_SWORD-Edge3",
    "WEAPON_HEAVY_HAMMER-Edge2", "WEAPON_HEAVY_HAMMER-Edge3", "WEAPON_TWO-HAND_MACE-Edge3", "WEAPON_TWO-HAND_MACE-Edge2",
    "EHand_1", "EHand_2", "EFingers_1", "EFingers_2", "EForearm_1", "EForearm_2" }
local SPEAR_EDGES = { "WEAPON_SPEAR-Edge2" }
local GLAIVE_EDGES = { "WEAPON_GLAIVE-Edge1", "WEAPON_GLAIVE-Edge3", "EForearm_2", "EHand_2", "EFingers_2" }

-- The opening move, played by Lua the moment the bodyguard appears.
local function start_move(id, file, first_sample, uninterruptible, inherit, attacks, swish)
    return sf2.moves.register {
        id = id, animation = clip(file), inherit = inherit,
        frames_per_sample = 2, first_sample = first_sample, priority = 500,
        no_wall_repulsion = true, no_interpolation_frames = true,
        align = "right_heel", face = "enemy",
        windows = { uninterruptible = { to = uninterruptible } },
        attacks = attacks,
        only_for = { rig = "Skeleton" },
        on = { [swish[1]] = { sound = { swish[2] } }, strike = { sound = HITS } },
    }
end

-- The strike that follows a Start which has none of its own.
local function end_move(id, file, first_sample, uninterruptible, attacks, after, swish)
    return sf2.moves.register {
        id = id, animation = clip(file), inherit = INHERIT_STRIKE,
        frames_per_sample = 2, first_sample = first_sample, priority = 500,
        no_wall_repulsion = true,
        align = "left_heel", face = "enemy",
        events = { { interval_end = "uninterruptible" } },
        when = { animation = move_id(after) },
        windows = { uninterruptible = { to = uninterruptible } },
        attacks = attacks,
        only_for = { rig = "Skeleton" },
        on = { [swish[1]] = { sound = { swish[2] } }, strike = { sound = HITS } },
    }
end

local katana = start_move("bodyguard_katana_start", "front_flip", 2, 37, INHERIT, nil, { 10, "snd_swish7" })
end_move("bodyguard_katana_end", "two_hand_low_slash", 5, 55,
    strike(14, 21, KATANA_EDGES, 0.25, { x = 700, y = 0, z = -675 }, "Sweep"), "bodyguard_katana_start", { 10, "snd_swish6" })

local naginata = start_move("bodyguard_naginata_start", "spear_heavy_split", 2, 49, INHERIT_STRIKE,
    strike(26, 35, SPEAR_EDGES, 0.1, { x = 350, y = 0, z = 0 }, "Overhead"), { 26, "snd_swish2" })

local yari = start_move("bodyguard_yari_start", "spear_super_split", 20, 49, INHERIT_STRIKE,
    strike(4, 25, SPEAR_EDGES, 0.25, { x = 500, y = 0, z = 0 }, "Middle"), { 4, "snd_swish5" })

local glaive = start_move("bodyguard_glaive_start", "forward_roll", 2, 33, INHERIT, nil, { 10, "snd_swish7" })
end_move("bodyguard_glaive_end", "glaive_spinning_slash", 4, 31,
    strike(14, 19, GLAIVE_EDGES, 0.25, { x = 245, y = 0, z = -350 }, "Spinning"), "bodyguard_glaive_start", { 6, "snd_swish_sword1" })

sf2.moves.register {
    id = "bodyguard_leave", animation = clip("jump_away"), inherit = { "Assistant", "BossAbility" },
    frames_per_sample = 2, first_sample = 1, priority = 600,
    no_wall_repulsion = true, mirror = "left_heel",
    align = "left_heel",
    events = { { interval_end = "uninterruptible" } },
    when = { any = {
        { animation = move_id("bodyguard_katana_end") },
        { animation = move_id("bodyguard_naginata_start") },
        { animation = move_id("bodyguard_yari_start") },
        { animation = move_id("bodyguard_glaive_end") },
    } },
    only_for = { rig = "Skeleton" },
    on = { finish = { delete_actor = "self" } },
}

local function bodyguard(id, weapon)
    return sf2.fighters.register {
        id = id,
        fighter = "core:warrior-templates/default",
        level = 1, tactic = "Standard", skeleton = "Skeleton",
        items = {
            sf2.items.get("core:items/weapon/" .. weapon),
            sf2.items.get("core:items/armor/ARMOR_CENTURION"),
            sf2.items.get("core:items/helm/HELM_CRESCENT"),
        },
    }
end

-- Like the native assistants (an invulnerable "Boss" window), they cannot be hurt or staggered.
local function behavior(start)
    return {
        on_actor_spawn = function(_, fighter)
            local request = fighter.actor:play_move(start)
            if request.status == "failed" then sf2.log.warn("Bodyguard move failed: " .. tostring(request.error)) end
        end,
        on_hit_pre_crit = function(_, fighter, event)
            if event.target == "self" then
                fighter:set_hit_armored(true)
            elseif event.blocked then
                fighter:set_hit_blocked(false)
            end
        end,
        on_damage_resolving = function(_, fighter)
            fighter:scale_incoming_damage(0)
        end,
    }
end

local function actor(id, weapon, start, spawn)
    spawn.actor = sf2.actors.register {
        id = id, character = bodyguard(id .. "_body", weapon),
        team = "owner", ai = false, lifetime_frames = LIFETIME_FRAMES, max_health = 1, behavior = behavior(start),
    }
    return spawn
end

-- Where each enters, from the native moves' Align: behind the summoner, or for the glaive
-- behind the enemy.
return {
    katana = actor("bodyguard_katana", "WEAPON_NODACHI", katana, { behind_player = 470 }),
    naginata = actor("bodyguard_naginata", "WEAPON_BG_NAGINATA", naginata, { behind_player = 470 }),
    yari = actor("bodyguard_yari", "WEAPON_BG_YARI", yari, { behind_player = 470 }),
    glaive = actor("bodyguard_glaive", "WEAPON_BG_GLAIVE", glaive, { behind_enemy = 500 }),
}
