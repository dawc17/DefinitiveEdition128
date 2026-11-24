local sf2 = require("sf2")
local words = require("content.text")
local shop_groups = require("content.shop_groups")

-- Every mythical five-piece set is sold as one chest (Seby, 2026-11-24): fourteen chests, one
-- per mythical enchantment except the Monk set's Tempest Rage, whose pieces come from
-- Ascension's chests (content.ascension), as in 1.9.38. The old 202-gem Monk's Chest (DE's
-- MonkSetChest, Act 2) is retired below so saves that bought it still resolve.
--
-- A chest unlocks at its set's level, in the shop group of an item of that level, and hands
-- over its five pieces upgraded to the buyer's level, at that level's first upgrade step, each
-- with the set's enchantment and the piece's own normal enchantment: what DE's
-- SentinelSetChest_Give quest (Assets/DExml/quests.xml) did. The pieces leave the shop
-- (content.shop, content.restored_* and below); a piece the player owns stays listed so it
-- can be equipped and upgraded.

-- Chests without their own art show this mod sprite. Replace it per chest as set art arrives.
local PLACEHOLDER = false

local SLOTS = { "weapon", "armor", "helm", "ranged", "magic" }

-- DE's gem price for one shop piece of item level L with a normal and a mythical enchantment:
-- A * r^L * 1.238, rounded per piece (owner decision, 2026-11-24). A and r per slot were fitted
-- to the archive's shop prices by level; 1.238 is the price of the two enchantments. A chest
-- costs its five pieces at its level: 231 gems at level 10 up to 1286 at level 49.
local PRICE_CURVE = {
    weapon = { 33.79, 1.04497 }, armor = { 27.48, 1.04505 }, helm = { 18.54, 1.04533 },
    ranged = { 14.94, 1.04511 }, magic = { 24.95, 1.04506 },
}
local ENCHANTED = 1.238

local function chest_price(level)
    local total = 0
    for _, slot in ipairs(SLOTS) do
        local curve = PRICE_CURVE[slot]
        total = total + math.floor(curve[1] * curve[2] ^ level * ENCHANTED + 0.5)
    end
    return total
end

-- DE128's own mythicals (kind = "combo" scripted perks), by module. Each gets an item set of
-- its pieces below, so the forge offers it only to a player who owns the whole set, as the
-- game does for its own sets.
local MYTHICALS = {
    stone_fetters = "content.stone_fetters",
    searing_luminary = "content.searing_luminary",
    revival_heal = "content.revival_heal",
}

-- In unlock order (Seby's list). set: the set enchantment, a core perk name or a MYTHICALS key.
-- pieces: weapon, armor, helm, ranged, magic, core item names (or, with own, DE128's own item
-- ids). extra: each piece's own normal enchantment, for pieces content.shop_data has no row
-- for (the others take the row's enchantment that is not the set's); false for none.
-- item_set: the set's title key and id, for DE128's own mythicals.
local chests = {
    { id = "sentinel_set_chest", name = "SentinelSetChest", text = "SentinelChestDesc", icon = "img_dragon_chest", level = 10,
      set = "PERK_SENTINEL_SET_SUPER_RETURN",
      pieces = { "WEAPON_C2_Z3_SENTINEL_SPEAR", "ARMOR_C2_Z3_SENTINEL", "HELM_C2_Z3_SENTINEL", "RANGED_C2_Z3_SENTINEL_SHURIKEN", "MAGIC_C2_Z3_SENTINEL_DRAGON" },
      -- The pieces have no enchantments of their own; these are SentinelSetChest_Give's.
      extra = { "PERK_ITEM_SPECIAL_OVERHEAT_WEAPON", "PERK_ITEM_SPECIAL_REGENERATION_ARMOR",
          "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_HEAD_HELM", "PERK_ITEM_SPECIAL_ENFEEBLE_RANGED", "PERK_ITEM_SPECIAL_BLOODRAGE_MAGIC" } },
    { id = "warlock_set_chest", name = "WarlockSetChest", text = "WarlockChestDesc", icon = PLACEHOLDER, level = 13,
      set = "PERK_WARLOCK_SET_CURSE",
      pieces = { "WEAPON_C4_Z1_WARLOCK_STAFF", "ARMOR_C4_Z1_WARLOCK", "HELM_C4_Z1_WARLOCK", "RANGED_C4_Z1_WARLOCK_SHURIKEN", "MAGIC_C4_Z1_WARLOCK_DARK_WAVE" } },
    { id = "guardian_set_chest", name = "GuardianSetChest", text = "GuardianChestDesc", icon = PLACEHOLDER, level = 16,
      set = "PERK_GUARDIAN_SET_PROTECTION",
      pieces = { "WEAPON_BP_S1_GUARDIAN", "ARMOR_BP_S1_GUARDIAN", "HELM_BP_S1_GUARDIAN", "RANGED_BP_S1_GUARDIAN", "MAGIC_BP_S1_GUARDIAN" } },
    { id = "skanda_set_chest", name = "SkandaSetChest", text = "SkandaChestDesc", icon = PLACEHOLDER, level = 19,
      set = "PERK_SKANDA_SET_KARMA",
      pieces = { "WEAPON_BP_S2_SKANDA", "ARMOR_BP_S2_SKANDA", "HELM_BP_S2_SKANDA", "RANGED_BP_S2_SKANDA", "MAGIC_BP_S2_SKANDA" } },
    -- The Dragon items DE128 restores (content.restored_weapons, content.restored_equipment).
    { id = "dragon_set_chest", name = "DragonSetChest", text = "DragonChestDesc", icon = PLACEHOLDER, level = 22,
      set = "stone_fetters", item_set = { id = "dragon_set", title = "DRAGON_SET" }, own = true,
      pieces = { "dragon_knives", "dragon_carapace", "dragon_helm", "dragon_boomerangs", "dragons_breath" },
      extra = { "PERK_ITEM_SPECIAL_OVERHEAT_WEAPON", "PERK_ITEM_SPECIAL_OVERHEAT_DEFENSE_ARMOR",
          "PERK_ITEM_SPECIAL_OVERHEAT_DEFENSE_HELM", "PERK_ITEM_SPECIAL_OVERHEAT_RANGED", "PERK_ITEM_SPECIAL_OVERHEAT_MAGIC" } },
    { id = "director_set_chest", name = "DirectorSetChest", text = "DirectorChestDesc", icon = PLACEHOLDER, level = 25,
      set = "PERK_DIRECTOR_SET_PLOT_TWIST",
      pieces = { "WEAPON_BP_S4_SCRIPTWRITER", "ARMOR_BP_S4_SCRIPTWRITER", "HELM_BP_S4_SCRIPTWRITER", "RANGED_BP_S4_SCRIPTWRITER", "MAGIC_BP_S4_SCRIPTWRITER" } },
    { id = "karcer_set_chest", name = "KarcerSetChest", text = "KarcerChestDesc", icon = PLACEHOLDER, level = 28,
      set = "PERK_KARCER_HUNGER_SET",
      pieces = { "WEAPON_RAID_KARCER_SET", "ARMOR_RAID_KARCER_SET", "HELM_RAID_KARCER_SET", "RANGED_KARCER_HUNGER_SET", "MAGIC_KARCER_HUNGER_SET" } },
    { id = "neo_set_chest", name = "NeoSetChest", text = "NeoChestDesc", icon = "img_neo_wanderer", level = 31,
      set = "PERK_ARCANE_MARTIAL_ART_SET_NEO_WANDERER",
      pieces = { "WEAPON_C1_Z4_NEO_WANDERER", "ARMOR_C1_Z4_NEO_WANDERER", "HELM_C1_Z4_NEO_WANDERER", "RANGED_C1_Z4_NEO_WANDERER", "MAGIC_C1_Z4_NEO_WANDERER" },
      -- DE's NeoSetChest enchantments; the pieces have none of their own.
      extra = { "PERK_ITEM_SPECIAL_TIME_BOMB_WEAPON", "PERK_ITEM_SPECIAL_MAGIC_PAIN_RECHARGE_ARMOR",
          "PERK_ITEM_SPECIAL_SHIELDING_HELM", "PERK_ITEM_SPECIAL_LIFESTEAL_RANGED", "PERK_ITEM_SPECIAL_TIME_BOMB_MAGIC" } },
    -- The tenth-anniversary items: Vulture's Feather, Snow Blind, Lunatic's Eye, Harpy's Bite and
    -- Inmate's Shackles. Revival Heal has no effect yet (content.revival_heal).
    { id = "revival_set_chest", name = "RevivalSetChest", text = "RevivalChestDesc", icon = PLACEHOLDER, level = 34,
      set = "revival_heal", item_set = { id = "revival_set", title = "REVIVAL_SET" },
      pieces = { "WEAPON_ANNIVERSARY_10TH", "ARMOR_ANNIVERSARY_10TH", "HELM_ANNIVERSARY_10TH", "RANGED_ANNIVERSARY_10TH", "MAGIC_ANNIVERSARY_10TH" } },
    -- Only the helm has a normal enchantment of its own in DE's data.
    { id = "fungus_set_chest", name = "FungusSetChest", text = "FungusChestDesc", icon = PLACEHOLDER, level = 37,
      set = "PERK_CORDYCEPS_FUNGUS_SET",
      pieces = { "WEAPON_RAID_FUNGUS_SET", "ARMOR_RAID_FUNGUS_SET", "HELM_RAID_FUNGUS_SET", "RANGED_RAID_FUNGUS_SET", "MAGIC_RAID_FUNGUS_SET" } },
    -- Dragon Teeth, Celestial Gown, Celestial Crown, Crystalline Spikes and Fire Splash, with
    -- their own enchantments; the Crown, which had none, gets helm Damage Absorption (Seby). The
    -- game's own name for this set is "Set of Heaven" (HEAVEN_SET, PERK_HEAVEN_SET_BURN).
    { id = "celestial_set_chest", name = "CelestialSetChest", text = "CelestialChestDesc", icon = PLACEHOLDER, level = 40,
      set = "searing_luminary", item_set = { id = "celestial_set", title = "HEAVEN_SET" },
      pieces = { "WEAPON_SUPER_DRAGON_TEETH", "ARMOR_CELESTIAL", "HELM_CELESTIAL", "RANGED_SUPER_DAGGERS", "MAGIC_FIRE_SPLASH" },
      extra = { "PERK_ITEM_SPECIAL_BLEEDING_WEAPON", "PERK_ITEM_SPECIAL_REJUVENATION_ARMOR",
          "PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_HEAD_HELM", "PERK_ITEM_SPECIAL_BLEEDING_RANGED", "PERK_ITEM_SPECIAL_OVERHEAT_MAGIC" } },
    { id = "volcano_set_chest", name = "VolcanoSetChest", text = "VolcanoChestDesc", icon = PLACEHOLDER, level = 43,
      set = "PERK_MAGMA_VOLCANO_SET",
      pieces = { "WEAPON_RAID_VOLCANO_SET", "ARMOR_RAID_VOLCANO_SET", "HELM_RAID_VOLCANO_SET", "RANGED_RAID_VOLCANO_SET", "MAGIC_RAID_VOLCANO_SET" } },
    { id = "chronos_set_chest", name = "ChronosSetChest", text = "ChronosChestDesc", icon = PLACEHOLDER, level = 46,
      set = "PERK_TIME_SHIFT_SET_TIME_SHIFTER",
      pieces = { "WEAPON_BP_S5_TIME_SHIFTER", "ARMOR_BP_S5_TIME_SHIFTER", "HELM_BP_S5_TIME_SHIFTER", "RANGED_BP_S5_TIME_SHIFTER", "MAGIC_BP_S5_TIME_SHIFTER" } },
    { id = "wind_maker_set_chest", name = "WindMakerSetChest", text = "WindMakerChestDesc", icon = PLACEHOLDER, level = 49,
      set = "PERK_GUST_SET_WIND_MAKER",
      pieces = { "WEAPON_BP_S3_WIND_MAKER", "ARMOR_BP_S3_WIND_MAKER", "HELM_BP_S3_WIND_MAKER", "RANGED_BP_S3_WIND_MAKER", "MAGIC_BP_S3_WIND_MAKER" } },
}

-- content.shop_data's rows by core item name.
local rows = {}
for _, row in ipairs(require("content.shop_data")) do rows[row[2]] = row end

-- Names of the pieces now sold only inside a chest, for content.shop (core rows) and
-- content.restored_* (DE128's own items), which own those items' shop visibility.
local hidden = {}
for _, chest in ipairs(chests) do
    for _, name in ipairs(chest.pieces) do hidden[name] = true end
end

-- The piece's own normal enchantment: the chest's extra, else its row's enchantment that is
-- not the set's, else none.
local function own_enchantment(chest, index)
    if chest.extra then return chest.extra[index] end
    local row = rows[chest.pieces[index]]
    for _, entry in ipairs(row and row[8] or {}) do
        if entry[1] ~= chest.set then return entry[1] end
    end
    return false
end

local function core_perk(name) return sf2.perks.get("core:perks/" .. name) end

local function register()
    for _, chest in ipairs(chests) do
        local set = MYTHICALS[chest.set] and require(MYTHICALS[chest.set]) or core_perk(chest.set)
        local items, contents = {}, {}
        for index, slot in ipairs(SLOTS) do
            local name = chest.pieces[index]
            local item = sf2.items.get((chest.own and sf2.mod.id or "core") .. ":items/" .. slot .. "/" .. name)
            items[index] = item
            -- A core piece without a shop_data row gets its off-sale policy here.
            if not chest.own and not rows[name] then sf2.items.patch { item = item, visibility = "force_hidden" } end
            local extra = own_enchantment(chest, index)
            local enchantments = { { perk = set, aspect = 0 } }
            if extra then enchantments[2] = core_perk(extra) end
            contents[index] = {
                item = item, scale_to_player = true,
                -- DE's quest: the set perk rolled around zero; Aspect = 3639 / 100 * Level + 60 for the other.
                aspect_by_level = { base = 60, per_level = 36.39 },
                enchantments = enchantments,
            }
        end
        if chest.item_set then
            local members = {}
            for index, item in ipairs(items) do members[index] = { item = item } end
            sf2.items.register {
                category = "set", id = chest.item_set.id, perk = set, members = members,
                title = words.own("set." .. chest.item_set.id .. ".title", chest.item_set.title),
                text = words.own("set." .. chest.item_set.id .. ".text", "SetUi_Collect_Text"),
                brief = words.own("set." .. chest.item_set.id .. ".brief", "special." .. chest.set .. ".description"),
            }
        end
        sf2.items.register {
            category = "chest", id = chest.id,
            display_name = words.own("chest." .. chest.id .. ".name", chest.name),
            description = words.own("chest." .. chest.id .. ".description", chest.text),
            icon = chest.icon and sf2.assets.sprite("core:UI/Items/" .. chest.icon)
                or sf2.assets.sprite("sprites/chests/placeholder"),
            shop = {
                level = chest.level, group = shop_groups.game(shop_groups.for_level(chest.level)),
                price = { gems = chest_price(chest.level) },
            },
            contents = contents,
        }
    end
    -- The Celestial Crown shipped without a normal enchantment; it now comes with helm Damage
    -- Absorption at its level's power (list.xml gives level-34 helm enchantments 1195).
    sf2.items.patch {
        item = sf2.items.get("core:items/helm/HELM_CELESTIAL"),
        enchantments = { { perk = core_perk("PERK_ITEM_SPECIAL_DAMAGE_ABSORPTION_HEAD_HELM"), aspect = 1195 } },
    }
    sf2.items.retire { id = "consumable/monk_set_chest" }
end

return { register = register, hidden = hidden }
