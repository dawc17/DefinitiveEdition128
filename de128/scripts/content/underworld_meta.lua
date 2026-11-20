local sf2 = require("sf2")
local words = require("content.text")
local elixirs = require("content.underworld_elixirs")

-- The sealed Underworld bosses' meta-game (content.underworld_seals runs it):
--   Seal Shards  one per seal broken, in the seal's colour, win or lose; brewed into elixirs on
--                the challenge screen (an elixir slot pressed).
--   Omens        one per win against a sealed boss; spent on the challenge screen to reroll one
--                seal or pact (its row pressed).
--   Seal Codex   per boss, the seal rules the player has broken him under; all of them turn his
--                hanko gold.
--   Pacts        chosen on the challenge screen (levels 0-3); the best level beaten is kept per boss.
-- Shards and Omens are stackable consumables, so they live in the inventory. The codex and best
-- pact share one saved string, uw_meta (content.sensei_state), as ",<boss key>=<codex>:<pact>,"
-- entries: <codex> is CODEX's bits, four to a hex digit, first rule lowest.
-- Words: de128.uw_meta.* in Eclipse's English text. Numbers are first guesses.

local FIELD = "uw_meta"
local SHARD_STACK, OMEN_STACK = 99, 20

-- The colours of the seal art (content.underworld_seals' rules), in the order the screens show
-- them, with the ink each is drawn in on the challenge screen's tally strip.
local ARTS = { "orange", "red", "jade", "green", "blue", "purple" }
local INK = { orange = "#D9822B", red = "#B8342A", jade = "#3F8F7C", green = "#6AA339", blue = "#3D73B8", purple = "#7D4BB0" }

-- Pictures (assets/textures/underworld_meta, cut from the game's seal art with ImageMagick):
-- shard_<art> a jagged piece of the seal, codex_<art> the seal with its cracks, pact a red hanko.
local pictures = { shard = {}, codex = {}, pact = sf2.assets.sprite("sprites/underworld_meta/pact"),
    omen = sf2.assets.sprite("sprites/underworld_meta/omen"),
    momentum = sf2.assets.sprite("sprites/underworld_seals/red_broken") }
for _, art in ipairs(ARTS) do
    pictures.shard[art] = sf2.assets.sprite("sprites/underworld_meta/shard_" .. art)
    pictures.codex[art] = sf2.assets.sprite("sprites/underworld_meta/codex_" .. art)
end

local shards = {}
for _, art in ipairs(ARTS) do
    local key = "de128.uw_meta.shard." .. art
    shards[art] = sf2.items.register {
        category = "consumable", id = "seal_shard_" .. art,
        display_name = words.own("item.seal_shard_" .. art, key .. ".name"),
        description = words.own("item.seal_shard_" .. art .. ".description", key .. ".description"),
        icon = pictures.shard[art], stack = SHARD_STACK,
    }
end

-- The game's dark raid orb (RaidItems1.sphere2) in assets/textures/underworld_meta.
local omen = sf2.items.register {
    category = "consumable", id = "omen",
    display_name = words.own("item.omen", "de128.uw_meta.omen.name"),
    description = words.own("item.omen.description", "de128.uw_meta.omen.description"),
    icon = pictures.omen, stack = OMEN_STACK,
}

-- Shards per elixir, in the order the challenge screen draws them under the elixir.
local RECIPES_ORDER = { "jade", "orange", "red", "green", "blue", "purple" }
local RECIPES = {
    healing_elixir = { jade = 2, green = 1 },
    iron_skin_elixir = { orange = 2, green = 1 },
    fury_elixir = { red = 3 },
    clear_mind_elixir = { blue = 2, purple = 2 },
}

-- Every seal rule in its codex place. Append only: a rule's place is its bit in saves.
local CODEX = {
    "bare_hands", "breathless", "burning", "darkness", "desperation", "draining_ground", "earthquake",
    "fragile_ground", "gale", "glass_cannon", "hard_ground", "hidden_health", "hot_ground", "inverted",
    "kicks_only", "measured_strikes", "mix_it_up", "moonless", "mounting_wrath", "no_blocks", "no_double",
    "no_jumps", "no_kicks", "overcharge", "patience", "relentless", "slow_hands", "thorny_walls",
    "tricksters_hex", "undertow", "unflinching", "vanishing", "vengeance", "withering",
}
local PLACE = {}
for index, name in ipairs(CODEX) do PLACE[name] = index end
local DIGITS = math.ceil(#CODEX / 4)

-- Saved codex and best pact ----------------------------------------------------------------------

local function entry(key)
    local codex, pact = (sf2.state.get(FIELD) or ","):match("," .. key .. "=(%x+):(%d),")
    return codex or string.rep("0", DIGITS), tonumber(pact) or 0
end

-- The set of rule names in a saved codex.
local function decode(hex)
    local set = {}
    for digit = 1, #hex do
        local value = tonumber(hex:sub(digit, digit), 16) or 0
        for bit = 0, 3 do
            local place = (digit - 1) * 4 + bit + 1
            if value % 2 == 1 and CODEX[place] then set[CODEX[place]] = true end
            value = math.floor(value / 2)
        end
    end
    return set
end

local function encode(set)
    local digits = {}
    for digit = 1, DIGITS do
        local value = 0
        for bit = 3, 0, -1 do
            local name = CODEX[(digit - 1) * 4 + bit + 1]
            value = value * 2 + ((name and set[name]) and 1 or 0)
        end
        digits[digit] = string.format("%x", value)
    end
    return table.concat(digits)
end

local function save(key, set, pact)
    local value = (sf2.state.get(FIELD) or ","):gsub("," .. key .. "=%x+:%d,", ",")
    sf2.state.set { [FIELD] = value .. key .. "=" .. encode(set) .. ":" .. pact .. "," }
end

local M = { shards = shards, arts = ARTS, ink = INK, pictures = pictures, omen = omen, codex_size = #CODEX, codex_order = CODEX }

function M.codex(key) return decode((entry(key))) end
function M.in_codex(name) return PLACE[name] ~= nil end

function M.codex_count(set)
    local count = 0
    for name in pairs(set) do if PLACE[name] then count = count + 1 end end
    return count
end

function M.best_pact(key)
    local _, pact = entry(key)
    return pact
end

-- After a fight: the rules broken join the codex; a win at a higher pact raises the best one.
-- Returns how many rules were new.
function M.record(key, broken, pact_won)
    local hex, best = entry(key)
    local set = decode(hex)
    local new = 0
    for _, name in ipairs(broken) do
        assert(PLACE[name], "Seal rule " .. tostring(name) .. " has no codex place")
        if not set[name] then
            set[name] = true
            new = new + 1
        end
    end
    local pact = math.max(best, pact_won or 0)
    if new > 0 or pact ~= best then save(key, set, pact) end
    return new
end

-- Shards and Omens -------------------------------------------------------------------------------

function M.shard_counts()
    local counts = {}
    for _, art in ipairs(ARTS) do counts[#counts + 1] = sf2.profile.item_count(shards[art]) end
    return counts
end

-- Gives up to `count` of an item; returns how many fit.
local function give(item, count)
    local before = sf2.profile.item_count(item)
    if count <= 0 or not sf2.profile.give_item(item, count) then return 0 end
    return sf2.profile.item_count(item) - before
end

-- A fight's spoils: a shard per broken seal (its colour), and an Omen on a win. Returns the
-- results screen's `items` rows.
function M.spoils(arts, won)
    local per = {}
    for _, art in ipairs(arts) do per[art] = (per[art] or 0) + 1 end
    local rows = {}
    for _, art in ipairs(ARTS) do
        local given = give(shards[art], per[art] or 0)
        if given > 0 then rows[#rows + 1] = { item = shards[art], count = given } end
    end
    if won and give(omen, 1) > 0 then rows[#rows + 1] = { item = omen, count = 1 } end
    return rows
end

function M.omens() return sf2.profile.item_count(omen) end
function M.spend_omen() return sf2.profile.take_item(omen, 1) end

-- An elixir's cost as challenge-screen pictures: one shard each, lit while the player holds it.
function M.cost(elixir)
    local recipe = assert(RECIPES[elixir.id], "No recipe for " .. elixir.id)
    local cost = {}
    for _, art in ipairs(RECIPES_ORDER) do
        local held = sf2.profile.item_count(shards[art])
        for piece = 1, recipe[art] or 0 do
            cost[#cost + 1] = { icon = pictures.shard[art], lit = piece <= held }
        end
    end
    return cost
end

-- Brews one elixir from shards: "brewed", "short" (not enough shards) or "full" (no room).
function M.brew(elixir)
    local recipe = assert(RECIPES[elixir.id], "No recipe for " .. elixir.id)
    for art, count in pairs(recipe) do
        if sf2.profile.item_count(shards[art]) < count then return "short" end
    end
    if sf2.profile.item_count(elixir.item) >= elixirs.stack then return "full" end
    for art, count in pairs(recipe) do
        if not sf2.profile.take_item(shards[art], count) then return "short" end
    end
    sf2.profile.give_item(elixir.item, 1)
    return "brewed"
end

return M
