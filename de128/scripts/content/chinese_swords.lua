local sf2 = require("sf2")
local data = require("content.chinese_swords_data")
local animation = sf2.assets.binary("animations/chinese_swords_super_slash_old")

-- The Super Slash (ChineseSwordsSuperSlash) is in the game's moves.xml, restricted until
-- enabled here; the game's Sai moves already list the ChineseSwords subtype. This file keeps
-- DE128's shop preview, which the game does not have.
sf2.moves.patch { move = "ChineseSwordsSuperSlash", enable = true }

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
return { preview = preview }
