local sf2 = require("sf2")

-- Changes in the owner's November 2026 stages.xml (against the archived DExml/stages.xml)
-- that apply to core battles. Only the deltas the public API can express live here.

-- Punching bag training, second fight: the Dojo_Disciple sparring partner now fights with
-- the Aggressive tactic (was Standard). Its stats and rules are unchanged, so the whole
-- warrior is restated with only the tactic changed.
sf2.battles.patch {
    fight = "core:fights/punchbag/training/2",
    opponents = { {
        fighter = "core:warrior-templates/dojo_disciple", tactic = "Aggressive",
        attributes = { WeaponDamage = 2, UnarmedDamage = 2, BodyDefense = 2, HeadDefense = -3, CriticalChance = 0 },
        attribute_alignments = {
            { factor = 0, shift = 0, priority = 1 },
            { factor = 1, shift = -10, priority = 1 },
        },
    } },
}
