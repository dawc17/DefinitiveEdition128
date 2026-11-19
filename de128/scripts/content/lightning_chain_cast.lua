local sf2 = require("sf2")
local abilities = require("content.boss_abilities")
local chain = require("content.lightning_chain")

-- Lightning Chain's cast on the raid charge button (content.lightning_chain has the plan). It
-- plays Dandy's native LightingChainPlayer pose (magic_death_ray_player, a byte-identical copy)
-- and drops the row of bolts from frame 57, native sample 20, where Dandy's chain appears.
-- Dandy keeps his own native move (content.dandy_lightning_chain); this one is the enchantment's.
-- Frames: first sample 2 with 3 frames a sample; the cast cannot be interrupted until the end
-- of sample 39 (frame 116), as in the native move.
return sf2.moves.register {
    id = "lightning_chain_player", animation = sf2.assets.binary("animations/magic_death_ray_player"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    type = "attack",
    no_wall_repulsion = true, first_sample = 2,
    priority = 200,
    align = "right_heel",
    when = {
        keys = "raid_charge",
        not_mod = { abilities.ready("lightning_chain"), "SilenceIcon" },
        controllable = true,
    },
    only_for = { perk = abilities.perks.lightning_chain, rig = "Skeleton" },
    windows = { uninterruptible = { to_sample = 39 } },
    on = chain.row_actions(),
    events = "controlled",
    face = "enemy",
}
