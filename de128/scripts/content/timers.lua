local sf2 = require("sf2")

-- Applies to timed battles only; training and untimed fights keep their behavior.
sf2.game.timers { subsystem = "battle", seconds = 150 }
-- Underworld and other raid rounds have no time limit.
sf2.game.timers { subsystem = "raid", endless = true }

-- Both new and already-paid saved forge orders use normal instant settlement.
-- The host applies the enchantment and clears the order; Lua never rewrites saves.
sf2.game.timers {
    subsystem = "forge",
    seconds = 0,
    skip_enabled = true,
    complete_pending = true,
}
