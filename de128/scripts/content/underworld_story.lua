local sf2 = require("sf2")
local story = require("content.underworld_story_data")
local text = require("content.underworld_text")
local shared = require("content.sensei_state")
local sensei_art = require("content.sensei_art")
local seals = require("content.underworld_seals")
local words = require("content.text")

-- The debug menu's button for the first-visit guide (read while loading, like all DE128 words).
local DEBUG_GUIDE = words.read("de128.uw_meta.guide.debug")

-- The archived Underworld quests (RaidIntro, RaidIntro2 and the 32 RaidEnter/
-- RaidWinAfter/RaidLoseAfter bosses; see Tools/GenerateDE128Underworld.py) as mod
-- state and native story dialogs. No XML or native user variable is read.

-- Native resources absent from the packaged-art catalog ship with DE128.
local OWNED_PORTRAITS = { character_may_1 = "sprites/underworld/character_may_1", character_may_4 = "sprites/underworld/character_may_4" }
local portraits = {}
local function portrait(name)
    if name == nil then return nil end
    local handle = portraits[name]
    if handle == nil then
        if OWNED_PORTRAITS[name] then handle = sf2.assets.sprite(OWNED_PORTRAITS[name])
        elseif sensei_art.owned[name] then handle = sensei_art.portrait(name)
        else handle = sf2.assets.sprite("core:ui/users/" .. name:lower()) end
        portraits[name] = handle
    end
    return handle
end

local function dialog_definition(card)
    assert((card.title == nil or text[card.title]) and text[card.text] and text[card.button], "Underworld dialog text missing")
    return {
        title = card.title and text[card.title] or nil, portrait = portrait(card.portrait), mirrored = card.mirrored == true,
        lines = { { text = text[card.text] } }, button = text[card.button],
        ignore_back = card.ignore_back == true,
    }
end

local function act_lines(card)
    local lines = {}
    for index, line in ipairs(card.lines) do lines[index] = { text = text[line.text], frames = line.frames } end
    return lines
end

local function sequence_steps(cards)
    local steps = {}
    for _, card in ipairs(cards) do
        steps[#steps + 1] = card.lines and { act_screen = { lines = act_lines(card) } }
            or { dialog = dialog_definition(card) }
    end
    return steps
end

-- Every portrait the story names, resolved during installation.
local function story_portraits()
    local result = {}
    local function add(cards)
        for _, card in ipairs(cards) do
            if card.portrait then result[card.portrait] = portrait(card.portrait) end
        end
    end
    add(story.intro)
    add(story.followup)
    for _, boss in pairs(story.bosses) do
        add(boss.enter)
        add(boss.win)
        add(boss.loss)
    end
    return result
end

-- Saved boss sets (sensei_state.lua): ",name,name," with lower-case archive names.
local function saved_set(set)
    local value = sf2.state.get("uw_" .. set)
    assert(type(value) == "string", "Underworld story set must be a string")
    return value
end
local function has(set, key) return saved_set(set):find("," .. key .. ",", 1, true) ~= nil end
local function add(set, key)
    if not has(set, key) then sf2.state.set { ["uw_" .. set] = saved_set(set) .. key .. "," } end
end
local function remove(set, key)
    local value = saved_set(set)
    local first, last = value:find("," .. key .. ",", 1, true)
    if first then sf2.state.set { ["uw_" .. set] = value:sub(1, first) .. value:sub(last + 1) } end
end

-- underworld: the table returned by content.underworld's install.
local function install(underworld)
    assert(type(underworld) == "table" and type(underworld.by_battle) == "table", "Underworld registration required")
    assert(underworld.battles[story.focus], "Unknown Underworld focus battle " .. tostring(story.focus))
    shared.register()
    story_portraits()
    local results = {}
    -- The first-visit guide's own fight request is under way (see try_guide below).
    local guide_launched = false
    for boss, sequences in pairs(story.bosses) do
        local fights = underworld.by_battle[boss]
        assert(fights and fights["1"], "Missing Underworld story fight " .. boss .. "|1")
        local key = boss:lower()
        results[fights["1"].id] = key
        -- A sealed boss (content.underworld_seals) has a pre-fight menu: after the entry below the
        -- first time, at once on later visits. Its Fight button lets the fight go ahead.
        local sealed = seals.menu(boss)
        -- RaidEnter<Boss>: once per profile, the exact entry is held until the Fight button.
        sf2.story.before_fight(fights["1"].handle, function(request)
            if has("entered", key) then
                if sealed then return sealed(request) end
                return true
            end
            local last = sequences.enter[#sequences.enter]
            assert(last and last.launch, "Underworld entry must end with its Fight button")
            local opened = sf2.story.play_sequence {
                steps = sequence_steps(sequences.enter),
                on_step = function() return sf2.story.fight_pending(request) end,
                on_complete = function()
                    if sealed then
                        add("entered", key)
                        if sf2.story.fight_pending(request) then sealed(request) end
                    elseif sf2.story.resume_fight(request) then add("entered", key)
                    else sf2.story.cancel_fight(request) end
                end,
                on_cancel = function()
                    guide_launched = false
                    sf2.story.cancel_fight(request)
                end,
            }
            if not opened then
                -- Another DE128 sequence is playing: a guide launch is tried again on a later event.
                guide_launched = false
                sf2.story.cancel_fight(request)
            end
            return nil
        end)
    end

    local scene, view = nil, nil
    local show_next = function() end

    -- A saved cursor belongs to a stable story key; acknowledgement advances it
    -- inside the API. Completion clears it together with the pending story work.
    local function run_cards(key, cards, on_done, on_step)
        if sf2.state.get("uw_sequence_key") ~= key then
            sf2.state.set { uw_sequence_key = key, uw_sequence_next = 1 }
        end
        view = true
        local opened = sf2.story.play_sequence {
            position = "uw_sequence_next", steps = sequence_steps(cards), on_step = on_step,
            on_complete = function()
                view = nil
                sf2.state.set { uw_sequence_key = "", uw_sequence_next = 1 }
                on_done()
            end,
            on_cancel = function() view = nil end,
        }
        if not opened then view = nil end
    end

    -- RaidIntro after its ActScreen: ShowRaidsGag and SetMapFocus on the first boss. DE128
    -- also opens the Underworld map there, so the rest of the story plays on it. Repeating
    -- this before every later card is harmless and recovers a resumed or refused switch.
    local function enter_underworld()
        sf2.map.show_underworld(true)
        sf2.map.focus(underworld.battles[story.focus])
        sf2.map.open_underworld()
    end

    -- The sealed Underworld's first-visit guide (content.underworld_seals) runs on the first boss's
    -- real challenge screen. Once the intro has finished it opens that screen the way the map's
    -- boss button does (the boss's own entry dialog first, the first time), so Fight and Back work
    -- as ever and nothing starts until Fight. A launch the game refuses, or one whose entry dialog
    -- cannot open while another DE128 sequence plays, is tried again on a later event.
    local focus_fight = assert(underworld.by_battle[story.focus] and underworld.by_battle[story.focus]["1"],
        "Missing Underworld focus fight " .. story.focus)
    local function try_guide()
        if guide_launched or not seals.guide_pending() then return end
        enter_underworld()
        guide_launched = sf2.story.start_fight(focus_fight.handle)
    end

    -- Debug builds (Eclipse's F1 menu outside fights): the guide again on any save. It opens the
    -- Underworld and the first boss's screen; the saved state only changes if it is walked to the end.
    sf2.debug.action { id = "underworld_guide", label = DEBUG_GUIDE, run = function()
        seals.force_guide()
        if scene ~= "map" then
            sf2.log.warn("Underworld guide: open the map first; it shows on the next sealed boss's screen.")
            return
        end
        enter_underworld()
        if not sf2.story.start_fight(focus_fight.handle) then
            sf2.log.warn("Underworld guide: no fight can start now; it shows on the next sealed boss's screen.")
        end
    end }

    local function run_intro()
        run_cards("intro", story.intro, function()
            sf2.state.set { uw_intro = 1 }
            show_next()
        end, function(index)
            if index > 1 then enter_underworld() end
        end)
    end

    local order = {}
    for boss in pairs(story.bosses) do order[#order + 1] = boss end
    table.sort(order)
    local function pending_result()
        local saved = sf2.state.get("uw_sequence_key")
        for _, boss in ipairs(order) do
            for _, kind in ipairs { "win", "loss" } do
                if saved == boss .. ":" .. kind and has(kind .. "_pending", boss:lower()) then return boss, kind end
            end
        end
        for _, boss in ipairs(order) do
            local key = boss:lower()
            if has("win_pending", key) then return boss, "win" end
            if has("loss_pending", key) then return boss, "loss" end
        end
        return nil, nil
    end

    show_next = function()
        if scene ~= "map" or view or shared.dialogue_pending() or shared.defeat_pending() then return end
        local intro = sf2.state.get("uw_intro")
        if intro == 0 then
            -- RaidIntro: the archive checks a win over Lynx 2 when a fight ends. Saves that
            -- already have it (or gained it before DE128) are caught up on map entry.
            if sf2.profile.fight(story.unlock_fight).wins < 1 then return end
            run_intro()
            return
        end
        if intro == 1 then
            -- RaidIntro2. Its last button changed scene to the dojo (the card's scene field);
            -- DE128 keeps the player on the Underworld map the intro just opened.
            run_cards("followup", story.followup, function()
                sf2.state.set { uw_intro = 2 }
                seals.intro_finished()
                show_next()
            end, enter_underworld)
            return
        end
        local boss, kind = pending_result()
        if not boss then
            -- A lost sealed fight's Continue: its challenge screen again, from the seal held. The
            -- map is back on the boss's Underworld page already (Eclipse returns there after a fight).
            local again = seals.take_continue()
            if again and sf2.story.start_fight(again) then return end
            try_guide()
            return
        end
        local key = boss:lower()
        run_cards(boss .. ":" .. kind, story.bosses[boss][kind], function()
            add(kind .. "_shown", key)
            remove(kind .. "_pending", key)
            show_next()
        end)
    end

    sf2.story.on("battle_result", function(event)
        local key = results[event.fight]
        -- The archive's FightResult is "Loss" for defeats; a surrender is distinct.
        if not key or (event.outcome ~= "win" and event.outcome ~= "loss") then return end
        if not has(event.outcome .. "_shown", key) then add(event.outcome .. "_pending", key) end
        show_next()
    end)
    -- A refused guide launch is tried again after any fight and on map buttons too.
    sf2.story.on("battle_result", function()
        guide_launched = false
        show_next()
    end)
    sf2.story.on("map_button", function() show_next() end)
    sf2.story.on("scene_enter", function(event)
        scene = event.scene
        view = nil
        guide_launched = false
        if scene ~= "map" then return end
        -- The toggle stays hidden until the intro's ShowRaidsGag step.
        if sf2.state.get("uw_intro") == 0 then sf2.map.show_underworld(false) end
        show_next()
    end)
end

return { install = install, portrait = portrait, story_portraits = story_portraits }
