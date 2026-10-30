local sf2 = require("sf2")
local words = require("content.text")

-- Missing purchasable equipment whose base move families and art are available.
-- Preserve Samurai Armour's head-only initial stat snapshot from the archive.
-- shared_moves.lua applies supported DE move deltas; remaining preview differences are pending.
-- Column 2 is the item's name key in Eclipse's English text.
local definitions = {
    { "mind_throw", "MAGIC_MIND_THROW_NORMAL", "magic", "Magic13.img_magic_mind_throw", "mdl_magic_fireball", "MindThrowNormal", 45, 181, "ACT_7_1", "PERK_ITEM_SPECIAL_FRENZY_MAGIC", 1622 },
    { "blast_of_the_void", "ComboSphere3", "magic", "UnknownItems.img_magic_unknown", "mdl_acid_cloud", "ComboSphere3", 27, 82, "ACT_5", "PERK_ITEM_SPECIAL_ENFEEBLE_MAGIC", 944 },
    { "large_charge_of_darkness", "Sphere3", "magic", "RaidItems1.sphere3", "mdl_acid_cloud", "Sphere3", 42, 159, "INTERMISSION", "PERK_ITEM_SPECIAL_LIFESTEAL_MAGIC", 1511 },
    { "medium_charge_of_darkness", "Sphere2", "magic", "RaidItems1.sphere2", "mdl_acid_cloud", "Sphere2", 37, 127, "GATES_OF_SHADOWS", "PERK_ITEM_SPECIAL_STUN_MAGIC", 1306 },
    { "minor_charge_of_darkness", "Sphere1", "magic", "RaidItems1.sphere1", "mdl_magic_fireball", "Sphere1", 23, 69, "ACT_4", "PERK_ITEM_SPECIAL_WEAKNESS_MAGIC", 798 },
    { "dragon_carapace", "ARMOR_C2_Z5_DRAGON", "armor", "Armor29.img_ARMOR_C2_Z5_DRAGON", "mdl_ARMOR_C2_Z5_DRAGON", nil, 13, 49, "ACT_3", "PERK_ITEM_SPECIAL_OVERHEAT_DEFENSE_ARMOR", 442 },
    { "old_legionnaire_armour", "ARMOR_OLD_LEGIONER", "armor", "Armor31.img_armor_old_legioner", "mdl_armor_legioner", nil, 15, 53, "ACT_3", "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_BODY_ARMOR", 512 },
    { "samurai_armour", "ARMOR_BIG_SHOGUN_OLD", "armor", "UnknownItems.img_armor_unknown", "mdl_armor_big_shogun_old", nil, 37, 140, "GATES_OF_SHADOWS", "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_BODY_ARMOR", 1306, { head_defense = 914 } },
    { "gabled_helm", "HELM_GABLED_OLD", "helm", "UnknownItems.img_helm_unknown", "mdl_helm_gabled_old", nil, 11, 30, "ACT_2", "PERK_ITEM_SPECIAL_REJUVENATION_HELM", 366 },
    { "dragon_helm", "HELM_C2_Z5_DRAGON", "helm", "Helm30.img_HELM_C2_Z5_DRAGON", "mdl_HELM_C2_Z5_DRAGON", nil, 13, 33, "ACT_3", "PERK_ITEM_SPECIAL_OVERHEAT_DEFENSE_HELM", 442 },
    { "dragon_boomerangs", "RANGED_C2_Z5_DRAGON_BOOMERANG", "ranged", "Ranged10.img_RANGED_C2_Z5_DRAGON_BOOMERANG", "mdl_RANGED_C2_Z5_DRAGON_BOOMERANG", "Chakram", 13, 27, "ACT_3", "PERK_ITEM_SPECIAL_OVERHEAT_RANGED", 442 },
    { "dragons_breath", "MAGIC_C2_Z5_DRAGON_EARTHQUAKE", "magic", "Magic9.img_MAGIC_C2_Z5_DRAGON_EARTHQUAKE", "mdl_magic_mass_bomb", "MassBomb", 13, 44, "ACT_3", "PERK_ITEM_SPECIAL_OVERHEAT_MAGIC", 442 },
    { "lightning_arc", "MAGIC_LIGHTNING", "magic", "Magic13.img_magic_lightning", "mdl_magic_fireball", "LightningArrow", 39, 139, "INTERMISSION", "PERK_ITEM_SPECIAL_ENFEEBLE_MAGIC", 1388 },
}
local equipment = {}
for _, row in ipairs(definitions) do
    local definition = {
        category = row[3],
        id = row[1],
        display_name = words.get(row[2]),
        icon = sf2.assets.sprite("core:UI/Items/" .. row[4]),
        model = sf2.assets.model("core:gamedata/models/" .. row[5]),
        initial_stats = row[12],
    }
    if row[6] then definition.subtype = row[6] end
    definition.shop = { level = row[7], price = { gems = row[8] } }
    local item = sf2.items.register(definition)
    sf2.items.patch {
        item = item, required_group = row[9], minimum_level = row[7],
        enchantments = { { perk = sf2.perks.get("core:perks/" .. row[10]), aspect = row[11] } },
    }
    equipment[row[1]] = item
end
sf2.items.patch { item = equipment.mind_throw, perks = { { perk = require("content.mind_throw_perk") } } }
return equipment
