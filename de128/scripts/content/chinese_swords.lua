local sf2 = require("sf2")

-- The Chinese swords are the Hermit's swords model (mdl_weapon_hermit_swords) under their own
-- ChineseSwords subtype; the game's Sai moves already list that subtype. Their Super Slash is
-- the Hermit swords' own, in fights (HermitSwordsSuperSlash) and in the shop try-on
-- (ShopHermitSwordsSuperSlash). The archive's ChineseSwordsSuperSlash, restricted in the game's
-- moves.xml and left that way, plays chinese_swords_super_slash_old, an older and shorter cut of
-- the same animation: the wrong one (owner, 2026-11-16).
for _, move in ipairs({ "HermitSwordsSuperSlash", "ShopHermitSwordsSuperSlash" }) do
    sf2.moves.patch {
        move = move,
        item_locks = { add = { { slot = "weapon", source_subtype = "HermitSwords", subtype = "ChineseSwords" } } },
    }
end

sf2.items.patch {
    item = sf2.items.get("core:items/weapon/WEAPON_CHNY21_JIAN"), subtype = "ChineseSwords",
}
return {}
