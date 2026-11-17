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

-- The game's track name (as stages and fights give it) and the SE file under audio/se_music.
local tracks = {
    { music = "fight37_Titan_Epic_Fight", file = "titan_epic_fight_se" },
    { music = "black_warrior", file = "black_warrior_se" },
    { music = "burning_town", file = "burning_town_se" },
    { music = "heavenly_clouds", file = "heavenly_clouds_se" },
    { music = "old_sensei", file = "old_sensei_se" },
    { music = "shadow_lady", file = "shadow_lady_se" },
    { music = "ship_battle", file = "ship_battle_se" },
    { music = "sparring", file = "sparring_se" },
}

for _, track in ipairs(tracks) do
    sf2.assets.replace {
        music = track.music,
        replacement = sf2.assets.audio("audio/se_music/" .. track.file),
        setting = se_music,
    }
end

-- The dojo theme (Seby, 2026-11-16): Normal, Special Edition, Shades or Shades pt. 2. "menu" is the
-- track the dojo, map, shop and profile play; all three switches off keeps the normal theme, and
-- turning one on turns the others off.
local dojo_themes = {
    { id = "dojo_music_se", file = "se_music/dojo_se" },
    { id = "dojo_music_shades", file = "dojo_music/dojo_shades" },
    { id = "dojo_music_shades_2", file = "dojo_music/dojo_shades_2" },
}
local registered = {}
for _, theme in ipairs(dojo_themes) do
    local switch = sf2.settings.toggle {
        id = theme.id,
        label = words.read("de128." .. theme.id .. ".label"),
        description = words.read("de128." .. theme.id .. ".description"),
        group = "Audio",
        default = false,
        excludes = #registered > 0 and registered or nil,
    }
    registered[#registered + 1] = switch
    sf2.assets.replace {
        music = "menu",
        replacement = sf2.assets.audio("audio/" .. theme.file),
        setting = switch,
    }
end
