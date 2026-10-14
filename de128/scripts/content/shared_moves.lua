local sf2 = require("sf2")

-- Scoped differences from archived moves.xml, expressed through typed patches.
-- Guards describe the canonical source so incompatible bases fail explicitly.
-- RangedHeavyPlayer's Uninterrupt window starts at sample 0, before the move's
-- first sample (3), so its bounds are written in samples. The sound frame is in
-- game frames: ShopRangedTryOnHeavyPlayer starts at sample 3 with 3 frames per
-- sample, so sample 18 is frame 48 and sample 16 is frame 42.
sf2.moves.patch {
    move = "RangedHeavyPlayer",
    windows = { change = { uninterruptible = { expected = { from_sample = 0, to_sample = 42 }, value = { to_sample = 40 } } } },
}
sf2.moves.patch {
    move = "ChakramFly",
    hit = { expected = "High", value = "MiddleShortPlus" },
}
sf2.moves.patch {
    move = "ShopRangedTryOnHeavyPlayer",
    sound_frame = { name = "snd_disk", expected = 48, value = 42 },
}
for _, move in ipairs({ "MassBombPlayer", "LightningArrowPlayer" }) do
    sf2.moves.patch {
        move = move,
        when = { not_mod = "Stun" },
    }
end
