local sf2 = require("sf2")

-- Earthquake: knockdowns feed the next quake, and fallen enemies take extra damage.
local MOVE = "de128:moves/butcher_earthquake_player"
local MAX_STACKS = 5
local STACK_BONUS = 0.2     -- per stack, on the earthquake's own hit
local FALL_BONUS = 1.3      -- every hit while the enemy is in a Fall animation
local ICON_FRAMES = 36000   -- stacks never expire; the icon is simply refreshed

local stack_icon = sf2.assets.sprite("core:ui/skills/IconFallenTree_Blue")

-- Tags and moves that leave the enemy off the ground.
local AIRBORNE = { "Jump", "Wall", "de128:moves/wasp_fly_150", "de128:moves/wasp_fly_200",
    "de128:moves/wasp_fly_300", "de128:moves/wasp_fly_370" }

local function airborne(fighter)
    for _, name in ipairs(AIRBORNE) do
        if fighter:animation_is(name, "opponent") then return true end
    end
    return false
end

local function show(fighter, stacks)
    if stacks > 0 then
        fighter:show_status_icon("stacks", stack_icon, ICON_FRAMES, stacks)
    else
        fighter:clear_status_icon("stacks")
    end
end

return {
    state = { stacks = 0, spent = 0, was_down = false },

    -- A stack for each transition into a Fall animation, not for hits on an enemy already down.
    on_tick = function(self, fighter)
        local down = fighter:animation_is("Fall", "opponent")
        if down and not self.state.was_down and self.state.stacks < MAX_STACKS then
            self.state.stacks = self.state.stacks + 1
            show(fighter, self.state.stacks)
        end
        self.state.was_down = down
    end,

    -- Pressing the button commits every stack, whether or not the landing connects.
    on_animation_start = function(self, fighter, event)
        if event.target == "self" and event.animation_name == MOVE then
            self.state.spent = self.state.stacks
            self.state.stacks = 0
            show(fighter, 0)
        end
    end,

    on_damage_dealing = function(self, fighter, event)
        local source = event.attack and event.attack.animation_name or ""
        local quake = source:find("butcher_earthquake", 1, true) ~= nil
        if quake and airborne(fighter) then
            fighter:scale_outgoing_damage(0)
            return
        end
        local factor = quake and (1 + STACK_BONUS * self.state.spent) or 1
        if fighter:animation_is("Fall", "opponent") then factor = factor * FALL_BONUS end
        if factor ~= 1 then fighter:scale_outgoing_damage(factor) end
    end,
}
