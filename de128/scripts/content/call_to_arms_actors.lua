local sf2 = require("sf2")

-- Shogun's four bodyguards. AssistantLongKatanaPlayer, AssistantBigNaginataPlayer,
-- AssistantBigMagariYariPlayer and AssistantUniqGlaivePlayer each create an "Assistant" in
-- ARMOR_CENTURION and HELM_CRESCENT (moves.xml) holding one of these weapons. The actors fight
-- with those weapons' own moves under the Aggressive tactic.
local function bodyguard(id, weapon)
    return sf2.fighters.register {
        id = id,
        fighter = "core:warrior-templates/default",
        level = 1, tactic = "Aggressive", skeleton = "Skeleton",
        items = {
            sf2.items.get("core:items/weapon/" .. weapon),
            sf2.items.get("core:items/armor/ARMOR_CENTURION"),
            sf2.items.get("core:items/helm/HELM_CRESCENT"),
        },
    }
end

-- Like the native assistants (an invulnerable "Boss" window), they cannot be hurt or staggered;
-- their hits cannot be blocked (IgnoresBlock on every native assistant strike).
local behavior = {
    on_hit_pre_crit = function(_, fighter, event)
        if event.target == "self" then
            fighter:set_hit_armored(true)
        elseif event.blocked then
            fighter:set_hit_blocked(false)
        end
    end,
    on_damage_resolving = function(_, fighter)
        fighter:scale_incoming_damage(0)
    end,
}

-- About three seconds on screen (counted after the entry animation).
local function actor(id, weapon, ahead)
    return {
        actor = sf2.actors.register {
            id = id, character = bodyguard(id .. "_body", weapon),
            team = "owner", ai = true, lifetime_frames = 180, max_health = 1, behavior = behavior,
        },
        -- The katana, naginata and yari enter from behind their summoner (ShiftX -470 in the native
        -- Start moves); the glaive lands in front, at the enemy (Position Enemy, ShiftX -500).
        ahead = ahead,
        distance = 300,
    }
end

return {
    katana = actor("bodyguard_katana", "WEAPON_NODACHI", false),
    naginata = actor("bodyguard_naginata", "WEAPON_BG_NAGINATA", false),
    yari = actor("bodyguard_yari", "WEAPON_BG_YARI", false),
    glaive = actor("bodyguard_glaive", "WEAPON_BG_GLAIVE", true),
}
