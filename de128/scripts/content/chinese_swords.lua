local sf2 = require("sf2")
local words = require("content.text")
local data = require("content.chinese_swords_data")
local animation = sf2.assets.binary("animations/chinese_swords_super_slash_old")

data.profile.display_name = words.get("PERK_SUPER_SLASH")

for _, move in ipairs(data.item_lock_extensions) do
    sf2.moves.patch {
        move = move,
        item_locks = { add = { { slot = "weapon", source_subtype = "Sai", subtype = "ChineseSwords" } } },
    }
end

local slash = sf2.moves.register {
    id = "chinese_swords_super_slash", animation = animation,
    inherit = { "3key", "Forward", "Weapon", "Jump", "Controlled", "NotTitan", "SoundStrike" },
    type = "attack", first_sample = 4, priority = 130,
    tactic_weapon = "HermitSwords",
    profile = data.profile, tactic_distance = data.tactic_distance,
    when = data.when, only_for = data.only_for, windows = data.windows, attacks = data.attacks,
    transitions = data.transitions, align = data.align, face = data.face,
    on = data.on,
    events = "controlled",
}
local preview = sf2.moves.register {
    id = "shop_chinese_swords_super_slash", animation = animation,
    inherit = { "ShopTryOn", "StanceShop", "StageStance", "Stance" },
    first_sample = 2, priority = 1, ends_stage = true,
    no_wall_repulsion = data.preview.no_wall_repulsion,
    no_interpolation_frames = data.preview.no_interpolation_frames,
    only_for = data.preview.only_for, align = data.preview.align, face = data.face,
    on = data.preview.on, events = { { round_stage = "try_on" } },
}
sf2.items.patch {
    item = sf2.items.get("core:items/weapon/WEAPON_CHNY21_JIAN"), subtype = "ChineseSwords",
}
return { slash = slash, preview = preview }
