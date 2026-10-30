local sf2 = require("sf2")
local words = require("content.text")

-- Optional: a clean critical hit plays the DE critical sting (snd_crit). The archived DE
-- moves played it from their CriticalEffect trigger; the shipped moves only carry the
-- visual effect, so the sound hangs off a screen grade that changes nothing on screen.
-- Blocked criticals stay silent, and title-screen sparring never fires it.
local critical_sound = sf2.settings.toggle {
    id = "critical_sound",
    label = words.read("de128.critical_sound.label"),
    description = words.read("de128.critical_sound.description"),
    group = "Audio",
    default = true,
}

sf2.fx.screen {
    id = "critical_sound",
    trigger = "critical",
    hold = 0,
    duration = 0.02,
    sound = { sound = "snd_crit" },
    setting = critical_sound,
}
