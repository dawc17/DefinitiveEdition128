local sf2 = require("sf2")
-- Sphere3. The fight moves (Sphere3Player, Sphere3Start, Sphere3Middle) are in the game's
-- moves.xml, restricted until enabled here. This file keeps DE128's shop preview and try-on
-- moves, which the game does not have.
for _, move in ipairs({ "Sphere3Player", "Sphere3Start", "Sphere3Middle" }) do
    sf2.moves.patch { move = move, enable = true }
end

-- Game frames: the shop moves have 3 frames per sample from sample 1 (sample N is frames
-- 3N .. 3N + 2).
local animation = {
    player = sf2.assets.binary("animations/big_sphere_player"),
}
local moves = {}

-- Equipment the fighter (player) or the spawned sphere actor must carry.
local function only_for(player, shop)
    return {
        screen = shop and "shop_magic" or nil,
        [player and "magic" or "weapon"] = "Sphere3",
        rig = player and "Skeleton" or "SkeletonMagic",
    }
end

local function register(id, definition)
    definition.id = id
    moves[id] = sf2.moves.register(definition)
    return moves[id]
end

for _, row in ipairs({ { "shop_magic_sphere3_player", "ShopPeacefulStart", "peaceful_start" },
    { "shop_magic_try_on_sphere3_player", "ShopTryOn", "try_on" } }) do
    register(row[1], {
        animation = animation.player, inherit = { row[2], "StanceShop", "StageStance", "Stance" },
        first_sample = 1, priority = 1, no_interpolation_frames = true, ends_stage = true,
        align = { axes = { "x", "z" }, pivot = { node = "right_heel" }, position = { pivot = "self", x = -80 } },
        only_for = only_for(true, true), on = {
        [66] = { effect = {
        name = "Sphere3Start", core_sequence = "mgc_magic_big_sphere_" .. string.lower("Start"),
        scale = 0.75, time_scale = 4, position = { wall = "back", of = "self", x = 415, y = 160 }, follow = false,
    } },
        [81] = { effect = {
        name = "Sphere3End", core_sequence = "mgc_magic_big_sphere_" .. string.lower("End"),
        scale = 2, time_scale = 1.5, position = { wall = "back", of = "self", x = 400, y = 150 }, follow = false,
    } },
        [63] = { sound = { "snd_bigsphere_end" } },
        finish = { try_on_end = true },
    }, events = { { round_stage = row[3] } }, face = "enemy",
    })
end
return moves
