local sf2 = require("sf2")
local words = require("content.text")
-- The three archived MindThrowNormal triggers, implemented as Lua decisions.
-- The behavior is registered under the perk's ID, "mind_throw".
local behavior = {
    on_animation_start = function(_, fighter, event)
        if event.target == "self" and event.animation_name == "de128:moves/mind_throw_player" then
            if not fighter:has_flag("pending") then fighter:set_flag("pending") end
        elseif event.animation_name == "de128:moves/mind_throw_wall" then
            fighter:clear_flag("pending")
        elseif event.target ~= "self" and event.animation_name == "de128:moves/mind_throw_hit"
            and fighter:has_flag("pending") then
            fighter:clear_flag("pending")
        end
    end,
}
return sf2.perks.register {
    id = "mind_throw", behavior = behavior,
    display_name = words.own("perk.mind_throw.name", "MAGIC_MIND_THROW_NORMAL"),
    description = words.own("perk.mind_throw.description", "de128.mind_throw.description"),
}
