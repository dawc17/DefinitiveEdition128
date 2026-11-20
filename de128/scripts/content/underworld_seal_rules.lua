local sf2 = require("sf2")

-- The Underworld's own seal rules (content.underworld_seals), beside the 14 it copies from the
-- Power Mode fights. Each entry is one seal's rule:
--   art       the Gates of Shadows seal colour, one per kind of rule (as in content.underworld_seals);
--   native    built-in rules switched on with the seal (a phased group, which also carries the text);
--   behaviors { behavior, target } Lua rules for the seal.
-- Title and hint text: de128.uw_seals.rule.<name> and de128.uw_seals.hint.<name> in Eclipse's eng.toml.
--
-- A behavior runs without a phase filter and is told its seal as parameters.phase: it checks the
-- fight's phase itself (live) so it can undo what it leaves on (inverted controls, a meter, a
-- locked button) when the seal breaks, Star Clarity lifts it or the intermission starts. A phase
-- filter would just stop its callbacks. Rules whose effect the game clears between rounds (controls,
-- meters, cloaks) keep round state, so both reset together.

local ICON = {
    gale = sf2.assets.sprite("core:ui/skills/IconAgility_Blue"),
    wrath = sf2.assets.sprite("core:ui/skills/IconFurious"),
    vengeance = sf2.assets.sprite("core:ui/skills/IconAvenger"),
    relentless = sf2.assets.sprite("core:ui/skills/IconCrackedApple"),
    patience = sf2.assets.sprite("core:ui/skills/IconEagleEye"),
    hex = sf2.assets.sprite("core:ui/skills/IconDisorientation_Red"),
    overcharge = sf2.assets.sprite("core:ui/skills/IconOvercharge"),
}

-- The snapshot while this behavior's seal is on and the round runs, else nil.
local function live(self, fighter)
    local now = fighter:snapshot()
    if now and now.round_active and now.phase == self.params.phase then return now end
    return nil
end

local function behavior(definition)
    definition.parameters = { phase = 1 }
    definition.state = definition.state or { lifetime = "fight", fields = { unused = 0 } }
    return definition
end

-- Ground and arena -------------------------------------------------------------------------------

-- Pinned against the wall behind you: 5% of your health a second.
local WALL_RANGE = 60
local thorny_walls = behavior {
    state = { lifetime = "fight", fields = { due = 0 } },
    on_tick = function(self, fighter, tick)
        local now = live(self, fighter)
        if not now or tick.frame < self.state.due then return end
        if (now.back_wall_distance or WALL_RANGE) < WALL_RANGE then
            self.state.due = tick.frame + 30
            fighter:change_health(-0.025)
            fighter:set_model_color("#FF5A3C", 10)
        end
    end,
}

-- Wind pushes both fighters one way and turns every 8 s, a second's warning first.
local GALE_PERIOD, GALE_WARNING, GALE_PUSH = 480, 60, 1.2
local gale = behavior {
    state = { lifetime = "fight", fields = { turn = -1, direction = 1, warned = false } },
    on_tick = function(self, fighter, tick)
        local now = live(self, fighter)
        local state = self.state
        if not now then
            state.turn = -1
            return
        end
        if state.turn < 0 then state.turn = tick.frame + GALE_PERIOD end
        if tick.frame >= state.turn then
            state.direction = -state.direction
            state.turn = tick.frame + GALE_PERIOD
            state.warned = false
        elseif not state.warned and tick.frame >= state.turn - GALE_WARNING then
            state.warned = true
            fighter:show_status_icon("uw_gale", ICON.gale, GALE_WARNING)
        end
        local push = state.direction * GALE_PUSH * tick.delta_frames
        fighter:move_by(push, 0)
        if fighter.opponent then fighter.opponent:move_by(push, 0) end
    end,
}

-- You drift towards the boss unless already at close quarters.
local UNDERTOW_PULL, UNDERTOW_CLOSE = 0.9, 90
local undertow = behavior {
    on_tick = function(self, fighter, tick)
        local now = live(self, fighter)
        if not now or not now.opponent then return end
        local gap = now.opponent.position.x - now.self.position.x
        if math.abs(gap) > UNDERTOW_CLOSE then
            fighter:move_by((gap > 0 and 1 or -1) * UNDERTOW_PULL * tick.delta_frames, 0)
        end
    end,
}

-- Damage -----------------------------------------------------------------------------------------

-- On both fighters: every hit deals double.
local glass_cannon = behavior {
    on_damage_dealing = function(self, fighter)
        if live(self, fighter) then fighter:scale_outgoing_damage(2) end
    end,
}

-- On the boss: +10% damage for every 10 s spent in the seal, up to double.
local WRATH_STEP, WRATH_MAX = 600, 10
local mounting_wrath = behavior {
    state = { lifetime = "fight", fields = { frames = 0, stacks = 0 } },
    on_tick = function(self, fighter, tick)
        local state = self.state
        if not live(self, fighter) then
            if state.stacks > 0 then fighter:clear_status_icon("uw_wrath") end
            return
        end
        state.frames = state.frames + tick.delta_frames
        local stacks = math.min(WRATH_MAX, math.floor(state.frames / WRATH_STEP))
        if stacks > 0 and (stacks ~= state.stacks or tick.frame % WRATH_STEP == 0) then
            fighter:show_status_icon("uw_wrath", ICON.wrath, WRATH_STEP + 60, stacks)
        end
        state.stacks = stacks
    end,
    on_damage_dealing = function(self, fighter)
        if self.state.stacks > 0 and live(self, fighter) then
            fighter:scale_outgoing_damage(1 + 0.1 * self.state.stacks)
        end
    end,
}

-- Your hits deal 25% less, but the first hit within 1.5 s of taking one deals triple.
local VENGEANCE_WINDOW = 90
local vengeance = behavior {
    state = { lifetime = "fight", fields = { armed_until = -1 } },
    on_damage_received = function(self, fighter, event)
        if event.damage <= 0 or event.blocked then return end
        local now = live(self, fighter)
        if not now then return end
        self.state.armed_until = now.frame + VENGEANCE_WINDOW
        fighter:show_status_icon("uw_vengeance", ICON.vengeance, VENGEANCE_WINDOW)
    end,
    on_damage_dealing = function(self, fighter, event)
        local now = live(self, fighter)
        if not now then return end
        if not event.blocked and now.frame <= self.state.armed_until then
            self.state.armed_until = -1
            fighter:clear_status_icon("uw_vengeance")
            fighter:scale_outgoing_damage(3)
        else
            fighter:scale_outgoing_damage(0.75)
        end
    end,
}

-- On the boss: no flinch or knockback from your hits.
local unflinching = behavior {
    on_hit_pre_crit = function(self, fighter, event)
        if event.target == "self" and not event.blocked and live(self, fighter) then
            fighter:set_hit_armored(true)
        end
    end,
}

-- Health -----------------------------------------------------------------------------------------

-- The lower your health, the harder you hit: double near death.
local desperation = behavior {
    on_damage_dealing = function(self, fighter)
        local now = live(self, fighter)
        if not now or now.self.max_health <= 0 then return end
        local missing = 1 - math.max(0, math.min(1, now.self.health / now.self.max_health))
        if missing > 0 then fighter:scale_outgoing_damage(1 + missing) end
    end,
}

-- Each hit costs a fifth of your breath; it refills (2 s from empty) once you hold off for
-- 0.75 s. Out of breath, your hits do nothing.
local BREATH_COST, BREATH_REST, BREATH_REFILL = 0.2, 45, 120
local breathless = behavior {
    state = { lifetime = "round", fields = { breath = 1, rest_from = 0, shown = false } },
    on_damage_dealing = function(self, fighter)
        local now = live(self, fighter)
        if not now then return end
        local state = self.state
        state.rest_from = now.frame + BREATH_REST
        if state.breath < BREATH_COST then
            fighter:scale_outgoing_damage(0)
        else
            state.breath = state.breath - BREATH_COST
        end
    end,
    on_tick = function(self, fighter, tick)
        local state = self.state
        if not live(self, fighter) then
            if state.shown then
                state.shown = false
                fighter:clear_meter("uw_breath")
            end
            return
        end
        if tick.frame >= state.rest_from then
            state.breath = math.min(1, state.breath + tick.delta_frames / BREATH_REFILL)
        end
        if tick.frame % 3 == 0 or not state.shown then
            state.shown = true
            fighter:set_meter("uw_breath", { value = state.breath, segments = 5,
                color = state.breath < BREATH_COST and "#FF6A6A" or "#9FE3FF" })
        end
    end,
}

-- Three seconds without landing a hit, then 5% of your health a second until you do.
local RELENTLESS_GRACE, RELENTLESS_WARNING = 180, 60
local relentless = behavior {
    state = { lifetime = "fight", fields = { last = -1, warned = false } },
    on_damage_dealt = function(self, fighter)
        local now = live(self, fighter)
        if now then
            self.state.last = now.frame
            self.state.warned = false
        end
    end,
    on_tick = function(self, fighter, tick)
        local state = self.state
        if not live(self, fighter) then
            state.last = -1
            return
        end
        if state.last < 0 then state.last = tick.frame end
        local idle = tick.frame - state.last
        if idle >= RELENTLESS_GRACE then
            if tick.frame % 6 == 0 then
                fighter:change_health(-0.005)
                fighter:set_model_color("#B07CFF", 8)
            end
        elseif not state.warned and idle >= RELENTLESS_GRACE - RELENTLESS_WARNING then
            state.warned = true
            fighter:show_status_icon("uw_relentless", ICON.relentless, RELENTLESS_WARNING)
        end
    end,
}

-- A hit within 0.4 s of your last one does nothing.
local MEASURED_GAP = 24
local measured_strikes = behavior {
    state = { lifetime = "fight", fields = { last = -1000 } },
    on_damage_dealing = function(self, fighter)
        local now = live(self, fighter)
        if not now then return end
        if now.frame - self.state.last < MEASURED_GAP then fighter:scale_outgoing_damage(0) end
        self.state.last = now.frame
    end,
}

-- Restrictions -----------------------------------------------------------------------------------

-- The same kind of attack (weapon, unarmed, ranged, magic) twice in a row: the second is halved.
local function attack_kind(event)
    if event.ranged then return "ranged" end
    if event.magic then return "magic" end
    if event.weapon then return "weapon" end
    return "unarmed"
end
local mix_it_up = behavior {
    state = { lifetime = "fight", fields = { last = "" } },
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or not live(self, fighter) then return end
        local kind = attack_kind(event)
        if kind == self.state.last then fighter:scale_outgoing_damage(0.5) end
        self.state.last = kind
    end,
}

-- The boss takes half damage except for 1 s after you block one of his attacks. The player's
-- block opens the window the boss's rule reads.
local PATIENCE_WINDOW = 60
local patience = { open_until = -1 }
local patience_player = behavior {
    on_fight_begin = function() patience.open_until = -1 end,
    on_block = function(self, fighter)
        local now = live(self, fighter)
        if not now then return end
        patience.open_until = now.frame + PATIENCE_WINDOW
        fighter:show_status_icon("uw_patience", ICON.patience, PATIENCE_WINDOW)
    end,
}
local patience_boss = behavior {
    on_damage_resolving = function(self, fighter)
        local now = live(self, fighter)
        if now and now.frame > patience.open_until then fighter:scale_incoming_damage(0.5) end
    end,
}

-- Controls ---------------------------------------------------------------------------------------

-- Every 10 s: a second's warning, then your movement is mirrored for 4 s.
local HEX_PERIOD, HEX_WARNING, HEX_FRAMES = 600, 60, 240
local tricksters_hex = behavior {
    state = { lifetime = "round", fields = { start = -1, inverted = false, warned = false } },
    on_tick = function(self, fighter, tick)
        local state = self.state
        local inverted = false
        if not live(self, fighter) then
            state.start = -1
        else
            if state.start < 0 then state.start = tick.frame end
            local cycle = (tick.frame - state.start) % HEX_PERIOD
            local from = HEX_PERIOD - HEX_FRAMES
            inverted = cycle >= from
            if cycle >= from - HEX_WARNING and cycle < from then
                if not state.warned then
                    state.warned = true
                    fighter:show_status_icon("uw_hex", ICON.hex, HEX_WARNING + HEX_FRAMES)
                end
            else
                state.warned = false
            end
        end
        if inverted ~= state.inverted then
            state.inverted = inverted
            fighter:set_controls_inverted(inverted)
        end
    end,
}

-- After a throw the ranged button rests 8 s; after a spell, magic is locked for 10 s.
local RANGED_REST, MAGIC_REST = 480, 600
local slow_hands = behavior {
    state = { lifetime = "round", fields = { magic_until = -1 } },
    on_animation_start = function(self, fighter, event)
        if event.target ~= "self" then return end
        local now = live(self, fighter)
        if not now then return end
        local name = event.animation_name or ""
        if name:sub(1, 6) == "Ranged" then
            fighter:set_button_cooldown("ranged", RANGED_REST)
        elseif name:sub(1, 5) == "Magic" then
            if self.state.magic_until < 0 then fighter:set_control_blocked("magic", true) end
            self.state.magic_until = now.frame + MAGIC_REST
        end
    end,
    on_tick = function(self, fighter, tick)
        if self.state.magic_until < 0 then return end
        if tick.frame >= self.state.magic_until or not live(self, fighter) then
            self.state.magic_until = -1
            fighter:set_control_blocked("magic", false)
        end
    end,
}

-- On the boss: his magic fills on its own, a full charge every 20 s on top of the usual.
local OVERCHARGE_FILL = 1200
local overcharge = behavior {
    on_tick = function(self, fighter, tick)
        if not live(self, fighter) then return end
        fighter:add_magic_charge(tick.delta_frames / OVERCHARGE_FILL)
        if tick.frame % 300 == 0 then fighter:show_status_icon("uw_overcharge", ICON.overcharge, 330) end
    end,
}

-- Sight ------------------------------------------------------------------------------------------

-- On the boss: he turns to glass for 2 s every 5 s.
local VANISH_FRAMES, VANISH_PERIOD = 120, 300
local vanishing = behavior {
    state = { lifetime = "round", fields = { due = -1, cloaked = false } },
    on_tick = function(self, fighter, tick)
        local state = self.state
        if not live(self, fighter) then
            state.due = -1
            if state.cloaked then
                state.cloaked = false
                fighter:clear_cloak()
            end
            return
        end
        if state.due < 0 then state.due = tick.frame + VANISH_PERIOD - VANISH_FRAMES end
        if tick.frame >= state.due then
            state.due = tick.frame + VANISH_PERIOD
            state.cloaked = true
            fighter:set_cloak(VANISH_FRAMES)
        end
    end,
}

local function on(b, target) return { behavior = b, target = target } end

return {
    thorny_walls = { art = "orange", behaviors = { on(thorny_walls, "player") } },
    gale = { art = "orange", behaviors = { on(gale, "player") } },
    undertow = { art = "orange", behaviors = { on(undertow, "player") } },
    glass_cannon = { art = "red", behaviors = { on(glass_cannon, "all") } },
    mounting_wrath = { art = "red", behaviors = { on(mounting_wrath, "opponent") } },
    vengeance = { art = "red", behaviors = { on(vengeance, "player") } },
    unflinching = { art = "red", behaviors = { on(unflinching, "opponent") } },
    desperation = { art = "jade", behaviors = { on(desperation, "player") } },
    breathless = { art = "jade", behaviors = { on(breathless, "player") } },
    relentless = { art = "jade", behaviors = { on(relentless, "player") } },
    measured_strikes = { art = "jade", behaviors = { on(measured_strikes, "player") } },
    kicks_only = { art = "green", native = { { kind = "no_button", name = "Punch", target = "player" } } },
    bare_hands = { art = "green", native = {
        { kind = "no_button", name = "Ranged", target = "player" },
        { kind = "no_button", name = "Magic", target = "player" },
    } },
    mix_it_up = { art = "green", behaviors = { on(mix_it_up, "player") } },
    patience = { art = "green", behaviors = { on(patience_player, "player"), on(patience_boss, "opponent") } },
    tricksters_hex = { art = "blue", behaviors = { on(tricksters_hex, "player") } },
    slow_hands = { art = "blue", behaviors = { on(slow_hands, "player") } },
    overcharge = { art = "blue", behaviors = { on(overcharge, "opponent") } },
    vanishing = { art = "purple", behaviors = { on(vanishing, "opponent") } },
    moonless = { art = "purple", native = {
        { kind = "light_in_the_darkness", radius = 0.12, shape = 1, target = "all" },
        { kind = "no_health_bar", target = "all" },
    } },
}
