local sf2 = require("sf2")

-- Boss-ability enchantments granted by DE's Special Recipes I-III.
-- Authority: Assets/DExml/perks.xml PERK_SHADOW_CLOAK .. PERK_TITANS_SHIELD
-- (PerkType="Combo", Button="RaidCharge"), list.xml's single-item SpecialRecipe
-- sets (name = perk Alias, description = set Brief) and forge.xml's Abilities
-- recipes. The archive is research input only; this module executes no XML.
--
-- Core keeps its own PERK_* boss-AI perks: they still unlock these moves for
-- opponents and set the native *Recharge flags. The perks below are the player's
-- versions. A combo perk only takes effect while all five equipped pieces carry
-- it, so at most one of them is active at a time.
--
-- PERK_SHADOW_CLOAK has no core boss perk (Lynx's PERK_INVISIBILITY is a different,
-- Super-button ability), so it is registered below on its own; see shadow_cloak.
--
-- Readiness on the HUD: every fighter carrying one of these abilities shows its icon
-- while it can be used and the greyed icon (with the remaining-time sweep) while it
-- recharges, through sf2.perks.recharge_indicator. The player's recharge is a timed
-- flag. A boss's is its core perk's native flag, plus, for DE128's own boss tactics,
-- a pacing flag that follows the tactic's cadence (see pace_perk below).

local behavior_id = "boss_ability"

-- Flag names seen by native move conditions: <qualified behavior ID>:<key>.
local function flag(key)
    return sf2.mod.id .. ":behaviors/" .. behavior_id .. ":" .. key
end

-- Owner-supplied enchantment icons (Tools/Recovery/ImportDE128AbilityIcons.py):
-- sprites/abilities/<key> while ready, <key>_cooldown (greyed) while recharging.
local function icon(key)
    return sf2.assets.sprite("sprites/abilities/" .. key)
end

local function cooldown_icon(key)
    return sf2.assets.sprite("sprites/abilities/" .. key .. "_cooldown")
end

-- key: frames/initial_frames from the perk's <Set>; native: the core perk's
-- <Set FlagName> (vanillaXml perks.xml); triggers: exact animation
-- names whose start begins the recharge (DE AnimationStart _AnimationName);
-- hit_moves: begin the recharge when hit during these instead (Hermit Storm's
-- PostHit Player="Me" trigger).
local abilities = {
    hermit_storm = { core = "PERK_HERMITSTORM", native = "HermitStormRecharge", frames = 600, initial_frames = 300,
        hit_moves = { "de128:moves/hermit_storm_player", "de128:moves/hermit_storm_idle" } },
    earthquake = { core = "PERK_EARTHQUAKE", native = "EarthquakeRecharge", frames = 600,
        triggers = { "de128:moves/butcher_earthquake_player" } },
    wasp_fly = { core = "PERK_WASPFLY", native = "WaspFlyRecharge", frames = 600,
        triggers = { "de128:moves/wasp_fly_150", "de128:moves/wasp_fly_200",
            "de128:moves/wasp_fly_300", "de128:moves/wasp_fly_370" } },
    teleportation = { core = "PERK_TELEPORTATION", native = "TeleportationRecharge", frames = 600,
        triggers = { "WidowTeleportationStart" } },
    assistants = { core = "PERK_ASSISTANTS", native = "AssistantsRecharge", frames = 550,
        triggers = { "AssistantLongKatanaPlayer", "AssistantBigNaginataPlayer",
            "AssistantBigMagariYariPlayer", "AssistantUniqGlaivePlayer" } },
    rat_wave = { core = "PERK_RAT_WAVE", native = "RatWaveRecharge", frames = 600,
        triggers = { "RatWavePlayer" } },
    war_whirl = { core = "PERK_WAR_WHIRL", native = "WarRecharge", frames = 600,
        triggers = { "de128:moves/war_whirl_player" } },
    lightning_chain = { core = "PERK_LIGHTING_CHAIN", native = "LightningChainCD", frames = 600, initial_frames = 300,
        triggers = { "LightingChainPlayer" } },
    fear_ray = { core = "PERK_FEAR_RAY", native = "FearRecharge", frames = 600,
        triggers = { "PerkFearRayPlayer" } },
    power_field = { core = "PERK_POWER_FIELD", native = "GateKeeperPowerFieldCD", frames = 600,
        triggers = { "de128:moves/gatekeeper_power_field" } },
    grasp_of_darkness = { core = "PERK_GRASP_OF_DARKNESS", native = "GraspOfDarknessCD", frames = 600,
        triggers = { "de128:moves/blackness_grasp_player" } },
}

local order = { "hermit_storm", "earthquake", "wasp_fly", "teleportation", "assistants", "rat_wave",
    "war_whirl", "lightning_chain", "fear_ray", "power_field", "grasp_of_darkness" }

local function set_of(list)
    local result = {}
    for _, name in ipairs(list or {}) do result[name] = true end
    return result
end

for _, key in ipairs(order) do
    local ability = abilities[key]
    ability.trigger_set = set_of(ability.triggers)
    ability.hit_set = set_of(ability.hit_moves)
end

-- The initial recharge starts on the first combat tick: flags and button
-- cooldowns need a processing round, which round-begin callbacks precede.
-- The flag is timed, so native modifier expiry ends the recharge and the
-- recharge indicator sweeps the greyed icon over its remaining frames.
local function recharge(self, fighter, frames)
    local key = self.params.key
    fighter:clear_flag(key)
    fighter:set_flag(key, frames)
    fighter:set_button_cooldown("raid_charge", frames)
end

local recharge_behavior = sf2.behaviors.register {
    id = behavior_id,
    parameters = {
        key = { type = "string" },
        frames = { type = "integer" },
        initial_frames = { type = "integer" },
    },
    state = { lifetime = "round", fields = {
        started = false,
    } },
    on_tick = function(self, fighter)
        if self.state.started then return end
        self.state.started = true
        recharge(self, fighter, self.params.initial_frames)
        -- DE quests.xml ShowRaidChargeButton: an active ability shows RaidCharge
        -- outside raids too. Opponents have no button; the call is then a no-op.
        fighter:set_control_visible("raid_charge", true)
    end,
    on_animation_start = function(self, fighter, event)
        if event.target == "self" and abilities[self.params.key].trigger_set[event.animation_name] then
            recharge(self, fighter, self.params.frames)
        end
    end,
    on_post_hit = function(self, fighter, event)
        local hit_set = abilities[self.params.key].hit_set
        if event.target ~= "self" or next(hit_set) == nil then return end
        local snapshot = fighter:snapshot()
        local animation = snapshot and snapshot.self and snapshot.self.animation
        if animation and hit_set[animation.name] then
            recharge(self, fighter, self.params.frames)
        end
    end,
}

local perks = {}
local flags = {}
local core_perks = {}
for _, key in ipairs(order) do
    local ability = abilities[key]
    perks[key] = sf2.perks.register {
        id = key,
        display_name = sf2.localization.key("ability." .. key .. ".name"),
        description = sf2.localization.key("ability." .. key .. ".description"),
        icon = icon(key),
        kind = "combo",
        behavior = recharge_behavior,
        parameters = { key = key, frames = ability.frames, initial_frames = ability.initial_frames or ability.frames },
    }
    flags[key] = flag(key)
    core_perks[key] = sf2.perks.get("core:perks/" .. ability.core)
end

-- PERK_TITANS_SHIELD: the first incoming hit after each 600-frame recharge is
-- negated (ModAttributes DamageFactor=-900000 on the attacker for one frame).
-- The shield is down while its timed "down" flag lasts.
local function shield_recharge(self, fighter)
    fighter:clear_flag("down")
    fighter:set_flag("down", self.params.cooldown)
end

local shield_behavior = sf2.behaviors.register {
    id = "titans_shield",
    parameters = { cooldown = { type = "integer" } },
    state = { lifetime = "round", fields = {
        started = false,
    } },
    on_tick = function(self, fighter)
        if self.state.started then return end
        self.state.started = true
        shield_recharge(self, fighter)
    end,
    on_damage_resolving = function(self, fighter, event)
        if self.state.started and event.damage > 0 and not fighter:has_flag("down") then
            fighter:scale_incoming_damage(0)
            shield_recharge(self, fighter)
        end
    end,
}

perks.titans_shield = sf2.perks.register {
    id = "titans_shield",
    display_name = sf2.localization.key("ability.titans_shield.name"),
    description = sf2.localization.key("ability.titans_shield.description"),
    icon = icon("titans_shield"),
    kind = "combo",
    behavior = shield_behavior,
    parameters = { cooldown = 600 },
}

-- PERK_SHADOW_CLOAK (alias LynxAbil_invisibility, "Smoke Bomb"):
-- <Set Frames="600" InvisibilityFrames="650" InitialFrames="300">.
-- * RoundStageStart Fight: recharge for InitialFrames.
-- * Frame 13 of ShadowCloakPlayer, while neither cloaked nor recharging: cloak the
--   model and make the player's hits unblockable for InvisibilityFrames. The archive
--   tints the model #FFFFFF80; DE128 draws Eclipse's glass cloak instead (owner's call,
--   2026-10-13: per-part alpha on the rig showed every overlap).
--   (The archive also runs <DisableInterval Uninterrupt> there; the move's own
--   Uninterrupt interval ends at that frame.)
-- * HitPreCrit on the enemy with Block=1 while unblockable: <SetHit Block="0">.
-- * When the cloak's timeout expires: recharge for Frames.
-- The archive's HitPostCrit trigger needs the cloak present after its timeout flag has
-- gone, which the timeout's own expiry trigger prevents, so being hit does not end it.
local cloak_behavior_id = "shadow_cloak"
local function cloak_flag(key)
    return sf2.mod.id .. ":behaviors/" .. cloak_behavior_id .. ":" .. key
end
local cloak_move = sf2.mod.id .. ":moves/shadow_cloak_player"
local cloak_buff = sf2.assets.sprite("core:ui/skills/IconInvisibility_Blue")

local function cloak_recharge(fighter, frames)
    fighter:clear_flag("recharge")
    fighter:set_flag("recharge", frames)
    fighter:set_button_cooldown("raid_charge", frames)
end

local cloak_behavior = sf2.behaviors.register {
    id = cloak_behavior_id,
    parameters = {
        frames = { type = "integer" },
        invisibility_frames = { type = "integer" },
        initial_frames = { type = "integer" },
    },
    state = { lifetime = "round", fields = {
        started = false,
        cloaked = false,
    } },
    on_tick = function(self, fighter)
        if not self.state.started then
            self.state.started = true
            cloak_recharge(fighter, self.params.initial_frames)
            fighter:set_control_visible("raid_charge", true)
            return
        end
        if self.state.cloaked then
            -- InvisibilityTimeout_flag expired.
            if not fighter:has_flag("active") then
                self.state.cloaked = false
                cloak_recharge(fighter, self.params.frames)
            end
            return
        end
        if fighter:has_flag("recharge") then return end
        local snapshot = fighter:snapshot()
        local animation = snapshot and snapshot.self and snapshot.self.animation
        if animation and animation.name == cloak_move and animation.frame == 13 then
            local frames = self.params.invisibility_frames
            fighter:set_cloak(frames)
            fighter:show_status_icon("cloak", cloak_buff, frames)
            fighter:set_flag("active", frames)
            self.state.cloaked = true
        end
    end,
    on_hit_pre_crit = function(self, fighter, event)
        if event.target == "opponent" and event.blocked and fighter:has_flag("active") then
            fighter:set_hit_blocked(false)
        end
    end,
}

perks.shadow_cloak = sf2.perks.register {
    id = "shadow_cloak",
    display_name = sf2.localization.key("ability.shadow_cloak.name"),
    description = sf2.localization.key("ability.shadow_cloak.description"),
    icon = icon("shadow_cloak"),
    kind = "combo",
    behavior = cloak_behavior,
    parameters = { frames = 600, invisibility_frames = 650, initial_frames = 300 },
}
flags.shadow_cloak = cloak_flag("recharge")

-- DE128's boss tactics pace their casts themselves (memory.next_* in each tactic).
-- A pacing perk on such a boss mirrors that cadence in a timed flag no move checks,
-- so the boss's icon is greyed exactly while its tactic waits. Its first-round
-- delay is the tactic's opening wait; later rounds start with the core perk's own
-- native recharge. Created on demand while warriors register; one per cadence.
local pace_flag_behavior = "boss_ability_pace"
local pace_moves = {}
local pace_behavior = sf2.behaviors.register {
    id = pace_flag_behavior,
    parameters = {
        id = { type = "string" },
        key = { type = "string" },
        frames = { type = "integer" },
        initial_frames = { type = "integer" },
    },
    state = { lifetime = "fight", fields = {
        started = false,
    } },
    on_tick = function(self, fighter)
        if self.state.started then return end
        self.state.started = true
        if self.params.initial_frames > 0 then fighter:set_flag(self.params.key, self.params.initial_frames) end
    end,
    on_animation_start = function(self, fighter, event)
        if event.target == "self" and pace_moves[self.params.id][event.animation_name] then
            fighter:clear_flag(self.params.key)
            fighter:set_flag(self.params.key, self.params.frames)
        end
    end,
}

local pace_perks = {}
-- key: ability; initial/frames: the tactic's opening wait and cadence in native
-- frames; moves: the cast moves whose start the tactic paces.
local function pace_perk(key, initial, frames, moves)
    local id = "boss_pace_" .. key .. "_" .. initial .. "_" .. frames
    if not pace_perks[id] then
        pace_moves[id] = set_of(moves)
        pace_perks[id] = sf2.perks.register {
            id = id,
            display_name = sf2.localization.key("ability." .. key .. ".name"),
            description = sf2.localization.key("ability." .. key .. ".description"),
            behavior = pace_behavior,
            parameters = { id = id, key = key, frames = frames, initial_frames = initial },
        }
    end
    return pace_perks[id]
end

-- Tactic name -> its pacing spec, recorded by the module that registers the tactic.
local tactic_paces = {}
local function pace(tactic, key, initial, frames, moves)
    assert(abilities[key], "Unknown boss ability " .. tostring(key))
    tactic_paces[tactic] = { key = key, initial = initial, frames = frames, moves = moves }
    return tactic
end

-- The pacing perk for a warrior using this tactic, or nil for unpaced tactics.
local function pace_perk_for(tactic)
    local spec = tactic_paces[tactic]
    return spec and pace_perk(spec.key, spec.initial, spec.frames, spec.moves) or nil
end

-- One indicator per perk: the player's enchantment watches its timed recharge; a
-- boss's core perk watches the native flag and the DE128 pacing flag.
for _, key in ipairs(order) do
    sf2.perks.recharge_indicator { perk = perks[key], flags = { flags[key] },
        ready = icon(key), cooldown = cooldown_icon(key) }
    sf2.perks.recharge_indicator { perk = core_perks[key],
        flags = { abilities[key].native, sf2.mod.id .. ":behaviors/" .. pace_flag_behavior .. ":" .. key },
        ready = icon(key), cooldown = cooldown_icon(key) }
end
sf2.perks.recharge_indicator { perk = perks.titans_shield, flags = { sf2.mod.id .. ":behaviors/titans_shield:down" },
    ready = icon("titans_shield"), cooldown = cooldown_icon("titans_shield") }
-- Greyed while cloaked too: the move cannot be cast again until the recharge ends.
sf2.perks.recharge_indicator { perk = perks.shadow_cloak, flags = { cloak_flag("recharge"), cloak_flag("active") },
    ready = icon("shadow_cloak"), cooldown = cooldown_icon("shadow_cloak") }

-- Requirement for de128-registered ability moves: the core boss perk (opponents) or
-- the player's enchantment. A list for `any`, so a move writes
-- only_for = { any = abilities.lock("x"), rig = "Skeleton" }.
local function lock(key)
    return { { perk = core_perks[key] }, { perk = perks[key] } }
end

-- Flag name for a move's `not_mod` list: the player's recharge for this ability has finished.
local function ready(key)
    return flags[key]
end

-- Flag name for a move's `not_mod` list: the Shadow Cloak is not active (the archive's UnblockableActive).
local function uncloaked()
    return cloak_flag("active")
end

-- Native moves keep their core perk lock and gain the enchantment as an alternative.
local function extend_lock(key, move)
    sf2.moves.extend_perk_lock { move = move, source_perk = core_perks[key], perk = perks[key] }
end

return {
    perks = perks,
    flags = flags,
    core_perks = core_perks,
    lock = lock,
    ready = ready,
    uncloaked = uncloaked,
    extend_lock = extend_lock,
    pace = pace,
    pace_perk_for = pace_perk_for,
}
