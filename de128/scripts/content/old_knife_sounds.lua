local sf2 = require("sf2")
local words = require("content.text")

-- Optional: knives and daggers swing with the older Shadow Fight 2 knife sounds instead of
-- the sword swishes their moves play. Only the exact subtypes Knives and Daggers are
-- affected (not ButcherKnives or CrescentKnives). The recordings are core assets, so this
-- needs no audio files of its own. The swap follows the switch live, with no restart.
local old_knives = sf2.settings.toggle {
    id = "old_knife_sounds",
    label = words.read("de128.old_knife_sounds.label"),
    description = words.read("de128.old_knife_sounds.description"),
    group = "Audio",
    default = false,
}

for number = 1, 3 do
    sf2.assets.replace {
        sound = "snd_swish_sword" .. number,
        replacement = sf2.assets.audio("core:gamedata/sounds/swish_sword" .. number),
        subtypes = { "Knives", "Daggers" },
        setting = old_knives,
    }
end
