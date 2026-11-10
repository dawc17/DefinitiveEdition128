local sf2 = require("sf2")

-- Definitive Edition moves of the game's moves.xml that no other DE128 file enables: the
-- rifle's second shot and the hit reaction it causes, and the wall stop of the Arcane
-- Martial Art punch.
for _, move in ipairs({ "RifleShot2Start", "RifleShot2Middle", "MiddleHitU", "ArcaneMartialArtPunchHitBoxWall" }) do
    sf2.moves.patch { move = move, enable = true }
end

-- Scoped differences from archived moves.xml, expressed through typed patches.
-- Guards describe the canonical source so incompatible bases fail explicitly.
-- RangedHeavyPlayer's Uninterrupt window covers the whole move in the game's moves.xml
-- (expected = {}: no start, no end); the archive ends it at sample 40. The sound frame is
-- in game frames:
-- ShopRangedTryOnHeavyPlayer starts at sample 3 with 3 frames per sample, so sample 18
-- is frame 48 and sample 16 is frame 42.
sf2.moves.patch {
    move = "RangedHeavyPlayer",
    windows = { change = { uninterruptible = { expected = {}, value = { to_sample = 40 } } } },
}
sf2.moves.patch {
    move = "ChakramFly",
    hit = { expected = "High", value = "MiddleShortPlus" },
}
sf2.moves.patch {
    move = "ShopRangedTryOnHeavyPlayer",
    sound_frame = { name = "snd_disk", expected = 48, value = 42 },
}
