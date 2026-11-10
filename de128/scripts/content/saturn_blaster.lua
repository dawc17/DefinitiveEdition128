local sf2 = require("sf2")

-- The core blaster graph already contains Saturn's pistol, both bullets, the
-- close-range strike and their cleanup. The reviewed DE caster's RaidCharge input and
-- priority 200 are in the game's moves.xml, so the move needs no patch.

local function register_tactic(id, cooldown)
    return sf2.ai.register {
        id = id, template = "Aggressive",
        on_decide = function(memory, event)
            local ready = event.frame >= 300 and event.frame >= (memory.next_blaster_frame or 0)
            local retreat, attacks = nil, {}
            for _, action in ipairs(event.actions) do
                if ready and action.name == "SaturnBlasterAbilityPlayer" then
                    memory.next_blaster_frame = event.frame + cooldown
                    return action
                end
                if action.name == "StepBack" then retreat = action end
                if action.type == "attack" and action.name ~= "SaturnBlasterAbilityPlayer" then
                    attacks[#attacks + 1] = action
                end
            end
            if not ready then
                if #attacks > 0 then
                    memory.other_attack = (memory.other_attack or 0) % #attacks + 1
                    return attacks[memory.other_attack]
                end
                return retreat or "wait"
            end
            if retreat then return retreat end
            return "wait"
        end,
    }
end

return {
    tactic = sf2.ai.name(register_tactic("saturn_blaster", 660)),
    power_tactic = sf2.ai.name(register_tactic("saturn_blaster_power", 550)),
}
