local sf2 = require("sf2")
local words = require("content.text")

-- Seby's DE list (2026-11-08): once Titan is beaten in the story (not Eclipse mode), a dojo
-- button beside the dojo changer lets the player take one of the three Shadow portraits or a
-- Titan bodyguard's. Eclipse draws the button (the current portrait) and the chooser.
sf2.profile.avatar_picker {
    id = "avatar_changer",
    -- The fight content.challengers also unlocks on: the final story Titan fight.
    unlock_fight = "core:fights/zone_7/c3_boss_titan/6",
    choices = {
        { avatar = "avatar_hero", name = words.get("NAME_SHADOW") },
        { avatar = "avatar_masked", name = words.get("de128.avatar_changer.masked") },
        { avatar = "avatar_human", name = words.get("de128.avatar_changer.human") },
        { avatar = "man_titans_army_1", name = words.get("NAME_EMERALD") },
        { avatar = "man_titans_army_2", name = words.get("NAME_GARNET") },
        { avatar = "man_titans_army_3", name = words.get("NAME_TOPAZ") },
        { avatar = "man_titans_army_4", name = words.get("NAME_BERYL") },
    },
}
