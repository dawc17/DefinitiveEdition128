local sf2 = require("sf2")
local words = require("content.text")

-- Deterministic forge: every recipe DE128 ships or uses lets the player pick the
-- exact enchantment and a strength tier instead of rolling one (selection
-- "choose"). Tier strength is the fraction of the item level's full enchantment
-- power (the aspect list.xml gives an item of that level): High is all of it,
-- Mid two thirds, Low one third. The price scale multiplies the recipe's level
-- price row. Eclipse owns the mechanism (sf2.forge.patch with selection / perk); this module is
-- only DE128's policy. Design: Docs/Engineering/Modding/DETERMINISTIC_FORGE_PLAN.md.
--
-- Candidate price scales: normal enchantments 1x (the default, so unconfigured),
-- boss abilities 1.5x, mythical set enchantments 2x. Mythical sets need no code
-- here: Eclipse offers a set enchantment once every piece of its set is owned (DE128's own
-- mythicals have their sets in content.set_chests). Boss abilities unlock after any win
-- against that ability's boss.
assert(type(sf2.forge.patch) == "function", "DE128 requires the public sf2.forge.patch API.")
local forge = require("content.forge")
local registered = forge.recipes

local tiers = {
    { id = "low", name = words.get("de128.forge_tier.low"), strength = 1 / 3, price = 0.5 },
    { id = "mid", name = words.get("de128.forge_tier.mid"), strength = 2 / 3, price = 1.0 },
    { id = "high", name = words.get("de128.forge_tier.high"), strength = 1.0, price = 2.0 },
}

-- Core recipes (vanillaXml/forge.xml Simple, Medium, Complex) are patched by
-- name; DE128's own recipes by the handles content.forge registered.
local recipes = {
    "Simple", "Medium", "Complex",
    registered.complex_2,
    registered.abilities_1, registered.abilities_2,
}
for _, recipe in ipairs(recipes) do
    sf2.forge.patch { recipe = recipe, selection = "choose", tiers = tiers }
end

-- The fifteen mythical (set) enchantments: the twelve ItemSet DefaultComboPerk ones
-- (vanillaXml/list.xml) and DE128's Stone Fetters, Searing Luminary and Revival Heal, in
-- Complex Recipes I (core Complex) and II (content.forge).
for recipe, names in pairs({ Complex = forge.mythicals.Complex, [registered.complex_2] = forge.mythicals.complex_2 }) do
    for _, name in ipairs(names) do
        sf2.forge.patch { recipe = recipe, perk = forge.perk(name), price = 2.0 }
    end
end

-- Boss abilities. Each unlocks after a win against any warrior that IS its
-- boss. The mapping follows the archived perk aliases (DExml/perks.xml:
-- LynxAbil_invisibility, HermitAbil_storm, ButcherAbil_earthquake,
-- WaspAbil_flight, HuntressAbil_teleportation, ShogunAbil_calltoarms, RatAbil,
-- WarAbil, FearAbil, PowerFieldAbil, BlacknessHugAbility, LightningAbil,
-- TitanShield) and the warriors that carry the matching core boss perk.
-- The Sensei opponents are inline opponent tables that keep their archive-era warrior IDs.
local function warrior_id(opponent) return sf2.mod.id .. ":warriors/" .. opponent.id end
local function both(pair) return { warrior_id(pair.normal), warrior_id(pair.eclipse) } end
local function join(...)
    local result = {}
    for _, list in ipairs({ ... }) do
        for _, warrior in ipairs(list) do result[#result + 1] = warrior end
    end
    return result
end

local function install(underworld)
    local sensei = require("content.sensei_boss_opponents")
    local by_template = underworld.warriors_by_template
    local function young(name) return (assert(by_template[name], "Missing Underworld boss " .. name)) end
    -- Core story bosses are anonymous stage warriors; Eclipse records their wins (and
    -- reads completed story fights retroactively) under the core warrior template.
    local function story(template) return { "core:warrior-templates/" .. template } end

    -- Core story bosses (vanillaXml stages.xml templates), Sensei's Story acts I Lynx,
    -- II Hermit, III Butcher, IV Wasp, V Widow, VI Shogun, and the Underworld raid bosses
    -- that are the ability's namesake. (The young demons fought only in the scrapped Gauntlet.)
    local bosses = {
        shadow_cloak = join(story("lynx_claws"), both(sensei[1])),
        hermit_storm = join(story("hermit_swords"), both(sensei[2])),
        earthquake = join(story("butcher_backswords"), both(sensei[3])),
        wasp_fly = join(story("wasp_naginata"), both(sensei[4])),
        teleportation = join(story("huntress_fan"), both(sensei[5])),
        assistants = join(story("shogun_katana"), both(sensei[6])),
        rat_wave = young("Man_Arkhos"),
        war_whirl = young("Girl_Drakaina"),
        power_field = young("Cyborg_Gatekeeper"),
        lightning_chain = young("Man_Dandy"),
    }

    local abilities = require("content.boss_abilities").perks
    local recipe_perks = {
        abilities_1 = { "shadow_cloak", "hermit_storm", "earthquake", "wasp_fly", "teleportation", "assistants" },
        abilities_2 = { "rat_wave", "war_whirl", "power_field", "lightning_chain" },
    }
    for id, keys in pairs(recipe_perks) do
        for _, key in ipairs(keys) do
            local warriors = bosses[key]
            sf2.forge.patch {
                recipe = registered[id], perk = abilities[key], price = 1.5,
                unlock = warriors and { defeated = warriors } or nil,
            }
        end
    end

    -- Hex Shield is a Medium enchantment now (content.hex_shield), offered after the first win against Titan.
    sf2.forge.patch { recipe = "Medium", perk = require("content.hex_shield"), unlock = { defeated = story("man_z7_titan") } }
end

return { install = install }
