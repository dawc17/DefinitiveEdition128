local sf2 = require("sf2")

-- The mythical set enchantments' charge, shown in the fight meter that Stone Fetters and Searing
-- Luminary draw (owner, 2026-11-26). Each meter reads the original perk's own state, so nothing
-- about the enchantments changes: the first phase that applies is shown. Karma and Plot Twist
-- have no meter (owner's choice). Names below are the perks' own (vanillaXml perks.xml).
local function meter(perk, segments, phases)
    sf2.perks.patch { perk = sf2.perks.get("core:perks/" .. perk), meter = { segments = segments, phases = phases } }
end

-- Roaring Luminary: four unbroken strikes open the lava pool for 450 frames.
meter("PERK_MAGMA_VOLCANO_SET", 4, {
    { flag = "MagmaActive", color = "#FF7A2E" },
    { variable = "StrikeCount", max = 4, color = "#B4532A" },
})

-- Predator's Fury: HitsLeft counts 4 down to the bite; then the orb waits to be touched and its
-- buff waits for the next hit.
meter("PERK_KARCER_HUNGER_SET", 4, {
    { flag = "OrbBuffActive", color = "#FF5A6E" },
    { flag = "CheckForOrbTouch", color = "#E0475A" },
    { variable = "HitsLeft", max = 4, count = "down", color = "#8C2F39" },
})

-- Tempest Rage: landed damage builds MyCounter to 0.6 (steps at 0.2, 0.4, 0.6), damage taken
-- drains it; full, the next hit is the tornado strike.
meter("PERK_MONK_SET_WHIRL", 3, {
    { flag = "WhirlActiveIcon", color = "#A6E8F0" },
    { variable = "MyCounter", max = 0.6, color = "#5FA8B8" },
})

-- Typhoon of Spirits: the same counter to 1.4 (steps at 0.5, 1 and 1.4, not even, so one bar);
-- full, the shield deflects the next strike.
meter("PERK_SENTINEL_SET_SUPER_RETURN", 1, {
    { flag = "WhirlActiveIcon", color = "#B7C4FF" },
    { variable = "MyCounter", max = 1.4, color = "#6B7FD7" },
})

-- Arcane Martial Art: stacks to four arm the arcane punch; after it lands, a 150-frame cooldown.
meter("PERK_ARCANE_MARTIAL_ART_SET_NEO_WANDERER", 4, {
    { flag = "ArcanePunch", color = "#D7B8FF" },
    { flag = "CD", show = "passed", color = "#5D4A78" },
    { variable = "StackCount", max = 4, color = "#9B6BD6" },
})

-- Icy Resistance: the blizzard shield while it is up; once it absorbs a strike, the empowered
-- attacks left (StikeCount, as the perk spells it).
meter("PERK_GUARDIAN_SET_PROTECTION", 3, {
    { flag = "GuardianPerkIcon", color = "#BFE6FF" },
    { variable = "StikeCount", max = 3, color = "#6FB6E8" },
})

-- Cordyceps: damage saturates StackCount to 100 (it fades a point a second); then the spore
-- drains the enemy for 300 frames.
meter("PERK_CORDYCEPS_FUNGUS_SET", 1, {
    { flag = "Cordyceps", color = "#C9D86A" },
    { variable = "StackCount", max = 100, color = "#8FA34A" },
})

-- Time Shift: the enemy's 360-frame slow, then the perk's own 360-frame cooldown; full when ready.
meter("PERK_TIME_SHIFT_SET_TIME_SHIFTER", 1, {
    { flag = "IsSlowedDown", on = "opponent", color = "#7A7AF0" },
    { flag = "SlowedCD", show = "passed", color = "#3B3B6E" },
    { color = "#A9A9FF" },
})

-- Crimson Corruption: the curse's level (EffectStep, up to 15) once it has one; before that, the
-- damage dealt toward the first level (DamageCounter, 0.25 a level).
meter("PERK_WARLOCK_SET_CURSE", 1, {
    { variable = "EffectStep", max = 15, only_above_zero = true, color = "#C0182E" },
    { variable = "DamageCounter", max = 0.25, color = "#6E1220" },
})

-- Squall: full while the gust is ready; after a low kick launches it, the 300-frame cooldown.
meter("PERK_GUST_SET_WIND_MAKER", 1, {
    { flag = "GustEffectCooldown", show = "passed", color = "#4E7A6A" },
    { color = "#9FE3C8" },
})
