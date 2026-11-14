local sf2 = require("sf2")

-- The owner's 2026-11 battle previews for single fights (core preview_fights.*): these
-- battles share their stage's picture in the game, so each gets its own. Shown in both
-- the regular and the Special Edition look.
local fights = {
    ["core:battles/zone_7/miniboss_ancient"] = "preview_fights.ancient",
    ["core:battles/zone_7/miniboss_cypher"] = "preview_fights.cypher",
    ["core:battles/zone_7/miniboss_shroud2"] = "preview_fights.shroud",
}

for battle, replacement in pairs(fights) do
    sf2.battles.replace_preview { battle = battle, replacement = replacement }
end

-- Titan's citadel (C3_BOSS_TITAN and its Eclipse twin) follows the player's progress: fights
-- 1-5 are the five bodyguards; entering fight 6 first sends the player to May until she is
-- beaten (quests Zone7FightWithMay and Zone7FightWithMay_EclipseMode), and only then to Titan,
-- who keeps the battle's own picture.
local TITAN = {
    ["core:battles/zone_7/c3_boss_titan"] = { may = "core:fights/zone_7/c3_fightwithmay/1" },
    ["core:battles/zone_7/c3_boss_titan_eclipsemode"] = { may = "core:fights/zone_7/c3_fightwithmay_eclipsemode/1", replayable = true },
}

sf2.battles.on_preview(function(battle)
    local titan = TITAN[battle.id]
    if titan == nil or battle.fight == nil then return nil end
    if battle.index <= 5 then return "preview_fights.titan_bodyguards" end
    -- The story fight meets May once; the Eclipse twin meets her before every Titan win.
    local titan_wins = titan.replayable and sf2.profile.fight(battle.fight).wins or 0
    if sf2.profile.fight(titan.may).wins <= titan_wins then return "preview_fights.may" end
    return nil
end)
