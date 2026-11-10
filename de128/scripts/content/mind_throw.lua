local sf2 = require("sf2")
-- Mind Throw (MAGIC_MIND_THROW_NORMAL). The MindThrowNormal move graph is in the game's
-- moves.xml, restricted until enabled here, and its innate perk is the game's MindThrowNormal
-- (perks.xml), which content.restored_equipment gives the item.
for _, move in ipairs({
    "MindThrowPlayerNormal", "MindThrowPlayer2Normal", "MindThrowStartNormal",
    "MindThrowMiddleNormal", "MindThrowWallNormal", "MindThrowHitNormal",
}) do
    sf2.moves.patch { move = move, enable = true }
end
