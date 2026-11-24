local sf2 = require("sf2")

-- Every core battle whose map placement the owner stages.xml changes from vanilla.
-- The archive moves Act 6's Duel clear of Sensei's Old Wounds entry; Seby's 2026-11-21 map
-- layout then places it (as Eclipse's own stages.xml does) at -295, 110. The locked Titan
-- button sits where Titan's own battle does (Eclipse stages.xml: -125, -75).
-- Seby's 2026-11-24 layout (his F6 map button file) moves Act 2's Duel down to -180, 105 and
-- Act 7's Survival and Duel to -290, -200 and -365, -5. An intermission battle and its normal
-- counterpart (and an _ECLIPSEMODE twin) always share a place; Act 7's C3 Survival and Duel
-- have no twins.
local moves = {
    { battle = "core:battles/zone_2/duel", x = -180, y = 105 },
    { battle = "core:battles/zone_2/duel_intermission", x = -180, y = 105 },
    { battle = "core:battles/zone_6/duel", x = -295, y = 110 },
    { battle = "core:battles/zone_6/duel_intermission", x = -295, y = 110 },
    { battle = "core:battles/zone_7/boss_titan_locked", x = -125, y = -75 },
    { battle = "core:battles/zone_7/c3_survival", x = -290, y = -200 },
    { battle = "core:battles/zone_7/c3_duel", x = -365, y = -5 },
}

for _, move in ipairs(moves) do
    sf2.battles.patch(move)
end
