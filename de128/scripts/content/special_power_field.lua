local sf2 = require("sf2")

-- Power Field: the zap marks the enemy with Static Charge; the fourth landed hit inside the
-- window electrocutes. Any hit taken has a chance to be armored.
local SURGE = "gatekeeper_power_surge"
local WINDOW_FRAMES = 300       -- 5 seconds, counted from the moment the enemy is back up
local HITS_NEEDED = 4
local ARMOR_CHANCE = 0.15
local NO_FALL_START = 60        -- an enemy that never falls (armored) starts the window anyway

local charge_icon = sf2.assets.sprite("core:ui/skills/IconLightning_Blue")

local function clear(self, fighter)
    self.state.marked = false
    self.state.window_end = 0
    self.state.hits = 0
    fighter:clear_status_icon("static_charge")
end

return {
    state = { marked = false, saw_fall = false, mark_frame = 0, window_end = 0, hits = 0, now = 0 },

    on_tick = function(self, fighter, event)
        local state = self.state
        state.now = event.frame
        if state.marked then
            local down = fighter:animation_is("Fall", "opponent")
            if down then state.saw_fall = true end
            local got_up = state.saw_fall and not down
            local never_fell = not state.saw_fall and event.frame - state.mark_frame > NO_FALL_START
            if got_up or never_fell then
                state.marked = false
                state.window_end = event.frame + WINDOW_FRAMES
                state.hits = 0
                fighter:show_status_icon("static_charge", charge_icon, WINDOW_FRAMES)
            end
        elseif state.window_end > 0 and event.frame >= state.window_end then
            clear(self, fighter)
        end
    end,

    on_hit_pre_crit = function(self, fighter, event)
        local state = self.state
        if event.target == "self" then
            if not event.ranged and not event.magic and not fighter:animation_is("BossAbility", "opponent")
                and sf2.random.number("power_field_armor") < ARMOR_CHANCE then
                fighter:set_hit_armored(true)
            end
            return
        end
        local source = event.attack and event.attack.animation_name or ""
        if source:find(SURGE, 1, true) then
            state.marked, state.saw_fall, state.mark_frame, state.window_end, state.hits = true, false, state.now, 0, 0
            fighter:clear_status_icon("static_charge")
            return
        end
        if state.window_end == 0 or event.blocked or event.ranged or event.magic
            or fighter:animation_is("BossAbility") then return end
        state.hits = state.hits + 1
        if state.hits >= HITS_NEEDED then
            fighter:set_hit_reaction("Electrocution")
            clear(self, fighter)
        end
    end,
}
