local sf2 = require("sf2")
local words = require("content.text")

-- Historical forge.xml splits the twelve existing Complex candidates into
-- three equal pools. The two new pools use the unchanged core Complex prices.
-- Special Recipes I and II (Abilities, Abilities2) grant the boss-ability
-- enchantments from content.boss_abilities. Like the current DE forge.xml, every
-- added recipe prices with the core Complex table; content.forge_choice scales it
-- per candidate (boss abilities 1.5x) and per strength tier.
local equipment = {
    "weapon", "armor", "helm",
    "ranged", "magic",
}
local complex = sf2.forge.get("Complex")
local simple = sf2.forge.get("Simple")
local pools = {
    { id = "complex_2", text = "forgeRecipeComplex2", perks = {
        "PERK_SKANDA_SET_KARMA", "PERK_GUST_SET_WIND_MAKER",
        "PERK_DIRECTOR_SET_PLOT_TWIST", "PERK_TIME_SHIFT_SET_TIME_SHIFTER",
    }, scripted = { "searing_luminary" } },
    { id = "complex_3", text = "forgeRecipeComplex3", perks = {
        "PERK_ARCANE_MARTIAL_ART_SET_NEO_WANDERER", "PERK_CORDYCEPS_FUNGUS_SET",
        "PERK_MAGMA_VOLCANO_SET", "PERK_KARCER_HUNGER_SET",
    }, scripted = { "stone_fetters" } },
}

-- DE128's own mythicals (kind = "combo" scripted perks) join the pool beside the core ones.
local mythicals = {
    searing_luminary = require("content.searing_luminary"),
    stone_fetters = require("content.stone_fetters"),
}

-- Handles of the recipes registered here, for content.forge_choice.
local registered = {}

for _, pool in ipairs(pools) do
    local items, candidates = {}, {}
    for _, category in ipairs(equipment) do
        items[#items + 1] = { equipment = category, enchantments = 1, bar_scale = "Enchantment" }
        for _, name in ipairs(pool.perks) do
            local perk = sf2.perks.get("core:perks/" .. name)
            sf2.forge.patch { profile = complex, perk = perk, equipment = category, exclude = true }
            candidates[#candidates + 1] = { perk = perk, equipment = category }
        end
        for _, key in ipairs(pool.scripted or {}) do
            candidates[#candidates + 1] = { perk = mythicals[key], equipment = category }
        end
    end
    registered[pool.id] = sf2.forge.register {
        id = pool.id, alias = words.key(pool.text),
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

return registered
