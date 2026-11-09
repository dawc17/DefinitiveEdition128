local sf2 = require("sf2")
local actors = require("content.call_to_arms_actors")
local recharge = require("content.ability_recharge")

local absorb_roll = sf2.random.stream("de128", "call_to_arms_absorb")

local PRESENCE_BONUS = 1.5
local STACK_BONUS = 0.25
local MAX_STACKS = 5
local ABSORB_CHANCE = 0.1
-- Give up on a summon that never appears (a rejected spawn is reported only after the call).
local APPEAR_FRAMES = 180

-- One assistant per pad direction.
local summons = {
    up = actors.katana,
    right = actors.naginata,
    down = actors.yari,
    left = actors.glaive,
}

local function show(fighter, stacks)
    fighter:set_meter("call_to_arms", { value = stacks / MAX_STACKS, segments = MAX_STACKS, color = "#D8452E",
        label = stacks .. "/" .. MAX_STACKS })
end

-- The assistant is gone (time, defeat or a failed spawn): the buffs end, the cooldown begins.
local function leave(self, fighter)
    self.state.active = false
    self.state.seen = false
    self.state.waited = 0
    self.state.stacks = 0
    fighter:clear_meter("call_to_arms")
    recharge(self, fighter, self.params.frames)
end

-- Spawn offsets are from the player; positive X is right.
local function spawn_x(fighter, summon)
    local combat = fighter:snapshot()
    if not combat then return 0 end
    local from = combat.self.position.x
    local to = combat.opponent and combat.opponent.position.x or from
    local toward = to >= from and 1 or -1
    if summon.behind_enemy then return to - from + toward * summon.behind_enemy end
    return -toward * summon.behind_player
end

return {
    state = { active = false, seen = false, waited = 0, stacks = 0, pad = false, absorb = false },
    on_tick = function(self, fighter)
        if not self.state.pad then
            self.state.pad = true
            fighter:set_control_directions("raid_charge", { "up", "right", "down", "left" })
            -- The bodyguards' hits build the same stacks as the player's.
            fighter:forward_actor_hits(true)
        end
        if not self.state.active then return end
        if #(fighter:actors() or {}) > 0 then
            self.state.seen = true
        elseif self.state.seen then
            leave(self, fighter)
        else
            self.state.waited = self.state.waited + 1
            if self.state.waited > APPEAR_FRAMES then leave(self, fighter) end
        end
    end,
    on_control_direction = function(self, fighter, event)
        local summon = summons[event.direction]
        if not summon or self.state.active or fighter:has_flag(self.params.key) then return end
        local receipt = fighter:spawn_actor(summon.actor, spawn_x(fighter, summon), 0)
        if receipt.status == "failed" then
            sf2.log.warn("Call to Arms spawn failed: " .. tostring(receipt.error))
            return
        end
        self.state.active = true
        show(fighter, 0)
        -- Greys the button until the assistant leaves, when the real cooldown starts.
        fighter:clear_flag(self.params.key)
        fighter:set_flag(self.params.key, 900)
        fighter:set_button_cooldown("raid_charge", 300)
    end,
    -- The assistant's own hits reach this callback too, as hits by `event.attack.actor_id`.
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or not self.state.active then return end
        local multiplier = 1 + STACK_BONUS * self.state.stacks
        if not (event.attack and event.attack.actor_id) then multiplier = multiplier * PRESENCE_BONUS end
        if multiplier ~= 1 then fighter:scale_outgoing_damage(multiplier) end
        if not event.blocked and self.state.stacks < MAX_STACKS then
            self.state.stacks = self.state.stacks + 1
            show(fighter, self.state.stacks)
        end
    end,
    -- Passive: 10% to absorb a hit that is neither magic nor a boss ability. Rolled once the hit is
    -- known to be magic or not, then spent by the damage step, so it adds to the Damage Absorption
    -- enchantment instead of sharing its roll.
    on_hit_post_crit = function(self, fighter, event)
        if event.target ~= "self" then return end
        self.state.absorb = not event.magic and not fighter:animation_is("BossAbility", "opponent")
            and absorb_roll:number() < ABSORB_CHANCE
    end,
    on_damage_resolving = function(self, fighter)
        if not self.state.absorb then return end
        self.state.absorb = false
        fighter:scale_incoming_damage(0)
    end,
}
