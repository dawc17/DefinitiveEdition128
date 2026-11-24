local sf2 = require("sf2")
local words = require("content.text")

-- Complex Recipes I and II hold the fifteen mythical (set) enchantments in the order their sets'
-- chests unlock (Seby, 2026-11-24; content.set_chests), seven in I and eight in II. Complex
-- Recipe I is the core Complex recipe: it keeps its first five set enchantments and Plot Twist,
-- lists DE128's Stone Fetters just before Plot Twist, and gives the other six to Complex Recipe
-- II. Complex Recipe III is retired the way Special Recipe III was: it is no longer registered,
-- and pieces forged with it keep their enchantments, which are the same perks. Every added
-- recipe prices with the core Complex table, as the DE forge.xml did; content.forge_choice
-- scales it per candidate (mythicals 2x, boss abilities 1.5x) and per strength tier.
-- Special Recipes I and II (Abilities, Abilities2) grant the boss-ability enchantments from
-- content.boss_abilities.
local equipment = {
    "weapon", "armor", "helm",
    "ranged", "magic",
}
local complex = sf2.forge.get("Complex")
local simple = sf2.forge.get("Simple")

-- DE128's own mythicals (kind = "combo" scripted perks), by the keys the pools below use.
local mythicals = {
    stone_fetters = require("content.stone_fetters"),
    searing_luminary = require("content.searing_luminary"),
    revival_heal = require("content.revival_heal"),
}
local function perk(name)
    return mythicals[name] or sf2.perks.get("core:perks/" .. name)
end

-- Complex Recipe I: Tempest Rage, Typhoon of Spirits, Crimson Corruption, Icy Resistance and
-- Karma stay core Complex's own candidates; Stone Fetters is listed before Plot Twist.
local before_plot_twist = sf2.perks.get("core:perks/PERK_DIRECTOR_SET_PLOT_TWIST")
for _, category in ipairs(equipment) do
    sf2.forge.patch {
        profile = complex, perk = mythicals.stone_fetters, equipment = category,
        include = { before = before_plot_twist },
    }
end

-- Complex Recipe II, in order: Predator's Fury, Arcane Martial Art, Revival Heal, Cordyceps,
-- Searing Luminary, Roaring Luminary, Time Shift, Squall. A mod recipe lists its candidates
-- in the order given; its core ones leave core Complex.
local complex_2 = {
    "PERK_KARCER_HUNGER_SET", "PERK_ARCANE_MARTIAL_ART_SET_NEO_WANDERER", "revival_heal",
    "PERK_CORDYCEPS_FUNGUS_SET", "searing_luminary", "PERK_MAGMA_VOLCANO_SET",
    "PERK_TIME_SHIFT_SET_TIME_SHIFTER", "PERK_GUST_SET_WIND_MAKER",
}

-- Handles of the recipes registered here, for content.forge_choice.
local registered = {}

do
    local items, candidates = {}, {}
    for _, category in ipairs(equipment) do
        items[#items + 1] = { equipment = category, enchantments = 1, bar_scale = "Enchantment" }
        for _, name in ipairs(complex_2) do
            if not mythicals[name] then
                sf2.forge.patch { profile = complex, perk = perk(name), equipment = category, exclude = true }
            end
            candidates[#candidates + 1] = { perk = perk(name), equipment = category }
        end
    end
    registered.complex_2 = sf2.forge.register {
        id = "complex_2", alias = words.key("forgeRecipeComplex2"),
        profile = complex, items = items, candidates = candidates,
    }
end

-- Special Recipes: one enchantment per category, BarScale "Enchantment", no
-- deviation, no variation conditions. Special Recipe I holds the demon abilities in
-- story order; Special Recipe II the Underworld boss abilities in the tier order of
-- their bosses (Arkhos, War, Gatekeeper, Dandy); Fear Ray and Grasp of Darkness are magic
-- items instead (Seby, 2026-11-23), so neither is offered here. The archive's
-- Special Recipe III is folded into II; items forged with it keep their enchantments,
-- which are the same perks.
local abilities = require("content.boss_abilities").perks
local special_recipes = {
    { id = "abilities_1", text = "forgeRecipeAbilities", perks = {
        "shadow_cloak", "hermit_storm", "earthquake", "wasp_fly", "teleportation", "assistants",
    } },
    -- lightning_chain is DE128's own Lightning Chain special (content.lightning_chain) under
    -- the old enchantment's ID, so forged and saved Lightning Chain pieces carry the new special.
    { id = "abilities_2", text = "forgeRecipeAbilities2", perks = {
        "rat_wave", "war_whirl", "power_field", "lightning_chain",
    } },
}
for _, recipe in ipairs(special_recipes) do
    local items, candidates = {}, {}
    for _, category in ipairs(equipment) do
        items[#items + 1] = { equipment = category, enchantments = 1, bar_scale = "Enchantment" }
        for _, key in ipairs(recipe.perks) do
            candidates[#candidates + 1] = { perk = abilities[key], equipment = category }
        end
    end
    registered[recipe.id] = sf2.forge.register {
        id = recipe.id, alias = words.key(recipe.text),
        profile = complex, items = items, candidates = candidates,
    }
end

-- Simple changes only its random-aspect deviation; base prices and base aspect
-- scale remain owned by Eclipse.
for _, category in ipairs(equipment) do
    sf2.forge.patch {
        profile = simple, equipment = category, deviation = { minimum = 15, maximum = 75 },
    }
end

return {
    -- Handles of the recipes registered here.
    recipes = registered,
    -- Each Complex recipe's mythicals in their order (core perk names or DE128 keys), and the
    -- perk handle for such a name, for content.forge_choice's prices.
    mythicals = {
        Complex = {
            "PERK_MONK_SET_WHIRL", "PERK_SENTINEL_SET_SUPER_RETURN", "PERK_WARLOCK_SET_CURSE",
            "PERK_GUARDIAN_SET_PROTECTION", "PERK_SKANDA_SET_KARMA", "stone_fetters", "PERK_DIRECTOR_SET_PLOT_TWIST",
        },
        complex_2 = complex_2,
    },
    perk = perk,
}
