local sf2 = require("sf2")
local words = require("content.text")

-- Stone Fetters (mythical, kind = "combo"): eight melee hits, each within 1.5 s of the last,
-- trigger a draining meter. While it lasts the ground shakes under the enemy, the enemy is
-- staggered every 3 s (never a boss) and the player takes hits armored. Bosses never use it.
-- Plan: Stone Fetters Mythical Enchantment Concept Plan.

local HITS = 8
local WINDOW = 90                         -- frames allowed between hits (1.5 s)
local FULL = 360                          -- frames a full bar lasts (6 s)
local REFILL = 36                         -- each landed hit refills 10%
local STAGGER_EVERY = 180                 -- 3 s
local STAGGER_REACTION = "MiddleHitHeavy" -- native heavy recoil used as the stagger
local METER_KEY = "stone_fetters"
local METER_COLOR = "#8E9AAF"
local TINT = "#9FB0C8"

-- Bosses carry the anti-shock perk; raid bosses also have several health bars.
local function is_boss(fighter, view)
    return not view or not view.opponent or view.opponent.max_health > 1 or fighter:has_perk("PERK_ANTI_SHOCK", "opponent")
end

local marker                              -- fallback ground marker; art only, not saved state

local function drop_marker()
    if marker then sf2.world.remove_marker(marker) end
    marker = nil
end

-- Ground shake under the enemy only. fighter:shake is the engine primitive; without it a
-- jittering strip of rubble at the enemy's feet stands in.
local function shake_ground(fighter, view, tick)
    if not view.opponent then return end
    if fighter.shake then
        if tick % STAGGER_EVERY == 0 then fighter:shake("opponent", 60) end
        return
    end
    local jitter = (tick % 6) < 3 and 2 or 6
    local position = view.opponent.position
    local rect = { x = position.x - 110, y = position.y - jitter, width = 220, height = jitter + 6 }
    if marker and sf2.world.is_marker_active(marker) then
        sf2.world.try_set_marker(marker, { rect = rect })
    else
        marker = fighter:mark_rect(rect, "#6B5A4AAA")
    end
end

local function show_meter(self, fighter)
    local s = self.state
    local value = s.active and s.charge / FULL or s.hits / HITS
    local shown = math.floor(value * 1000)
    if shown == s.shown then return end
    s.shown = shown
    fighter:set_meter(METER_KEY, { value = value, segments = 1, color = METER_COLOR,
        label = not s.active and s.hits .. "/" .. HITS or nil })
end

local function stop(self, fighter)
    local s = self.state
    s.active, s.charge, s.hits, s.stagger_due = false, 0, 0, false
    drop_marker()
    fighter:clear_model_color()
    show_meter(self, fighter)
end

local function landed(self, fighter)
    local s = self.state
    if s.active then
        s.charge = math.min(FULL, s.charge + REFILL)
    else
        if s.now - s.last_hit > WINDOW then s.hits = 0 end
        s.hits = s.hits + 1
        s.last_hit = s.now
        if s.hits >= HITS then
            s.active, s.charge, s.next_stagger = true, FULL, s.now + STAGGER_EVERY
            fighter:set_model_color(TINT, 60)
        end
    end
    show_meter(self, fighter)
end

local behavior = {
    state = { lifetime = "round", fields = {
        now = 0, hits = 0, last_hit = 0, charge = 0, active = false,
        next_stagger = 0, stagger_due = false, shown = -1,
    } },
    on_round_begin = function(self, fighter)
        self.state.shown = -1
        show_meter(self, fighter)
    end,
    on_round_end = function(_, fighter)
        drop_marker()
        fighter:clear_meter(METER_KEY)
    end,
    on_tick = function(self, fighter, event)
        local s = self.state
        s.now = event.frame
        if not s.active then
            if s.hits > 0 and s.now - s.last_hit > WINDOW then
                s.hits = 0
                show_meter(self, fighter)
            end
            return
        end
        s.charge = s.charge - event.delta_frames
        if s.charge <= 0 then
            stop(self, fighter)
            return
        end
        local view = fighter:snapshot()
        if view and view.round_active then
            shake_ground(fighter, view, s.now)
            if s.now >= s.next_stagger then
                s.next_stagger = s.now + STAGGER_EVERY
                s.stagger_due = not is_boss(fighter, view)
            end
        end
        if s.now % 30 == 0 then fighter:set_model_color(TINT, 60) end
        show_meter(self, fighter)
    end,
    on_hit_pre_crit = function(self, fighter, event)
        local s = self.state
        if not s.active then return end
        if event.target == "self" then
            -- Armor: damage is taken, no stagger or interruption.
            fighter:set_hit_armored(true)
        elseif s.stagger_due and not event.blocked then
            fighter:set_hit_reaction(STAGGER_REACTION)
            s.stagger_due = false
        end
    end,
    on_post_hit = function(self, fighter, event)
        -- Only landed melee hits count: not ranged, magic or ability moves.
        if event.target ~= "opponent" or event.blocked or event.ranged or event.magic then return end
        if not (event.weapon or event.unarmed) then return end
        if fighter:animation_is("BossAbility") or fighter:animation_is("Ability") then return end
        landed(self, fighter)
    end,
}

return sf2.perks.register {
    id = "stone_fetters",
    display_name = words.own("special.stone_fetters.name", "special.stone_fetters.name"),
    description = words.own("special.stone_fetters.description", "special.stone_fetters.description"),
    icon = sf2.assets.sprite("core:ui/skills/IconMasterOfStyle"),
    kind = "combo",
    behavior = behavior,
}
