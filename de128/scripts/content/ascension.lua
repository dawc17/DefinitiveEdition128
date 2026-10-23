-- Ascension prototype disabled by the owner on 2026-09-18.
--[==[
local sf2 = require("sf2")
local trial = require("content.ascension_rules")

local function label(id, value)
    sf2.text.register { id = id, language = "eng", value = value }
    return "de128:localization/" .. id
end

local title = label("ascension.title", "Ascension Trials")
label("zones/ascension", "Ascension Trials")
local overview = label("ascension.description",
    "Win five trials without losing. Each trial has a different opponent and challenge. " ..
    "Combat preview: no entry fee or reward lottery yet.")
local completed = label("ascension.completed", "You completed all five Ascension trials. A new run is ready.")
local defeated = label("ascension.defeated", "Your Ascension run has ended. The next attempt starts at trial one.")

sf2.state.register {
    version = 1,
    fields = {
        ascension_rng = 128731,
        ascension_foes = "",
        ascension_trials = "",
        ascension_buffs = "",
        ascension_ranged = "",
    },
}

local templates = {
    "ascension_2_ninja_man_crescent_knives", "ascension_2_ninja_man_tonfa",
    "ascension_2_ninja_man_keris", "ascension_2_ninja_girl_swords", "ascension_2_ninja_man_nunchaku",
}
local ranged_items = {
    sf2.items.get("core:items/ranged/RANGED_SHURIKENS"),
    sf2.items.get("core:items/ranged/RANGED_KUNAI"),
}
local opponents = {}
for i, template in ipairs(templates) do
    opponents[i] = {}
    for j, ranged in ipairs(ranged_items) do
        -- An opponent table, written inline into a fight (and into a mode's prepared plan).
        opponents[i][j] = {
            id = "ascension_opponent_" .. i .. "_" .. j,
            fighter = "core:warrior-templates/" .. template,
            tactic = "Standard", items = { ranged },
            attributes = { WarriorPower = 0, EnchantmentResistance = 1500 },
            attribute_alignments = {
                { factor = 1, shift = 9, priority = 1 },
                { factor = 1, shift = 9, priority = 1 },
            },
        }
    end
end

-- The preview has its own map entry. Story unlocks, ticket costs and the mixed
-- Monk/material lottery need separate public contracts before replacing them.
local zone = sf2.map.register { id = "ascension", art = "Map1.2", start = false }
local descriptions, fight_specs = {}, {}
for step = 1, 5 do
    descriptions[step] = {}
    for index, challenge in ipairs(trial.challenges) do
        descriptions[step][index] = label("ascension.trial." .. step .. "." .. index,
            "Trial " .. step .. "/5: " .. challenge.name .. ". " .. challenge.text)
    end
    -- The fight ID is <battle id>_<name>: ascension_trial_<step>.
    fight_specs[step] = {
        name = "trial_" .. step, power = 0,
        rounds = 1, round_time = 150, replays = 1, location = "core:locations/statue", music = "halls_of_the_dead_heroes",
        description = overview, opponents = { opponents[step][1] },
        rules = trial.base, rewards = { [0] = { items = {} }, [1] = { items = {} } },
    }
end
local battle = sf2.battles.register {
    id = "ascension", page = zone, x = -374, y = 50,
    title = title, description = overview, icon = "ascension",
    preview = "preview_main.statue", location = "core:locations/statue", music = "halls_of_the_dead_heroes",
    fights = fight_specs,
}
local fights = battle.fights

local function shuffle(count)
    local values = {}
    for i = 1, count do values[i] = i end
    for i = count, 2, -1 do
        local j = sf2.random.integer("ascension_rng", 1, i)
        values[i], values[j] = values[j], values[i]
    end
    return values
end

local function read_route(field, count, maximum, distinct)
    local text = sf2.state.get(field)
    assert(type(text) == "string", "Ascension route state is unavailable: " .. field)
    local values, seen = {}, {}
    for entry in string.gmatch(text, "[^,]+") do
        assert(string.match(entry, "^%d+$"), "Invalid saved Ascension route: " .. field)
        local value = tonumber(entry)
        assert(value >= 1 and value <= maximum and (not distinct or not seen[value]),
            "Invalid saved Ascension selection: " .. field)
        values[#values + 1], seen[value] = value, true
    end
    assert(#values == count and table.concat(values, ",") == text,
        "Invalid saved Ascension route length or encoding: " .. field)
    return values
end

sf2.modes.register {
    id = "ascension_trials", fights = fights, repeatable = true, reset_on_loss = true,
    on_prepare = function(_, event)
        if sf2.state.get("ascension_foes") == "" then
            assert(event.step == 1, "Ascension route is missing for an unfinished run.")
            local foes, challenges = shuffle(5), shuffle(6)
            local buffs, ranged = {}, {}
            for step = 1, 5 do
                buffs[step] = sf2.random.integer("ascension_rng", 1, #trial.buffs)
                ranged[step] = sf2.random.integer("ascension_rng", 1, #ranged_items)
            end
            sf2.state.set {
                ascension_foes = table.concat(foes, ","),
                ascension_trials = table.concat(challenges, ","),
                ascension_buffs = table.concat(buffs, ","),
                ascension_ranged = table.concat(ranged, ","),
            }
        end
        local foes = read_route("ascension_foes", 5, 5, true)
        local challenges = read_route("ascension_trials", 6, 6, true)
        local buffs = read_route("ascension_buffs", 5, #trial.buffs, false)
        local ranged = read_route("ascension_ranged", 5, #ranged_items, false)
        local step, rules = event.step, {}
        for _, rule in ipairs(trial.base) do rules[#rules + 1] = rule end
        rules[#rules + 1] = trial.buffs[buffs[step]]
        for _, rule in ipairs(trial.challenges[challenges[step]].rules) do rules[#rules + 1] = rule end
        return {
            warriors = { opponents[foes[step]][ranged[step]] }, rules = rules,
            description = descriptions[step][challenges[step]], rounds = 1, round_time = 150,
        }
    end,
    on_result = function(event)
        if not event.won or event.step == 5 then
            sf2.state.set { ascension_foes = "", ascension_trials = "", ascension_buffs = "", ascension_ranged = "" }
        end
        return nil
    end,
}

sf2.story.on("session", function()
    sf2.map.reveal { battle = battle, locked = false }
end)
sf2.story.on("fight_end", function(event)
    if event.fight == fights[5] and event.result == "Win" then
        sf2.story.play_sequence { title = title, image = "character_puppeteer", lines = { completed } }
    end
end)
local ours = {}
for _, fight in ipairs(fights) do
    ours[fight] = true
end
sf2.story.on("fight_end", function(event)
    if ours[event.fight] and event.result ~= "Win" then
        sf2.story.play_sequence { title = title, image = "character_puppeteer", lines = { defeated } }
    end
end)

return { fights = fights, battle = battle }
]==]
return {}
