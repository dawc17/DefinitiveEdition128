local sf2 = require("sf2")

-- Seby's Rifle and Musket plan (2026-11-08): each Super Slash then recharges for 3 seconds,
-- shown as a ring filling round the punch button, and the Musket's ball flies 1.5x faster.
-- A move cooldown is native: it holds for opponents too, and in dojo practice.
for _, move in ipairs { "RifleSuperSlash", "MusketSuperSlash" } do
    sf2.moves.patch { move = move, cooldown = { frames = 180, button = "punch" } }
end

-- vanillaXml moves.xml: MusketShotMiddle carries <Velocity X="30"/>.
sf2.moves.patch { move = "MusketShotMiddle", speed = { expected = 30, value = 45 } }
