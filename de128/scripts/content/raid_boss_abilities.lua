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
sf2.moves.patch {
    move = "PerkFearRayPlayer",
    when = { not_mod = { "Stun", abilities.ready("fear_ray") } },
}
abilities.extend_lock("fear_ray", "PerkFearRayPlayer")

local function tactic(id, moves, initial, cooldown, advance_for_range)
    return sf2.ai.name(sf2.ai.register {
        id = id, template = "Aggressive",
        on_decide = function(memory, event)
            local ready = event.frame >= initial and event.frame >= (memory.next_ability_frame or 0)
            local retreat, advance, attacks = nil, nil, {}
            for _, action in ipairs(event.actions) do
                if ready and moves[action.name] then
                    memory.next_ability_frame = event.frame + cooldown
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
    tenebris = abilities.pace(tactic("tenebris_fear_ray", { PerkFearRayPlayer = true }, 600, 600),
        "fear_ray", 600, 600, { "PerkFearRayPlayer" }),
}
