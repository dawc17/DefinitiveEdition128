local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- DE's ShadowCloakPlayer: the RaidCharge cast of the Shadow Cloak (Special Recipe I). The move
-- is in the game's moves.xml, restricted until enabled here. Its lock is the game's
-- PERK_SHADOW_CLOAK; DE128's own shadow_cloak perk unlocks it too. The cloak itself (glass
-- cloak, unblockable hits, recharge) is that perk's behavior in content.boss_abilities, which
-- starts it on frame 13 of this move, so the cast waits for DE128's recharge and cloak flags.
sf2.moves.patch {
    move = "ShadowCloakPlayer",
    enable = true,
    when = { not_mod = { abilities.ready("shadow_cloak"), abilities.uncloaked() } },
    perk_locks = { add = { {
        source_perk = sf2.perks.get("core:perks/PERK_SHADOW_CLOAK"), perk = abilities.perks.shadow_cloak,
    } } },
}

return { move = "ShadowCloakPlayer" }
