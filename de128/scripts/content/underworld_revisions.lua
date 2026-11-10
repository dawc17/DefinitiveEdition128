-- DE128's own changes to the generated Underworld rows. content.underworld_data is regenerated
-- from the reviewed archive, so later design changes live here and are applied, once, before
-- content.underworld registers anything.

-- Gauntlet (Survival_DEMON): every boss has the core shock protection (archive form:
-- <Perk Name="PERK_ANTI_SHOCK" ApplyTo="Bot" />). A 15% WarriorPower rise made them one-shot
-- the player (owner playtest 2026-11-10), so their power stays as archived.
local GAUNTLET = "Survival_DEMON"
-- In Power Mode the gauntlet fields the regular demons (the story bosses' core templates,
-- with the same equipment) instead of DE's young ones. Their DE128 tactics are the young
-- ones' (`tactic_of`). The Power Mode twin is otherwise the same fight.
local REGULAR_DEMONS = {
    Boss_Lynx_Young = "core:Lynx_Claws",
    Boss_Hermit_Young = "core:Hermit_Swords",
    Boss_Butcher_Young = "core:Butcher_Backswords",
    Boss_Wasp_Young = "core:Wasp_Naginata",
    Boss_Widow_Young = "core:Huntress_Fan",
    Boss_Shogun_Young = "core:Shogun_Katana",
}
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

local function revise_gauntlet(data)
    local zone, index, battle = find_battle(data, GAUNTLET)
    assert(battle.power_mode == nil, "The Gauntlet already has a Power Mode twin")
    assert(#battle.fights == 1, "The Gauntlet is expected to be one fight")
    local fight = battle.fights[1]
    local warriors, regular = {}, {}
    for position, row in ipairs(fight.warriors) do
        local attributes = copy(assert(row.attributes, "Gauntlet boss without attributes"))
        warriors[position] = copy(row)
        regular[position] = copy(warriors[position])
        regular[position].template = assert(REGULAR_DEMONS[row.template],
            "No regular demon for Gauntlet boss " .. tostring(row.template))
        regular[position].tactic_of = row.template
        -- The young templates' raid resistance, which the core templates lack.
        regular[position].attributes = copy(attributes)
        regular[position].attributes.EnchantmentResistance = 100
    end
    local rules = {}
    for position, rule in ipairs(fight.rules) do rules[position] = rule end
    table.insert(rules, #rules, { kind = "perk", perk = "core:perks/PERK_ANTI_SHOCK", target = "opponent" })
    local revised = copy(fight)
    revised.warriors, revised.rules = warriors, rules
    local normal = copy(battle)
    normal.fights, normal.power_mode = { revised }, "normal"
    local power = copy(battle)
    power.name, power.power_mode = GAUNTLET .. "_HARDMODE", "power"
    power.fights = { { name = fight.name, inherit = GAUNTLET, warriors = regular } }
    zone.battles[index] = normal
    table.insert(zone.battles, index + 1, power)
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
    revise_gauntlet(data)
    revise_prince(data)
    return data
end

return { apply = apply }
