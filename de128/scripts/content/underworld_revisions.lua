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
    -- The owner's 2026-11 preview, first drawn for the Sensei story's Act 6. That act now shows
    -- Seby's own picture (2026-11-27, sprites/sensei/act6), so the Prince keeps this one here.
    battle.preview_sprite = "sprites/underworld/preview_prince"
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

-- Seby's 2026-11-24 map layout (his F6 map button file) places every tier 1-4 battle, in
-- stage units (drawn at twice their value); it replaces his 2026-11-21 place for BOSS_7.
-- Boss 4's 126.5 is held at 126, as the story map's half units are. A Power Mode twin keeps
-- its normal battle's place.
local PLACES = {
    -- Tier 1
    BOSS_1 = { x = -80, y = -180 }, BOSS_SON_OF_HEAVEN = { x = -280, y = -230 },
    BOSS_2 = { x = -480, y = -180 }, BOSS_PUPPETEER = { x = -480, y = -15 },
    BOSS_3 = { x = -280, y = -45 }, BOSS_LAMB_VULCAN = { x = -80, y = -15 },
    BOSS_4 = { x = -280, y = 126 },
    -- Tier 2
    BOSS_5 = { x = -150, y = 15 }, BOSS_LAMB_FUNGUS = { x = 80, y = 5 },
    BOSS_WOLF_WIND = { x = -480, y = 90 }, BOSS_6 = { x = -380, y = -70 },
    BOSS_7 = { x = -150, y = -230 },
    -- Tier 3
    BOSS_8 = { x = -290, y = -180 }, BOSS_LAMB_HUNGER = { x = -485, y = -195 },
    BOSS_9 = { x = -40, y = -105 }, BOSS_BANSHEE = { x = 165, y = -125 },
    BOSS_10 = { x = -260, y = 40 }, BOSS_ARCHITECT_1 = { x = -475, y = 80 },
    -- Tier 4
    BOSS_11 = { x = -120, y = 80 }, BOSS_ARCHITECT_2 = { x = -200, y = -200 },
    BOSS_12 = { x = -25, y = -60 }, BOSS_13 = { x = -455, y = 85 },
    BOSS_14 = { x = -265, y = -35 },
}
-- Tiers 5-8 are the dark copies of the tier 1-4 maps (Seby: their places are tier 1-4's), so
-- each of their battles moves with the tier 1-4 battle whose spot it shared (Rakshasa sat 5
-- units below the Wind Wolf). Tier 8 takes its tier 4 places in content.underworld (TIER8_PLACES).
local SHARED_PLACES = {
    -- Tier 5 on tier 1
    BOSS_WHISPER = "BOSS_1", BOSS_SON_OF_THE_SUN = "BOSS_SON_OF_HEAVEN", BOSS_RAVANA = "BOSS_2",
    BOSS_ADANTI = "BOSS_PUPPETEER", BOSS_COUNTESS = "BOSS_3",
    -- Tier 6 on tier 2
    BOSS_MORGANA = "BOSS_5", BOSS_LAMB = "BOSS_LAMB_FUNGUS", BOSS_RAKSHASA = "BOSS_WOLF_WIND",
    BOSS_HALLOWEEN_PUPPETEER = "BOSS_6",
    -- Tier 7 on tier 3
    BOSS_FARADEYA = "BOSS_8", BOSS_BERSTUUK = "BOSS_LAMB_HUNGER", BOSS_DANDY = "BOSS_9",
    BOSS_SHURALE = "BOSS_10",
}

-- Seby's 2026-11 preview for the tier 1 Puppeteer (the hard mode keeps the archive's).
local function revise_puppeteer(data)
    local _, _, battle = find_battle(data, "BOSS_PUPPETEER")
    battle.preview_sprite = "sprites/underworld/preview_puppeteer"
end

local function place_battle(data, name, place)
    for _, battle_name in ipairs({ name, name .. "_HARDMODE" }) do
        local _, _, battle = find_battle(data, battle_name)
        battle.x, battle.y = place.x, place.y
    end
end

local function revise_places(data)
    for name, place in pairs(PLACES) do place_battle(data, name, place) end
    for name, partner in pairs(SHARED_PLACES) do
        place_battle(data, name, assert(PLACES[partner], "No Underworld place for " .. partner))
    end
end

local applied = false
local function apply(data)
    if applied then return data end
    applied = true
    scrap(data)
    revise_prince(data)
    revise_puppeteer(data)
    revise_places(data)
    return data
end

return { apply = apply }
