-- The DE archive names its shop groups after the acts (ACT_2 ... ACT_7_3, INTERMISSION); the
-- game unlocks the same groups under its own names (ZONE_2 ... ZONE_7_3, ZONE_IM), as the
-- story reaches each act. An item whose group the save never unlocks is never sold, so every
-- DE group is translated before it reaches the shop. Act 1 items have no group.
local GAME = {
    ACT_2 = "ZONE_2", ACT_3 = "ZONE_3", ACT_4 = "ZONE_4", ACT_5 = "ZONE_5", ACT_6 = "ZONE_6",
    ACT_7_1 = "ZONE_7", ACT_7_2 = "ZONE_7_2", ACT_7_3 = "ZONE_7_3", INTERMISSION = "ZONE_IM",
}

-- The game's shop group for a DE group; empty and unknown names pass through unchanged.
local function game(group)
    if group == nil or group == "" then return group end
    return GAME[group] or group
end

return { game = game }
