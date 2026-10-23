local sf2 = require("sf2")

-- Pending integration: the caller must supply the recovered perk-state reader.
-- Charge inventory and the forced Sensei loadout are not substitutes for it.
-- One rule table per script context: the Sensei story and the Underworld share it.
local registered = nil
local function register(is_available)
    if registered then return registered end
    assert(type(is_available) == "function", "Sensei RaidCharge requires a perk-state reader")
    -- A rule table: every fight that lists it shares one registered behavior.
    registered = {
        kind = "behavior", target = "player",
        behavior = {
            on_round_begin = function(_, fighter)
                local available = is_available()
                assert(type(available) == "boolean", "Sensei RaidCharge availability must be boolean")
                fighter:set_control_blocked("raid_charge", not available)
            end,
        },
    }
    return registered
end

return { register = register }
