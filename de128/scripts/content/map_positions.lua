local sf2 = require("sf2")

-- Every core battle whose map placement the owner stages.xml changes from vanilla.
-- The archive moves Act 6's Duel clear of Sensei's Old Wounds entry; Seby's 2026-11-21 map
-- layout then places it (as Eclipse's own stages.xml does) at -295, 110. The locked Titan
-- button sits where Titan's own battle does (Eclipse stages.xml: -125, -75).
local moves = {
    { battle = "core:battles/zone_6/duel", x = -295, y = 110 },
    { battle = "core:battles/zone_6/duel_intermission", x = -295, y = 110 },
    { battle = "core:battles/zone_7/boss_titan_locked", x = -125, y = -75 },
}

for _, move in ipairs(moves) do
    sf2.battles.patch(move)
end
