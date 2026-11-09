local sf2 = require("sf2")

-- Teleportation: moving forward charges the next hit; the strike heals for what it deals.
local BUFF = 1.3
local BUFF_FRAMES = 180
-- Long step forward, forward roll, front flip (the forward jump).
local FORWARD_MOVES = { DoubleStepForward = true, ForwardRoll = true, FrontFlip = true }

local buff_icon = sf2.assets.sprite("core:ui/skills/IconAgility_Blue")

local function is_strike(event)
    local source = event.attack and event.attack.animation_name or ""
    return source:find("WidowTeleportationEnd", 1, true) ~= nil
        or source:find("widow_teleportation_end", 1, true) ~= nil
end

return {
    state = { now = 0, buff_until = 0 },

    on_tick = function(self, fighter, event)
        self.state.now = event.frame
    end,

    on_animation_start = function(self, fighter, event)
        if event.target == "self" and FORWARD_MOVES[event.animation_name] then
            self.state.buff_until = self.state.now + BUFF_FRAMES
            fighter:show_status_icon("forward", buff_icon, BUFF_FRAMES)
        end
    end,

    -- The next landed hit, unless it is the strike (fixed 28 damage, no enchantment interaction).
    on_damage_dealing = function(self, fighter, event)
        if self.state.now >= self.state.buff_until or event.blocked or event.damage <= 0 or is_strike(event) then return end
        fighter:scale_outgoing_damage(BUFF)
        self.state.buff_until = 0
        fighter:clear_status_icon("forward")
    end,

    -- A miss deals no damage and so never reaches here.
    on_damage_dealt = function(self, fighter, event)
        if is_strike(event) then
            fighter:change_health(event.damage * (event.critical and 2 or 1))
        end
    end,
}
