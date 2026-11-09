local sf2 = require("sf2")

-- Enchantment chances are Aspect(enchantment - EnchantmentResistance), and the Aspect curve
-- halves the chance for every 108 points (internalSettings.xml DoublingRange). 108 halves the
-- debuffs thrown at the wearer; the resistance enchantment's own 261 would cut them to a fifth.
local DEBUFF_RESISTANCE = 108
local MAX_RAT_STACKS = 5
local DEBUFF_STACKS = 2
local DAMAGE_PER_STACK = 0.01
local PULSE_FRAMES = 60

-- The rat projectile's only attack runs in RatWaveMiddle; nothing else uses that animation.
local function is_rat_hit(event)
    return event.attack ~= nil and event.attack.animation_name == "RatWaveMiddle"
end

local function stack_count(self, fighter)
    return self.state.rats + DEBUFF_STACKS * (fighter:debuff_count() or 0)
end

-- The bar fills with the permanent rat stacks; the number counts every stack dealing damage.
local function show(self, fighter)
    local stacks = stack_count(self, fighter)
    if stacks == self.state.shown then return end
    self.state.shown = stacks
    fighter:set_meter("rat_stacks", { value = self.state.rats / MAX_RAT_STACKS, segments = MAX_RAT_STACKS,
        color = "#7CB342", label = tostring(stacks) })
end

-- Rat stacks last the round; debuff stacks are read live, so they end with their debuff. The
-- damage is dealt as plain health loss, which no damage buff, enchantment or armor touches.
return {
    state = { rats = 0, elapsed = 0, resistant = false, shown = -1 },
    on_tick = function(self, fighter, event)
        if not self.state.resistant then
            self.state.resistant = true
            fighter:set_attribute_bonus("EnchantmentResistance", DEBUFF_RESISTANCE)
        end
        show(self, fighter)
        self.state.elapsed = self.state.elapsed + event.delta_frames
        if self.state.elapsed < PULSE_FRAMES then return end
        self.state.elapsed = 0
        local stacks = stack_count(self, fighter)
        if stacks > 0 and fighter.opponent then
            fighter.opponent:change_health(-DAMAGE_PER_STACK * stacks)
        end
    end,
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or event.blocked or not is_rat_hit(event) then return end
        if self.state.rats >= MAX_RAT_STACKS then return end
        self.state.rats = self.state.rats + 1
        show(self, fighter)
    end,
}
