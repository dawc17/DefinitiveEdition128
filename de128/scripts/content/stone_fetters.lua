local sf2 = require("sf2")
local words = require("content.text")

-- Stone Fetters (mythical, kind = "combo"): eight melee hits, each within 3.5 s of the last,
-- trigger a draining meter. While it lasts an earthquake strikes the enemy every 3 s whether or
-- not a hit lands (never a boss), knocking them down as a landed sweep does, and the player takes
-- hits armored. Bosses never use it.
-- Plan: Stone Fetters Mythical Enchantment Concept Plan.

local HITS = 8
local WINDOW = 210                        -- frames allowed between hits (3.5 s)
local FULL = 360                          -- frames a full bar lasts (6 s)
local REFILL = 36                         -- each landed hit refills 10%
local STAGGER_EVERY = 180                 -- 3 s
local METER_KEY = "stone_fetters"
local METER_COLOR = "#8E9AAF"             -- counting hits, one cell each
local ACTIVE_COLOR = "#C9D5E8"            -- bound: the cells are the time left
local TINT = "#9FB0C8"

-- The quake is the challenges' EARTHQUAKE rule (PERK_RULE_EARTHQUAKE; vanillaXml moves.xml,
-- triggers Rule_Earthquake_screen_shake and Rule_Earthquake, and the move RuleEarthquakeHit):
-- the screen shakes, the rule's sound plays with its seven bursts along the floor, and a child
-- carrying the hidden RULE_EARTHQUAKE weapon strikes with the "Earthquake" hit, through block.
-- The enemy answers it with its own reaction to that hit, SweepHitFall: the fall a landed sweep
-- causes (Seby, 2026-11-24, instead of the old recoil and tremble). The animation is a
-- byte-identical copy of rule_earthquake.bytes, played from sample 2 at 5 frames a sample as the
-- native move is. The rule's shake runs 3 s before its quake; here, with a quake every 3 s, it
-- runs one second from the quake. Unlike the rule, the quake deals no damage.
local quake_item = sf2.items.get("core:items/magic/RULE_EARTHQUAKE")
local QUAKE_ACTOR = "de128.stone_fetters_quake"
local QUAKE_MOVE = "de128:moves/stone_fetters_quake"
-- The rule's bursts: floor position from the arena's left end, height, scale.
local BURSTS = { { 250, 100, 2.1 }, { 500, 75, 2.0 }, { 750, 95, 1.8 }, { 1000, 75, 2.5 },
    { 1250, 100, 1.8 }, { 1500, 100, 2.5 }, { 1750, 75, 2.1 } }

local function quake_actions()
    local actions = {
        { shake = { pause_time = 0, effect_time = 60, amplitude_x = 7, frequency_x = 1,
            amplitude_y = 20, frequency_y = 0.5 } },
        { sound = "snd_earthquake" },
    }
    for _, burst in ipairs(BURSTS) do
        actions[#actions + 1] = { effect = {
            name = "StoneFettersQuake", core_sequence = "mgc_magic_earth_quake_end", scale = burst[3],
            time_scale = 4, looped = false, position = { floor = "self", x = burst[1], y = burst[2] }, follow = false,
        } }
    end
    return actions
end

local quake_move = sf2.moves.register {
    id = "stone_fetters_quake", animation = sf2.assets.binary("animations/rule_earthquake"),
    frames_per_sample = 5, first_sample = 2, priority = 500,
    no_wall_repulsion = true, no_magic_recharge = true,
    face = "with_parent",                 -- RuleEarthquakeHit's SetDirection: the parent's back wall to its front
    align = { axes = { "x", "z" }, pivot = { node = "Magic-Node2_1" }, position = { node = "pelvis", of = "enemy" } },
    when = { actor = QUAKE_ACTOR },
    only_for = { weapon = { item = "RULE_EARTHQUAKE" }, rig = "SkeletonMagic" },
    -- RuleEarthquakeHit's attack. It reaches the enemy wherever they stand, as the rule's quake
    -- covers the whole floor.
    attacks = { {
        from_sample = 3, to_sample = 3, direct = true,
        damage = { amount = 0, magic = 0, unarmed = -25 },
        impulse = { x = 150, y = -300 }, hit = "Earthquake",
        no_effect = true, no_critical = true, no_perk_bonus = true, body_part = "body", defense = { "body" },
        ignores_block = true, ignores_invulnerable = { "Evade", "Recovery", "Dash" },
    } },
    -- Frame 0 runs before the new child is placed; nothing here needs its place, but frame 1 is safe.
    on = {
        [1] = quake_actions(),
        finish = { delete_actor = "self" },
    },
}

local quake = sf2.projectiles.register {
    id = "stone_fetters_quake", name = QUAKE_ACTOR, core_skeleton = "SkeletonMagic",
    item = quake_item, start_move = quake_move, lifetime_frames = 60,
}

-- States a quake must not cut into: a body in the air or on the floor, a throw in progress on
-- either side, an ability, or a reaction that is already playing. The quake waits for them.
local NO_STAGGER = { "Physical", "Fall", "Jump", "Wall", "Throw", "ThrowFall", "ThrowProfile",
    "BossAbility", "Ability", "Recoil" }

local function can_stagger(fighter)
    for _, name in ipairs(NO_STAGGER) do
        if fighter:animation_is(name, "opponent") then return false, name end
    end
    return true
end

-- Bosses carry the anti-shock perk; raid bosses also have several health bars.
local function is_boss(fighter, view)
    return not view or not view.opponent or view.opponent.max_health > 1 or fighter:has_perk("PERK_ANTI_SHOCK", "opponent")
end

-- Spawn offsets are from the player's centre along the arena's axes, at most 1000 each way.
local function clamp(offset)
    return math.max(-1000, math.min(1000, offset))
end

local function quake_enemy(fighter, view)
    local receipt = fighter:spawn_projectile(quake, clamp(view.opponent.position.x - view.self.position.x), 0)
    sf2.log.info("Stone Fetters quake spawn: " .. tostring(receipt.status) .. " " .. tostring(receipt.error))
end

-- Eight cells: one a hit while counting, then the time left while the enemy is bound.
local function show_meter(self, fighter)
    local s = self.state
    local value = s.active and s.charge / FULL or s.hits / HITS
    local shown = math.floor(value * 1000) + (s.active and 1000000 or 0)
    if shown == s.shown then return end
    s.shown = shown
    fighter:set_meter(METER_KEY, { value = value, segments = HITS, color = s.active and ACTIVE_COLOR or METER_COLOR })
end

local function stop(self, fighter)
    local s = self.state
    s.active, s.charge, s.hits, s.stagger_due = false, 0, 0, false
    fighter:clear_model_color()
    show_meter(self, fighter)
end

local function landed(self, fighter)
    local s = self.state
    if s.active then
        s.charge = math.min(FULL, s.charge + REFILL)
    else
        if s.now - s.last_hit > WINDOW then s.hits = 0 end
        s.hits = s.hits + 1
        s.last_hit = s.now
        if s.hits >= HITS then
            s.active, s.charge, s.next_stagger = true, FULL, s.now + STAGGER_EVERY
            fighter:set_model_color(TINT, 60)
        end
    end
    show_meter(self, fighter)
end

local behavior = {
    state = { lifetime = "round", fields = {
        now = 0, hits = 0, last_hit = 0, charge = 0, active = false,
        next_stagger = 0, stagger_due = false, shown = -1,
    } },
    -- No on_round_end clear: the meter stays until the round resets, so it leaves with the rest
    -- of the fight HUD.
    -- The meter is drawn from on_tick: fight meters need a running round.
    on_round_begin = function(self, fighter)
        self.state.shown = -1
    end,
    on_tick = function(self, fighter, event)
        local s = self.state
        s.now = event.frame
        if s.shown == -1 then
            local first = fighter:snapshot()
            if first and first.round_active then show_meter(self, fighter) end
        end
        if not s.active then
            if s.hits > 0 and s.now - s.last_hit > WINDOW then
                s.hits = 0
                show_meter(self, fighter)
            end
            return
        end
        s.charge = s.charge - event.delta_frames
        if s.charge <= 0 then
            stop(self, fighter)
            return
        end
        local view = fighter:snapshot()
        if view and view.round_active then
            if s.now >= s.next_stagger then
                s.next_stagger = s.now + STAGGER_EVERY
                s.stagger_due = not is_boss(fighter, view)
                -- Temporary diagnostics (2026-11-24): why a due quake does not spawn.
                if not s.stagger_due then sf2.log.info("Stone Fetters quake skipped: opponent counts as a boss") end
            end
            if s.stagger_due and fighter.opponent then
                local free, blocker = can_stagger(fighter)
                if free then
                    s.stagger_due = false
                    quake_enemy(fighter, view)
                elseif s.now % 60 == 0 then
                    sf2.log.info("Stone Fetters quake waiting: opponent in " .. tostring(blocker))
                end
            end
        end
        if s.now % 30 == 0 then fighter:set_model_color(TINT, 60) end
        show_meter(self, fighter)
    end,
    on_hit_pre_crit = function(self, fighter, event)
        local s = self.state
        if s.active and event.target == "self" then
            -- Armor: damage is taken, no stagger or interruption.
            fighter:set_hit_armored(true)
        end
    end,
    on_post_hit = function(self, fighter, event)
        -- Only landed melee hits count: not ranged, magic or ability moves, nor the quake itself.
        if event.target ~= "opponent" or event.blocked or event.ranged or event.magic then return end
        if not (event.weapon or event.unarmed) then return end
        if event.attack and event.attack.animation_name == QUAKE_MOVE then return end
        if fighter:animation_is("BossAbility") or fighter:animation_is("Ability") then return end
        landed(self, fighter)
    end,
}

return sf2.perks.register {
    id = "stone_fetters",
    display_name = words.own("special.stone_fetters.name", "special.stone_fetters.name"),
    description = words.own("special.stone_fetters.description", "special.stone_fetters.description"),
    -- The game's own Stone Fetters orb (PERK_DRAGON_SET_STONE, Enchantments.EnchantmentStone).
    icon = sf2.assets.sprite("core:ui/atlases/enchantments.enchantmentstone"),
    kind = "combo",
    behavior = behavior,
}
