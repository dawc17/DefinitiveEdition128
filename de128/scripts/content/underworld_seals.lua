local sf2 = require("sf2")
local words = require("content.text")
local elixirs = require("content.underworld_elixirs")
local raid_boss_abilities = require("content.raid_boss_abilities")
local own_rules = require("content.underworld_seal_rules")

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
-- The Underworld's own seal rules (content.underworld_seal_rules): built-in rules and Lua behaviors,
-- with their hint text in de128.uw_seals.hint.<name>.
for name, rule in pairs(own_rules) do
    assert(not RULES[name], "Seal rule " .. name .. " is defined twice")
    RULES[name] = rule
end

-- Seals split the boss's health 8:10:12 from the top (later seals larger), rounded to bars:
-- 30 bars break at 22 and 12.
local SPLIT = { 8, 10, 12 }

-- Sealed bosses by archive battle name. Only the normal fight (fight "1") is sealed; Power Mode is
-- left alone. bars: the boss's health in health bars (his template's, or the fight's own). seals:
-- three RULES names, mildest first; the last is usually the rule his Power Mode fight is known
-- for. portrait: core:ui/users/<name>. glow: the colour he gathers himself in between seals.
-- sound: the cue as he rises again (default the raid's fight-ready call). tactic and cooldowns:
-- Arkhos only, his Rat Wave cooldown in frames by difficulty (Medium is his usual). Every boss
-- keeps his own tactic otherwise and is held between seals with fighter:set_ai_held.
local BOSSES = {
    -- Tier 1
    BOSS_1 = { bars = 15, title = "RAIDBOSS_FIRE_TITLE", portrait = "boss_fire", glow = "#FF8A3D",
        seals = { "hard_ground", "mounting_wrath", "hot_ground" } },
    BOSS_SON_OF_HEAVEN = { bars = 16, title = "RAIDBOSS_CNY_Title", portrait = "new_man_shuang_gou", glow = "#FFD24A",
        seals = { "kicks_only", "draining_ground", "burning" } },
    BOSS_2 = { bars = 17, title = "RAIDBOSS_Stone_Title", portrait = "boss_crystal", glow = "#9FE3FF",
        seals = { "hard_ground", "unflinching", "earthquake" } },
    BOSS_PUPPETEER = { bars = 18, title = "RAIDBOSS_PUPPETEER_TITLE", portrait = "character_puppeteer", glow = "#C08CFF",
        seals = { "undertow", "fragile_ground", "inverted" } },
    BOSS_3 = { bars = 19, title = "RAIDBOSS_Mushroom_Title", portrait = "boss_mushroom", glow = "#B6FF5C",
        seals = { "no_jumps", "breathless", "draining_ground" } },
    BOSS_LAMB_VULCAN = { bars = 21, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb_vulcan", glow = "#FF6A2A",
        seals = { "bare_hands", "burning", "hot_ground" } },
    BOSS_4 = { bars = 23, title = "RAIDBOSS_Vortex_Title", portrait = "boss_vortex", glow = "#5CD6FF",
        seals = { "gale", "earthquake", "inverted" } },
    BOSS_5 = { bars = 25, title = "RAIDBOSS_Fatum_Title", portrait = "boss_fatum", glow = "#B07CFF",
        seals = { "no_double", "measured_strikes", "hidden_health" } },
    BOSS_LAMB_FUNGUS = { bars = 27, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb_fungus", glow = "#B6FF5C",
        seals = { "no_kicks", "relentless", "hidden_health" } },
    BOSS_WOLF_WIND = { bars = 29, title = "RAIDBOSS_WIND_WOLF", portrait = "boss_wind_wolf_new", glow = "#CFFFF2",
        seals = { "no_jumps", "patience", "inverted" } },
    BOSS_6 = { bars = 30, title = "RAIDBOSS_Arkhos_Title", portrait = "boss_arkhos", glow = "#7CFF8A",
        seals = { "mix_it_up", "draining_ground", "darkness" }, sound = "snd_rats_ring",
        tactic = raid_boss_abilities.arkhos_sealed,
        cooldowns = { easy = 690, medium = 600, hard = 540, very_hard = 480 } },
    BOSS_7 = { bars = 31, title = "RAIDBOSS_Hoaxen_Title", portrait = "boss_hoaxen", glow = "#4CFFD0",
        seals = { "undertow", "no_blocks", "inverted" } },
    BOSS_8 = { bars = 33, title = "RAIDBOSS_Hunger_Title", portrait = "boss_hunger", glow = "#FF4A4A",
        seals = { "desperation", "withering", "earthquake" } },
    BOSS_LAMB_HUNGER = { bars = 35, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb_hunger", glow = "#FF5A5A",
        seals = { "no_double", "glass_cannon", "darkness" } },
    BOSS_9 = { bars = 37, title = "RAIDBOSS_War_Title", portrait = "boss_war", glow = "#FF7040",
        seals = { "no_blocks", "mounting_wrath", "fragile_ground" } },
    BOSS_BANSHEE = { bars = 39, title = "RAIDBOSS_Witch_banshee_Title", portrait = "witch_halloween_ghost", glow = "#A8D8FF",
        seals = { "vanishing", "earthquake", "darkness" } },
    BOSS_10 = { bars = 41, title = "RAIDBOSS_Tenebris_Title", portrait = "boss_tenebris", glow = "#9A6CFF",
        seals = { "hard_ground", "withering", "moonless" } },
    -- His first fight's own avatar (boss_architect_hummer_new) has no portrait.
    BOSS_ARCHITECT_1 = { bars = 42, title = "RAIDBOSS_ARCHITECT_TITLE", portrait = "boss_architect", glow = "#FFC060",
        seals = { "thorny_walls", "no_blocks", "inverted" } },
    BOSS_11 = { bars = 43, title = "RAIDBOSS_GATEKEEPER_TITLE", portrait = "boss_gatekeeper", glow = "#5CA8FF",
        seals = { "no_double", "patience", "hidden_health" } },
    BOSS_ARCHITECT_2 = { bars = 45, title = "RAIDBOSS_ARCHITECT_TITLE", portrait = "boss_architect", glow = "#FFC060",
        seals = { "thorny_walls", "earthquake", "hidden_health" } },
    BOSS_12 = { bars = 47, title = "RAIDBOSS_SATURN_TITLE", portrait = "boss_saturn", glow = "#8CF0FF",
        seals = { "overcharge", "burning", "inverted" } },
    BOSS_13 = { bars = 49, title = "BLACKNESS_TITLE", portrait = "boss_blackness", glow = "#B05CFF",
        seals = { "no_blocks", "vengeance", "moonless" } },
    BOSS_14 = { bars = 50, title = "RAIDBOSS_HUNTER_TITLE", portrait = "hunter_raid", glow = "#6AB8FF",
        seals = { "slow_hands", "fragile_ground", "darkness" } },
    -- The event bosses
    BOSS_WHISPER = { bars = 15, title = "RAIDBOSS_WHISPER_TITLE", portrait = "boss_whisper_24", glow = "#FF6AD8",
        seals = { "no_double", "tricksters_hex", "darkness" } },
    BOSS_SON_OF_THE_SUN = { bars = 16, title = "RAIDBOSS_CNY24_Title", portrait = "boss_son_of_the_sun", glow = "#FFC83A",
        seals = { "desperation", "hot_ground", "darkness" } },
    BOSS_RAVANA = { bars = 17, title = "BOSS_RAVANA_Title", portrait = "boss_ravana", glow = "#FF9A3A",
        seals = { "mix_it_up", "burning", "no_blocks" } },
    BOSS_ADANTI = { bars = 19, title = "BOSS_BISON_Title", portrait = "boss_bison", glow = "#7CC8FF",
        seals = { "unflinching", "earthquake", "hot_ground" } },
    BOSS_COUNTESS = { bars = 20, title = "RAIDBOSS_Witch_old_Title", portrait = "witch_halloween_old", glow = "#D84A6A",
        seals = { "no_jumps", "breathless", "inverted" } },
    BOSS_MORGANA = { bars = 22, title = "RAIDBOSS_Witch_young_Title", portrait = "boss_morgana", glow = "#9CFF6A",
        seals = { "no_double", "fragile_ground", "tricksters_hex" } },
    BOSS_LAMB = { bars = 25, title = "RAIDBOSS_LAMB_Title", portrait = "boss_lamb", glow = "#C85CFF",
        seals = { "glass_cannon", "hot_ground", "hidden_health" } },
    BOSS_RAKSHASA = { bars = 28, title = "RAIDBOSS_RAKSHASA", portrait = "boss_rakshasa", glow = "#FFA040",
        seals = { "no_double", "measured_strikes", "darkness" } },
    BOSS_HALLOWEEN_PUPPETEER = { bars = 30, title = "RAIDBOSS_PUPPETEER_TITLE", portrait = "boss_puppeteer_hw21", glow = "#FF9A2A",
        seals = { "kicks_only", "draining_ground", "inverted" } },
    BOSS_FARADEYA = { bars = 34, title = "RAIDBOSS_FARADAY_Title", portrait = "character_faradaya", glow = "#8C9CFF",
        seals = { "overcharge", "earthquake", "withering" } },
    BOSS_BERSTUUK = { bars = 36, title = "RAIDBOSS_BERSTUUK_TITLE", portrait = "boss_berstuuk", glow = "#FFB04A",
        seals = { "slow_hands", "no_blocks", "fragile_ground" } },
    BOSS_DANDY = { bars = 40, title = "RAIDBOSS_DANDY_Title", portrait = "character_samson", glow = "#9CC8FF",
        seals = { "no_jumps", "vengeance", "withering" } },
    BOSS_SHURALE = { bars = 42, title = "RAIDBOSS_SHURALE_TITLE", portrait = "boss_shurale_ny22", glow = "#9CEBFF",
        seals = { "gale", "burning", "inverted" } },
    -- No Power Mode
    BOSS_INVISIBLE = { bars = 32, title = "RAIDBOSS_Invisible_Title", portrait = "man_invisible", glow = "#E0E8FF",
        seals = { "no_blocks", "vanishing", "hidden_health" } },
    BOSS_HAUNTED_PRINCE = { bars = 46, title = "RAIDBOSS_PRINCE_TITLE", portrait = "character_prince_evil", glow = "#8A5CFF",
        seals = { "patience", "withering", "darkness" } },
}

local INTERMISSION = 300   -- frames between seals (5 s of fight time)
local RULELESS = 10        -- phase RULELESS + n is seal n without its rule (intermission, Clear Mind)
local MOMENTUM = 0.1       -- reward bonus per seal
local FIELD = "uw_seal_progress"
local RESUME_SOUND = "snd_raid_fight_ready"
-- Difficulties where a loss sends the boss back one seal.
local GO_BACK = { hard = true, very_hard = true }

-- Words from Eclipse's English text (de128.uw_seals.*), read once while loading.
local function say(key) return words.read("de128.uw_seals." .. key) end
local TEXT = {}
for _, key in ipairs({ "hud.prepare", "prepare.title", "prepare.subtitle", "prepare.hint", "prepare.momentum",
    "menu.subtitle", "menu.momentum", "menu.elixirs_hint", "results.won", "results.lost", "results.won_subtitle",
    "results.lost_kept", "results.lost_back", "results.won_note", "results.momentum" }) do
    TEXT[key] = say(key)
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

for battle, boss in pairs(BOSSES) do
    boss.key = battle:lower()
    boss.name = words.read(boss.title)
    boss.picture = sf2.assets.sprite("core:ui/users/" .. boss.portrait)
    boss.glow_rgb = { tonumber(boss.glow:sub(2, 3), 16), tonumber(boss.glow:sub(4, 5), 16), tonumber(boss.glow:sub(6, 7), 16) }
    assert(#boss.seals == #SPLIT, "Sealed boss " .. battle .. " needs " .. #SPLIT .. " seals")
    local seals, marks, top, used = {}, {}, boss.bars, 0
    for index, name in ipairs(boss.seals) do
        local rule = assert(RULES[name], "Unknown seal rule " .. tostring(name))
        used = used + SPLIT[index]
        local floor = index == #boss.seals and 0 or boss.bars - math.floor(boss.bars * used / 30 + 0.5)
        assert(floor < top, "Sealed boss " .. battle .. " has an empty seal")
        -- A copied Power Mode rule shows the game's own text; the Underworld's own rules their hint.
        local hint = rule.rule or "de128.uw_seals.hint." .. name
        seals[index] = { name = name, rule = rule, top = top, floor = floor,
            title = say("rule." .. name), hint = words.read(hint), description = words.get(hint),
            sprites = sprites(rule.art) }
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
        subtitle = fill(TEXT["prepare.subtitle"], run.seal - 1, run.boss.seals[run.seal].title),
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

-- A fight resumed at a later seal: the boss starts at its top, in its phase.
local function place_boss(fighter)
    local now = fighter:snapshot()
    if not (now and now.opponent and fighter.opponent) then return false end
    fighter.opponent:change_health(run.boss.seals[run.seal].top - now.opponent.health)
    fighter:set_phase(run.seal)
    return true
end

local function begin_fight(boss, fighter)
    local seal = saved_seal(boss)
    run = { boss = boss, seal = seal, frame = 0, streak = 0, bonus = 0, bonus_set = 0, drunk = {}, waiting = {} }
    hold.held = false
    hold.cooldown = boss.cooldowns and boss.cooldowns[sf2.saves.get("difficulty")] or nil
    -- From on_fight_begin the round starts in that phase; the first tick catches up otherwise.
    run.placed = seal == 1 or place_boss(fighter)
end

local function break_seal(fighter, now)
    local index = run.seal
    local broken = run.boss.seals[index]
    -- Damage past the floor does not carry into the next seal.
    fighter.opponent:change_health(broken.floor - now.opponent.health)
    run.seal = index + 1
    run.streak = run.streak + 1
    run.bonus = MOMENTUM * run.streak
    run.hold_until = run.frame + INTERMISSION
    hold.held = true
    -- The intermission has no seal rule.
    fighter:set_phase(RULELESS + run.seal)
    -- The fight pauses while the seal shatters in the middle of the screen; the intermission's
    -- frames count from when it resumes.
    fighter:play_seal_break(broken.sprites.intact)
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
    -- Clear Mind keeps the rule-free phase until it wears off (tick_fight).
    if not run.clear_until then fighter:set_phase(run.seal) end
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
            fighter:set_phase(run.seal)
        end
        local floor = run.boss.seals[run.seal].floor
        -- The last seal has no floor: the knockout ends the fight as usual.
        if floor > 0 and now.opponent.health <= floor then break_seal(fighter, now) end
    end
    -- Momentum changed by a break, or reset by Prepare.
    if run.bonus ~= run.bonus_set and fighter:set_reward_bonus(run.bonus) then run.bonus_set = run.bonus end
end

-- How many times the player has beaten the boss's sealed fight (the profile's own count, which
-- includes wins from before the seals).
local function victories(boss)
    return boss.fight and sf2.profile.fight(boss.fight).wins or 0
end

-- The fight's result on Eclipse's results screen, in place of the game's tally: the seals as they
-- ended (broken ones cracked), where the next visit starts, and the rewards with Momentum, which
-- the host fills in. A surrender goes straight to the map as before.
local function show_results(boss, seal, won)
    local stages = {}
    for index, stage in ipairs(boss.seals) do
        local broken = won or index < seal
        stages[index] = { name = stage.title, text = stage.hint,
            icon = broken and stage.sprites.broken or stage.sprites.intact,
            state = broken and "done" or (index == seal and "next" or "locked") }
    end
    local subtitle
    if won then
        subtitle = fill(TEXT["results.won_subtitle"], #boss.seals)
    else
        -- The same rule the battle_result handler saves.
        local restart = GO_BACK[sf2.saves.get("difficulty")] and math.max(1, seal - 1) or seal
        subtitle = restart == seal and fill(TEXT["results.lost_kept"], seal) or fill(TEXT["results.lost_back"], seal, restart)
    end
    -- Mod Lua has no pcall: a refusal is logged by the host and the game's tally shows instead.
    sf2.ui.results({
        title = won and TEXT["results.won"] or TEXT["results.lost"],
        subtitle = subtitle,
        portrait = boss.picture,
        stages = stages,
        bonus = TEXT["results.momentum"],
        note = won and TEXT["results.won_note"] or nil,
        -- The profile counts this fight's result after on_fight_end, so a win is added here.
        victories = victories(boss) + (won and 1 or 0),
    })
end

local function end_fight(fighter, event)
    if not run then return end
    local won = event.player_result == "win"
    -- The last seal breaks with the boss and counts for Momentum too.
    if won then fighter:set_reward_bonus(MOMENTUM * (run.streak + 1)) end
    local boss, seal = run.boss, run.seal
    reached[boss.key] = seal
    hold.held = false
    hold.cooldown = nil
    close_view(prepare)
    close_view(intermission)
    intermission = nil
    run = nil
    -- Last, so a refused screen cannot leave the run behind.
    show_results(boss, seal, won)
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
    for index, seal in ipairs(boss.seals) do
        if seal.rule.rule then
            local group = rule_group(seal.rule.rule)
            group.phases = { index }
            fight.rules[#fight.rules + 1] = rule_table(group)
        else
            -- The seal's text, and its built-in rules if it has any (a group may be empty).
            fight.rules[#fight.rules + 1] = { kind = "group", phases = { index },
                description = seal.description, rules = copy(seal.rule.native or {}) }
            -- Behaviors check the phase themselves (content.underworld_seal_rules).
            for _, entry in ipairs(seal.rule.behaviors or {}) do
                fight.rules[#fight.rules + 1] = { kind = "behavior", behavior = entry.behavior,
                    target = entry.target, parameters = { phase = index } }
            end
        end
    end
    fight.rules[#fight.rules + 1] = { kind = "behavior", behavior = boss.controller, target = "player", controls_outcome = true }
    fight.rules[#fight.rules + 1] = { kind = "behavior", behavior = guard, target = "opponent" }
end

-- The pre-fight menu ------------------------------------------------------------------------------

local function open_menu(boss, request)
    local next_seal = saved_seal(boss)
    local stages = {}
    for index, seal in ipairs(boss.seals) do
        stages[index] = { name = seal.title, text = seal.hint,
            icon = index < next_seal and seal.sprites.broken or seal.sprites.intact,
            state = index < next_seal and "done" or (index == next_seal and "next" or "locked") }
    end
    local held = {}
    for _, elixir in ipairs(elixirs.list) do
        held[#held + 1] = { item = elixir.item, count = sf2.profile.item_count(elixir.item) }
    end
    sf2.ui.challenge {
        title = boss.name,
        subtitle = fill(TEXT["menu.subtitle"], #boss.seals),
        portrait = boss.picture,
        -- The hanko on the portrait: stamped once per win, an empty ring before the first.
        victories = victories(boss),
        stages = stages,
        items = held,
        items_note = TEXT["menu.elixirs_hint"],
        loadouts = true,
        note = fill(TEXT["menu.momentum"], math.floor(MOMENTUM * 100 + 0.5)),
        on_fight = function(view)
            close_view(view)
            if not sf2.story.resume_fight(request) then sf2.story.cancel_fight(request) end
        end,
        on_back = function(view)
            close_view(view)
            sf2.story.cancel_fight(request)
        end,
    }
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
        local seal = reached[boss.key]
        reached[boss.key] = nil
        if event.outcome == "win" then
            save_seal(boss, 1)
        elseif seal then
            save_seal(boss, GO_BACK[sf2.saves.get("difficulty")] and math.max(1, seal - 1) or seal)
        end
    end)
end

return { apply = apply, menu = menu, install = install }
