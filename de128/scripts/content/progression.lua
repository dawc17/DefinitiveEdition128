local sf2 = require("sf2")
local perks = require("content.combat_perks")

-- DoubleJumpKick, ElbowStrike, TwoFootJumpKick, BackFlipKick and both Suplex moves have no
-- direct perk lock in the game's moves.xml any more, as in the DE moves.

-- Assets/DExml/CharacterProgress.xml: PerkTree/Level Values 4,8,11,14,17.
sf2.perks.patch {
    branch = {
        level = 4,
        entries = {
            { action = "unlock", perk = perks.master_of_style },
            { action = "unlock", perk = perks.relentless },
        },
    },
}
for _, level in ipairs({ 8, 11, 14, 17 }) do
    sf2.perks.patch {
        branch = {
            level = level,
            entries = {
                { action = "upgrade", perk = perks.master_of_style },
                { action = "upgrade", perk = perks.relentless },
            },
        },
    }
end

return perks
