-- The DE archive names its shop groups after the acts (ACT_2 ... ACT_7_3, INTERMISSION); the
-- game unlocks the same groups under its own names (ZONE_2 ... ZONE_7_3, ZONE_IM), as the
-- story reaches each act. An item whose group the save never unlocks is never sold, so every
-- DE group is translated before it reaches the shop. Act 1 items have no group.
-- GATES_OF_SHADOWS (Shadow Lord's sword and the other level-37 items) has no game group: DE
-- switched it on together with INTERMISSION (Assets/DExml/quests.xml Items_ZoneIM_Toggle, at
-- level 37), so it opens with the game's ZONE_IM.
local GAME = {
    ACT_2 = "ZONE_2", ACT_3 = "ZONE_3", ACT_4 = "ZONE_4", ACT_5 = "ZONE_5", ACT_6 = "ZONE_6",
    ACT_7_1 = "ZONE_7", ACT_7_2 = "ZONE_7_2", ACT_7_3 = "ZONE_7_3", INTERMISSION = "ZONE_IM",
    GATES_OF_SHADOWS = "ZONE_IM",
}

-- The game's shop group for a DE group; empty and unknown names pass through unchanged.
local function game(group)
    if group == nil or group == "" then return group end
    return GAME[group] or group
end

-- The DE group of the archive's shop items of each level (content.shop_data and the restored
-- items): Act 1 to level 6, Act 2 to 12, Act 3 13-18, Act 4 19-24, Act 5 25-30, Act 6 31-36,
-- the Gates of Shadows 37, the Intermission 38-43, Act 7 45-46, 48-49 and 50-52. No archived
-- item is of level 44 or 47; each counts with the act before it.
local BY_LEVEL = {
    { 6, "" }, { 12, "ACT_2" }, { 18, "ACT_3" }, { 24, "ACT_4" }, { 30, "ACT_5" }, { 36, "ACT_6" },
    { 37, "GATES_OF_SHADOWS" }, { 44, "INTERMISSION" }, { 47, "ACT_7_1" }, { 49, "ACT_7_2" }, { 52, "ACT_7_3" },
}

-- The DE group an item of this level belongs to ("" for Act 1), for content that has a level
-- but no archived group, such as content.set_chests' chests.
local function for_level(level)
    for _, row in ipairs(BY_LEVEL) do
        if level <= row[1] then return row[2] end
    end
    return BY_LEVEL[#BY_LEVEL][2]
end

return { game = game, for_level = for_level }
