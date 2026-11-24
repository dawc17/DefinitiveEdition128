local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- Core's two hidden Root Potion items fall back to generic magic geometry.
-- Their archived attack edges live in these reviewed owner models.
sf2.items.patch {
    item = sf2.items.get("core:items/magic/MAGIC_VERTICAL_TRIGGER"),
    model = sf2.assets.model("models/underworld/mdl_vertical_trigger"),
}
sf2.items.patch {
    item = sf2.items.get("core:items/magic/SMALL_COLLISION_BOX"),
    model = sf2.assets.model("models/underworld/mdl_small_collision_box"),
}

-- The game's moves.xml already has the reviewed boss casts: the RaidCharge button on
-- Hoaxen's, Hunter's, the Root Potion's, Arkhos's, Tenebris's and Shogun's four Call to Arms
-- casts, Hunter's wall-range variants at priority 110, Arkhos's and Tenebris's packaged clips
-- and no Evade window on the Fear Ray. Only the DE128 recharge gates remain.
sf2.moves.patch {
    move = "RatWavePlayer",
    when = { not_mod = { "Stun", abilities.ready("rat_wave") } },
}
abilities.extend_lock("rat_wave", "RatWavePlayer")

-- Rat Wave and the Water Wave magic (Redemptive Gift, MAGIC_AZTEC_24) throw an invisible bomb
-- that arcs from just in front of the caster to about 280 units ahead (core mass_bomb_start)
-- and only hits once it has landed and rolls on (RatWaveMiddle, WaterWaveMiddle), so an enemy
-- closer than that was flown over (Seby, 2026-11-24). The Start moves are restated with the
-- Middle's attack, so the bomb also hits what it passes on the way; that hit ends the wave as
-- the Middle's does. Everything else is the native Start. mass_bomb_start.bytes is a
-- byte-identical copy of the packaged clip. Frames: from sample 2 at 3 frames per sample,
-- sample N is frames (N - 1) * 3 .. + 2 (sample 3 is frame 6, sample 13 is frame 36).
local function wave_start(spec)
    sf2.moves.patch {
        move = spec.move,
        replace = {
            id = spec.id,
            expected_file = "mass_bomb_start.bytes",
            animation = sf2.assets.binary("animations/mass_bomb_start"),
            inherit = { "MagicMissileStart", spec.template, "MagicMissile", "MissileStart", "MagicMissileFly" },
            first_sample = 2, priority = 500,
            no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
            face = { from = { wall = "back", of = "parent" }, to = { wall = "front", of = "parent" } },
            align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent", x = 100 } },
            events = { "birth" },
            when = { actor = spec.actor, parent = { not_animation = "StanceShop" } },
            only_for = { weapon = spec.weapon, rig = "SkeletonMagic" },
            attacks = { {
                edges = { "MassBomb-Edge1" },
                damage = { amount = spec.damage, magic = 0, unarmed = -25 },
                impulse = { x = 200, y = -500 }, hit = spec.hit,
                no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
                ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
            } },
            on = spec.on,
        },
    }
end

wave_start {
    move = "RatWaveStart", id = "rat_wave_start", template = "RatWave", actor = "RatWave",
    weapon = { item = "MAGIC_RAT_WAVE" }, damage = 0.40, hit = "RatWaveHit",
    on = {
        [36] = { sound = "snd_rats_ring" },
        strike = {
            { effect = { name = "RatWaveEnd", core_sequence = "mgc_rat_wave_end", scale = 1.2, time_scale = 3,
                position = { node = "MassBomb-MacroNode1", of = "self", x = 120, y = 150 } } },
            { stop_sound = "snd_rats_ring" },
            { sound = "snd_rats_hit" },
            { delete_actor = "self" },
        },
    },
}

wave_start {
    move = "WaterWaveStart", id = "water_wave_start", template = "WaterWave", actor = "WaterWave",
    weapon = "WaterWave", damage = 0.45, hit = "WaterWaveHit",
    on = {
        [6] = { effect = { name = "WaterWaveStart", core_sequence = "mgc_water_wave_start", scale = 1.2, time_scale = 4,
            position = { node = "MassBomb-MacroNode1", of = "self", x = 0, y = 70 } } },
        strike = {
            { effect = { name = "WaterWaveEnd", core_sequence = "mgc_water_wave_end", scale = 1.2, time_scale = 3,
                position = { node = "MassBomb-MacroNode1", of = "self", x = 120, y = 70 } } },
            { sound = "snd_magic_water_ball_end" },
            { delete_actor = "self" },
        },
    },
}

sf2.moves.patch {
    move = "PerkFearRayPlayer",
    when = { not_mod = { "Stun", abilities.ready("fear_ray") } },
}
abilities.extend_lock("fear_ray", "PerkFearRayPlayer")

-- A sealed Underworld fight (content.underworld_seals) shares this table with its boss's tactic:
-- while `held` is set the boss waits between seals, and `cooldown` (frames, or nil) replaces the
-- tactic's own ability cooldown for the save's difficulty. Only tactics built `sealed` read it.
local seal_hold = { held = false, cooldown = nil }

local function tactic(id, moves, initial, cooldown, advance_for_range, sealed)
    return sf2.ai.name(sf2.ai.register {
        id = id, template = "Aggressive",
        on_decide = function(memory, event)
            if sealed and seal_hold.held then return "wait" end
            local ready = event.frame >= initial and event.frame >= (memory.next_ability_frame or 0)
            local retreat, advance, attacks = nil, nil, {}
            for _, action in ipairs(event.actions) do
                if ready and moves[action.name] then
                    memory.next_ability_frame = event.frame + (sealed and seal_hold.cooldown or cooldown)
                    return action
                end
                if action.name == "StepBack" then retreat = action end
                if action.name == "StepForward" then advance = action end
                if action.type == "attack" and not moves[action.name] then
                    attacks[#attacks + 1] = action
                end
            end
            if ready then
                if advance_for_range then
                    local back_wall = event.back_wall_distance
                    if (not back_wall or back_wall < 120) and advance then return advance end
                    if back_wall and back_wall > 300 and retreat then return retreat end
                elseif retreat then
                    -- Open the native minimum-range gate, but do not repeat
                    -- StepBack while the back wall leaves no room.
                    local back_wall = event.back_wall_distance
                    if not back_wall or back_wall > 120 then return retreat end
                end
            end
            if #attacks > 0 then
                memory.other_attack = (memory.other_attack or 0) % #attacks + 1
                return attacks[memory.other_attack]
            end
            if ready and advance_for_range then return nil end
            return retreat or "wait"
        end,
    })
end

local hunter_moves = {}
for _, range in ipairs({ "150", "200", "300", "370" }) do
    hunter_moves["HunterFly_" .. range] = true
end

return {
    hoaxen = tactic("hoaxen_tentacles", { HoaxenSpikeStrikePlayer = true }, 600, 600),
    hunter = tactic("hunter_fly", hunter_moves, 900, 900, true),
    hunter_power = tactic("hunter_fly_power", hunter_moves, 800, 800, true),
    berstuuk = tactic("berstuuk_root_potion", { AbilityRootPotionPlayer = true }, 300, 600),
    arkhos = abilities.pace(tactic("arkhos_rat_wave", { RatWavePlayer = true }, 600, 600),
        "rat_wave", 600, 600, { "RatWavePlayer" }),
    -- His sealed normal fight: the same Rat Wave, held between seals, its cooldown set by the
    -- fight. The same cadence as above, so he keeps the same pacing icon.
    arkhos_sealed = abilities.pace(tactic("arkhos_rat_wave_sealed", { RatWavePlayer = true }, 600, 600, false, true),
        "rat_wave", 600, 600, { "RatWavePlayer" }),
    tenebris = abilities.pace(tactic("tenebris_fear_ray", { PerkFearRayPlayer = true }, 600, 600),
        "fear_ray", 600, 600, { "PerkFearRayPlayer" }),
    seal_hold = seal_hold,
}
