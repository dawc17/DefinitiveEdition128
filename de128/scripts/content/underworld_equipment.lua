local sf2 = require("sf2")
local words = require("content.text")

-- Berstuuk's hidden opponent equipment. The archive defines both entries in
-- list.xml; their exact model geometry ships under assets/models/underworld/.
local form = sf2.items.register {
    category = "armor",
    id = "berstuuk_form",
    display_name = words.own("uw.BODY_BERSTUUK", "BODY_BERSTUUK"),
    icon = sf2.assets.sprite("core:UI/Items/UnknownItems.img_armor_unknown"),
    model = sf2.assets.model("models/underworld/mdl_body_berstuuk_early"),
    initial_stats = { body_defense = 1, unarmed_damage = 1 },
}
local mask = sf2.items.register {
    category = "helm",
    id = "berstuuk_mask",
    display_name = words.own("uw.HEAD_BERSTUUK", "HEAD_BERSTUUK"),
    icon = sf2.assets.sprite("core:UI/Items/UnknownItems.img_helm_unknown"),
    model = sf2.assets.model("models/underworld/mdl_head_berstuuk"),
}

return { form = form, mask = mask }
