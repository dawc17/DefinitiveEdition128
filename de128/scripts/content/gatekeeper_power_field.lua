local sf2 = require("sf2")
local abilities = require("content.boss_abilities")

-- Restore the archived RaidCharge cast and its hidden power-field actor.
-- Both animations are byte-identical copies of the packaged native data.

local aura_item = sf2.items.get("core:items/magic/MAGIC_FIRE_AURA")

sf2.moves.patch { move = "GateKeeperPowerField", disable = true }
sf2.moves.patch { move = "AbilityGateKeeperPowerField", disable = true }

-- Frames: surge has 2 frames per sample from sample 1 (sample 2 is frames 4-5, sample 5
-- is 10-11); the cast has 3 frames per sample from sample 1 (sample 8 is frame 24,
-- 13 is 39, 20 is 60, and its sample 26 starts on frame 78 and ends on frame 80).
local surge = sf2.moves.register {
    id = "gatekeeper_power_surge",
    animation = sf2.assets.binary("animations/ability_power_surge"),
    inherit = { "MagicFireAura", "MagicMissileFly", "MagicMissile" },
    frames_per_sample = 2, first_sample = 1, priority = 500,
    no_wall_repulsion = true, no_interpolation_frames = true, no_magic_recharge = true,
    face = "with_parent",
    align = { axes = { "x", "y", "z" }, pivot = { node = "Magic-Node3_1", of = "self" },
        position = { node = "neck", of = "parent", x = -80, y = 60 } },
    events = { "birth" },
    when = { actor = "AbilityPowerField" },
    attacks = { {
        from = 4, to = 11,
        edges = { "Magic-Edge1_1", "Magic-Edge2_1", "Magic-Edge4_1", "Magic-Edge6_1" },
        damage = { amount = 0.3, magic = 0, unarmed = -25 },
        impulse = { x = 175, y = 350 }, hit = "ElectrocutionPowerfield",
        no_effect = true, no_critical = true, body_part = "body",
        defense = { "body" }, ignores_block = true,
        ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } },
    on = {
        [0] = { { effect = {
            name = "PowerFieldEffect", core_sequence = "effect_electricity",
            scale = 1.5, time_scale = 2, on_background = true,
            attach = { of = "parent", root_point = "stomach", attach_point = "chest",
                offset_x = 15, offset_y = -15 },
        } }, { effect = {
            name = "PowerFieldEffect2", core_sequence = "effect_electricity",
            scale = 1.5, time_scale = 2, on_background = true,
            attach = { of = "parent", root_point = "stomach", attach_point = "chest",
                offset_x = 15, offset_y = -15, start_rotation = 330 },
        } } },
        finish = { delete_actor = "self" },
    },
    only_for = { weapon = "MagicFireAura", rig = "SkeletonMagic" },
}

local cast = sf2.moves.register {
    id = "gatekeeper_power_field",
    animation = sf2.assets.binary("animations/ability_gatekeeper_power_field"),
    inherit = { "1key", "BossAbility", "Controlled", "SoundStrike" },
    no_wall_repulsion = true, first_sample = 1,
    priority = 1010,
    -- No rig requirement here (the ability lock only), so the left-heel default does not apply.
    mirror = "left_heel",
    tactic_when = { distance = { axis = "x", max = 350, from = { pivot = "self" }, to = { node = "pelvis", of = "enemy" } } },
    align = "left_heel",
    when = {
        keys = "raid_charge",
        not_mod = { "GateKeeperPowerFieldCD", abilities.ready("power_field") },
        controllable = true,
    },
    only_for = { any = abilities.lock("power_field") },
    windows = { uninterruptible = { to = 80 }, block = { from = 78 } },
    on = {
        [39] = { effect = {
            name = "ElectroEffect", core_sequence = "mgc_effect_shocker",
            scale = 0.75, time_scale = 2, on_background = true,
            attach = { of = "self", root_point = "MacroBodyGatekeeper-Node975",
                attach_point = "MacroBodyGatekeeper-Node445",
                offset_x = -54, offset_y = -12, start_rotation = -78 },
        } },
        [60] = { projectile = {
            name = "AbilityPowerField", core_skeleton = "SkeletonMagic",
            item = aura_item, start = surge,
        } },
        [24] = { sound = { "snd_energy_burst" } },
    },
    events = "controlled",
    face = "enemy",
}

-- Seconds between fields; recorded as the boss's pacing for its HUD icon.
local FIELD_EVERY = 6
local tactic = sf2.tactics.register {
    id = "gatekeeper_power_field", template = "Aggressive",
    on_decide = function(memory, event)
        if event.seconds < (memory.next_field or 0) then return nil end
        for _, action in ipairs(event.actions) do
            if action.name == "de128:moves/gatekeeper_power_field" then
                memory.next_field = event.seconds + FIELD_EVERY
                return action
            end
        end
        return nil
    end,
}

return { cast = cast, surge = surge,
    tactic = abilities.pace(sf2.tactics.name(tactic), "power_field", 0, FIELD_EVERY * 60,
        { "de128:moves/gatekeeper_power_field" }) }
