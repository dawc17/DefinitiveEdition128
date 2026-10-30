local sf2 = require("sf2")
local words = require("content.text")

-- Missing weapon definitions from the archived DE list, authored as typed Lua.
-- Keep the archive's placeholder icons for Kelt Axes and Moon Fans. Assets and move families were
-- checked independently; ChineseSwords is registered by content.chinese_swords.
-- Moon Fans explicitly preserves the archive's absent initial damage attribute.
-- This does not replace its normal Weapon_Bonus upgrade progression.
-- Column 2 is the item's name key in Eclipse's English text.
local definitions = {
    { "super_knives", "WEAPON_SUPER_KNIVES", "Weapon23.img_weapon_super_knives", "mdl_weapon_super_knives", "Daggers", 9, 50, "ACT_2", "PRECISION", 296 },
    { "batons", "WEAPON_BATONS", "Weapon17.img_weapon_batons", "mdl_weapon_batons", "Batons", 11, 55, "ACT_2", "WEAKNESS", 366 },
    { "dragon_knives", "WEAPON_C2_Z5_DRAGON_KNIVES", "Weapon19.img_WEAPON_C2_Z5_DRAGON_KNIVES", "mdl_WEAPON_C2_Z5_DRAGON_KNIVES", "Keris", 13, 60, "ACT_3", "OVERHEAT", 442 },
    { "super_poleaxe", "WEAPON_SUPER_POLEAXE", "Weapon23.img_weapon_super_poleaxe", "mdl_weapon_super_poleaxe", "TwoHandedBlunt", 19, 78, "ACT_4", "PRECISION", 658 },
    { "kelt_axes", "WEAPON_KELT_AXES", "UnknownItems.img_weapon_unknown", "mdl_weapon_kelt_axes", "Axes", 26, 106, "ACT_5", "WEAKNESS", 909 },
    { "fans", "WEAPON_FANS", "Weapon20.img_weapon_fan", "mdl_weapon_fans", "Swords", 29, 121, "ACT_5", "BLOODRAGE", 1014 },
    { "moon_fans", "WEAPON_MOON_FANS", "UnknownItems.img_weapon_unknown", "mdl_weapon_moon_fans", "Fans", 31, 132, "ACT_6", "LIFESTEAL", 1090, {} },
    { "imhotep_axes", "WEAPON_SUPER_AXES2", "weapon_super_axes2", "mdl_weapon_super_axes2", "Axes", 36, 165, "ACT_6", "STUN", 1265 },
    { "chinese_swords", "WEAPON_CHINESE_SWORDS", "Weapon19.img_weapon_chinese_swords", "mdl_weapon_hermit_swords", "ChineseSwords", 42, 214, "INTERMISSION", "FRENZY", 1511 },
    { "giant_sword", "WEAPON_GIANT_SWORD", "Weapon20.img_weapon_giant_sword", "mdl_weapon_giant_sword_mini", "GiantSword", 50, 305, "ACT_7_3", "TIME_BOMB", 1797 },
}
local weapons = {}
for _, row in ipairs(definitions) do
    local item = sf2.items.register {
        category = "weapon",
        id = row[1],
        display_name = words.own("item." .. row[1], row[2]),
        icon = sf2.assets.sprite("core:UI/Items/" .. row[3]),
        model = sf2.assets.model("core:gamedata/models/" .. row[4]), subtype = row[5],
        initial_stats = row[11],
        shop = { level = row[6], price = { gems = row[7] } },
    }
    sf2.items.patch {
        item = item, required_group = row[8], minimum_level = row[6],
        enchantments = { { perk = sf2.perks.get("core:perks/PERK_ITEM_SPECIAL_" .. row[9] .. "_WEAPON"), aspect = row[10] } },
    }
    weapons[row[1]] = item
end
return weapons
