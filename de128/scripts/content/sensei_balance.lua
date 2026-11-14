-- Old Wounds balance (Seby, 2026-11-14): Sensei fights even. Every Sensei opponent is fully
-- aligned (factor 1), so damage depends only on the opponent's shift, not on either side's
-- attributes: shift 6 for normal guards and bosses, 8 for the normal Prince (Act 6 fight 2),
-- 7 for every Eclipse gauntlet (content.sensei_guard_opponents, sensei_boss_opponents,
-- sensei_act_one_opponents). A shift of s makes the opponent deal 2^(s/10) and take 2^(-s/10);
-- fight strength k scales those by sqrt(k) and 1/sqrt(k), so k = 2^(-2s/10) cancels the shift.

local function shift(id)
    local act, mode, fight = tostring(id):match("de128:battles/sensei_act_(%d)_(%a+)|(%d+)$")
    if act == nil then return nil end
    if mode == "eclipse" then return 7 end
    if act == "6" and fight == "2" then return 8 end
    return 6
end

-- The fight strength that cancels a Sensei fight's shift; 1 for every other fight.
local function strength(id)
    local s = shift(id)
    if s == nil then return 1 end
    return 2 ^ (-2 * s / 10)
end

return { strength = strength, shift = shift }
