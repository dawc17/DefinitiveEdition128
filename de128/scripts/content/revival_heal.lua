local sf2 = require("sf2")
local words = require("content.text")

-- Revival Heal: the Revival Set's mythical enchantment (Seby, 2026-11-24). It does nothing yet;
-- the set's chest (content.set_chests) and Complex Recipe II (content.forge) already hand it out,
-- so pieces carry it once its behaviour is written. The game's own unused stub for this set is
-- PERK_REVIVAL ("Strengthened Vitality", Enchantments.EnchantmentRegen); DE128 shows Seby's lotus
-- (ResearchSources/seby_2026-11-24/emoji_MythicalRevivalHeal.png) instead.
return sf2.perks.register {
    id = "revival_heal",
    display_name = words.own("special.revival_heal.name", "special.revival_heal.name"),
    description = words.own("special.revival_heal.description", "special.revival_heal.description"),
    icon = sf2.assets.sprite("sprites/enchantments/revival_heal"),
    kind = "combo",
    -- A behaviour needs at least one handler (on_round_begin, on_tick, on_post_hit...); this one does
    -- nothing until Revival Heal is written.
    behavior = { on_round_begin = function() end },
}
