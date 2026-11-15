local sf2 = require("sf2")
local words = require("content.text")

-- Optional, off by default (Seby, 2026-11-14): nine tracks play their Shadow Fight 2 Special
-- Edition versions wherever the game would play them, in fights, on the map and in menus. Its
-- own switch, apart from the Special Edition locations. Fights DE128 gives its archived
-- campaign music (content.campaign_music) keep that music. The SE dojo theme (Seby, 2026-11-15)
-- replaces "menu", the track the dojo, map, shop and profile play.
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
    { music = "menu", file = "dojo_se" },
}

for _, track in ipairs(tracks) do
    sf2.assets.replace {
        music = track.music,
        replacement = sf2.assets.audio("audio/se_music/" .. track.file),
        setting = se_music,
    }
end
