local sf2 = require("sf2")

-- Time Shift (the Set of Chronos enchantment, PERK_TIME_SHIFT_SET_TIME_SHIFTER in vanillaXml
-- perks.xml): a magic hit on the enemy slows it to a fifth of its speed for SlowFrames (360)
-- frames (SlowModel Speed="5") and marks it with the timed IsSlowedDown icon for as long. Its
-- projectiles flew at full speed, so a slowed enemy could still shoot, cast and use its boss
-- abilities as usual (Seby, 2026-11-27). While IsSlowedDown is on a fighter it now starts no
-- ranged throw, magic cast or boss ability, by button or by its tactic; what it already started
-- finishes. The slow's own length, its cooldown and its end at a round's close are the perk's.
sf2.perks.patch {
    perk = sf2.perks.get("core:perks/PERK_TIME_SHIFT_SET_TIME_SHIFTER"),
    forbid_moves = { flag = "IsSlowedDown", moves = { "ranged", "magic", "ability" } },
}
