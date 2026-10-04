local sf2 = require("sf2")

-- Boss-ability enchantments granted by DE's Special Recipes I-III.
-- Authority: Assets/DExml/perks.xml PERK_HERMITSTORM .. PERK_TITANS_SHIELD
-- (PerkType="Combo", Button="RaidCharge"), list.xml's single-item SpecialRecipe
-- sets (name = perk Alias, description = set Brief) and forge.xml's Abilities
-- recipes. The archive is research input only; this module executes no XML.
--
-- Core keeps its own PERK_* boss-AI perks: they still unlock these moves for
-- opponents and set the native *Recharge flags. The perks below are the player's
-- versions. A combo perk only takes effect while all five equipped pieces carry
-- it, so at most one of them is active at a time.
--
-- Not ported: PERK_SHADOW_CLOAK (Special Recipe I). Its cloak needs a model
-- transparency and an "opponent cannot block" capability that the API lacks.

local behavior_id = "boss_ability"

-- Flag names seen by native move conditions: <qualified behavior ID>:<key>.
local function flag(key)
    return sf2.mod.id .. ":behaviors/" .. behavior_id .. ":" .. key
end

local function sprite(name)
    return sf2.assets.sprite("core:ui/skills/" .. name)
end

-- key: frames/initial_frames from the perk's <Set>; triggers: exact animation
-- names whose start begins the recharge (DE AnimationStart _AnimationName);
-- hit_moves: begin the recharge when hit during these instead (Hermit Storm's
-- PostHit Player="Me" trigger). icon: native ModIcon image of the ready state.
local abilities = {
    hermit_storm = { core = "PERK_HERMITSTORM", frames = 600, initial_frames = 300, icon = "IconAscetism",
        hit_moves = { "de128:moves/hermit_storm_player", "de128:moves/hermit_storm_idle" } },
    earthquake = { core = "PERK_EARTHQUAKE", frames = 600, icon = "IconCruelty",
        triggers = { "de128:moves/butcher_earthquake_player" } },
    wasp_fly = { core = "PERK_WASPFLY", frames = 600, icon = "IconAccuracy",
        triggers = { "de128:moves/wasp_fly_150", "de128:moves/wasp_fly_200",
            "de128:moves/wasp_fly_300", "de128:moves/wasp_fly_370" } },
    teleportation = { core = "PERK_TELEPORTATION", frames = 600, icon = "IconChargeSteal",
        triggers = { "WidowTeleportationStart" } },
    assistants = { core = "PERK_ASSISTANTS", frames = 550, icon = "IconIronGrip",
        triggers = { "AssistantLongKatanaPlayer", "AssistantBigNaginataPlayer",
            "AssistantBigMagariYariPlayer", "AssistantUniqGlaivePlayer" } },
    rat_wave = { core = "PERK_RAT_WAVE", frames = 600, icon = "IconMagicAttack",
        triggers = { "RatWavePlayer" } },
    war_whirl = { core = "PERK_WAR_WHIRL", frames = 600, icon = "IconSyphon",
        triggers = { "de128:moves/war_whirl_player" } },
    lightning_chain = { core = "PERK_LIGHTING_CHAIN", frames = 600, initial_frames = 300, icon = "IconLightning",
        triggers = { "LightingChainPlayer" } },
    fear_ray = { core = "PERK_FEAR_RAY", frames = 600, icon = "IconElementalPrecision",
        triggers = { "PerkFearRayPlayer" } },
    power_field = { core = "PERK_POWER_FIELD", frames = 600, icon = "IconCriticalChance",
        triggers = { "de128:moves/gatekeeper_power_field" } },
    grasp_of_darkness = { core = "PERK_GRASP_OF_DARKNESS", frames = 600, icon = "IconLifesteal",
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
    ability.cooldown_icon = sprite(ability.icon .. "_Red")
end

-- The initial recharge starts on the first combat tick: flags and button
-- cooldowns need a processing round, which round-begin callbacks precede.
local function recharge(self, fighter, frames)
    local key = self.params.key
    self.state.remaining = frames
    fighter:set_flag(key)
    fighter:set_button_cooldown("raid_charge", frames)
    fighter:show_status_icon(key, abilities[key].cooldown_icon, frames)
end

local recharge_behavior = sf2.behaviors.register {
    id = behavior_id,
    parameters = {
        key = sf2.behaviors.STRING,
        frames = sf2.behaviors.INTEGER,
        initial_frames = sf2.behaviors.INTEGER,
    },
    state = { lifetime = "round", fields = {
        started = { type = sf2.behaviors.BOOLEAN, default = false },
        remaining = { type = sf2.behaviors.INTEGER, default = 0 },
    } },
    on_tick = function(self, fighter, event)
        if not self.state.started then
            self.state.started = true
            recharge(self, fighter, self.params.initial_frames)
            -- DE quests.xml ShowRaidChargeButton: an active ability shows RaidCharge
            -- outside raids too. Opponents have no button; the call is then a no-op.
            fighter:set_control_visible("raid_charge", true)
            return
        end
        if self.state.remaining > 0 then
            self.state.remaining = self.state.remaining - event.delta_frames
            if self.state.remaining <= 0 then
                self.state.remaining = 0
                fighter:clear_flag(self.params.key)
            end
        end
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
        icon = sprite(ability.icon),
        kind = sf2.perks.COMBO,
        behavior = recharge_behavior,
        parameters = { key = key, frames = ability.frames, initial_frames = ability.initial_frames or ability.frames },
    }
    flags[key] = flag(key)
    core_perks[key] = sf2.perks.get("core:perks/" .. ability.core)
end

-- PERK_TITANS_SHIELD: the first incoming hit after each 600-frame recharge is
-- negated (ModAttributes DamageFactor=-900000 on the attacker for one frame).
local shield_down = sf2.assets.sprite("sprites/abilities/titan_shield_down")
local shield_active = sf2.assets.sprite("sprites/abilities/titan_shield_active")
local shield_refresh = 3600

local function shield_recharge(self, fighter)
    self.state.ready = false
    self.state.remaining = self.params.cooldown
    fighter:clear_status_icon("shield_active")
    fighter:show_status_icon("shield_down", shield_down, self.params.cooldown)
end

local shield_behavior = sf2.behaviors.register {
    id = "titans_shield",
    parameters = { cooldown = sf2.behaviors.INTEGER },
    state = { lifetime = "round", fields = {
        started = { type = sf2.behaviors.BOOLEAN, default = false },
        ready = { type = sf2.behaviors.BOOLEAN, default = false },
        remaining = { type = sf2.behaviors.INTEGER, default = 0 },
    } },
    on_tick = function(self, fighter, event)
        if not self.state.started then
            self.state.started = true
            shield_recharge(self, fighter)
            return
        end
        self.state.remaining = self.state.remaining - event.delta_frames
        if self.state.remaining > 0 then return end
        -- Ready: keep the active icon shown; status icons need a finite lifetime.
        self.state.ready = true
        self.state.remaining = shield_refresh
        fighter:show_status_icon("shield_active", shield_active, shield_refresh)
    end,
    on_damage_resolving = function(self, fighter, event)
        if self.state.ready and event.damage > 0 then
            fighter:scale_incoming_damage(0)
            shield_recharge(self, fighter)
        end
    end,
}

perks.titans_shield = sf2.perks.register {
    id = "titans_shield",
    display_name = sf2.localization.key("ability.titans_shield.name"),
    description = sf2.localization.key("ability.titans_shield.description"),
    icon = shield_active,
    kind = sf2.perks.COMBO,
    behavior = shield_behavior,
    parameters = { cooldown = 600 },
}

-- Locks for de128-registered ability moves: the core boss perk (opponents) or
-- the player's enchantment.
local function lock(key)
    return { any = { { perk = core_perks[key] }, { perk = perks[key] } } }
end

-- Move condition: the player's recharge for this ability has finished.
local function ready(key)
    return { not_mod = flags[key] }
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
    extend_lock = extend_lock,
}
