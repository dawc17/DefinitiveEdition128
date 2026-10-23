local sf2 = require("sf2")

-- Archived choices keep the DE order; every installed location whose params
-- declare Dojo="1" is offered too, next to its series. new_year_china_dojo
-- replaces the archive's removed new_year_24_china_dojo under the same label.
local choices = {
    { location = "dojo", label = "DefaultDojo" },
    { location = "new_year_china_dojo", label = "DojoChinese24" },
    { location = "dojo_indian_event", label = "DojoIndia" },
    { location = "dojo_indian_event_22", label = "DojoIndia22" },
    { location = "dojo_india24", label = "DojoIndia24" },
    { location = "dojo_india25", label = "DojoIndia25" },
    { location = "haloween_dojo", label = "DojoHalloween" },
    { location = "haloween_dojo_2019", label = "DojoHalloween19" },
    { location = "dojo_hw21", label = "DojoHalloween21" },
    { location = "whisper_raid", label = "DojoWhisper" },
    { location = "dojo_american_event", label = "DojoAmerican" },
    { location = "dojo_american_event_22", label = "DojoAmerican22" },
    { location = "dojo_american_event_26", label = "DojoAmerican26" },
    { location = "dojo_new_year_22", label = "DojoNewYear22" },
    { location = "dojo_hw22", label = "DojoStudio" },
    { location = "dojo_8_march", label = "Dojo8March" },
    { location = "ritual_battle_raid", label = "DojoRitual" },
}

for _, choice in ipairs(choices) do
    choice.preview = sf2.assets.sprite("sprites/dojo_changer/" .. choice.location)
    choice.name = sf2.text.get("dojo." .. choice.label)
end
-- Eclipse draws the picker (a large medallion with a gliding strip) and hosts its
-- button in the dojo menu, below the disciple toggle's slot.
sf2.locations.dojo_picker {
    id = "dojo_changer",
    button = sf2.assets.sprite("sprites/dojo_changer/button"),
    button_pressed = sf2.assets.sprite("sprites/dojo_changer/button_pressed"),
    title = sf2.text.get("dojo.DojoChangerTitle"),
    choices = (function()
        local list = {}
        for i, choice in ipairs(choices) do
            list[i] = { location = "core:locations/" .. choice.location, name = choice.name, preview = choice.preview }
        end
        return list
    end)(),
}

-- Earlier versions saved a map button into profiles; remove it at each session start.
sf2.story.on("session", function()
    sf2.map.hide_button("dojo_changer")
end)

return choices
