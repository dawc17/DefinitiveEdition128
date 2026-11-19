local sf2 = require("sf2")
local words = require("content.text")

-- Optional, off by default (Seby, 2026-11-14): nine tracks play their Shadow Fight 2 Special
-- Edition versions wherever the game would play them, in fights, on the map and in menus. Its
-- own switch, apart from the Special Edition locations. Fights DE128 gives its archived
-- campaign music (content.campaign_music) keep that music. The dojo theme has its own choice below.
local se_music = sf2.settings.toggle {
    id = "se_music",
    label = words.read("de128.se_music.label"),
    description = words.read("de128.se_music.description"),
    group = "Audio",
    default = false,
}

-- The game's track file name (as stages and fights give it) and the SE file under audio/se_music.
local tracks = {
    { music = "fight37_Titan_Epic_Fight", file = "titan_epic_fight_se" },
    { music = "fight10_black_warrior", file = "black_warrior_se" },
    { music = "fight23_burning_town", file = "burning_town_se" },
    { music = "fight22_heavenly_clouds", file = "heavenly_clouds_se" },
    { music = "fight13_old_sensei", file = "old_sensei_se" },
    { music = "fight15_shadow_lady", file = "shadow_lady_se" },
    { music = "fight14_ship_battle", file = "ship_battle_se" },
    { music = "fight6_sparring", file = "sparring_se" },
}

for _, track in ipairs(tracks) do
    sf2.assets.replace {
        music = track.music,
        replacement = sf2.assets.audio("audio/se_music/" .. track.file),
        setting = se_music,
    }
end

-- The dojo theme (Seby, 2026-11-16; one picker since 2026-11-19): Normal keeps the game's own
-- theme; Special Edition, Shades and Shades pt. 2 each replace "menu", the track the dojo, map,
-- shop and profile play. Up to 0.59.0 these were three switches that turned each other off; each
-- choice names its old switch (from_switch), so a player who had one on starts on its choice.
local themes = {
    { id = "special_edition", file = "se_music/dojo_se", from_switch = "dojo_music_se" },
    { id = "shades", file = "dojo_music/dojo_shades", from_switch = "dojo_music_shades" },
    { id = "shades_2", file = "dojo_music/dojo_shades_2", from_switch = "dojo_music_shades_2" },
}

local choices = {
    { id = "normal", label = words.read("de128.dojo_theme.normal") },
}
for _, theme in ipairs(themes) do
    choices[#choices + 1] = {
        id = theme.id,
        label = words.read("de128.dojo_theme." .. theme.id),
        from_switch = theme.from_switch,
    }
end

local dojo_theme = sf2.settings.choice {
    id = "dojo_theme",
    label = words.read("de128.dojo_theme.label"),
    description = words.read("de128.dojo_theme.description"),
    group = "Audio",
    choices = choices,
    default = "normal",
}

for _, theme in ipairs(themes) do
    sf2.assets.replace {
        music = "menu",
        replacement = sf2.assets.audio("audio/" .. theme.file),
        setting = dojo_theme,
        choice = theme.id,
    }
end
