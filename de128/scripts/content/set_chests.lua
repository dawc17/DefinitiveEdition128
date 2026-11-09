local sf2 = require("sf2")
local words = require("content.text")

-- Every mythical five-piece set is sold as one chest, the way DE sold the Monk, Sentinel,
-- Neo-wanderer and Chronos sets. A chest unlocks at the level its set belongs to and costs
-- the sum of its pieces' gem prices; the pieces leave the shop (see content.shop).
-- Monk, Sentinel and Neo-wanderer keep the prices DE gave them: their pieces are level-1
-- shop-hidden items whose own prices mean nothing.

-- Replace these as set art arrives.
local PLACEHOLDER = "UnknownItems.img_weapon_unknown"

local SLOTS = { "weapon", "armor", "helm", "ranged", "magic" }

local function piece_paths(names)
    local paths = {}
    for index, slot in ipairs(SLOTS) do paths[index] = "core:items/" .. slot .. "/" .. names[index] end
    return paths
end

-- Pieces are listed weapon, armor, helm, ranged, magic. `scaled` chests are DE's own: the
-- pieces arrive upgraded to the buyer's level with these enchantments, the set perk on all.
local chests = {
    { id = "monk_set_chest", name = "MonkSetChest", text = "MonkChestDesc", icon = "RaidItems2.monk_chest",
      level = 7, group = "ACT_2", gems = 202, scaled = {
        set = "PERK_MONK_SET_WHIRL",
        extra = { "PERK_ITEM_SPECIAL_WEAKNESS_WEAPON", "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_BODY_ARMOR",
            "PERK_ITEM_SPECIAL_REJUVENATION_HELM", "PERK_ITEM_SPECIAL_BLOODRAGE_RANGED", "PERK_ITEM_SPECIAL_INTOXICATION_MAGIC" } },
      pieces = { "WEAPON_C2_Z2_MONK_KATAR", "ARMOR_C2_Z2_MONK", "HELM_C2_Z2_MONK", "RANGED_C2_Z2_MONK_SHURIKEN", "MAGIC_C2_Z2_MONK_ROOT_STUN" } },
    { id = "sentinel_set_chest", name = "SentinelSetChest", text = "SentinelChestDesc", icon = "img_dragon_chest",
      level = 13, group = "ACT_3", gems = 263, scaled = {
        set = "PERK_SENTINEL_SET_SUPER_RETURN",
        extra = { "PERK_ITEM_SPECIAL_OVERHEAT_WEAPON", "PERK_ITEM_SPECIAL_REGENERATION_ARMOR",
            "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_HEAD_HELM", "PERK_ITEM_SPECIAL_ENFEEBLE_RANGED", "PERK_ITEM_SPECIAL_BLOODRAGE_MAGIC" } },
      pieces = { "WEAPON_C2_Z3_SENTINEL_SPEAR", "ARMOR_C2_Z3_SENTINEL", "HELM_C2_Z3_SENTINEL", "RANGED_C2_Z3_SENTINEL_SHURIKEN", "MAGIC_C2_Z3_SENTINEL_DRAGON" } },
    -- Neo's pieces sit in a raid shop group the player never unlocks, so they need the shop policy
    -- that lists a piece once it is owned.
    { id = "neo_set_chest", name = "NeoSetChest", text = "NeoChestDesc", icon = "img_neo_wanderer",
      level = 19, group = "ACT_4", gems = 345, list_owned = true, scaled = {
        set = "PERK_ARCANE_MARTIAL_ART_SET_NEO_WANDERER",
        extra = { "PERK_ITEM_SPECIAL_TIME_BOMB_WEAPON", "PERK_ITEM_SPECIAL_MAGIC_PAIN_RECHARGE_ARMOR",
            "PERK_ITEM_SPECIAL_SHIELDING_HELM", "PERK_ITEM_SPECIAL_LIFESTEAL_RANGED", "PERK_ITEM_SPECIAL_TIME_BOMB_MAGIC" } },
      pieces = { "WEAPON_C1_Z4_NEO_WANDERER", "ARMOR_C1_Z4_NEO_WANDERER", "HELM_C1_Z4_NEO_WANDERER", "RANGED_C1_Z4_NEO_WANDERER", "MAGIC_C1_Z4_NEO_WANDERER" } },
    { id = "chronos_set_chest", name = "ChronosSetChest", text = "ChronosChestDesc", icon = PLACEHOLDER,
      level = 45, group = "ACT_7_1", gems = 1079, scaled = {
        set = "PERK_TIME_SHIFT_SET_TIME_SHIFTER",
        extra = { "PERK_ITEM_SPECIAL_FRENZY_WEAPON", "PERK_ITEM_SPECIAL_FRENZY_DEFENSE_ARMOR",
            "PERK_ITEM_SPECIAL_FRENZY_DEFENSE_HELM", "PERK_ITEM_SPECIAL_FRENZY_RANGED", "PERK_ITEM_SPECIAL_FRENZY_MAGIC" } },
      pieces = { "WEAPON_BP_S5_TIME_SHIFTER", "ARMOR_BP_S5_TIME_SHIFTER", "HELM_BP_S5_TIME_SHIFTER", "RANGED_BP_S5_TIME_SHIFTER", "MAGIC_BP_S5_TIME_SHIFTER" } },
    { id = "warlock_set_chest", name = "WarlockSetChest", text = "WarlockChestDesc", icon = PLACEHOLDER, level = 6, group = "", gems = 192,
      pieces = { "WEAPON_C4_Z1_WARLOCK_STAFF", "ARMOR_C4_Z1_WARLOCK", "HELM_C4_Z1_WARLOCK", "RANGED_C4_Z1_WARLOCK_SHURIKEN", "MAGIC_C4_Z1_WARLOCK_DARK_WAVE" } },
    { id = "guardian_set_chest", name = "GuardianSetChest", text = "GuardianChestDesc", icon = PLACEHOLDER, level = 15, group = "ACT_3", gems = 288,
      pieces = { "WEAPON_BP_S1_GUARDIAN", "ARMOR_BP_S1_GUARDIAN", "HELM_BP_S1_GUARDIAN", "RANGED_BP_S1_GUARDIAN", "MAGIC_BP_S1_GUARDIAN" } },
    { id = "skanda_set_chest", name = "SkandaSetChest", text = "SkandaChestDesc", icon = PLACEHOLDER, level = 20, group = "ACT_4", gems = 359,
      pieces = { "WEAPON_BP_S2_SKANDA", "ARMOR_BP_S2_SKANDA", "HELM_BP_S2_SKANDA", "RANGED_BP_S2_SKANDA", "MAGIC_BP_S2_SKANDA" } },
    { id = "wind_maker_set_chest", name = "WindMakerSetChest", text = "WindMakerChestDesc", icon = PLACEHOLDER, level = 25, group = "ACT_5", gems = 447,
      pieces = { "WEAPON_BP_S3_WIND_MAKER", "ARMOR_BP_S3_WIND_MAKER", "HELM_BP_S3_WIND_MAKER", "RANGED_BP_S3_WIND_MAKER", "MAGIC_BP_S3_WIND_MAKER" } },
    { id = "fungus_set_chest", name = "FungusSetChest", text = "FungusChestDesc", icon = PLACEHOLDER, level = 30, group = "ACT_5", gems = 466,
      pieces = { "WEAPON_RAID_FUNGUS_SET", "ARMOR_RAID_FUNGUS_SET", "HELM_RAID_FUNGUS_SET", "RANGED_RAID_FUNGUS_SET", "MAGIC_RAID_FUNGUS_SET" } },
    { id = "karcer_set_chest", name = "KarcerSetChest", text = "KarcerChestDesc", icon = PLACEHOLDER, level = 35, group = "ACT_6", gems = 695,
      pieces = { "WEAPON_RAID_KARCER_SET", "ARMOR_RAID_KARCER_SET", "HELM_RAID_KARCER_SET", "RANGED_KARCER_HUNGER_SET", "MAGIC_KARCER_HUNGER_SET" } },
    { id = "volcano_set_chest", name = "VolcanoSetChest", text = "VolcanoChestDesc", icon = PLACEHOLDER, level = 40, group = "INTERMISSION", gems = 864,
      pieces = { "WEAPON_RAID_VOLCANO_SET", "ARMOR_RAID_VOLCANO_SET", "HELM_RAID_VOLCANO_SET", "RANGED_RAID_VOLCANO_SET", "MAGIC_RAID_VOLCANO_SET" } },
    { id = "director_set_chest", name = "DirectorSetChest", text = "DirectorChestDesc", icon = PLACEHOLDER, level = 50, group = "ACT_7_3", gems = 1344,
      pieces = { "WEAPON_BP_S4_SCRIPTWRITER", "ARMOR_BP_S4_SCRIPTWRITER", "HELM_BP_S4_SCRIPTWRITER", "RANGED_BP_S4_SCRIPTWRITER", "MAGIC_BP_S4_SCRIPTWRITER" } },
}

-- Names of the pieces now sold only inside a chest, for content.shop.
local hidden = {}

local function register()
    for _, chest in ipairs(chests) do
        local paths = piece_paths(chest.pieces)
        local contents = {}
        for index, path in ipairs(paths) do
            hidden[chest.pieces[index]] = true
            local item = sf2.items.get(path)
            if chest.list_owned then sf2.items.patch { item = item, visibility = "force_hidden" } end
            if chest.scaled then
                contents[index] = {
                    item = item, scale_to_player = true,
                    -- DE's quest: Aspect = 3639 / 100 * Level + 60; the set perk rolled around zero.
                    aspect_by_level = { base = 60, per_level = 36.39 },
                    enchantments = {
                        { perk = sf2.perks.get("core:perks/" .. chest.scaled.set), aspect = 0 },
                        sf2.perks.get("core:perks/" .. chest.scaled.extra[index]),
                    },
                }
            else
                contents[index] = item
            end
        end
        sf2.items.register {
            category = "chest", id = chest.id,
            display_name = words.own("chest." .. chest.id .. ".name", chest.name),
            description = words.own("chest." .. chest.id .. ".description", chest.text),
            icon = sf2.assets.sprite("core:UI/Items/" .. chest.icon),
            shop = { level = chest.level, group = chest.group, price = { gems = chest.gems } },
            contents = contents,
        }
    end
end

return { register = register, hidden = hidden }
