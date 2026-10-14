local sf2 = require("sf2")
local registered = false
local result = {
    dialogue_pending = function() return false end, wake_notifications = function() end,
    defeat_pending = function() return false end, wake_defeat = function() end,
}
function result.register()
    if registered then return end
    local fields = {}
    for act = 1, 6 do
        for _, kind in ipairs { "opened", "pending", "dialogue_pending", "complete" } do
            fields["sensei_" .. kind .. "_" .. act] = false
        end
        fields["sensei_dialogue_next_" .. act] = 1
    end
    for act = 1, 6 do
        for index = 1, (act == 6 and 2 or 3) do
            fields["sensei_entered_" .. act .. "_" .. index] = false
        end
    end
    fields.sensei_shogun_greeted = false
    fields.sensei_defeat_pending = false
    fields.sensei_defeat_rng = 12859
    -- DE128 keeps one state schema (at most 64 fields); the Underworld story shares it.
    -- uw_intro: 0 not shown, 1 intro shown (followup pending), 2 complete. The other
    -- fields are sets of lower-case archive boss names, stored as ",boss_1,boss_2,"
    -- (see underworld_story.lua) so later data changes cannot reinterpret saves.
    fields.uw_intro = 0
    for _, set in ipairs { "entered", "win_pending", "win_shown", "loss_pending", "loss_shown" } do
        fields["uw_" .. set] = ","
    end
    fields.uw_sequence_next = 1
    fields.uw_sequence_key = ""
    -- Challengers (challengers.lua): the archived ChallengerBattlesUnlocked flag and
    -- the Challenger keys whose weapon-drop dialog is still due, as ",key,key,".
    fields.challengers_revealed = false
    fields.challenger_drops_pending = ","
    sf2.state.register { version = 1, fields = fields }
    registered = true
end
return result
