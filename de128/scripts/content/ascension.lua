local sf2 = require("sf2")
local words = require("content.text")
local shared = require("content.sensei_state")
local trial = require("content.ascension_rules")

-- Ascension: Act 2's "Challenge 2", the Puppeteer's (theatre director's) Monk set event, from
-- Marmalade SF2 1.9.38 (stages.xml ZONE_2 Battle Ascension; quests.xml Ascension*;
-- quest_extensions/zone_2/story.xml Zone2AscensionUnlock and the Asc_* tutorials).
--   Battle   five one-round fights (99 s) at the statue, Halls of the Dead Heroes, on the Act 2
--            map at -374, 50. A loss sends the run back to fight 1; winning fight 5 starts over.
--   Entry    three tickets when a run starts (the archive's CurrencyCost on fight 1).
--   Enemies  one Ascension_2 ninja, with Survival_Ranged_2's shurikens or kunai, both at random.
--   Rules    immunity thresholds and the random enchantment and challenge (content.ascension_rules).
--   Rewards  a loss raises immunity (Resistance_2) by 45; a win draws from the fight's chest
--            (Bronze, Bronze, Silver, Silver, Gold): one Monk piece, forge orbs, coins or a ticket.
--   Tickets  three from the Puppeteer when Ascension opens, three more after a first loss in
--            fight 1, two for every duel win (as the archive's duels paid), one from a chest.
-- The game's own Ascension words are Eclipse's English text; de128.ascension.* are DE128's.
-- Saved state: one field, "ascension", a set of words such as ",unlocked,zone_intro,".

shared.register()
local FIELD = "ascension"
local TICKET_STACK = 999
local ENTRY_TICKETS = 3
local LOCK_FIGHT = "core:fights/zone_1/boss_lynx/6"
local UNLOCK_FIGHT = "core:fights/zone_2/tournament/12"

local function key(name) return words.get(name) end
local puppeteer = sf2.assets.sprite("core:ui/users/character_puppeteer")
local tickets_picture = sf2.assets.sprite("core:ui/users/tickets")
local ticket_icon = sf2.assets.sprite("core:ui/atlases/MiscSprites.ticket")

local ticket = sf2.items.register {
    category = "consumable", id = "ascension_ticket",
    display_name = words.own("item.ascension_ticket", "de128.ascension.ticket.name"),
    description = words.own("item.ascension_ticket.description", "de128.ascension.ticket.description"),
    icon = ticket_icon, stack = TICKET_STACK,
}

-- Opponents: the archive's Warrior (WarriorPower 0, AttributesAlign 1/0, 0.965/7, 0/7) with one
-- template from Ascension_2 and one ranged weapon from Survival_Ranged_2, each picked at random.
local TEMPLATES = {
    "ascension_2_ninja_man_crescent_knives", "ascension_2_ninja_man_tonfa", "ascension_2_ninja_man_keris",
    "ascension_2_ninja_girl_swords", "ascension_2_ninja_man_nunchaku",
}
local RANGED = { "RANGED_SHURIKENS", "RANGED_KUNAI" }
local opponents = {}
for index, template in ipairs(TEMPLATES) do
    for _, ranged in ipairs(RANGED) do
        opponents[#opponents + 1] = sf2.fighters.register {
            id = "ascension_" .. index .. "_" .. ranged:lower(), fighter = "core:warrior-templates/" .. template,
            tactic = "Standard", items = { sf2.items.get("core:items/ranged/" .. ranged) },
            attributes = { WarriorPower = 0 },
            attribute_alignments = {
                { factor = 1, shift = 0, priority = 1 },
                { factor = 0.965, shift = 7, priority = 1 },
                { factor = 0, shift = 7, priority = 1 },
            },
        }
    end
end

-- The chests. Each holds the fight's Monk piece twice (scaled to the player's level with its
-- archived enchantment, Aspect 36.39 * level + 105, and the Tempest Rage set perk) among forge
-- orbs and coins worth a multiple of the level's base value, and one ticket. Silver chests pay
-- twice a Bronze chest's amounts, the Gold chest three times. Coins come in the archive's three
-- level bands (gold, platinum, credit art), which pay the same.
local monk_set = sf2.perks.get("core:perks/PERK_MONK_SET_WHIRL")
local PIECES = {
    { item = "helm/HELM_C2_Z2_MONK", perk = "PERK_ITEM_SPECIAL_REJUVENATION_HELM" },
    { item = "ranged/RANGED_C2_Z2_MONK_SHURIKEN", perk = "PERK_ITEM_SPECIAL_BLOODRAGE_RANGED" },
    { item = "armor/ARMOR_C2_Z2_MONK", perk = "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_BODY_ARMOR" },
    { item = "weapon/WEAPON_C2_Z2_MONK_KATAR", perk = "PERK_ITEM_SPECIAL_WEAKNESS_WEAPON" },
    { item = "magic/MAGIC_C2_Z2_MONK_ROOT_STUN", perk = "PERK_ITEM_SPECIAL_INTOXICATION_MAGIC" },
}
local CHESTS = { 1, 1, 2, 2, 3 }
local chest_pictures = {}
for tier = 1, 3 do chest_pictures[tier] = sf2.assets.sprite("sprites/ascension/challenge2_chest_" .. tier) end
local monk_items = {}

local function piece_slot(piece)
    local item = sf2.items.get("core:items/" .. piece.item)
    local perk = sf2.perks.get("core:perks/" .. piece.perk)
    return {
        item = item,
        configure = function(context)
            return {
                level = context.player_level,
                enchantments = { { perk = perk, aspect = 3639 / 100 * context.player_level + 105 }, { perk = monk_set } },
            }
        end,
    }
end

local function lottery(step)
    local tier = CHESTS[step]
    local piece = PIECES[step]
    local slots = {}
    local function scaled(amount) return math.floor(amount * tier * 100 + 0.5) / 100 end
    local function orbs(green, red, purple)
        slots[#slots + 1] = { currency = "ForgeMaterial1", scale = scaled(green) }
        slots[#slots + 1] = { currency = "ForgeMaterial2", scale = scaled(red) }
        slots[#slots + 1] = { currency = "ForgeMaterial3", scale = scaled(purple) }
    end
    local function coins(amount)
        slots[#slots + 1] = { coins_scale = scaled(amount), max_level = 37 }
        slots[#slots + 1] = { coins_scale = scaled(amount), min_level = 38, max_level = 43 }
        slots[#slots + 1] = { coins_scale = scaled(amount), min_level = 44 }
    end
    slots[#slots + 1] = piece_slot(piece)
    orbs(0.01, 0.02, 0.27)
    slots[#slots + 1] = { item = ticket, count = 1, image = ticket_icon }
    coins(0.2)
    orbs(0.01, 0.18, 0.03)
    slots[#slots + 1] = piece_slot(piece)
    orbs(0.09, 0.02, 0.03)
    coins(0.8)
    orbs(0.01, 0.02, 0.03)
    return { image = chest_pictures[tier], slots = slots }
end

local fight_specs = {}
for step = 1, 5 do
    monk_items[("core:items/" .. PIECES[step].item):lower()] = true
    fight_specs[step] = {
        opponents = { { fighter = opponents[1] } }, rules = trial.rules(step),
        rounds = 1, round_time = 99, replays = 1, power = 0,
        rewards = {
            [0] = { prize_base = 5, resistances = { { name = "Resistance_2", value = 45 } } },
            [1] = { prize_base = 5, lottery = lottery(step) },
        },
    }
end

-- Fight IDs are de128:fights/ascension_1 .. ascension_5.
local battle = sf2.battles.register {
    id = "ascension", page = sf2.map.get("core:zones/zone_2"), x = -374, y = 50,
    alias = words.key("Ascension"), title = words.key("Ascension_TITLE"),
    description = words.key("LockedAscensionDescription"), icon = "ascension",
    preview = "preview_main.statue", location = "core:locations/statue",
    music = "fight34_halls_of_the_dead_heroes", show_resistance = true,
    fights = fight_specs,
}
local fights = battle.fights
local fight_step = {}
for step = 1, #fights do fight_step[sf2.mod.id .. ":fights/ascension_" .. step] = step end

-- Saved words ------------------------------------------------------------------------------------

local function saved() return sf2.state.get(FIELD) or "," end
local function has(word) return saved():find("," .. word .. ",", 1, true) ~= nil end
local function add(word) if not has(word) then sf2.state.set { [FIELD] = saved() .. word .. "," } end end
local function remove(word)
    local value = saved()
    local first, last = value:find("," .. word .. ",", 1, true)
    if first then sf2.state.set { [FIELD] = value:sub(1, first) .. value:sub(last + 1) } end
end
local function number(name)
    return tonumber(saved():match("," .. name .. "=(%d+),")) or 0
end
local function set_number(name, value)
    local text = saved():gsub("," .. name .. "=%d+,", ",")
    sf2.state.set { [FIELD] = text .. name .. "=" .. value .. "," }
end

-- Run: three tickets when it starts, a random opponent for every fight ----------------------------

sf2.modes.register {
    id = "ascension", fights = fights, repeatable = true, reset_on_loss = true,
    entry_item = ticket, entry_count = ENTRY_TICKETS, entry_per = "run",
    on_prepare = function(_, event)
        local draw = number("draws") + 1
        set_number("draws", draw)
        local roll = sf2.random.stream(sf2.saves.seed(), "ascension", event.completions, event.step, draw)
        return { opponents = { roll:pick(opponents) } }
    end,
}

-- Every fight's duel win pays two tickets, as each archived Duel did (ExpectedValue 2).
local DUELS = {
    "zone_1/duel_intermission", "zone_2/duel", "zone_2/duel_intermission", "zone_3/duel",
    "zone_3/duel_intermission", "zone_4/duel", "zone_4/duel_intermission", "zone_5/duel",
    "zone_5/duel_intermission", "zone_6/duel", "zone_6/duel_intermission", "zone_7/duel", "zone_7/c3_duel",
}
for _, duel in ipairs(DUELS) do
    sf2.battles.patch {
        fight = "core:fights/" .. duel .. "/1",
        reward_drops = { { wins = 1, reward = { items = { { item = ticket, count = 2 } } } } },
    }
end

-- Dialogs ------------------------------------------------------------------------------------------

local TITLE, MESSAGE = key("tutorial_ascention_intro_title"), key("dlgAlertTitle")
local MORE, OK, TAKE = key("dlgStoryBtnMore"), key("dlgStoryBtnOk"), key("dlgStoryBtnTake")
-- "Acquired {image0} {1}." with the ticket picture as the dialog's portrait.
local acquired = sf2.text.register {
    id = "ascension.tickets_acquired", language = "eng",
    value = (words.read("tutorial_ascension_intro2_2"):gsub("{0}%s*", ""):gsub("{1}", tostring(ENTRY_TICKETS))),
}

local function card(line, button, title, portrait)
    return { dialog = { title = title or TITLE, portrait = portrait or puppeteer,
        lines = { { text = line } }, button = button or OK } }
end

local scene, view = nil, false
local due = {}
local show_next = function() end

local function play(steps, on_complete)
    view = sf2.story.play_sequence {
        steps = steps,
        on_complete = function() view = false; if on_complete then on_complete() end; show_next() end,
        on_cancel = function() view = false end,
    }
    if not view then view = false end
    return view
end

local function reveal()
    if has("unlocked") or has("locked") then return end
    if sf2.profile.fight(LOCK_FIGHT).wins < 1 then return end
    if sf2.map.reveal { battle = battle, locked = true } then add("locked") end
end

-- Zone2AscensionUnlock: the Puppeteer's invitation, three tickets and the battle opened.
local function unlock()
    return play({ card(key("tutorial_ascension_intro1"), MORE), card(key("tutorial_ascension_intro2_1"), MORE) }, function()
        if has("unlocked") then return end
        if not sf2.map.reveal { battle = battle, locked = false } then return end
        sf2.map.lock { battle = battle, locked = false }
        sf2.profile.give_item(ticket, ENTRY_TICKETS)
        add("unlocked"); add("locked")
        due[#due + 1] = "invited"
    end)
end

local DIALOGS = {
    invited = function()
        return play({ card(acquired, TAKE, MESSAGE, tickets_picture), card(key("tutorial_ascension_intro2_3"), OK, MESSAGE) },
            function() sf2.map.focus(battle) end)
    end,
    -- Asc_immunity_tutorial (first defeat) and Asc_defeat_dialog (every later one).
    first_defeat = function() return play({ card(key("tutorial_ascension_immunity_fail")) }) end,
    defeat = function()
        local roll = sf2.random.stream(sf2.saves.seed(), "ascension_defeat", number("draws"))
        return play({ card(key("AscDefeatPrase_" .. roll:integer(1, 4))) })
    end,
    -- Asc_tutorial_first_fightend_loss: three more tickets after a first loss in fight 1.
    consolation = function()
        if not has("consolation_owed") then return false end
        if not sf2.profile.give_item(ticket, ENTRY_TICKETS) then return false end
        remove("consolation_owed")
        return play({ card(key("tutorial_ascension_immunity_fail_2"), MORE), card(acquired, TAKE, MESSAGE, tickets_picture) })
    end,
    -- Asc_tutorial_duel and Zone2LossTutor.
    duel = function() return play({ card(key("de128.ascension.duel_tickets")) }) end,
    loss_tutor = function() return play({ card(key("tutorial_ascension_loss1")) }) end,
    -- Asc_win_dialog after fight 5.
    win = function()
        local roll = sf2.random.stream(sf2.saves.seed(), "ascension_win", number("draws"))
        return play({ card(key("AscWinPrase_" .. roll:integer(1, 4))) })
    end,
    -- Asc_tutorial_set_item, the first Monk piece.
    set_item = function() return play({ card(key("AscSetItemAcquered")) }) end,
    reminder = function() return play({ card(key("tutorial_ascension_reminder")) }) end,
}

show_next = function()
    if scene ~= "map" or view or shared.dialogue_pending() or shared.defeat_pending() then return end
    reveal()
    if not has("unlocked") then
        if sf2.profile.fight(UNLOCK_FIGHT).wins >= 1 then unlock() end
        return
    end
    -- The consolation tickets stay owed (saved) until they are given on the map.
    if has("consolation_owed") then
        local queued = false
        for _, name in ipairs(due) do if name == "consolation" then queued = true end end
        if not queued then due[#due + 1] = "consolation" end
    end
    while #due > 0 do
        local name = table.remove(due, 1)
        if DIALOGS[name]() then return end
    end
end

-- Asc_tutorial_reminder / Asc_reminder_counter: up to four nudges, one every three fights,
-- until the player first plays fight 1.
local function untouched()
    local first = sf2.profile.fight(fights[1])
    return first.wins < 1 and first.losses < 1
end
local function check_reminder()
    if not has("unlocked") or not untouched() then return end
    local count, limit = number("remind"), number("reminded")
    if count >= 3 and limit < 4 then
        set_number("remind", 0); set_number("reminded", limit + 1)
        due[#due + 1] = "reminder"
    end
end

sf2.story.on("session", function() check_reminder() end)

sf2.story.on("fight_end", function(event)
    if has("unlocked") and number("reminded") < 3 and untouched() then set_number("remind", number("remind") + 1) end
    local step = fight_step[event.fight]
    if step then
        if event.result == "win" then
            if step == 5 then due[#due + 1] = "win" end
        else
            if not has("first_defeat") then add("first_defeat"); due[#due + 1] = "first_defeat"
            else due[#due + 1] = "defeat" end
            local first = sf2.profile.fight(fights[1])
            if step == 1 and first.wins < 1 and first.losses < 2 and not has("consolation") then
                add("consolation"); add("consolation_owed")
                due[#due + 1] = "consolation"
            end
            if step ~= 1 and not has("duel_tutor") then add("duel_tutor"); due[#due + 1] = "duel" end
            if not has("loss_tutor") then add("loss_tutor"); due[#due + 1] = "loss_tutor" end
        end
    end
    check_reminder()
end)

sf2.story.on("item_acquired", function(event)
    if event.item and monk_items[event.item:lower()] and event.previous_count == 0 and not has("set_item") then
        add("set_item"); due[#due + 1] = "set_item"
    end
end)

sf2.story.on("scene_enter", function(event)
    scene = event.scene
    view = false
    show_next()
end)

-- AscensionZoneIntro: the Puppeteer tells the Monk's story the first time the player enters.
for _, fight in ipairs(fights) do
    sf2.story.before_fight(fight, function(request)
        if has("zone_intro") then return true end
        local opened = sf2.story.play_sequence {
            steps = {
                card(key("ZONE_2Asc_Intro_1"), MORE), card(key("ZONE_2Asc_Intro_2"), MORE),
                card(key("ZONE_2Asc_Intro_3"), MORE), card(key("ZONE_2Asc_Intro_4"), OK),
            },
            on_step = function() return sf2.story.fight_pending(request) end,
            on_complete = function()
                add("zone_intro")
                if not sf2.story.resume_fight(request) then sf2.story.cancel_fight(request) end
            end,
            on_cancel = function() sf2.story.cancel_fight(request) end,
        }
        if not opened then sf2.story.cancel_fight(request) end
        return nil
    end)
end

return { battle = battle, fights = fights, ticket = ticket }
