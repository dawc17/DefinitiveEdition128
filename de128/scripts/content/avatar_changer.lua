local sf2 = require("sf2")
local words = require("content.text")

-- Seby's DE list (2026-11-08): once Titan is beaten in the story (not Eclipse mode), a dojo
-- button beside the dojo changer lets the player take one of the three Shadow portraits or one
-- of the Titan's five bodyguards'. Eclipse draws the chooser.
sf2.profile.avatar_picker {
    id = "avatar_changer",
    -- A portrait glyph on the dojo menu's button disc (built from the difficulty button's disc).
    button = sf2.assets.sprite("sprites/avatar_changer/button"),
    button_pressed = sf2.assets.sprite("sprites/avatar_changer/button_pressed"),
    -- The fight content.challengers also unlocks on: the final story Titan fight.
    unlock_fight = "core:fights/zone_7/c3_boss_titan/6",
    choices = {
        { avatar = "avatar_hero", name = words.get("NAME_SHADOW") },
        { avatar = "avatar_masked", name = words.get("de128.avatar_changer.masked") },
        { avatar = "avatar_human", name = words.get("de128.avatar_changer.human") },
        -- The five fights before the Titan himself (c3_boss_titan/1-5). A bodyguard's portrait
        -- also takes the bodyguard's name on the fight HUD (Seby, 2026-11-14); the Shadow
        -- portraits above give the player's own name back.
        { avatar = "character_assasin", name = words.get("characterAssasin"), rename = true },
        { avatar = "character_master", name = words.get("characterMaster"), rename = true },
        { avatar = "character_guru", name = words.get("characterGuru"), rename = true },
        { avatar = "character_corsair", name = words.get("characterCorsair"), rename = true },
        { avatar = "character_emperor", name = words.get("characterEmperor"), rename = true },
    },
}
