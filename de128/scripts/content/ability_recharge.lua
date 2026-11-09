-- Start an ability enchantment's recharge: the timed flag its move checks, and the button sweep.
-- Shared by content.boss_abilities and the content.special_* modules that end a cooldown themselves.
return function(self, fighter, frames)
    local key = self.params.key
    fighter:clear_flag(key)
    fighter:set_flag(key, frames)
    fighter:set_button_cooldown("raid_charge", frames)
end
