local sf2 = require("sf2")

-- Applies to timed battles only; training and untimed fights keep their behavior.
sf2.timers.set { subsystem = "battle", seconds = 150 }

-- Both new and already-paid saved forge orders use normal instant settlement.
-- The host applies the enchantment and clears the order; Lua never rewrites saves.
sf2.timers.set {
    subsystem = "forge",
    seconds = 0,
    skip_enabled = true,
    complete_pending = true,
}
