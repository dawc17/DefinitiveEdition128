local sf2 = require("sf2")

-- Lightning Chain, DE128's special (Seby's plan, 2026-11-19: Lightning_Chain_Special_Concept_Plan).
-- Passive: every hit you land charges the enemy; 6 charges are spent on a lightning strike that
-- knocks the enemy down. Active, on the raid charge button: a row of Hermit Storm's bolts falls
-- in front of the player, each farther than the last; if it hits, Raiden mode makes every landed
-- hit charge faster. This file holds the numbers and the bolts; content.special_lightning_chain
-- the enchantment's rules and content.lightning_chain_cast the cast. Dandy keeps his own
-- native Lightning Chain (content.dandy_lightning_chain).

-- None of these numbers has been playtested. Frames are 1/60 s; damage 0.30 is 30.
-- The 10-second cooldown (600 frames, 300 at the start of a round) is the recharge that
-- content.boss_abilities gives every ability enchantment.
local TUNING = {
    charge_per_hit = { 1, 2 },          -- charges for each hit you land (average 1.5)
    raiden_charge_per_hit = { 3, 6 },   -- the same in Raiden mode (average 4.5)
    strike_cost = 6,                    -- charges a lightning strike spends (and the most shown)
    strike_damage = 0.10,               -- the plan sets none; Ken weighed it at about 10 base damage
    strike_gap = 60,                    -- frames before another strike may follow
    bolts = 5,                          -- bolts in the row
    bolt_damage = 0.30,                 -- each bolt, as the plan gives Hermit Storm's
    first_bolt = 100,                   -- units in front of the player the first bolt falls
    bolt_step = 100,                    -- each bolt this much farther than the one before
    bolt_gap = 8,                       -- frames between bolts
    release = 57,                       -- cast frame of the first bolt (native sample 20, as Dandy's)
    raiden_frames = 300,                -- Raiden mode: 5 seconds from the row's first hit
}

-- The bolts are Hermit Storm's: its hidden HERMIT_STORM item and the falling bolt of
-- HermitStormMiddle (vanillaXml moves.xml; the animations are byte-identical copies). Like the
-- native bolt it takes its height from the clip and only lines up across, its Magic-Node2_1
-- over a point. Frames (first sample 4, 3 frames a sample): the flash at sample 10 (frame 21),
-- the attack from sample 11 to the end, the screen shake at sample 13 (frame 30).
local storm_item = sf2.items.get("core:items/magic/HERMIT_STORM")
local CHILD = { weapon = { item = "HERMIT_STORM" }, rig = "SkeletonMagic" }
local ROW_ACTOR = "de128.lightning_chain_bolt"
local STRIKE_ACTOR = "de128.lightning_chain_strike"

-- spec: id, actor (the child's name), over (the point it falls on), damage, contact (how it
-- hits: its edge, or direct to always reach the enemy), and events/face for how it starts.
local function bolt(spec)
    -- HermitStormMiddle's attack; "HermitStorm" is the storm's own knockdown (OverheadHitFall).
    local attack = {
        from_sample = 11, damage = { amount = spec.damage, magic = 0, unarmed = -25 },
        impulse = { x = 150, y = 600 }, hit = "HermitStorm",
        no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery" },
    }
    for key, value in pairs(spec.contact) do attack[key] = value end
    return sf2.moves.register {
        id = spec.id, animation = sf2.assets.binary("animations/hermit_storm_middle"),
        inherit = { "MagicMissileFly", "MagicMissile" },
        first_sample = 4, priority = 500,
        no_wall_repulsion = true, no_magic_recharge = true,
        align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" }, position = spec.over },
        events = spec.events, face = spec.face,
        when = { actor = spec.actor },
        only_for = CHILD,
        attacks = { attack },
        on = {
            [21] = {
                { effect = { name = "LightningChainBolt", core_sequence = "mgc_effect_lightning_end",
                    scale = 1.2, time_scale = 2, position = { node = "Magic-Node2_1", y = -230 } } },
                { sound = { "snd_hermit_lightning", "snd_hermit_lightning2" } },
            },
            [30] = { shake = { effect_time = 60, amplitude_x = 7, frequency_x = 1,
                amplitude_y = 18, frequency_y = 0.5 } },
            finish = { delete_actor = "self" },
        },
    }
end

-- The row: one bolt per distance, each over the caster's pelvis that far ahead. The cast creates
-- them itself, as Hermit's storm is created, so they fall wherever the cast is played.
local row = {}
for index = 1, TUNING.bolts do
    row[index] = bolt { id = "lightning_chain_bolt_" .. index, actor = ROW_ACTOR,
        over = { node = "pelvis", of = "parent", x = TUNING.first_bolt + (index - 1) * TUNING.bolt_step },
        damage = TUNING.bolt_damage, contact = { edges = { "HermitStorm-Edge1" } }, face = "with_parent" }
end

-- The strike is called from Lua on the enemy, so Eclipse first places the new child. A moment's
-- hold comes first; the bolt that follows takes the clip's height again and lines up over the
-- enemy, as HermitStormMiddle0 does, and reaches the enemy without needing to touch it.
local strike_hold = sf2.moves.register {
    id = "lightning_chain_strike_hold", animation = sf2.assets.binary("animations/hermit_storm_start"),
    inherit = { "MagicMissileFly", "MagicMissile" },
    first_sample = 10, last_sample = 11, priority = 500,
    no_wall_repulsion = true, no_magic_recharge = true,
    face = "with_parent",
    when = { actor = STRIKE_ACTOR },
    only_for = CHILD,
}
bolt { id = "lightning_chain_strike", actor = STRIKE_ACTOR, over = { node = "pelvis", of = "enemy" },
    damage = TUNING.strike_damage, contact = { direct = true }, events = { { finish = strike_hold } } }
local strike = sf2.projectiles.register {
    id = "lightning_chain_strike", name = STRIKE_ACTOR, core_skeleton = "SkeletonMagic",
    item = storm_item, start_move = strike_hold, lifetime_frames = 120,
}

-- The cast's actions: bolt N at release + (N - 1) * bolt_gap frames.
local function row_actions()
    local actions = {}
    for index, move in ipairs(row) do
        actions[TUNING.release + (index - 1) * TUNING.bolt_gap] = { projectile = {
            name = ROW_ACTOR, core_skeleton = "SkeletonMagic", item = storm_item, start = move,
            lifetime_frames = 120,
        } }
    end
    return actions
end

return {
    tuning = TUNING,
    strike = strike,
    row_actions = row_actions,
    -- Move names that hits report in event.attack.animation_name.
    row_move = "de128:moves/lightning_chain_bolt_",
    strike_move = "de128:moves/lightning_chain_strike",
}
