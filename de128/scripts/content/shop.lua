local sf2 = require("sf2")

-- Priced core equipment that the DE archive makes available in the normal shop.
-- The generated table contains static data; no XML is read by the mod in game.
-- Core identity stays base-owned. Prices, art, starting profiles, legacy paid
-- markers and changed enchantments are reversible catalog patches.
for _, row in ipairs(require("content.shop_data")) do
    local item = sf2.items.get("core:items/" .. row[1] .. "/" .. row[2])
    local patch = {
        item = item,
        visibility = "force_visible",
        minimum_level = row[3],
        required_group = row[4],
        initial_profile = {
            level = row[3], upgrade_level = row[5],
            upgrade_template = row[6], initial_stats = row[7],
            legacy_paid_item = row[9],
            clear_local_upgrades = row[11],
        },
    }
    if row[10] then
        patch.price = { gems = row[10] }
        patch.secondary_price = row[12] > 0 and { coins = row[12] } or nil
    end
    if row[13] then patch.icon = sf2.assets.sprite("core:UI/Items/" .. row[13]) end
    if row[14] then patch.model = sf2.assets.model("core:gamedata/models/" .. row[14]) end
    if row[8] then
        local entries = {}
        for _, enchantment in ipairs(row[8]) do
            entries[#entries + 1] = {
                perk = sf2.perks.get("core:perks/" .. enchantment[1]),
                aspect = enchantment[2],
            }
        end
        patch.enchantments = entries
    end
    sf2.items.patch(patch)
end
