local sf2 = require("sf2")
-- Definitive Edition's additions to the default (unarmed) moveset. The game's moves.xml
-- holds them, restricted until a mod enables them:
--   FrontJumpScissorsKick  Up-Forward + Kick, Kick
--   AxeKickOld             Forward + Kick, Kick
--   WallRunUp              Back + Kick, Kick near the back wall
--   AirPunch               Down-Forward + Punch
--   ThrowLegPush           Back + Kick (or Forward + Punch facing a wall) in throw range
-- plus the throw's victim, stand-up and profile-preview moves.
for _, move in ipairs({
    "FrontJumpScissorsKick", "AxeKickOld", "WallRunUp", "AirPunch",
    "ThrowLegPush", "ThrowLegPushV", "StandupAfterLegFall", "ThrowLegPushProfile", "ThrowLegPushVProfile",
}) do
    sf2.moves.patch { move = move, enable = true }
end

-- The second Kick of a double kick reaches Wall Run while BackKick is outside Uninterrupt
-- and inside SemiUninterrupt. BackKick's 0-4 window is widened to 0-6 for a quick tap
-- (owner's playtest). Those numbers are animation samples, and BackKick's windows start
-- at sample 0, before its first sample (1), so the bounds are written in samples.
-- FrontKick needs no patch: the game's FrontKick now has the DE 0-4 SemiUninterrupt window.
sf2.moves.patch {
    move = "BackKick",
    windows = {
        change = {
            semi_uninterruptible = { expected = { from_sample = 0, to_sample = 4 }, value = { to_sample = 6 } },
            uninterruptible = { expected = { from_sample = 5, to_sample = 18 }, value = { from_sample = 7 } },
        },
    },
}
