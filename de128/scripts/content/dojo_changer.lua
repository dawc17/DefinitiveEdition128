local sf2 = require("sf2")

-- The remaining archived choices need missing installed art or params. Keep the
-- order of the choices whose location dependencies have been audited.
local choices = {
    { location = "dojo", label = "DefaultDojo" },
    { location = "new_year_24_china_dojo", label = "DojoChinese24" },
    { location = "dojo_indian_event", label = "DojoIndia" },
    { location = "dojo_indian_event_22", label = "DojoIndia22" },
    { location = "dojo_india24", label = "DojoIndia24" },
    { location = "haloween_dojo", label = "DojoHalloween" },
    { location = "haloween_dojo_2019", label = "DojoHalloween19" },
    { location = "dojo_hw21", label = "DojoHalloween21" },
    { location = "dojo_american_event_22", label = "DojoAmerican22" },
    { location = "dojo_hw22", label = "DojoStudio" },
}

for _, choice in ipairs(choices) do
    choice.preview = sf2.assets.sprite("sprites/dojo_changer/" .. choice.location)
    choice.name = sf2.localization.key("dojo." .. choice.label)
end
-- Eclipse draws the picker (a large medallion with a gliding strip) and hosts its
-- button in the dojo menu, below the disciple toggle's slot.
sf2.locations.dojo_picker {
    id = "dojo_changer",
    button = sf2.assets.sprite("sprites/dojo_changer/credits"),
    title = sf2.localization.key("dojo.DojoChangerTitle"),
    choices = (function()
        local list = {}
        for i, choice in ipairs(choices) do
            list[i] = { location = "core:locations/" .. choice.location, name = choice.name, preview = choice.preview }
        end
        return list
    end)(),
}

-- Earlier versions saved a map button into profiles; remove it at each session start.
sf2.quests.register {
    id = "dojo_changer_map_button", place = "map", events = { "session" },
    actions = { { type = "hide_map_button", id = "dojo_changer" } },
}

return choices
