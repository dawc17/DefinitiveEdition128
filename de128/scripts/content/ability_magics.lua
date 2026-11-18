local sf2 = require("sf2")
local words = require("content.text")
local grasp = require("content.blackness_grasp")

-- Fear Ray and Grasp of Darkness as magic items (Special Recipe III no longer offers them). Each
-- is a pre-enchanted Magic item cast with the magic button: a copy of the boss-ability cast
-- that pays one magic charge instead of using the perk recharge, locked to the item's own
-- subtype. The boss and raid-charge versions stay as they are (content.boss_abilities).
--
-- Gem prices follow the archive's shop curve (Assets/DExml/list.xml BonusPrice): an enchanted
-- magic item costs about 1.237x a plain one of the same level (plain 107 at level 38 against the
-- enchanted curve's 127 at 37 and 139 at 39). Fear Ray (level 38, plain 107) takes the curve's
-- 133; Grasp of Darkness (level 41) takes the curve's 152, which is already an enchanted price.
-- Aspects are the curve of the restored rows in content.restored_equipment (1306 at 37, 1388 at
-- 39, 1511 at 42), read at each level.
local rows = {
    { id = "fear_ray", text = "FearAbil", subtype = "FearRayMagic", level = 38, gems = 133,
        perk = "PERK_ITEM_SPECIAL_LIFESTEAL_MAGIC", aspect = 1347 },
    { id = "grasp_of_darkness", text = "BlacknessHugAbility", subtype = "GraspOfDarknessMagic", level = 41, gems = 152,
        perk = "PERK_ITEM_SPECIAL_FRENZY_MAGIC", aspect = 1429 },
}

local items = {}
for _, row in ipairs(rows) do
    local item = sf2.items.register {
        category = "magic", id = row.id,
        display_name = words.own("item." .. row.id, row.text),
        icon = sf2.assets.sprite("sprites/abilities/" .. row.id),
        model = sf2.assets.model("core:gamedata/models/mdl_magic_fireball"),
        subtype = row.subtype,
        shop = { level = row.level, price = { gems = row.gems } },
    }
    sf2.items.patch {
        item = item, required_group = require("content.shop_groups").game("INTERMISSION"), minimum_level = row.level,
        enchantments = { { perk = sf2.perks.get("core:perks/" .. row.perk), aspect = row.aspect } },
    }
    items[row.id] = item
end

local HITS = { "snd_hit1", "snd_hit2", "snd_hit3", "snd_hit4", "snd_hit5", "snd_hit6" }

-- Same gate as the game's Fireball cast: the magic key, one charge, no silence, stun or concussion.
local function cast_when(subtype)
    return {
        keys = "magic", bullets = { type = "magic", min = 1 },
        not_mod = { "Concussion", "Stun", "SilenceIcon" },
        controllable = true,
    }, { magic = subtype, rig = "Skeleton" }
end

-- The beam: a copy of the game's MagicFearRayStart (fire_pillar_end.bytes, copied byte for byte)
-- without its Conditions, which want the caster to carry the boss perk PERK_FEAR_RAY. Like the
-- game's player chest ray (FuturistRayStart) it also takes NoAutoDelete, so a hit on the caster
-- does not remove a beam already out. Native samples: first 2, 3 frames per sample; the attack
-- is samples 4 to 10 and the six ray effects start on samples 2, 5, 8, 11, 14 and 17 (frames 0,
-- 12, 21, 30, 39 and 48).
local ray_on = { finish = { delete_actor = "self" } }
for n, frame in ipairs({ 0, 12, 21, 30, 39, 48 }) do
    ray_on[frame] = { effect = {
        name = "EnergyRay" .. n, core_sequence = "mgc_effect_energy_ray_" .. n,
        scale = 0.8, time_scale = 2,
        position = { node = "pelvis", of = "parent", x = 450, y = 30 },
    } }
end
local fear_ray_beam = sf2.moves.register {
    id = "fear_ray_magic_beam",
    animation = sf2.assets.binary("animations/fire_pillar_end"),
    inherit = { "MagicMissileStart", "MagicFearRay", "MagicMissile", "MissileStart", "NoAutoDelete", "MagicMissileFly" },
    first_sample = 2, priority = 500,
    no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    align = { axes = { "x", "z" }, pivot = { animation = true }, position = { animation = "parent" } },
    face = "with_parent",
    when = { actor = "PerkFearRay" },
    only_for = { rig = "SkeletonMagic", weapon = "FearRay" },
    attacks = { {
        from_sample = 4, to_sample = 10, edges = { "FearRayEdge1" },
        damage = { amount = 0.4, magic = 0, unarmed = -25 },
        impulse = { x = 1000, y = -300 }, hit = "Physycal",
        no_effect = true, no_critical = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } },
    on = ray_on,
}

-- PerkFearRayPlayer's graph: first sample 1, 3 frames per sample, so the ray spawns on sample 21
-- (frame 63) and the Uninterrupt interval ends on sample 47 (frame 143). The beam is started
-- directly (fear_ray_magic_beam above). As in the game's player chest ray (MagicFuturistPlayer,
-- same clip and timing), the caster has an Evade window from the beam's sample 21 to sample 47,
-- so a hit while the beam is out cannot cut the cast short.
local fear_when, fear_for = cast_when("FearRayMagic")
local fear_ray = sf2.moves.register {
    id = "fear_ray_magic_player",
    animation = sf2.assets.binary("animations/chest_laser_ray_player"),
    inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 1, priority = 110,
    only_for = fear_for, when = fear_when,
    face = "enemy", align = "right_heel", events = "controlled",
    tactic_when = { distance = { axis = "x", min = 300, max = 600, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
    windows = {
        uninterruptible = { to = 143 },
        invulnerable = { name = "Evade", from = 63, to = 143 },
    },
    on = {
        [1] = { sound = { "snd_rayshot_bones" } },
        [6] = { sound = { "snd_rayshot" } },
        [63] = { { projectile = {
            name = "PerkFearRay", core_skeleton = "SkeletonMagic",
            item = sf2.items.get("core:items/magic/MAGIC_FEAR_RAY"), start = fear_ray_beam,
        } }, { add_bullets = "magic", amount = -1 } },
        strike = { sound = HITS },
    },
}

-- blackness_grasp_player's graph (frames as in content.blackness_grasp), with the same hand
-- children; the charge is paid when the hand appears. The hand starts its attack by itself 24
-- frames later (frame 48 of this cast), so a hit on the caster no longer cancels the strike.
local grasp_when, grasp_for = cast_when("GraspOfDarknessMagic")
local grasp_cast = sf2.moves.register {
    id = "grasp_of_darkness_magic_player",
    animation = sf2.assets.binary("animations/darkness_hug_player"),
    inherit = { "1key", "MagicPlayer", "Controlled", "SoundStrike" },
    type = "attack", first_sample = 2, priority = 110,
    no_wall_repulsion = true,
    only_for = grasp_for, when = grasp_when,
    face = "enemy", align = "right_heel", events = "controlled",
    tactic_when = { distance = { axis = "x", min = 450, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
    windows = { uninterruptible = { to = 116 } },
    on = {
        [24] = { { projectile = {
            name = "BlackHand", core_skeleton = "SkeletonMagic",
            item = sf2.items.get("core:items/magic/MAGIC_ACID_CLOUD"), start = grasp.hand_start,
        } }, { add_bullets = "magic", amount = -1 } },
    },
}

return { items = items, fear_ray = fear_ray, grasp = grasp_cast }
