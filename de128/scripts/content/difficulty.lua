local sf2 = require("sf2")

-- Four difficulties, chosen per save on the title screen. Medium is DE128 as it plays
-- without this file. The dojo's Difficulty button changes or locks it later.
local OPTION = "difficulty"

local CHOICES = {
    { id = "easy", title = "Easy", subtitle = "Give Me Grace",
      description = "200-second rounds, weaker foes, cheaper shop and upgrades." },
    { id = "medium", title = "Medium", subtitle = "Give Me Balance",
      description = "Definitive Edition as designed." },
    { id = "hard", title = "Hard", subtitle = "Give Me a Challenge",
      description = "99-second rounds; stronger, smarter, enchanted foes; fewer Survival coins." },
    { id = "very_hard", title = "Very Hard", subtitle = "Give Me Shadow Fight",
      description = "Hard, with far smarter foes, more enchantments and dearer shop prices." },
}

sf2.saves.option {
    id = OPTION,
    title = "Choose your difficulty",
    description = "Change it any time from the dojo's Difficulty button, or lock it for good.",
    default = "medium",
    lockable = true,
    choices = CHOICES,
}

-- Upgrades cost coins only, on every difficulty.
sf2.game.economy { upgrade_gems = 0 }
sf2.game.economy { option = OPTION, choice = "easy", shop_coins = 0.85, shop_gems = 0.85, upgrade_coins = 0.7 }
sf2.game.economy { option = OPTION, choice = "hard", reward_coins = { survival = 0.9 } }
sf2.game.economy { option = OPTION, choice = "very_hard", shop_coins = 1.1, shop_gems = 1.1,
    reward_coins = { survival = 0.9 } }

-- The Standard AI most opponents use starts every fight with no dodge, counter, block or
-- attack-sequence chance and only learns them from the player's repeated moves. The
-- multipliers make that learning faster; the additions give a chance from the first exchange.
-- Sensei, the game's hardest AI, has every chance at 1.
local HARD_AI = {
    counter_attack = 1.25, dodge = 1.25, block = 1.25, evade = 1.25, dodge_missiles = 1.25, dodge_magic = 1.25,
    table_attack = 1.3, quick_attack = 1.3, response_delay = 0.8, distance_error = 0.75, frame_error = 0.75,
    chance_cap = 0.75,
}
local HARD_AI_ADD = {
    counter_attack = 0.15, dodge = 0.15, block = 0.2, evade = 0.1, dodge_missiles = 0.15, dodge_magic = 0.1,
    table_attack = 0.2, safe_attack = 0.1, quick_attack = 0.1,
}
local VERY_HARD_AI = {
    counter_attack = 1.5, dodge = 1.5, block = 1.5, evade = 1.5, dodge_missiles = 1.5, dodge_magic = 1.5,
    table_attack = 1.6, quick_attack = 1.6, response_delay = 0.6, distance_error = 0.5, frame_error = 0.5,
    chance_cap = 0.9,
}
local VERY_HARD_AI_ADD = {
    counter_attack = 0.35, dodge = 0.35, block = 0.4, evade = 0.25, dodge_missiles = 0.35, dodge_magic = 0.3,
    table_attack = 0.45, safe_attack = 0.2, quick_attack = 0.2,
}

-- Difficulty-bar bands: Easy below 0.82, Normal from 0.82, Hard from 1.3, Insane from 2.6,
-- Impossible from 5.2. strength moves a fight about one band per x2. minimum_ratio is the
-- band gear cannot push a fight below: Normal on Hard, Hard on Very Hard.
-- arrow is the tint of the player's ground arrow: green, orange or red (Medium keeps the native one).
local TIERS = {
    easy = { round_time = 200, strength = 0.5, arrow = "#40FF40" },
    hard = { round_time = 99, strength = 2, minimum_ratio = 0.85,
        ai = HARD_AI, ai_add = HARD_AI_ADD, enchantments = "hard", arrow = "#FF9A3C" },
    very_hard = { round_time = 99, strength = 2, minimum_ratio = 1.35,
        ai = VERY_HARD_AI, ai_add = VERY_HARD_AI_ADD, enchantments = "very_hard", arrow = "#FF3030" },
}

-- Fight kinds left as they are. The Underworld is excluded separately.
local UNCHANGED = { tutorial = true, raid = true, other = true }

-- Enchantments each slot can hold, by type. One enemy never gets the same type twice.
local POOLS = {
    weapon = { "bleeding", "bloodrage", "enfeeble", "frenzy", "intoxication", "lifesteal",
        "magic_damage_recharge", "overheat", "precision", "stun", "time_bomb", "weakness" },
    ranged = { "bleeding", "bloodrage", "enfeeble", "frenzy", "intoxication", "lifesteal",
        "overheat", "precision", "stun", "time_bomb", "weakness" },
    magic = { "bleeding", "bloodrage", "enfeeble", "frenzy", "intoxication", "lifesteal",
        "overheat", "stun", "time_bomb", "weakness" },
    armor = { "damage_absorption_body", "damage_return", "frenzy_defense", "magic_pain_recharge",
        "overheat_defense", "regeneration", "rejuvenation", "shielding" },
    helm = { "critical_protection", "damage_absorption_head", "damage_return", "frenzy_defense",
        "magic_pain_recharge", "overheat_defense", "regeneration", "rejuvenation", "shielding" },
}
local SLOT_ORDER = { "weapon", "ranged", "magic", "armor", "helm" }
local HEALING = { lifesteal = true, regeneration = true, rejuvenation = true }
local ENCHANTMENT_PREFIX = "core:perks/perk_item_special_"

local PERKS = {}
for slot, types in pairs(POOLS) do
    PERKS[slot] = {}
    for _, kind in ipairs(types) do
        PERKS[slot][kind] = sf2.perks.get(ENCHANTMENT_PREFIX .. kind .. "_" .. slot)
    end
end

local function enchanted(enemy)
    for _, perk in ipairs(enemy.perks) do
        if perk:sub(1, #ENCHANTMENT_PREFIX) == ENCHANTMENT_PREFIX then return true end
    end
    return false
end

-- Very Hard keeps 2-3 picks and Hard 1-2, both from the front of one ordered roll, so a
-- difficulty change only adds or removes enchantments. No pick pairs healing with Damage Return.
-- The same save, fight and opponent always roll the same enchantments.
local function roll(seed, fight_id, enemy, tier)
    local stream = sf2.random.stream(seed, fight_id, enemy.index)
    local function next_value(count) return stream:integer(1, count) end
    -- Both counts are drawn every time so both difficulties read the same sequence.
    local hard_count, very_hard_count = next_value(2), 1 + next_value(2)
    local count = tier == "very_hard" and very_hard_count or hard_count
    local slots = {}
    for _, slot in ipairs(SLOT_ORDER) do
        for _, owned in ipairs(enemy.slots) do
            if owned == slot then slots[#slots + 1] = slot end
        end
    end
    for i = #slots, 2, -1 do
        local j = next_value(i)
        slots[i], slots[j] = slots[j], slots[i]
    end
    local used, healing, damage_return, perks = {}, false, false, {}
    for _, slot in ipairs(slots) do
        if #perks >= count then break end
        -- Earlier picks never depend on count, so Hard's picks are the front of Very Hard's.
        local options = {}
        for _, kind in ipairs(POOLS[slot]) do
            local blocked = used[kind] or (HEALING[kind] and damage_return) or (kind == "damage_return" and healing)
            if not blocked then options[#options + 1] = kind end
        end
        if #options > 0 then
            local kind = options[next_value(#options)]
            used[kind] = true
            healing = healing or HEALING[kind] == true
            damage_return = damage_return or kind == "damage_return"
            perks[#perks + 1] = PERKS[slot][kind]
        end
    end
    return perks
end

sf2.battles.on_prepare(function(fight)
    local tier = TIERS[sf2.saves.get(OPTION)]
    if tier == nil then return nil end
    -- The arrow shows the save's difficulty in every fight, the dojo's sparring included;
    -- the fights the difficulty leaves alone get only the arrow.
    if fight.mode == "dojo" or fight.underworld or UNCHANGED[fight.mode] then
        return { arrow_color = tier.arrow }
    end
    if fight.preview then return { strength = tier.strength, minimum_ratio = tier.minimum_ratio } end
    local plan = { round_time = tier.round_time, strength = tier.strength, minimum_ratio = tier.minimum_ratio,
        ai = tier.ai, ai_add = tier.ai_add, arrow_color = tier.arrow }
    if tier.enchantments then
        local seed, enemies = sf2.saves.seed(), {}
        for _, enemy in ipairs(fight.enemies) do
            if not enchanted(enemy) then
                local perks = roll(seed, fight.id, enemy, tier.enchantments)
                if #perks > 0 then enemies[enemy.index] = { perks = perks } end
            end
        end
        plan.enemies = enemies
    end
    return plan
end)

-- The dojo's Difficulty button opens Eclipse's difficulty screen (the same one a new save
-- shows) to change the difficulty or lock it for this save.
local BUTTON = sf2.ui.dojo_button { id = "difficulty",
    image = sf2.assets.sprite("sprites/difficulty/button"),
    pressed_image = sf2.assets.sprite("sprites/difficulty/button_pressed") }

sf2.story.on("dojo_button", function(event)
    if event.button == BUTTON then sf2.saves.show(OPTION) end
end)

-- A save the title screen could not ask (it opened before the mod's options were known)
-- is asked once on the map.
sf2.story.on("scene_enter", function(event)
    if event.scene == "map" and not sf2.saves.is_chosen(OPTION) then sf2.saves.show(OPTION) end
end)
