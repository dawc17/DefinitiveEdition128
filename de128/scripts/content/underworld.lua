local sf2 = require("sf2")
-- DE Underworld: eight tiers of offline boss fights (archive raid_stages_default.xml)
-- registered as Underworld map pages, with Power Mode twins. Data is generated
-- offline by Tools/GenerateDE128Underworld.py; this module only registers it.
local data = require("content.underworld_data")
local text = require("content.underworld_text")
local words = require("content.text")
local wasp_fly = require("content.wasp_fly")
local butcher_earthquake = require("content.butcher_earthquake")
local hermit_storm = require("content.hermit_storm")
local war_whirl = require("content.war_whirl")
local gatekeeper_power_field = require("content.gatekeeper_power_field")
local blackness_grasp = require("content.blackness_grasp")
local saturn_blaster = require("content.saturn_blaster")
local dandy_lightning_chain = require("content.dandy_lightning_chain")
local raid_boss_abilities = require("content.raid_boss_abilities")
local widow_teleportation = require("content.widow_teleportation")
local boss_abilities = require("content.boss_abilities")

-- Event-raid map buttons absent from core art ship as DE128 sprites.
-- Every archived Underworld battle music id is supplied by DE128, including
-- tracks which the base game would otherwise resolve to a substitute.
-- Sources and exact id coverage: Tools/ExtractDE128UnderworldArt.py.
local OWNED_MUSIC = {
    burning_town_old = true, crystal = true, dark_ritual = true, drakaina = true,
    fatum = true, fear = true, fight_halloween2019 = true, fight_halloween2022 = true,
    fight_independence_day = true, fight38_sakura_forest = true, fight43_bihu_india = true,
    flying_rocks = true, fungus = true, halls_of_the_dead_heroes = true,
    holyman7 = true, holyman8 = true, hunger = true, ninja_in_the_night_old = true,
    raid_hw24 = true, raid_newyear18 = true, raids_berstuuk = true, raids_blackness = true,
    raids_freeze = true, raids_gatekeeper = true, raids_hunter = true, raids_saturn = true,
    raids_shurale = true, vortex = true, vulcan = true,
}
local OWNED_BUTTONS = {
    BattleBtnArchitect = true, BattleBtnHalloween = true, BattleBtnLamb = true, BattleBtnNrityu = true,
    BattleBtnPuppeteer = true, BattleBtnRakshasa = true, BattleBtnRavana = true, BattleBtnShurale = true,
    BattleBtnSnowflake = true, BattleBtnWindWolf = true, BattleBtnPrince = true,
}
-- Only these twenty owner portraits are packaged by DE128. The older
-- boss_wind_wolf_new name is already a native core resource.
local OWNED_AVATARS = {
    boss_architect_hummer_new = true, boss_arkhos_hardmode_new = true,
    boss_bison_hard_new = true, boss_crystal_hardmode_new = true,
    boss_fatum_hardmode_new = true, boss_fire_hardmode_new = true,
    boss_hoaxen_hardmode_new = true, boss_hunger_hardmode_new = true,
    boss_lamb_fungus_hard_new = true, boss_lamb_hard_new = true,
    boss_lamb_hunger_hard_new = true, boss_mushroom_hardmode_new = true,
    boss_rakshasa_hardmode_new = true, boss_ravana_hard_new = true,
    boss_saturn_hard_new = true, boss_tenebris_hardmode_new = true,
    boss_vortex_hardmode_new = true, boss_war_hardmode_new = true,
    boss_whisper_hardmode_new = true, new_man_shuang_gou_hardmode_new = true,
}

-- seby's Underworld map art (2026-10-22), one page per tier: tiers 1-4 in daylight and
-- their dark copies 5-8. It replaces the archive's zone files, so tier 8 is now tier 4's
-- island instead of the mountain map, and its four battles take the places of the
-- matching tier 4 buttons. Power Mode twins follow their normal battle.
local MAP_TIERS = 8
local TIER8_PLACES = {
    BOSS_INVISIBLE = "BOSS_11", BOSS_HAUNTED_PRINCE = "BOSS_12",
    Survival_MERCENARY = "BOSS_13", Survival_DEMON = "BOSS_ARCHITECT_2",
}

local function avatar(name)
    if OWNED_AVATARS[name] then
        return sf2.assets.sprite("sprites/underworld/" .. name)
    end
    return name
end

local BATTLE_TYPES = { final = "final", survival = "survival" }

local function lower_id(name) return (name:gsub("[^%w_]", "_")):lower() end

local function install(raid_charge_rule)
    assert(raid_charge_rule, "Underworld fights need the shared RaidCharge conditional rule")
    local items, perks = {}, {}
    local function item(ref) items[ref] = items[ref] or sf2.items.get(ref); return items[ref] end
    local function perk(ref) perks[ref] = perks[ref] or sf2.perks.get(ref); return perks[ref] end
    local function item_list(refs)
        if not refs then return nil end
        local result = {}
        for index, ref in ipairs(refs) do result[index] = item(ref) end
        return result
    end
    local function perk_rows(rows)
        if not rows then return nil end
        local result = {}
        for index, row in ipairs(rows) do
            local frames = row.frames
            -- The reviewed DE perk base is 600; Eclipse's core definition is 300.
            if row.perk == "core:perks/PERK_LIGHTING_CHAIN" and frames == nil then frames = 600 end
            if row.perk == "core:perks/PERK_TELEPORTATION" and frames == nil then frames = 600 end
            result[index] = { perk = perk(row.perk), aspect = row.aspect, chance = row.chance,
                chance_factor = row.chance_factor, frames = frames, parameters = row.parameters }
        end
        return result
    end
    local function saturn_tactic(warrior)
        for _, row in ipairs(warrior.perks or {}) do
            if row.perk == "core:perks/PERK_SUPER_BLASTER" and
                row.parameters and row.parameters.InitialFrames == 300 then
                if row.frames == 660 then return saturn_blaster.tactic end
                if row.frames == 550 then return saturn_blaster.power_tactic end
            end
        end
        error("Saturn's archived Blaster timing is missing or unsupported")
    end
    local function blackness_tactic(warrior)
        for _, row in ipairs(warrior.perks or {}) do
            if row.perk == "core:perks/PERK_GRASP_OF_DARKNESS" then
                if row.frames == 800 then return blackness_grasp.tactic end
                if row.frames == 700 then return blackness_grasp.power_tactic end
            end
        end
        error("Blackness's archived Grasp timing is missing or unsupported")
    end
    local function dandy_tactic(warrior)
        for _, row in ipairs(warrior.perks or {}) do
            if row.perk == "core:perks/PERK_LIGHTING_CHAIN" then
                if row.frames == nil then return dandy_lightning_chain.tactic end
                if row.frames == 500 then return dandy_lightning_chain.power_tactic end
            end
        end
        error("Dandy's archived Lightning Chain timing is missing or unsupported")
    end
    local function hunter_tactic(warrior)
        for _, row in ipairs(warrior.perks or {}) do
            if row.perk == "core:perks/PERK_HUNTERFLY" then
                if row.frames == 900 then return raid_boss_abilities.hunter end
                if row.frames == 800 then return raid_boss_abilities.hunter_power end
            end
        end
        error("Hunter's archived Fly timing is missing or unsupported")
    end
    local function teleport_tactic(warrior)
        for _, row in ipairs(warrior.perks or {}) do
            if row.perk == "core:perks/PERK_TELEPORTATION" then
                local frames = row.frames or 600
                if frames == 600 then return widow_teleportation.normal end
                if frames == 300 then return widow_teleportation.fast end
                if frames == 480 then return widow_teleportation.power end
                if frames == 660 then return widow_teleportation.slow end
                error("Unsupported archived Teleportation timing " .. tostring(frames))
            end
        end
        return nil
    end

    -- Fighters, parents first (the generator orders them).
    local templates = {}
    local function template(ref)
        if ref:sub(1, 5) == "core:" then
            return sf2.fighters.get("core:warrior-templates/" .. ref:sub(6):lower())
        end
        return assert(templates[ref], "Unregistered Underworld template " .. ref)
    end
    for _, spec in ipairs(data.templates) do
        templates[spec.name] = sf2.fighters.register {
            id = "uw_" .. lower_id(spec.name), fighter = spec.parent and template(spec.parent) or nil,
            first_name = spec.first_name and text.key(spec.first_name) or nil,
            avatar = avatar(spec.avatar), voice = spec.voice, health_bars = spec.health_bars,
            attributes = spec.attributes, items = item_list(spec.items), skeleton = spec.skeleton,
        }
    end

    -- Generated rule rows are already rule tables ({ kind = ..., ... }) with the same field
    -- names. Only two things are resolved here: the shared RaidCharge rule, and a group's
    -- description key, which names a localization in content.underworld_text.
    local function rule_table(spec)
        if spec.kind == "raid_charge" then return raid_charge_rule end
        if spec.kind == "group" or spec.kind == "random" then
            local rule = {}
            for key, value in pairs(spec) do rule[key] = value end
            rule.rules = {}
            for index, child in ipairs(spec.rules) do rule.rules[index] = rule_table(child) end
            if spec.description then rule.description = text[spec.description] end
            return rule
        end
        return spec
    end

    local owned_music = {}
    local function music(name)
        assert(OWNED_MUSIC[name], "Missing DE128 Underworld music source for " .. tostring(name))
        owned_music[name] = owned_music[name] or sf2.assets.audio("audio/underworld/" .. name)
        return owned_music[name]
    end
    local zones, battles, fights = {}, {}, {}
    -- Every registered opponent's qualified ID by archive template name (content.forge_choice
    -- reads the bosses).
    local by_template = {}
    -- by_battle[archive battle][archive fight] = { handle, id } for story hooks.
    local by_battle = {}
    -- Generated Power Mode rows contain only differences from the normal fight.
    -- Resolve into a fresh table so registering a twin cannot mutate its source.
    local fight_rows = {}
    assert(#data.zones == MAP_TIERS, "Underworld map art expects " .. MAP_TIERS .. " tiers")
    local places = {}
    for _, spec in ipairs(data.zones[4].battles) do places[spec.name] = spec end
    for tier, zone_spec in ipairs(data.zones) do
        local zone_id = "underworld_tier_" .. tier
        local art = sf2.assets.sprite("sprites/underworld/maps/tier" .. tier)
        local zone = sf2.map.register { id = zone_id, art = art, underworld = true }
        -- The map footer names a page by the text registered as zones/<page id>: the game's
        -- own raid tier name (ZONE_RAID, ZONE_RAID1 ...).
        sf2.text.register { id = "zones/" .. zone_id, language = "eng",
            value = words.read(tier == 1 and "ZONE_RAID" or "ZONE_RAID" .. (tier - 1)) }
        zones[tier] = zone
        for _, spec in ipairs(zone_spec.battles) do
            local battle_id = "uw_" .. lower_id(spec.name)
            local icons = nil
            if spec.icon_atlas and OWNED_BUTTONS[spec.icon_atlas] then
                icons = {
                    base = sf2.assets.sprite("sprites/underworld/" .. spec.icon_atlas:lower() .. "_base"),
                    active = sf2.assets.sprite("sprites/underworld/" .. spec.icon_atlas:lower() .. "_active"),
                }
            end
            local description = nil
            if spec.description then
                description = text.key(spec.description) .. (spec.description_level and ("{" .. spec.description_level .. "}") or "")
            end
            local place = spec
            if tier == 8 then
                local normal = spec.name:gsub("_HARDMODE$", "")
                place = assert(places[TIER8_PLACES[normal]], "No tier 4 place for Underworld battle " .. spec.name)
            end
            fight_rows[spec.name] = {}
            local fight_specs, fight_ids = {}, {}
            for _, row in ipairs(spec.fights) do
                local fight_spec = row
                if row.inherit then
                    local base = assert(fight_rows[row.inherit] and fight_rows[row.inherit][row.name],
                        "Missing normal Underworld fight " .. row.inherit .. "/" .. row.name)
                    fight_spec = {}
                    for key, value in pairs(base) do fight_spec[key] = value end
                    for key, value in pairs(row) do
                        if key ~= "inherit" then fight_spec[key] = value end
                    end
                end
                fight_rows[spec.name][row.name] = fight_spec
                -- A fight's ID is <battle id>_<name>, so this name keeps the archive's fight IDs.
                local fight_name = lower_id(fight_spec.name)
                local prefix = battle_id .. "_" .. fight_name
                local opponents = {}
                for index, w in ipairs(fight_spec.warriors) do
                    local tactic = w.template == "Boss_Wasp_Young" and wasp_fly.tactic or
                        (w.template == "Boss_Butcher_Young" and butcher_earthquake.tactic or
                        (w.template == "Boss_Hermit_Young" and hermit_storm.tactic or
                        (w.template == "Girl_Drakaina" and war_whirl.tactic or
                        (w.template == "Cyborg_Gatekeeper" and gatekeeper_power_field.tactic or
                        (w.template == "Girl_Blackness" and blackness_tactic(w) or
                        (w.template == "Girl_Saturn" and saturn_tactic(w) or
                        (w.template == "Man_Dandy" and dandy_tactic(w) or
                        (w.template == "Man_Hoaxen" and raid_boss_abilities.hoaxen or
                        (w.template == "Man_Stalker" and hunter_tactic(w) or
                        (w.template == "Man_Berstuuk" and raid_boss_abilities.berstuuk or w.tactic))))))))))
                    if w.template == "Man_Arkhos" then tactic = raid_boss_abilities.arkhos end
                    if w.template == "Man_Tenebris" then tactic = raid_boss_abilities.tenebris end
                    tactic = teleport_tactic(w) or tactic
                    -- A DE128 boss tactic's cadence drives the boss's ability icon.
                    local perks = perk_rows(w.perks)
                    local pace = boss_abilities.pace_perk_for(tactic)
                    if pace then
                        perks = perks or {}
                        perks[#perks + 1] = pace
                    end
                    -- The opponent keeps its archive-era warrior ID (<fight id>_w<position>).
                    local opponent_id = prefix .. "_w" .. index
                    opponents[index] = {
                        id = opponent_id, fighter = template(w.template), tactic = tactic,
                        avatar = avatar(w.avatar), health_bars = w.health_bars, attributes = w.attributes,
                        attribute_alignments = w.alignments, perks = perks,
                        items = item_list(w.items), skeleton = w.skeleton,
                    }
                    by_template[w.template] = by_template[w.template] or {}
                    table.insert(by_template[w.template], sf2.mod.id .. ":warriors/" .. opponent_id)
                end
                local rewards = {}
                for index, r in ipairs(fight_spec.rewards) do
                    local reward = { prize_base = r.prize_base, experience = r.experience,
                        gems = r.gems, currencies = r.currencies }
                    -- An empty reward is a missing key: the slot still exists and pays nothing.
                    if next(reward) then rewards[index - 1] = reward end
                end
                local rules = {}
                for index, rule in ipairs(fight_spec.rules) do rules[index] = rule_table(rule) end
                fight_specs[#fight_specs + 1] = {
                    name = fight_name, power = fight_spec.power, rounds = fight_spec.rounds,
                    round_time = fight_spec.round_time, replays = fight_spec.replays,
                    health_recovery = fight_spec.health_recovery, opponents = opponents, rules = rules, rewards = rewards,
                }
                fight_ids[#fight_ids + 1] = { name = fight_spec.name, id = sf2.mod.id .. ":fights/" .. prefix }
            end
            local battle = sf2.battles.register {
                id = battle_id, page = zone, type = BATTLE_TYPES[spec.type], x = place.x, y = place.y,
                alias = text.key(spec.alias), title = text.key(spec.title), description = description,
                icon = spec.icon, icon_atlas = (not icons) and spec.icon_atlas or nil, icons = icons,
                preview = spec.preview, location = spec.location, music = music(spec.music),
                power_mode = spec.power_mode,
                fights = fight_specs,
            }
            battles[spec.name] = battle
            by_battle[spec.name] = {}
            for index, ids in ipairs(fight_ids) do
                local handle = battle.fights[index]
                fights[#fights + 1] = handle
                by_battle[spec.name][ids.name] = { handle = handle, id = ids.id }
            end
        end
    end
    return { zones = zones, battles = battles, fights = fights, templates = templates, by_battle = by_battle,
        warriors_by_template = by_template }
end

return { install = install }
