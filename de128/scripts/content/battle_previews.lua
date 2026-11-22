local sf2 = require("sf2")
local words = require("content.text")

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
-- who keeps the battle's own picture. May's panel is titled Justice and reads "Justice accepted
-- your challenge."
local JUSTICE = words.read("de128.battle_previews.may_challenger")
local MAY = { preview = "preview_fights.may", challenger = JUSTICE, title = JUSTICE }
-- Fights 1-5 are the bodyguards in the battle's order (stages.xml C3_BOSS_TITAN and its
-- twin): each shows Seby's own picture (2026-11-22) and is titled with the bodyguard's name.
local BODYGUARDS = {}
for index, key in ipairs({ "assassin", "master", "guru", "corsair", "emperor" }) do
    local name = words.read("de128.battle_previews." .. key)
    BODYGUARDS[index] = {
        preview = sf2.assets.sprite("sprites/titan_bodyguards/preview_" .. key), challenger = name, title = name,
    }
end

-- Act 3's Sensei battle fights in the village, which the Special Edition locations switch swaps
-- for village_se: sprites/sensei/act3 (Seby's classic village) shows without it, act3_se with it.
-- Chosen here because replace_preview only takes battles already registered, and these are
-- registered later in loading (content.sensei_battles).
local se_locations = require("content.se_locations").setting
local ACT3_SE = sf2.assets.sprite("sprites/sensei/act3_se")
local ACT3 = { ["de128:battles/sensei_act_3_normal"] = true, ["de128:battles/sensei_act_3_eclipse"] = true }
-- Four Challengers fight on stages the same switch swaps (mountain, sakura, pink_lake,
-- waterfall); Seby's pictures of them on the Special Edition stage (2026-11-15) show with it.
-- Fisher, Outcast and Nova keep theirs. The battles come from content.challengers.
local CHALLENGERS_SE = {}
for _, key in ipairs({ "trickster", "hawk", "rose", "ronin" }) do
    CHALLENGERS_SE["de128:battles/challenger_" .. key] = sf2.assets.sprite("sprites/challenger/preview_" .. key .. "_se")
end
local TITAN = {
    ["core:battles/zone_7/c3_boss_titan"] = { may = "core:fights/zone_7/c3_fightwithmay/1" },
    ["core:battles/zone_7/c3_boss_titan_eclipsemode"] = { may = "core:fights/zone_7/c3_fightwithmay_eclipsemode/1", replayable = true },
}

sf2.battles.on_preview(function(battle)
    if ACT3[battle.id] then return sf2.settings.get(se_locations) and ACT3_SE or nil end
    local challenger = CHALLENGERS_SE[battle.id]
    if challenger then return sf2.settings.get(se_locations) and challenger or nil end
    local titan = TITAN[battle.id]
    if titan == nil or battle.fight == nil then return nil end
    if battle.index >= 1 and battle.index <= 5 then return BODYGUARDS[battle.index] end
    -- The story fight meets May once; the Eclipse twin meets her before every Titan win.
    local titan_wins = titan.replayable and sf2.profile.fight(battle.fight).wins or 0
    if sf2.profile.fight(titan.may).wins <= titan_wins then return MAY end
    return nil
end)
