local sf2 = require("sf2")

-- War Whirl: armored while whirling, and Glory in Death, a once-per-round last stand.
local WHIRL = "de128:moves/war_whirl_player"
local MELEE_BONUS = 1.5
local BURN_SHARE = 0.02         -- of max health, every second
local BURN_EVERY = 60
local glory_icon = sf2.assets.sprite("core:ui/skills/IconPainRage_Blue")

return {
    state = { used = false, burning = false, burn_clock = 0, enlightenment_off = false },

    -- Armor against normal attacks; ranged weapons, magic and boss abilities still interrupt.
    on_hit_pre_crit = function(self, fighter, event)
        if event.target == "self" and fighter:animation_is(WHIRL)
            and not event.ranged and not event.magic and not fighter:animation_is("BossAbility", "opponent") then
            fighter:set_hit_armored(true)
        end
    end,

    on_damage_resolving = function(self, fighter, event)
        if self.state.used or event.damage <= 0 then return end
        local combat = fighter:snapshot()
        if not combat or combat.self.max_health <= 0 then return end
        if event.damage < combat.self.health then return end
        fighter:scale_incoming_damage(0)
        fighter:change_health(combat.self.max_health - combat.self.health)
        self.state.used = true
        self.state.burning = true
        fighter:show_status_icon("glory", glory_icon, 3600)
    end,

    on_post_hit = function(self, fighter, event)
        if self.state.used and event.target == "opponent" and (event.weapon or event.unarmed)
            and not event.ranged and not event.magic then
            fighter:scale_outgoing_damage(MELEE_BONUS)
        end
    end,

    on_tick = function(self, fighter)
        if not self.state.enlightenment_off then
            self.state.enlightenment_off = true
            fighter:set_perk_disabled("PERK_ENLIGHTENMENT", true)
        end
        if not self.state.burning then return end
        self.state.burn_clock = self.state.burn_clock + 1
        if self.state.burn_clock < BURN_EVERY then return end
        self.state.burn_clock = 0
        local combat = fighter:snapshot()
        if combat then fighter:change_health(-BURN_SHARE * combat.self.max_health) end
    end,
}
