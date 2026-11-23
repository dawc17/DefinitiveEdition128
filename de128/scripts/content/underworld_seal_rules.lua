local sf2 = require("sf2")

-- The Underworld's own seal rules (content.underworld_seals), beside the 14 it copies from the
-- Power Mode fights. Each entry is one seal's rule:
--   art       the Gates of Shadows seal colour, one per kind of rule (as in content.underworld_seals);
--   native    built-in rules switched on with the seal (a phased group, which also carries the text);
--   player, opponent  Lua handlers run on that side while the rule is on;
--   state     a function making a handler's fresh state (one per rule and side);
--   round     the state resets every round, with the effects the game clears between rounds
--             (inverted controls, meters, cloaks, locked buttons).
-- Title and hint text: de128.uw_seals.rule.<name> and de128.uw_seals.hint.<name> in Eclipse's eng.toml.
--
-- Seals are rolled every run, so a sealed fight registers every rule. To stay under a fight's 64
-- rules the Lua parts run through two behaviors, one per side (behaviors below), which call the
-- handlers of the rule that is on (active, set by content.underworld_seals as the seal changes).
-- on_tick reaches every handler, with on = false for the rules that are off, so a rule can undo
-- what it left on when its seal breaks, the intermission starts or Star Clarity lifts it.

local ICON = {
    gale = sf2.assets.sprite("core:ui/skills/IconAgility_Blue"),
    wrath = sf2.assets.sprite("core:ui/skills/IconFurious"),
    vengeance = sf2.assets.sprite("core:ui/skills/IconAvenger"),
    relentless = sf2.assets.sprite("core:ui/skills/IconCrackedApple"),
    patience = sf2.assets.sprite("core:ui/skills/IconEagleEye"),
    hex = sf2.assets.sprite("core:ui/skills/IconDisorientation_Red"),
    overcharge = sf2.assets.sprite("core:ui/skills/IconOvercharge"),
}

local function frame(fighter)
    local now = fighter:snapshot()
    return now and now.frame or 0
end

local RULES = {}

-- Ground and arena -------------------------------------------------------------------------------

-- Pinned against the wall behind you: 5% of your health a second.
local WALL_RANGE = 60
RULES.thorny_walls = { art = "orange", state = function() return { due = 0 } end, player = {
    on_tick = function(st, fighter, tick, on)
        if not on or tick.frame < st.due then return end
        local now = fighter:snapshot()
        if now and (now.back_wall_distance or WALL_RANGE) < WALL_RANGE then
            st.due = tick.frame + 30
            fighter:change_health(-0.025)
            fighter:set_model_color("#FF5A3C", 10)
        end
    end,
} }

-- Wind pushes both fighters one way and turns every 8 s, a second's warning first.
local GALE_PERIOD, GALE_WARNING, GALE_PUSH = 480, 60, 1.2
RULES.gale = { art = "orange", state = function() return { turn = -1, direction = 1, warned = false } end, player = {
    on_tick = function(st, fighter, tick, on)
        if not on then
            st.turn = -1
            return
        end
        if st.turn < 0 then st.turn = tick.frame + GALE_PERIOD end
        if tick.frame >= st.turn then
            st.direction = -st.direction
            st.turn = tick.frame + GALE_PERIOD
            st.warned = false
        elseif not st.warned and tick.frame >= st.turn - GALE_WARNING then
            st.warned = true
            fighter:show_status_icon("uw_gale", ICON.gale, GALE_WARNING)
        end
        local push = st.direction * GALE_PUSH * tick.delta_frames
        fighter:move_by(push, 0)
        if fighter.opponent then fighter.opponent:move_by(push, 0) end
    end,
} }

-- You drift towards the boss unless already at close quarters.
local UNDERTOW_PULL, UNDERTOW_CLOSE = 0.9, 90
RULES.undertow = { art = "orange", player = {
    on_tick = function(_, fighter, tick, on)
        if not on then return end
        local now = fighter:snapshot()
        if not now or not now.opponent then return end
        local gap = now.opponent.position.x - now.self.position.x
        if math.abs(gap) > UNDERTOW_CLOSE then
            fighter:move_by((gap > 0 and 1 or -1) * UNDERTOW_PULL * tick.delta_frames, 0)
        end
    end,
} }

-- Damage -----------------------------------------------------------------------------------------

-- Every hit deals double, both ways.
local function double(_, fighter) fighter:scale_outgoing_damage(2) end
RULES.glass_cannon = { art = "red", player = { on_damage_dealing = double }, opponent = { on_damage_dealing = double } }

-- On the boss: +10% damage for every 10 s spent in the seal, up to double.
local WRATH_STEP, WRATH_MAX = 600, 10
RULES.mounting_wrath = { art = "red", state = function() return { frames = 0, stacks = 0 } end, opponent = {
    on_tick = function(st, fighter, tick, on)
        if not on then
            if st.stacks > 0 then
                st.stacks = 0
                fighter:clear_status_icon("uw_wrath")
            end
            st.frames = 0
            return
        end
        st.frames = st.frames + tick.delta_frames
        local stacks = math.min(WRATH_MAX, math.floor(st.frames / WRATH_STEP))
        if stacks > 0 and stacks ~= st.stacks then
            fighter:show_status_icon("uw_wrath", ICON.wrath, 36000, stacks)
        end
        st.stacks = stacks
    end,
    on_damage_dealing = function(st, fighter)
        if st.stacks > 0 then fighter:scale_outgoing_damage(1 + 0.1 * st.stacks) end
    end,
} }

-- Your hits deal 25% less, but the first hit within 1.5 s of taking one deals triple.
local VENGEANCE_WINDOW = 90
RULES.vengeance = { art = "red", state = function() return { armed_until = -1 } end, player = {
    on_damage_received = function(st, fighter, event)
        if event.damage <= 0 or event.blocked then return end
        st.armed_until = frame(fighter) + VENGEANCE_WINDOW
        fighter:show_status_icon("uw_vengeance", ICON.vengeance, VENGEANCE_WINDOW)
    end,
    on_damage_dealing = function(st, fighter, event)
        if not event.blocked and frame(fighter) <= st.armed_until then
            st.armed_until = -1
            fighter:clear_status_icon("uw_vengeance")
            fighter:scale_outgoing_damage(3)
        else
            fighter:scale_outgoing_damage(0.75)
        end
    end,
} }

-- On the boss: no flinch or knockback from your hits.
RULES.unflinching = { art = "red", opponent = {
    on_hit_pre_crit = function(_, fighter, event)
        if event.target == "self" and not event.blocked then fighter:set_hit_armored(true) end
    end,
} }

-- Health -----------------------------------------------------------------------------------------

-- The lower your health, the harder you hit: double near death.
RULES.desperation = { art = "jade", player = {
    on_damage_dealing = function(_, fighter)
        local now = fighter:snapshot()
        if not now or now.self.max_health <= 0 then return end
        local missing = 1 - math.max(0, math.min(1, now.self.health / now.self.max_health))
        if missing > 0 then fighter:scale_outgoing_damage(1 + missing) end
    end,
} }

-- Each hit costs a fifth of your breath; it refills (2 s from empty) once you hold off for
-- 0.75 s. Out of breath, your hits do nothing.
local BREATH_COST, BREATH_REST, BREATH_REFILL = 0.2, 45, 120
RULES.breathless = { art = "jade", round = true,
    state = function() return { breath = 1, rest_from = 0, shown = false } end, player = {
    on_damage_dealing = function(st, fighter)
        st.rest_from = frame(fighter) + BREATH_REST
        if st.breath < BREATH_COST then
            fighter:scale_outgoing_damage(0)
        else
            st.breath = st.breath - BREATH_COST
        end
    end,
    on_tick = function(st, fighter, tick, on)
        if not on then
            if st.shown then
                st.shown = false
                fighter:clear_meter("uw_breath")
            end
            return
        end
        if tick.frame >= st.rest_from then
            st.breath = math.min(1, st.breath + tick.delta_frames / BREATH_REFILL)
        end
        if tick.frame % 3 == 0 or not st.shown then
            st.shown = true
            fighter:set_meter("uw_breath", { value = st.breath, segments = 5,
                color = st.breath < BREATH_COST and "#FF6A6A" or "#9FE3FF" })
        end
    end,
} }

-- Three seconds without landing a hit, then 5% of your health a second until you do.
local RELENTLESS_GRACE, RELENTLESS_WARNING = 180, 60
RULES.relentless = { art = "jade", state = function() return { last = -1, warned = false } end, player = {
    on_damage_dealt = function(st, fighter)
        st.last = frame(fighter)
        st.warned = false
    end,
    on_tick = function(st, fighter, tick, on)
        if not on then
            st.last = -1
            return
        end
        if st.last < 0 then st.last = tick.frame end
        local idle = tick.frame - st.last
        if idle >= RELENTLESS_GRACE then
            if tick.frame % 6 == 0 then
                fighter:change_health(-0.005)
                fighter:set_model_color("#B07CFF", 8)
            end
        elseif not st.warned and idle >= RELENTLESS_GRACE - RELENTLESS_WARNING then
            st.warned = true
            fighter:show_status_icon("uw_relentless", ICON.relentless, RELENTLESS_WARNING)
        end
    end,
} }

-- A hit within 0.4 s of your last one does nothing.
local MEASURED_GAP = 24
RULES.measured_strikes = { art = "jade", state = function() return { last = -1000 } end, player = {
    on_damage_dealing = function(st, fighter)
        local now = frame(fighter)
        if now - st.last < MEASURED_GAP then fighter:scale_outgoing_damage(0) end
        st.last = now
    end,
} }

-- Restrictions -----------------------------------------------------------------------------------

RULES.kicks_only = { art = "green", native = { { kind = "no_button", name = "Punch", target = "player" } } }

RULES.bare_hands = { art = "green", native = {
    { kind = "no_button", name = "Ranged", target = "player" },
    { kind = "no_button", name = "Magic", target = "player" },
} }

-- The same kind of attack (weapon, unarmed, ranged, magic) twice in a row: the second is halved.
local function attack_kind(event)
    if event.ranged then return "ranged" end
    if event.magic then return "magic" end
    if event.weapon then return "weapon" end
    return "unarmed"
end
RULES.mix_it_up = { art = "green", state = function() return { last = "" } end, player = {
    on_post_hit = function(st, fighter, event)
        if event.target ~= "opponent" then return end
        local kind = attack_kind(event)
        if kind == st.last then fighter:scale_outgoing_damage(0.5) end
        st.last = kind
    end,
} }

-- The boss takes half damage except for 1 s after you block one of his attacks. The player's
-- block opens the window the boss's handler reads.
local PATIENCE_WINDOW = 60
local patience = { open_until = -1 }
RULES.patience = { art = "green", player = {
    on_block = function(_, fighter)
        patience.open_until = frame(fighter) + PATIENCE_WINDOW
        fighter:show_status_icon("uw_patience", ICON.patience, PATIENCE_WINDOW)
    end,
}, opponent = {
    on_damage_resolving = function(_, fighter)
        if frame(fighter) > patience.open_until then fighter:scale_incoming_damage(0.5) end
    end,
} }

-- Controls ---------------------------------------------------------------------------------------

-- Every 10 s: a second's warning, then your movement is mirrored for 4 s.
local HEX_PERIOD, HEX_WARNING, HEX_FRAMES = 600, 60, 240
RULES.tricksters_hex = { art = "blue", round = true,
    state = function() return { start = -1, inverted = false, warned = false } end, player = {
    on_tick = function(st, fighter, tick, on)
        local inverted = false
        if not on then
            st.start = -1
        else
            if st.start < 0 then st.start = tick.frame end
            local cycle = (tick.frame - st.start) % HEX_PERIOD
            local from = HEX_PERIOD - HEX_FRAMES
            inverted = cycle >= from
            if cycle >= from - HEX_WARNING and cycle < from then
                if not st.warned then
                    st.warned = true
                    fighter:show_status_icon("uw_hex", ICON.hex, HEX_WARNING + HEX_FRAMES)
                end
            else
                st.warned = false
            end
        end
        if inverted ~= st.inverted then
            st.inverted = inverted
            fighter:set_controls_inverted(inverted)
        end
    end,
} }

-- After a throw the ranged button rests 8 s; after a spell, magic is locked for 10 s. The player's
-- ranged and magic moves are told apart by name (Ranged*, Magic*).
local RANGED_REST, MAGIC_REST = 480, 600
RULES.slow_hands = { art = "blue", round = true, state = function() return { magic_until = -1 } end, player = {
    on_animation_start = function(st, fighter, event)
        if event.target ~= "self" then return end
        local name = event.animation_name or ""
        if name:sub(1, 6) == "Ranged" then
            fighter:set_button_cooldown("ranged", RANGED_REST)
        elseif name:sub(1, 5) == "Magic" then
            if st.magic_until < 0 then fighter:set_control_blocked("magic", true) end
            st.magic_until = frame(fighter) + MAGIC_REST
        end
    end,
    on_tick = function(st, fighter, tick, on)
        if st.magic_until < 0 then return end
        if tick.frame >= st.magic_until or not on then
            st.magic_until = -1
            fighter:set_control_blocked("magic", false)
        end
    end,
} }

-- On the boss: his magic fills on its own, a full charge every 20 s on top of the usual.
local OVERCHARGE_FILL = 1200
RULES.overcharge = { art = "blue", state = function() return { shown = false } end, opponent = {
    on_tick = function(st, fighter, tick, on)
        if not on then
            if st.shown then
                st.shown = false
                fighter:clear_status_icon("uw_overcharge")
            end
            return
        end
        fighter:add_magic_charge(tick.delta_frames / OVERCHARGE_FILL)
        if not st.shown then
            st.shown = true
            fighter:show_status_icon("uw_overcharge", ICON.overcharge, 36000)
        end
    end,
} }

-- Sight ------------------------------------------------------------------------------------------

-- On the boss: he turns invisible for 2 s every 5 s. The see-through tint is set again every
-- tick, so another rule's brief flash on him (one tint per behavior) cannot end it early.
local VANISH_FRAMES, VANISH_PERIOD = 120, 300
RULES.vanishing = { art = "purple", round = true, state = function() return { due = -1, hidden_until = -1 } end, opponent = {
    on_tick = function(st, fighter, tick, on)
        if not on then
            st.due = -1
            if st.hidden_until >= 0 then
                st.hidden_until = -1
                fighter:clear_model_color()
            end
            return
        end
        if st.due < 0 then st.due = tick.frame + VANISH_PERIOD - VANISH_FRAMES end
        if tick.frame >= st.due then
            st.due = tick.frame + VANISH_PERIOD
            st.hidden_until = tick.frame + VANISH_FRAMES
        end
        if tick.frame < st.hidden_until then
            fighter:set_model_color("#FFFFFF00", st.hidden_until - tick.frame)
        end
    end,
} }

RULES.moonless = { art = "purple", native = {
    { kind = "light_in_the_darkness", radius = 0.12, shape = 1, target = "all" },
    { kind = "no_health_bar", target = "all" },
} }

-- Dispatch ---------------------------------------------------------------------------------------

-- active: the rule of the seal being fought; pacts: a set of rules on for the whole fight while a
-- seal is (content.underworld_seals sets both).
local M = { rules = RULES, active = nil, pacts = nil }

local function on(name) return M.active == name or (M.pacts ~= nil and M.pacts[name] == true) end

-- Lua rules that can be a pact: those with handlers (the others are built-in, phase-bound rules).
M.pactable = {}

local ORDER = {}
for name in pairs(RULES) do ORDER[#ORDER + 1] = name end
table.sort(ORDER)
for _, name in ipairs(ORDER) do
    if RULES[name].player or RULES[name].opponent then M.pactable[#M.pactable + 1] = name end
end

-- Handler state by side and rule, fresh every fight (and every round for round rules).
local states = { player = {}, opponent = {} }
local function reset(side, rounds_only)
    for _, name in ipairs(ORDER) do
        local rule = RULES[name]
        if rule[side] and (not rounds_only or rule.round) then
            states[side][name] = rule.state and rule.state() or {}
        end
    end
end

local function state(side, name)
    local st = states[side][name]
    if not st then
        local rule = RULES[name]
        st = rule.state and rule.state() or {}
        states[side][name] = st
    end
    return st
end

local EVENTS = { "on_damage_dealing", "on_damage_resolving", "on_damage_received", "on_damage_dealt",
    "on_hit_pre_crit", "on_post_hit", "on_block", "on_animation_start" }

local function dispatcher(side)
    local definition = {
        on_fight_begin = function()
            if side == "player" then patience.open_until = -1 end
            reset(side, false)
        end,
        on_round_begin = function() reset(side, true) end,
        on_tick = function(_, fighter, tick)
            for _, name in ipairs(ORDER) do
                local handler = RULES[name][side]
                if handler and handler.on_tick then
                    handler.on_tick(state(side, name), fighter, tick, on(name))
                end
            end
        end,
    }
    for _, event_name in ipairs(EVENTS) do
        definition[event_name] = function(_, fighter, event)
            if not M.active and not M.pacts then return end
            for _, name in ipairs(ORDER) do
                local handler = RULES[name][side]
                local callback = handler and handler[event_name]
                if callback and on(name) then callback(state(side, name), fighter, event) end
            end
        end
    end
    return definition
end

-- The two behavior rules a sealed fight adds, after the rules' phased groups.
M.behaviors = {
    { kind = "behavior", behavior = dispatcher("player"), target = "player" },
    { kind = "behavior", behavior = dispatcher("opponent"), target = "opponent" },
}

return M
