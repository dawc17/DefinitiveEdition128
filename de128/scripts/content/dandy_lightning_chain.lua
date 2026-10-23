local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- Preserve the core caster identity: its CreatePlayer action and five linked
-- native chain phases already match the reviewed DE graph.
sf2.moves.patch {
    move = "LightingChainPlayer",
    input = { expected = "super", value = "raid_charge" },
    priority = { expected = 9000, value = 200 },
    -- The native Uninterrupt window starts at sample 9 (frame 24) and the new start is sample 0,
    -- before the move's first sample (2), so these bounds are samples.
    windows = { change = { uninterruptible = { expected = { from_sample = 9, to_sample = 39 }, value = { from_sample = 0 } } } },
    when = { not_mod = abilities.ready("lightning_chain") },
}
abilities.extend_lock("lightning_chain", "LightingChainPlayer")

-- Eclipse's spawned magic actor has its hidden HERMIT_STORM item but no parent
-- perk slot. Keep the five linked native phases exclusive to LightningChain.
local chain_perk = sf2.perks.get("core:perks/PERK_LIGHTING_CHAIN")
for _, name in ipairs({ "LightingChainStart", "LightingChain50", "LightingChain150",
    "LightingChain300", "LightingChain400" }) do
    sf2.moves.patch { move = name, perk_locks = { remove = { chain_perk } } }
    sf2.moves.patch { move = name, when = { actor = "LightningChain" } }
end

-- Opening wait in frames; the tactic and the boss's HUD pacing share it.
local CHAIN_DELAY = 300

local function register_tactic(id, cooldown)
    return sf2.ai.register {
        id = id, template = "Aggressive",
        on_decide = function(memory, event)
            local ready = event.frame >= CHAIN_DELAY and event.frame >= (memory.next_chain_frame or 0)
            local retreat, attacks = nil, {}
            for _, action in ipairs(event.actions) do
                if ready and action.name == "LightingChainPlayer" then
                    memory.next_chain_frame = event.frame + cooldown
                    return action
                end
                if action.name == "StepBack" then retreat = action end
                if action.type == "attack" and action.name ~= "LightingChainPlayer" then
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
            -- The native caster has a 450-unit AI range gate. If the player
            -- stays close, let Aggressive keep fighting instead of repeating
            -- StepBack against the arena wall forever.
            return nil
        end,
    }
end

return {
    tactic = abilities.pace(sf2.ai.name(register_tactic("dandy_lightning_chain", 600)),
        "lightning_chain", CHAIN_DELAY, 600, { "LightingChainPlayer" }),
    power_tactic = abilities.pace(sf2.ai.name(register_tactic("dandy_lightning_chain_power", 500)),
        "lightning_chain", CHAIN_DELAY, 500, { "LightingChainPlayer" }),
}
