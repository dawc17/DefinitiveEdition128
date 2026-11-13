-- DE128's own changes to the generated Underworld rows. content.underworld_data is regenerated
-- from the reviewed archive, so later design changes live here and are applied, once, before
-- content.underworld registers anything.

-- Scrapped for DE's Underworld rework (Seby, 2026-11-11): the Gauntlet (Survival_DEMON) and
-- the Mercenary Unit (Survival_MERCENARY), both on tier 8.
local SCRAPPED = { Survival_DEMON = true, Survival_MERCENARY = true }
-- The Prince (Man_Haunted_Prince) summons Shogun's bodyguards instead of teleporting: Call to
-- Arms takes Teleportation's place, and the core boss perk unlocks the native casts as it does
-- for Shogun. Without Teleportation he keeps his row's own tactic.
local PRINCE_BATTLE, PRINCE = "BOSS_HAUNTED_PRINCE", "Man_Haunted_Prince"
local ASSISTANTS = "core:perks/PERK_ASSISTANTS"
local TELEPORTATION = "core:perks/PERK_TELEPORTATION"

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function find_battle(data, name)
    for _, zone in ipairs(data.zones) do
        for index, battle in ipairs(zone.battles) do
            if battle.name == name then return zone, index, battle end
        end
    end
    error("Underworld battle " .. name .. " is missing")
end

local function scrap(data)
    local found = 0
    for _, zone in ipairs(data.zones) do
        for index = #zone.battles, 1, -1 do
            if SCRAPPED[zone.battles[index].name] then
                table.remove(zone.battles, index)
                found = found + 1
            end
        end
    end
    assert(found == 2, "Expected to scrap the Gauntlet and the Mercenary Unit, found " .. found)
end

local function revise_prince(data)
    local _, _, battle = find_battle(data, PRINCE_BATTLE)
    for _, fight in ipairs(battle.fights) do
        for position, row in ipairs(fight.warriors) do
            if row.template == PRINCE then
                local perks, replaced = {}, false
                for index, perk in ipairs(row.perks or {}) do
                    assert(perk.perk ~= ASSISTANTS, "The Prince already has Call to Arms")
                    if perk.perk == TELEPORTATION then
                        perks[index] = { perk = ASSISTANTS }
                        replaced = true
                    else
                        perks[index] = perk
                    end
                end
                assert(replaced, "The Prince is expected to have Teleportation")
                local revised = copy(row)
                revised.perks = perks
                fight.warriors[position] = revised
            end
        end
    end
end

local applied = false
local function apply(data)
    if applied then return data end
    applied = true
    scrap(data)
    revise_prince(data)
    return data
end

return { apply = apply }
