local sf2 = require("sf2")
local words = require("content.text")
local elixirs = require("content.underworld_elixirs")
local raid_boss_abilities = require("content.raid_boss_abilities")
local own_rules = require("content.underworld_seal_rules")
local meta = require("content.underworld_meta")

-- Phased Underworld bosses (Eclipse Docs/Engineering/Modding/UNDERWORLD_PHASED_BOSSES_PLAN.md).
-- A boss's health is split into seals, later ones larger, and each seal is a fight phase with its
-- own rule (fighter:set_phase). Nothing about the seals is on screen while the player fights: the
-- boss bar's marks show where they split. Breaking a seal pauses the fight while it shatters in the
-- middle of the screen (fighter:play_seal_break), then a live intermission of about five seconds
-- starts: the boss cannot be hurt and waits, gathering himself, and a small Prepare button opens the
-- game's Prepare screen (sf2.ui.prepare; the fight pauses) to put on an Armory loadout and drink
-- elixirs. Breaking the last seal wins. The pre-fight screen is the game's challenge screen
-- (sf2.ui.challenge), and the fight's result shows on Eclipse's results screen (sf2.ui.results:
-- the seals as they ended, the rewards counted up with Momentum, the elixir drop) instead of the
-- game's tally. All three are drawn by Eclipse in the shop's art; this module fills them.
--
-- Momentum: +10% coins, gems and experience for every seal broken since Prepare was last opened;
-- the last seal counts when the boss falls. A loss or surrender keeps the seal reached on Easy and
-- Medium and goes back one on Hard and Very Hard; a win starts the next visit at seal 1. Progress
-- is saved once the fight's result arrives, never mid-fight, in uw_seal_progress
-- (content.sensei_state) as ",<key>=<seal>," entries; seal 1 is not stored.
--
-- The seals' rules are rolled for every run: three different rules from RULES, picked when the
-- challenge screen opens (or when the fight starts, if it did not) and kept until a fight ends, so
-- leaving the challenge screen does not roll again. Rolls draw on the saved uw_seal_rng sequence.
-- A sealed fight registers every rule, each limited to its own fight phase (PHASES); the
-- controller moves the fight to the phase of the seal's rule, or to RULELESS between seals.
--
-- Each run also rolls three pacts, Lua rules the player may take on for every seal from the
-- challenge screen's pact tiles (levels 0-3, +25% rewards each, beside Momentum); while they are
-- on, the fight's pause screen lists them under the seal's rule. On the
-- challenge screen an Omen rerolls a seal (the Omen control at the end of its row, pressed twice),
-- Seal Shards brew elixirs (a slot pressed twice) and the codex tally opens the boss's Seal Codex
-- page; a fight gives a shard per seal broken and an Omen on a win, and its broken rules join the
-- codex (content.underworld_meta). Nothing on the screen spends on a single press: Eclipse arms
-- the control first and its info line says what a second press does.

-- Seal rules by name: rule, the description key of a rule group the Underworld's Power Mode
-- fights use (content.underworld_data), copied for the seal; title, de128.uw_seals.rule.<name>;
-- art, a Gates of Shadows seal colour (core:ui/items/img_drop_<art>_seal, cracked versions in
-- assets/textures/underworld_seals), one colour per kind of rule.
local RULES = {
    hard_ground = { rule = "HARD_GROUND", art = "orange" },
    no_jumps = { rule = "NO_JUMPS", art = "orange" },
    earthquake = { rule = "EARTHQUAKE", art = "orange" },
    hot_ground = { rule = "HOT_GROUND", art = "red" },
    burning = { rule = "TRANSIENT_BLEEDING", art = "red" },
    no_blocks = { rule = "NO_BLOCKS", art = "red" },
    draining_ground = { rule = "RANDOM_AREA_HEALTH_DEGENERATION", art = "jade" },
    withering = { rule = "HEALTH_DROPS", art = "jade" },
    fragile_ground = { rule = "FRAGILITY", art = "green" },
    no_kicks = { rule = "NO_KICKS", art = "green" },
    no_double = { rule = "NO_DOUBLE", art = "blue" },
    inverted = { rule = "INVERTED_JOYSTICK", art = "blue" },
    darkness = { rule = "LIGHT_IN_THE_DARK", art = "purple" },
    hidden_health = { rule = "NO_HEALTHBAR", art = "purple" },
}
-- The Underworld's own seal rules (content.underworld_seal_rules): built-in rules and Lua handlers,
-- with their hint text in de128.uw_seals.hint.<name>.
for name, rule in pairs(own_rules.rules) do
    assert(not RULES[name], "Seal rule " .. name .. " is defined twice")
    RULES[name] = rule
end

-- Rules that never meet in one run, and rules only the last seal may roll.
local CLASHES = {
    { "inverted", "tricksters_hex" },
    { "darkness", "moonless" },
    { "hidden_health", "moonless" },
    { "no_kicks", "kicks_only" },
}
local LAST_SEAL_ONLY = { moonless = true }

-- Every rule has a fight phase of its own, from 2 in name order; phase 1 has no rule.
local RULELESS = 1
local ORDER, PHASES = {}, {}
for name in pairs(RULES) do ORDER[#ORDER + 1] = name end
table.sort(ORDER)
for index, name in ipairs(ORDER) do PHASES[name] = index + 1 end

-- Seals split the boss's health 8:10:12 from the top (later seals larger), rounded to bars:
-- 30 bars break at 22 and 12.
local SPLIT = { 8, 10, 12 }

-- Sealed bosses by archive battle name. Only the normal fight (fight "1") is sealed; Power Mode is
-- left alone. bars: the boss's health in health bars (his template's, or the fight's own).
-- portrait: core:ui/users/<name>. glow: the colour he gathers himself in between seals.
-- sound: the cue as he rises again (default the raid's fight-ready call). tactic and cooldowns:
-- Arkhos only, his Rat Wave cooldown in frames by difficulty (Medium is his usual). Every boss
-- keeps his own tactic otherwise and is held between seals with fighter:set_ai_held.
local BOSSES = {
    -- Tier 1
    BOSS_1 = { bars = 15, title = "RAIDBOSS_FIRE_TITLE", portrait = "boss_fire", glow = "#FF8A3D" },
    BOSS_SON_OF_HEAVEN = { bars = 16, title = "RAIDBOSS_CNY_Title", portrait = "new_man_shuang_gou", glow = "#FFD24A" },
    BOSS_2 = { bars = 17, title = "RAIDBOSS_Stone_Title", portrait = "boss_crystal", glow = "#9FE3FF" },
    BOSS_PUPPETEER = { bars = 18, title = "RAIDBOSS_PUPPETEER_TITLE", portrait = "character_puppeteer", glow = "#C08CFF" },
    BOSS_3 = { bars = 19, title = "RAIDBOSS_Mushroom_Title", portrait = "boss_mushroom", glow = "#B6FF5C" },
    BOSS_LAMB_VULCAN = { bars = 21, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb_vulcan", glow = "#FF6A2A" },
    BOSS_4 = { bars = 23, title = "RAIDBOSS_Vortex_Title", portrait = "boss_vortex", glow = "#5CD6FF" },
    BOSS_5 = { bars = 25, title = "RAIDBOSS_Fatum_Title", portrait = "boss_fatum", glow = "#B07CFF" },
    BOSS_LAMB_FUNGUS = { bars = 27, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb_fungus", glow = "#B6FF5C" },
    BOSS_WOLF_WIND = { bars = 29, title = "RAIDBOSS_WIND_WOLF", portrait = "boss_wind_wolf_new", glow = "#CFFFF2" },
    BOSS_6 = { bars = 30, title = "RAIDBOSS_Arkhos_Title", portrait = "boss_arkhos", glow = "#7CFF8A",
        sound = "snd_rats_ring",
        tactic = raid_boss_abilities.arkhos_sealed,
        cooldowns = { easy = 690, medium = 600, hard = 540, very_hard = 480 } },
    BOSS_7 = { bars = 31, title = "RAIDBOSS_Hoaxen_Title", portrait = "boss_hoaxen", glow = "#4CFFD0" },
    BOSS_8 = { bars = 33, title = "RAIDBOSS_Hunger_Title", portrait = "boss_hunger", glow = "#FF4A4A" },
    BOSS_LAMB_HUNGER = { bars = 35, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb_hunger", glow = "#FF5A5A" },
    BOSS_9 = { bars = 37, title = "RAIDBOSS_War_Title", portrait = "boss_war", glow = "#FF7040" },
    BOSS_BANSHEE = { bars = 39, title = "RAIDBOSS_Witch_banshee_Title", portrait = "witch_halloween_ghost", glow = "#A8D8FF" },
    BOSS_10 = { bars = 41, title = "RAIDBOSS_Tenebris_Title", portrait = "boss_tenebris", glow = "#9A6CFF" },
    -- His first fight's own avatar (boss_architect_hummer_new) has no portrait.
    BOSS_ARCHITECT_1 = { bars = 42, title = "RAIDBOSS_ARCHITECT_TITLE", portrait = "boss_architect", glow = "#FFC060" },
    BOSS_11 = { bars = 43, title = "RAIDBOSS_GATEKEEPER_TITLE", portrait = "boss_gatekeeper", glow = "#5CA8FF" },
    BOSS_ARCHITECT_2 = { bars = 45, title = "RAIDBOSS_ARCHITECT_TITLE", portrait = "boss_architect", glow = "#FFC060" },
    BOSS_12 = { bars = 47, title = "RAIDBOSS_SATURN_TITLE", portrait = "boss_saturn", glow = "#8CF0FF" },
    BOSS_13 = { bars = 49, title = "BLACKNESS_TITLE", portrait = "boss_blackness", glow = "#B05CFF" },
    BOSS_14 = { bars = 50, title = "RAIDBOSS_HUNTER_TITLE", portrait = "hunter_raid", glow = "#6AB8FF" },
    -- The event bosses
    BOSS_WHISPER = { bars = 15, title = "RAIDBOSS_WHISPER_TITLE", portrait = "boss_whisper_24", glow = "#FF6AD8" },
    BOSS_SON_OF_THE_SUN = { bars = 16, title = "RAIDBOSS_CNY24_Title", portrait = "boss_son_of_the_sun", glow = "#FFC83A" },
    BOSS_RAVANA = { bars = 17, title = "BOSS_RAVANA_Title", portrait = "boss_ravana", glow = "#FF9A3A" },
    BOSS_ADANTI = { bars = 19, title = "BOSS_BISON_Title", portrait = "boss_bison", glow = "#7CC8FF" },
    BOSS_COUNTESS = { bars = 20, title = "RAIDBOSS_Witch_old_Title", portrait = "witch_halloween_old", glow = "#D84A6A" },
    BOSS_MORGANA = { bars = 22, title = "RAIDBOSS_Witch_young_Title", portrait = "boss_morgana", glow = "#9CFF6A" },
    BOSS_LAMB = { bars = 25, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb", glow = "#C85CFF" },
    BOSS_RAKSHASA = { bars = 28, title = "RAIDBOSS_RAKSHASA", portrait = "boss_rakshasa", glow = "#FFA040" },
    BOSS_HALLOWEEN_PUPPETEER = { bars = 30, title = "RAIDBOSS_PUPPETEER_TITLE", portrait = "boss_puppeteer_hw21", glow = "#FF9A2A" },
    BOSS_FARADEYA = { bars = 34, title = "RAIDBOSS_FARADAY_Title", portrait = "character_faradaya", glow = "#8C9CFF" },
    BOSS_BERSTUUK = { bars = 36, title = "RAIDBOSS_BERSTUUK_TITLE", portrait = "boss_berstuuk", glow = "#FFB04A" },
    BOSS_DANDY = { bars = 40, title = "RAIDBOSS_DANDY_Title", portrait = "character_samson", glow = "#9CC8FF" },
    BOSS_SHURALE = { bars = 42, title = "RAIDBOSS_SHURALE_TITLE", portrait = "boss_shurale_ny22", glow = "#9CEBFF" },
    -- No Power Mode
    BOSS_INVISIBLE = { bars = 32, title = "RAIDBOSS_Invisible_Title", portrait = "man_invisible", glow = "#E0E8FF" },
    BOSS_HAUNTED_PRINCE = { bars = 46, title = "RAIDBOSS_PRINCE_TITLE", portrait = "character_prince_evil", glow = "#8A5CFF" },
}

local INTERMISSION = 300   -- frames between seals (5 s of fight time)
local MOMENTUM = 0.1       -- reward bonus per seal
local PACT_BONUS = 0.25    -- reward bonus per pact level
local PACTS = 3
local ROMAN = { "I", "II", "III" }
local FIELD = "uw_seal_progress"
local ROLLS = "uw_seal_rng"
local RESUME_SOUND = "snd_raid_fight_ready"
-- Difficulties where a loss sends the boss back one seal.
local GO_BACK = { hard = true, very_hard = true }

-- Words from Eclipse's English text (de128.uw_seals.*), read once while loading.
local function say(key) return words.read("de128.uw_seals." .. key) end
local TEXT = {}
for _, key in ipairs({ "hud.prepare", "prepare.title", "prepare.subtitle", "prepare.hint", "prepare.momentum",
    "menu.subtitle", "menu.momentum", "results.won", "results.lost", "results.won_subtitle",
    "results.lost_kept", "results.lost_back", "results.won_note", "results.momentum" }) do
    TEXT[key] = say(key)
end
local META = {}
for _, key in ipairs({ "menu.new_stamp", "menu.codex_title", "menu.codex_count", "menu.codex_hint", "menu.share",
    "menu.no_omens", "menu.brewed", "menu.short", "menu.full", "menu.rerolled",
    "menu.rate", "menu.reroll_confirm", "menu.brew_confirm", "menu.label_pacts", "menu.label_elixirs",
    "menu.momentum_info", "menu.pact_title", "menu.pact_info", "menu.wins_title", "menu.wins_info", "menu.shard_info",
    "menu.pact_choice_info", "menu.pact_choice_taken", "menu.pacts_intro", "pause.pacts", "pause.pact",
    "results.codex", "results.codex_new", "results.bonus_pact" }) do
    META[key] = words.read("de128.uw_meta." .. key)
end

-- "{0}", "{1}" ... in a text, filled in order.
local function fill(template, ...)
    local values = { ... }
    return (template:gsub("{(%d+)}", function(n)
        local value = values[tonumber(n) + 1]
        return value ~= nil and tostring(value) or nil
    end))
end

local seal_sprites = {}
local function sprites(art)
    if not seal_sprites[art] then
        seal_sprites[art] = {
            intact = sf2.assets.sprite("core:ui/items/img_drop_" .. art .. "_seal"),
            broken = sf2.assets.sprite("sprites/underworld_seals/" .. art .. "_broken"),
        }
    end
    return seal_sprites[art]
end

for _, name in ipairs(ORDER) do assert(meta.in_codex(name), "Seal rule " .. name .. " has no codex place") end

-- What the screens show of each rule. A copied Power Mode rule shows the game's own text; the
-- Underworld's own rules their hint.
local SHOWN = {}
for _, name in ipairs(ORDER) do
    local rule = RULES[name]
    local hint = rule.rule or "de128.uw_seals.hint." .. name
    SHOWN[name] = { name = name, phase = PHASES[name], title = say("rule." .. name), hint = words.read(hint),
        description = words.get(hint), sprites = sprites(rule.art), art = rule.art }
end

for battle, boss in pairs(BOSSES) do
    boss.key = battle:lower()
    boss.name = words.read(boss.title)
    boss.picture = sf2.assets.sprite("core:ui/users/" .. boss.portrait)
    boss.glow_rgb = { tonumber(boss.glow:sub(2, 3), 16), tonumber(boss.glow:sub(4, 5), 16), tonumber(boss.glow:sub(6, 7), 16) }
    local seals, marks, top, used = {}, {}, boss.bars, 0
    for index, share in ipairs(SPLIT) do
        used = used + share
        local floor = index == #SPLIT and 0 or boss.bars - math.floor(boss.bars * used / 30 + 0.5)
        assert(floor < top, "Sealed boss " .. battle .. " has an empty seal")
        seals[index] = { top = top, floor = floor }
        if floor > 0 then table.insert(marks, 1, floor) end
        top = floor
    end
    boss.seals = seals
    boss.marks = marks
    -- The boss rising again after the intermission: a pulse in his colour.
    boss.resume_fx = sf2.fx.screen {
        id = "uw_seal_resume_" .. boss.key, trigger = "script",
        saturation = 0.7, tint = boss.glow, tint_strength = 0.25, vignette = 0.45,
        shake = 0.25, hold = 0.1, duration = 0.5,
        sound = { sound = boss.sound or RESUME_SOUND, volume = 0.8 },
    }
end

-- Saved progress -------------------------------------------------------------------------------

local function saved_seal(boss)
    local seal = tonumber((sf2.state.get(FIELD) or ","):match("," .. boss.key .. "=(%d+),"))
    return math.max(1, math.min(#boss.seals, seal or 1))
end

local function save_seal(boss, seal)
    local value = (sf2.state.get(FIELD) or ","):gsub("," .. boss.key .. "=%d+,", ",")
    if seal > 1 then value = value .. boss.key .. "=" .. seal .. "," end
    sf2.state.set { [FIELD] = value }
end

-- The seal reached in the last sealed fight, by boss key, until its result is saved.
local reached = {}

-- Rolled seal rules ------------------------------------------------------------------------------

local function clashes(a, b)
    for _, pair in ipairs(CLASHES) do
        if (pair[1] == a and pair[2] == b) or (pair[1] == b and pair[2] == a) then return true end
    end
    return false
end

local function fits(picks, name)
    for _, picked in ipairs(picks) do
        if picked == name or clashes(picked, name) then return false end
    end
    return true
end

-- A rule from `pool` that fits beside `taken` (for a seal, its number; nil for a pact): rolled
-- again until one fits, then after 32 misses the first that does.
local function pick(taken, pool, seal)
    local function ok(name)
        if LAST_SEAL_ONLY[name] and seal ~= #SPLIT then return false end
        return fits(taken, name)
    end
    for _ = 1, 32 do
        local name = pool[sf2.random.integer(ROLLS, 1, #pool)]
        if ok(name) then return name end
    end
    for _, name in ipairs(pool) do if ok(name) then return name end end
    error("No seal rule fits")
end

-- One run: three seal rules and three pacts, all different, as SHOWN entries, and the pact level.
local function roll()
    local plan, taken = { seals = {}, pacts = {}, level = 0 }, {}
    for seal = 1, #SPLIT do
        taken[#taken + 1] = pick(taken, ORDER, seal)
        plan.seals[seal] = SHOWN[taken[#taken]]
    end
    for index = 1, PACTS do
        taken[#taken + 1] = pick(taken, own_rules.pactable, nil)
        plan.pacts[index] = SHOWN[taken[#taken]]
    end
    return plan
end

-- An Omen spent: one seal ("seals") or pact ("pacts") rolled again, to a different rule.
local function reroll(plan, kind, index)
    local taken = { plan[kind][index].name }
    for _, list in ipairs({ plan.seals, plan.pacts }) do
        for _, shown in ipairs(list) do
            if shown ~= plan[kind][index] then taken[#taken + 1] = shown.name end
        end
    end
    plan[kind][index] = SHOWN[pick(taken, kind == "seals" and ORDER or own_rules.pactable, kind == "seals" and index or nil)]
    return plan[kind][index]
end

-- The run rolled for a boss's next fight, by boss key, until a fight with it ends. The pact level
-- picked last for the boss carries over to his next run (until the game restarts).
local rolled, last_level = {}, {}
local function plan_for(boss)
    if not rolled[boss.key] then
        rolled[boss.key] = roll()
        rolled[boss.key].level = last_level[boss.key] or 0
    end
    return rolled[boss.key]
end

-- The fight ---------------------------------------------------------------------------------------

-- The sealed fight being fought (one at a time), shared by the controller, the boss's guard rule
-- and the Prepare menu; nil outside it. Menu handlers have no combat authority, so they only leave
-- requests here (elixirs drunk, Momentum reset) for the controller's next tick.
local run = nil
local hold = raid_boss_abilities.seal_hold
local intermission, prepare = nil, nil

local function close_view(view)
    if view and sf2.ui.is_open(view) then sf2.ui.close(view) end
end

-- Prepare: the game's Prepare screen; the fight pauses under it. Opening it resets Momentum.
-- Healing lands just after the fight resumes; the timed elixirs when the next seal begins.
local function open_prepare()
    if not run or not run.hold_until or (prepare and sf2.ui.is_open(prepare)) then return end
    run.streak = 0
    run.bonus = 0
    local slots = {}
    for _, elixir in ipairs(elixirs.list) do
        slots[#slots + 1] = { id = elixir.id, item = elixir.item, count = sf2.profile.item_count(elixir.item),
            text = elixir.short, enabled = not run.drunk[elixir.id] }
    end
    prepare = sf2.ui.prepare {
        title = TEXT["prepare.title"],
        subtitle = fill(TEXT["prepare.subtitle"], run.seal - 1, run.rules[run.seal].title),
        items = slots, loadouts = true,
        note = TEXT["prepare.hint"] .. " " .. TEXT["prepare.momentum"],
        on_use = function(_, id)
            local elixir = elixirs.by_id[id]
            if not (elixir and run and run.hold_until and not run.drunk[id]) then return nil, false end
            if not sf2.profile.take_item(elixir.item) then return nil, false end
            run.drunk[id] = true
            if elixir.effect == "heal" then run.heal_in = 2 else run.waiting[elixir.effect] = true end
            return sf2.profile.item_count(elixir.item), false
        end,
        on_continue = close_view,
    }
end

-- During the intermission only: a small Prepare button under the health bars and the time left.
local function open_intermission()
    close_view(intermission)
    intermission = sf2.ui.open {
        id = "uw_seals_intermission", mount = "hud", placement = { anchor = "top", x = 0, y = 150 },
        root = { kind = "column", width = 220, height = 64, gap = 6, children = {
            { id = "time", kind = "progress", width = 200, height = 8, value = 1, style = { fill_color = run.boss.glow } },
            { id = "prepare", kind = "button", width = 200, height = 48, text = TEXT["hud.prepare"], on_click = open_prepare },
        } },
    }
end

-- The fight's phase: the rule of the seal being fought, or none (RULELESS). The Underworld's own
-- rules also learn which of them is on (content.underworld_seal_rules).
-- pacts: whether the run's pacts are on (while a seal is fought, with or without its rule).
-- The pause screen lists the pacts while they are on (fighter:set_pause_notes): their share of
-- the rewards, then each pact's seal, name and hint under the seal's own rule.
local function rule_phase(fighter, shown, pacts)
    own_rules.active = shown and own_rules.rules[shown.name] and shown.name or nil
    own_rules.pacts = pacts and run.pacts or nil
    fighter:set_phase(shown and shown.phase or RULELESS)
    local on = pacts and run.level > 0
    if on ~= run.notes_on then
        local notes = nil
        if on then
            notes = { { text = fill(META["pause.pacts"], math.floor(run.pact_bonus * 100 + 0.5)) } }
            for _, pact in ipairs(run.pact_list) do
                notes[#notes + 1] = { text = fill(META["pause.pact"], pact.title, pact.hint), icon = pact.sprites.intact }
            end
        end
        fighter:set_pause_notes(notes)
        run.notes_on = on
    end
end

-- The boss starts at his seal's top (a fight resumed at a later seal), in its rule's phase.
local function place_boss(fighter)
    local now = fighter:snapshot()
    if not (now and now.opponent and fighter.opponent) then return false end
    fighter.opponent:change_health(run.boss.seals[run.seal].top - now.opponent.health)
    rule_phase(fighter, run.rules[run.seal], true)
    return true
end

local function begin_fight(boss, fighter)
    local seal = saved_seal(boss)
    local plan = plan_for(boss)
    run = { boss = boss, seal = seal, first = seal, rules = plan.seals, level = plan.level, pacts = {}, pact_list = {},
        broken = {}, pact_bonus = PACT_BONUS * plan.level, frame = 0, streak = 0, bonus = 0, bonus_set = 0, drunk = {},
        waiting = {}, notes_on = false }
    for index = 1, plan.level do
        run.pacts[plan.pacts[index].name] = true
        run.pact_list[index] = plan.pacts[index]
    end
    hold.held = false
    hold.cooldown = boss.cooldowns and boss.cooldowns[sf2.saves.get("difficulty")] or nil
    -- From on_fight_begin the round starts in that phase; the first tick catches up otherwise.
    run.placed = place_boss(fighter)
end

local function break_seal(fighter, now)
    local index = run.seal
    local broken = run.boss.seals[index]
    -- Damage past the floor does not carry into the next seal.
    fighter.opponent:change_health(broken.floor - now.opponent.health)
    run.broken[#run.broken + 1] = run.rules[index].name
    run.seal = index + 1
    run.streak = run.streak + 1
    run.bonus = MOMENTUM * run.streak
    run.hold_until = run.frame + INTERMISSION
    hold.held = true
    -- The intermission has no seal rule.
    rule_phase(fighter, nil, false)
    -- The fight pauses while the seal shatters in the middle of the screen; the intermission's
    -- frames count from when it resumes.
    fighter:play_seal_break(run.rules[index].sprites.intact)
    open_intermission()
end

local function end_intermission(fighter, now)
    run.hold_until = nil
    hold.held = false
    close_view(prepare)
    close_view(intermission)
    intermission = nil
    local seal = run.boss.seals[run.seal]
    -- Whatever chipped him while he waited (bleeding, burns) is undone.
    fighter.opponent:change_health(seal.top - now.opponent.health)
    -- Elixirs drunk in Prepare that last a while start now, with the seal.
    local frames = elixirs.frames
    for _, elixir in ipairs(elixirs.list) do
        if run.waiting[elixir.effect] then fighter:show_status_icon(elixir.effect, elixir.icon, frames) end
    end
    if run.waiting.iron_skin then fighter:add_damage_shield("iron_skin", elixirs.iron_skin, frames) end
    if run.waiting.fury then run.fury_until = run.frame + frames end
    if run.waiting.clear_mind then run.clear_until = run.frame + frames end
    run.waiting = {}
    -- Clear Mind keeps the seal's rule off until it wears off (tick_fight); the pacts hold.
    rule_phase(fighter, not run.clear_until and run.rules[run.seal] or nil, true)
    sf2.fx.play(run.boss.resume_fx)
    fighter:shake(30, "opponent", 6)
end

local function tick_fight(fighter, tick)
    if not run then return end
    run.frame = tick.frame
    local now = fighter:snapshot()
    if not now or not now.round_active or not now.opponent or not fighter.opponent then return end
    if not run.placed then run.placed = place_boss(fighter) end
    if run.heal_in then
        run.heal_in = run.heal_in - 1
        if run.heal_in <= 0 then
            run.heal_in = nil
            fighter:change_health(elixirs.heal)
            fighter:set_model_color("#A8FFB0", 24)
        end
    end
    if run.hold_until then
        if run.frame >= run.hold_until then end_intermission(fighter, now)
        elseif intermission and sf2.ui.is_open(intermission) and run.frame % 3 == 0 then
            sf2.ui.update(intermission, "time", { value = math.max(0, run.hold_until - run.frame) / INTERMISSION })
        end
    else
        if run.clear_until and run.frame >= run.clear_until then
            run.clear_until = nil
            rule_phase(fighter, run.rules[run.seal], true)
        end
        local floor = run.boss.seals[run.seal].floor
        -- The last seal has no floor: the knockout ends the fight as usual.
        if floor > 0 and now.opponent.health <= floor then break_seal(fighter, now) end
    end
    -- Momentum changed by a break, or reset by Prepare; the pact's share stays.
    local bonus = run.bonus + run.pact_bonus
    if bonus ~= run.bonus_set and fighter:set_reward_bonus(bonus) then run.bonus_set = bonus end
end

-- How many times the player has beaten the boss's sealed fight (the profile's own count, which
-- includes wins from before the seals).
local function victories(boss)
    return boss.fight and sf2.profile.fight(boss.fight).wins or 0
end

-- The fight's result on Eclipse's results screen, in place of the game's tally: the seals as they
-- ended (broken ones cracked), where the next visit starts, the rewards with Momentum and the
-- pact (filled in by the host), the shards and Omen it gave, and the Seal Codex with the rules
-- this fight added. A surrender goes straight to the map as before.
-- Rules a fight has just added to a boss's codex, by boss key, until his codex page is next
-- opened: the tally pulses and they crack in on the page. Not saved; it is for the visit right
-- after the fight.
local fresh_codex = {}

local function show_results(boss, ended)
    local rules, seal, won = ended.rules, ended.seal, ended.won
    local first = ended.first or 1
    local stages = {}
    for index, stage in ipairs(rules) do
        local broken = won or index < seal
        -- Broken seals keep their colour under the cracks (the codex art). Those broken in this
        -- fight are stamped in turn; those broken before it (a resumed run) show settled, in ink.
        stages[index] = { name = stage.title, text = stage.hint,
            icon = broken and meta.pictures.codex[stage.art] or stage.sprites.intact,
            state = broken and "done" or (index == seal and "next" or "upcoming") }
        if broken then stages[index].fresh = index >= first end
    end
    local subtitle
    if won then
        subtitle = fill(TEXT["results.won_subtitle"], #boss.seals)
    else
        -- The same rule the battle_result handler saves.
        local restart = GO_BACK[sf2.saves.get("difficulty")] and math.max(1, seal - 1) or seal
        subtitle = restart == seal and fill(TEXT["results.lost_kept"], seal) or fill(TEXT["results.lost_back"], seal, restart)
    end
    -- The codex as it will be once the battle_result handler saves this fight's rules.
    local codex, new = meta.codex(boss.key), 0
    for _, name in ipairs(ended.broken) do
        if not codex[name] then
            codex[name] = true
            new = new + 1
            fresh_codex[boss.key] = fresh_codex[boss.key] or {}
            fresh_codex[boss.key][name] = true
        end
    end
    local known = meta.codex_count(codex)
    local lines = {}
    if won then lines[#lines + 1] = TEXT["results.won_note"] end
    lines[#lines + 1] = new > 0 and fill(META["results.codex_new"], known, meta.codex_size, new)
        or fill(META["results.codex"], known, meta.codex_size)
    -- Mod Lua has no pcall: a refusal is logged by the host and the game's tally shows instead.
    sf2.ui.results({
        title = won and TEXT["results.won"] or TEXT["results.lost"],
        subtitle = subtitle,
        portrait = boss.picture,
        stages = stages,
        bonus = ended.level > 0 and META["results.bonus_pact"] or TEXT["results.momentum"],
        note = table.concat(lines, "\n"),
        items = ended.spoils,
        -- The profile counts this fight's result after on_fight_end, so a win is added here.
        victories = victories(boss) + (won and 1 or 0),
        golden = known == meta.codex_size,
        hanko_info = { title = META["menu.wins_title"] },
    })
end

local function end_fight(fighter, event)
    if not run then return end
    local won = event.player_result == "win"
    -- The last seal breaks with the boss and counts for Momentum and the codex too.
    if won then
        fighter:set_reward_bonus(MOMENTUM * (run.streak + 1) + run.pact_bonus)
        run.broken[#run.broken + 1] = run.rules[run.seal].name
    end
    local boss = run.boss
    local arts = {}
    for _, name in ipairs(run.broken) do arts[#arts + 1] = RULES[name].art end
    local ended = { rules = run.rules, seal = run.seal, first = run.first, won = won, broken = run.broken, level = run.level,
        spoils = meta.spoils(arts, won) }
    -- Saved when the result arrives (install).
    reached[boss.key] = { seal = run.seal, broken = run.broken, pact = won and run.level or 0 }
    -- The next run rolls new rules.
    rolled[boss.key] = nil
    own_rules.active = nil
    own_rules.pacts = nil
    -- Eclipse drops them as the fight ends too; cleared here so nothing outlives the run.
    if run.notes_on then fighter:set_pause_notes(nil) end
    hold.held = false
    hold.cooldown = nil
    close_view(prepare)
    close_view(intermission)
    intermission = nil
    run = nil
    -- Last, so a refused screen cannot leave the run behind.
    show_results(boss, ended)
end

-- The round controller on the player: one per boss.
local function controller(boss)
    return {
        on_fight_begin = function(_, fighter) begin_fight(boss, fighter) end,
        on_tick = function(_, fighter, tick) tick_fight(fighter, tick) end,
        on_damage_dealing = function(_, fighter)
            if run and run.fury_until and run.frame < run.fury_until then
                fighter:scale_outgoing_damage(elixirs.fury)
            end
        end,
        on_fight_end = function(_, fighter, event) end_fight(fighter, event) end,
    }
end

-- "#RRGGBB" between white (0) and the boss's glow (1).
local function glow(boss, strength)
    local channels = {}
    for index, value in ipairs(boss.glow_rgb) do
        channels[index] = math.floor(255 + (value - 255) * strength + 0.5)
    end
    return string.format("#%02X%02X%02X", channels[1], channels[2], channels[3])
end

-- On the boss: no damage while the fight holds him, his AI held (he starts nothing, whatever his
-- tactic), and a glow that pulses and grows as he gathers himself. No move plays: core Standup
-- needs him on the floor, and play_move takes only moves a mod registers.
local guard = {
    on_tick = function(_, fighter, tick)
        if not run then return end
        if not run.hold_until then
            if run.ai_held then
                run.ai_held = false
                fighter:set_ai_held(false)
            end
            if run.glowing then
                run.glowing = false
                fighter:clear_model_color()
            end
            return
        end
        if not run.ai_held then
            run.ai_held = true
            fighter:set_ai_held(true)
        end
        if tick.frame % 6 ~= 0 then return end
        run.glowing = true
        local grown = 1 - math.max(0, run.hold_until - tick.frame) / INTERMISSION
        local wave = (tick.frame % 40) / 20
        local pulse = wave < 1 and wave or 2 - wave
        fighter:set_model_color(glow(run.boss, grown * (0.4 + 0.6 * pulse)), 8)
    end,
    on_damage_resolving = function(_, fighter)
        if run and run.hold_until then fighter:scale_incoming_damage(0) end
    end,
    -- Hits do not make him flinch while he gathers himself.
    on_hit_pre_crit = function(_, fighter, event)
        if run and run.hold_until and event.target == "self" then fighter:set_hit_armored(true) end
    end,
}

for _, boss in pairs(BOSSES) do boss.controller = controller(boss) end

-- Registration ---------------------------------------------------------------------------------

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

-- The first rule group with this description in the generated Underworld rows.
local function rule_group(description)
    for _, zone in ipairs(require("content.underworld_data").zones) do
        for _, battle in ipairs(zone.battles) do
            for _, fight in ipairs(battle.fights) do
                for _, rule in ipairs(fight.rules or {}) do
                    if rule.kind == "group" and rule.description == description then return copy(rule) end
                end
            end
        end
    end
    error("No Underworld rule group " .. description)
end

-- content.underworld calls this for every fight it registers. fight: the fresh table about to go
-- to sf2.battles.register; rule_table resolves a generated rule row (its description key).
-- The rule tables every sealed fight shares: every seal rule, each in its own phase (any of them
-- can be rolled), the Lua dispatchers and the boss's guard. Built once, so Eclipse registers them
-- once for all the sealed fights (a mod has 4096 registrations).
local shared = nil
local function shared_rules(rule_table)
    if shared then return shared end
    shared = {}
    for _, name in ipairs(ORDER) do
        local rule = RULES[name]
        if rule.rule then
            local group = rule_group(rule.rule)
            group.phases = { PHASES[name] }
            shared[#shared + 1] = rule_table(group)
        else
            -- The rule's text, and its built-in rules if it has any (a group may be empty).
            shared[#shared + 1] = { kind = "group", phases = { PHASES[name] },
                description = SHOWN[name].description, rules = copy(rule.native or {}) }
        end
    end
    -- The Lua parts of the Underworld's own rules, one behavior per side.
    for _, entry in ipairs(own_rules.behaviors) do shared[#shared + 1] = entry end
    shared[#shared + 1] = { kind = "behavior", behavior = guard, target = "opponent" }
    return shared
end

local function apply(battle, fight, rule_table)
    local boss = BOSSES[battle]
    if not boss or fight.name ~= "1" then return end
    local opponent = assert(fight.opponents[1], "Sealed Underworld fight " .. battle .. " has no boss")
    opponent.health_bars = boss.bars
    -- One visible bar, so every seal mark shows on it.
    opponent.visible_health_bars = 1
    opponent.health_marks = boss.marks
    -- Arkhos has a sealed tactic of his own; everyone else keeps his.
    if boss.tactic then opponent.tactic = boss.tactic end
    for _, rule in ipairs(shared_rules(rule_table)) do fight.rules[#fight.rules + 1] = rule end
    fight.rules[#fight.rules + 1] = { kind = "behavior", behavior = boss.controller, target = "player", controls_outcome = true }
end

-- The pre-fight menu ------------------------------------------------------------------------------

-- A line for the next refresh of the challenge screen (an Omen spent, an elixir brewed), then gone.
local notice = nil
-- The challenge screen's codex page: open or not, and the seal rule selected on it.
local codex_page = { open = false, selected = nil }

-- The rules of each seal colour, in codex order: the codex page's rows and the tally's groups.
local BY_ART = {}
for _, art in ipairs(meta.arts) do BY_ART[art] = {} end
for _, name in ipairs(meta.codex_order) do
    local list = BY_ART[RULES[name].art]
    list[#list + 1] = name
end

-- The codex page: one row per seal colour, a rule's seal cracked once broken under this boss
-- (in its colour, its name under it), a pale ghost until then. Rules the last fight added crack
-- in as the page opens. A seal is always selected, so its words show at the foot: the one picked,
-- else the first found, else the first.
local function codex_grid(boss, codex)
    local fresh = fresh_codex[boss.key] or {}
    if not codex_page.selected then
        for _, name in ipairs(meta.codex_order) do
            if codex[name] then
                codex_page.selected = name
                break
            end
        end
        codex_page.selected = codex_page.selected or BY_ART[meta.arts[1]][1]
    end
    local rows = {}
    for _, art in ipairs(meta.arts) do
        local row = {}
        for _, name in ipairs(BY_ART[art]) do
            local known = codex[name] == true
            row[#row + 1] = { id = name, lit = known, selected = name == codex_page.selected,
                icon = known and meta.pictures.codex[art] or SHOWN[name].sprites.intact,
                label = known and SHOWN[name].title or nil, fresh = fresh[name] == true }
        end
        rows[#rows + 1] = row
    end
    local selected = SHOWN[codex_page.selected]
    return {
        title = META["menu.codex_title"],
        count = fill(META["menu.codex_count"], meta.codex_count(codex), meta.codex_size),
        caption = selected.title,
        text = codex[selected.name] and selected.hint or META["menu.codex_hint"],
        rows = rows,
    }
end

-- The challenge screen's content for the boss's next run, pictures first: the seals on the scroll
-- (a red stamp on rules new to his codex; an Omen control on each seal still to break, the Omens
-- held over them), or his codex page; on the card the codex tally, the stakes (Momentum's rate and
-- the pact's share), the info line, the three pacts to take, the elixirs with their shard costs,
-- and the shard pouch. Everything the player can select says what it is on the info line.
local function menu_content(boss)
    local plan = plan_for(boss)
    local next_seal = saved_seal(boss)
    local codex = meta.codex(boss.key)
    local omens = meta.omens()
    local stages = {}
    for index, shown in ipairs(plan.seals) do
        stages[index] = { name = shown.title, text = shown.hint,
            stamp = not codex[shown.name] and META["menu.new_stamp"] or nil,
            icon = index < next_seal and meta.pictures.codex[shown.art] or shown.sprites.intact,
            state = index < next_seal and "done" or (index == next_seal and "next" or "upcoming") }
        -- A seal still to break can be rolled again for an Omen: pressed once to arm, again to spend.
        if index >= next_seal then
            stages[index].action = { icon = meta.pictures.omen, text = "1", confirm = META["menu.reroll_confirm"],
                enabled = omens > 0, reason = META["menu.no_omens"] }
        end
    end
    local tally = {}
    for _, art in ipairs(meta.arts) do
        local filled = 0
        for _, name in ipairs(BY_ART[art]) do if codex[name] then filled = filled + 1 end end
        tally[#tally + 1] = { color = meta.ink[art], count = #BY_ART[art], filled = filled }
    end
    local rate = math.floor(MOMENTUM * 100 + 0.5)
    local stakes = { { icon = meta.pictures.momentum, text = fill(META["menu.rate"], rate),
        info = { title = TEXT["results.momentum"], text = fill(META["menu.momentum_info"], rate) } } }
    if plan.level > 0 then
        local share = math.floor(PACT_BONUS * plan.level * 100 + 0.5)
        stakes[#stakes + 1] = { icon = meta.pictures.pact, text = fill(META["menu.share"], share),
            info = { title = META["menu.pact_title"], text = fill(META["menu.pact_info"], plan.level, share) } }
    end
    local each = math.floor(PACT_BONUS * 100 + 0.5)
    local tag = fill(META["menu.share"], each)
    -- Each tile says what taking it does (or did), not only its rule, as pressing it takes it.
    local choices = {}
    for index, shown in ipairs(plan.pacts) do
        local chosen = index <= plan.level
        choices[index] = { id = "pact" .. index, icon = shown.sprites.intact, name = shown.title,
            chosen = chosen, mark = ROMAN[index], tag = tag,
            info = { title = shown.title,
                text = fill(META[chosen and "menu.pact_choice_taken" or "menu.pact_choice_info"], shown.hint, each) } }
    end
    local held = {}
    for _, elixir in ipairs(elixirs.list) do
        local check = meta.can_brew(elixir)
        held[#held + 1] = { item = elixir.item, count = sf2.profile.item_count(elixir.item), cost = meta.cost(elixir),
            info = { title = elixir.name, text = elixir.short }, confirm = META["menu.brew_confirm"],
            enabled = check == "brewed", reason = check ~= "brewed" and fill(META["menu." .. check], elixir.name) or nil }
    end
    local pouch, counts = {}, meta.shard_counts()
    for index, art in ipairs(meta.arts) do
        pouch[index] = { icon = meta.pictures.shard[art], count = counts[index],
            info = { title = meta.shard_names[art], text = META["menu.shard_info"] } }
    end
    local known = meta.codex_count(codex)
    local content = {
        title = boss.name,
        portrait = boss.picture,
        -- The hanko on the portrait: stamped once per win, an empty ring before the first; gold
        -- once every seal rule is in his codex.
        victories = victories(boss),
        golden = known == meta.codex_size,
        hanko_info = { title = META["menu.wins_title"], text = fill(META["menu.wins_info"], boss.name) },
        stages = stages,
        action_stock = { icon = meta.pictures.omen, count = omens },
        tally = tally,
        -- The tally pulses after a fight that added rules, until the codex page shows them.
        tally_new = fresh_codex[boss.key] ~= nil,
        stakes = stakes,
        choices = choices,
        choices_label = META["menu.label_pacts"],
        -- Until a pact is taken, the info line (with nothing selected) says what pacts are; after,
        -- it falls back to the next seal and the pact stake explains the share.
        info = plan.level == 0 and { title = META["menu.label_pacts"], text = fill(META["menu.pacts_intro"], each) } or nil,
        items = held,
        items_label = META["menu.label_elixirs"],
        pouch = pouch,
        loadouts = true,
        note = notice,
    }
    notice = nil
    if codex_page.open then
        content.grid = codex_grid(boss, codex)
        -- Shown cracking in once; later refreshes draw them settled.
        fresh_codex[boss.key] = nil
    end
    return content
end

local function open_menu(boss, request)
    local plan = plan_for(boss)
    codex_page.open, codex_page.selected = false, nil
    local content = menu_content(boss)
    local function refresh(view) sf2.ui.refresh(view, menu_content(boss)) end
    content.on_fight = function(view)
        close_view(view)
        if not sf2.story.resume_fight(request) then sf2.story.cancel_fight(request) end
    end
    -- Back closes the codex page first, then the screen.
    content.on_back = function(view)
        if codex_page.open then
            codex_page.open = false
            refresh(view)
            return
        end
        close_view(view)
        sf2.story.cancel_fight(request)
    end
    -- The codex tally opens and closes the codex page, and the page's own cross closes it; a seal
    -- on it is selected for its words.
    content.on_tally = function(view)
        codex_page.open = not codex_page.open
        refresh(view)
    end
    content.on_close_grid = function(view)
        codex_page.open = false
        refresh(view)
    end
    content.on_cell = function(view, id)
        codex_page.selected = id
        refresh(view)
    end
    -- A pact taken (with the ones before it) or given back (with the ones after it).
    content.on_choice = function(view, id)
        local index = tonumber(id:match("%d+")) or 0
        plan.level = plan.level >= index and index - 1 or index
        last_level[boss.key] = plan.level
        refresh(view)
    end
    -- A seal still to break, rolled again for an Omen. The host runs this only on the second
    -- press of its control, and never while no Omen is held (the control then says why).
    content.on_action = function(view, index)
        if index < saved_seal(boss) then return end
        if not meta.spend_omen() then
            notice = META["menu.no_omens"]
        else
            notice = fill(META["menu.rerolled"], reroll(plan, "seals", index).title)
        end
        refresh(view)
    end
    -- An elixir brewed from shards.
    content.on_item = function(view, index)
        local elixir = elixirs.list[index]
        if not elixir then return end
        local result = meta.brew(elixir)
        notice = fill(META["menu." .. (result == "brewed" and "brewed" or result)], elixir.name)
        refresh(view)
    end
    sf2.ui.challenge(content)
end

-- A sealed boss's before_fight step for content.underworld_story (only one handler per fight, so
-- the story calls it after its first-entry dialogue), or nil for other bosses. Holds the fight.
local function menu(battle)
    local boss = BOSSES[battle]
    if not boss then return nil end
    return function(request)
        open_menu(boss, request)
        return nil
    end
end

-- After registration: save each sealed fight's progress once its result arrives. Bosses with no
-- story of their own (content.underworld_story_data) get their pre-fight menu here.
local function install(underworld)
    local stories = require("content.underworld_story_data").bosses
    local by_fight = {}
    for battle, boss in pairs(BOSSES) do
        local fight = assert(underworld.by_battle[battle] and underworld.by_battle[battle]["1"],
            "Missing sealed Underworld fight " .. battle)
        by_fight[fight.id] = boss
        boss.fight = fight.id
        if not stories[battle] then sf2.story.before_fight(fight.handle, menu(battle)) end
    end
    sf2.story.on("battle_result", function(event)
        local boss = by_fight[event.fight]
        if not boss then return end
        local ended = reached[boss.key]
        reached[boss.key] = nil
        if event.outcome == "win" then
            save_seal(boss, 1)
        elseif ended then
            save_seal(boss, GO_BACK[sf2.saves.get("difficulty")] and math.max(1, ended.seal - 1) or ended.seal)
        end
        -- The rules broken join the boss's codex; a win raises his best pact.
        if ended then meta.record(boss.key, ended.broken, ended.pact) end
    end)
end

return { apply = apply, menu = menu, install = install }
