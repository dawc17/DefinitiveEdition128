local sf2 = require("sf2")
-- Pending assembler. The caller must resolve the real guard fighters, prince
-- equipment and a faithful conditional control rule before calling this once.
-- A static NoButton handle is NOT an implementation of that condition.
local function register(opponents, conditional_raid_charge)
    assert(type(opponents) == "table" and #opponents == 6 and conditional_raid_charge,
        "Sensei encounters require six complete rosters and a conditional RaidCharge rule")
    for act = 1, 6 do
        local count = act == 6 and 2 or 3
        assert(type(opponents[act]) == "table" and type(opponents[act].normal) == "table"
            and type(opponents[act].eclipse) == "table" and #opponents[act].normal == count
            and #opponents[act].eclipse == count, "Incomplete Sensei opponent roster")
    end
    local rewards = require("content.sensei_rewards")
    local rules = require("content.sensei_fight_rules")
    local function with_charge(entry)
        local copy = {}
        for index, rule in ipairs(entry.unconditional) do copy[index] = rule end
        table.insert(copy, entry.charge_position, conditional_raid_charge)
        return copy
    end
    -- Opponents are written inline; a battle is registered together with its fights.
    local fights = { normal = {}, eclipse = {} }
    for act = 1, 6 do
        local normal = {}
        for index, opponent in ipairs(opponents[act].normal) do
            normal[index] = {
                opponents = { opponent }, rewards = rewards[act].normal[index], rules = with_charge(rules.acts[act].normal[index]),
                rounds = 2, round_time = 150, replays = 1, power = 0, evaluated_rating = 10,
            }
        end
        fights.normal[act] = normal
        fights.eclipse[act] = { {
            opponents = opponents[act].eclipse, rewards = rewards[act].eclipse, rules = with_charge(rules.acts[act].eclipse),
            rounds = 1, round_time = 150, replays = 0, power = 0, evaluated_rating = 10,
        } }
    end
    local battles = require("content.sensei_battles").register(fights)
    local result = { battles = battles, normal = {}, normal_ids = {}, eclipse = {}, finals = {}, final_ids = {}, prior_final_ids = {} }
    for act = 1, 6 do
        local normal = {}
        local ids = {}
        for index, fight in ipairs(battles.normal[act].fights) do
            normal[index] = fight
            ids[index] = sf2.mod.id .. ":fights/sensei_act_" .. act .. "_normal_" .. index
        end
        result.normal[act] = normal
        result.normal_ids[act] = ids
        result.final_ids[act] = ids[#ids]
        if act < 6 then
            result.finals[act] = normal[#normal]
            result.prior_final_ids[act] = result.final_ids[act]
        end
        result.eclipse[act] = battles.eclipse[act].fights[1]
    end
    return result
end
return { register = register }
