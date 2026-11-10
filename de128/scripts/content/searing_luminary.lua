local sf2 = require("sf2")
local words = require("content.text")

-- Searing Luminary (mythical, kind = "combo"): varied landed moves fill a three-segment
-- meter; when full a fire aura burns enemies in Requiem's range while the bar drains,
-- and a lethal hit is held back for a few seconds. Bosses never use it.
-- Plan: Searing Luminary Mythical Enchantment Concept Plan.

local SEGMENTS = 3
local FULL = 480                          -- frames the aura lasts from a full bar (about 8 s)
local SEGMENT = FULL / SEGMENTS
local WINDOW = 300                        -- a move type only counts again after 5 s
local BURN_EVERY = 15                     -- frames between burn ticks
local BURN_FRACTION = 0.4                 -- of weapon base damage per second
local DEFAULT_BASE = 0.02                 -- burn base until a weapon hit has been seen
local RANGE = 250                         -- PERK_MAGIC_THORNS (Requiem) Distance, vanillaXml/perks.xml
local DODGE_REACH = 350                   -- an attack this near makes a dodge count
local HEAD_HEIGHT = 300                   -- a kick lands on the head above this height over the feet
local DOOM_FRAMES = 180                   -- delayed death: 3 s
local LEAVE = 0.001                       -- health the lethal hit leaves behind
-- Delayed death needs the bar lit with at least this much charge left. The plan says "full
-- meter"; a lit bar is full only for an instant, so any charge counts.
local DOOM_MIN_CHARGE = 1
local METER_KEY = "searing_luminary"
local METER_COLOR = "#FF7A1A"

local kinds = { "ranged", "magic", "crit", "throw", "kick", "super", "dodge" }

-- Aura art: 400x400 px sprites, played start -> loop -> end by swapping the marker's sprite.
local SIZE = 400
local STEP = 3                            -- ticks per art frame
local function frames(name, count)
    local list = {}
    for index = 1, count do
        list[index] = sf2.assets.sprite(string.format("sprites/searing_aura/mgc_fenix_aura_effect_%s_%02d", name, index))
    end
    return list
end
local start_frames, loop_frames, end_frames = frames("start", 3), frames("loop", 10), frames("end", 4)

local function aura_sprite(phase, tick)
    local index = math.floor(tick / STEP)
    if phase == 1 then
        if index < #start_frames then return start_frames[index + 1] end
        return loop_frames[(index - #start_frames) % #loop_frames + 1]
    end
    return end_frames[index + 1]          -- nil once the end frames are done
end

local marker                              -- aura marker handle; art only, not saved state

local function drop_marker()
    if marker then sf2.world.remove_marker(marker) end
    marker = nil
end

local function has_interval(animation, kind)
    for _, interval in ipairs(animation and animation.intervals or {}) do
        if interval.type == kind then return true end
    end
    return false
end

local function show_meter(self, fighter)
    fighter:set_meter(METER_KEY, { value = self.state.charge / FULL, segments = SEGMENTS, color = METER_COLOR })
end

local function end_aura(self, fighter)
    local s = self.state
    s.lit, s.charge, s.aura_phase, s.aura_tick = false, 0, 2, 0
    show_meter(self, fighter)
end

local function trigger(self, fighter)
    local s = self.state
    s.lit, s.charge, s.aura_phase, s.aura_tick, s.burn_tick = true, FULL, 1, 0, 0
    for _, kind in ipairs(kinds) do s["last_" .. kind] = -WINDOW end   -- used moves reset
    show_meter(self, fighter)
end

-- A move type adds a segment unless it was used within the last 5 seconds.
local function use(self, fighter, kind)
    local s = self.state
    local field = "last_" .. kind
    if s.now - s[field] < WINDOW then return end
    s[field] = s.now
    if s.lit then
        s.charge = math.min(FULL, s.charge + SEGMENT)
        show_meter(self, fighter)
    else
        s.charge = s.charge + SEGMENT
        if s.charge >= FULL then trigger(self, fighter) else show_meter(self, fighter) end
    end
end

-- Delayed death ends: still charged means the player lives, otherwise the hit finishes them.
local function settle_doom(self, fighter)
    local s = self.state
    s.doom_until = 0
    if not (s.lit and s.charge > 0) then fighter:change_health(-1) end
end

local function draw_aura(self, fighter, view)
    local s = self.state
    if s.aura_phase == 0 then return end
    local sprite = aura_sprite(s.aura_phase, s.aura_tick)
    if not sprite then
        drop_marker()
        s.aura_phase = 0
        return
    end
    s.aura_tick = s.aura_tick + 1
    -- Positions are at the feet, y down: the art is centered on the body.
    local position = view.self.position
    local rect = { x = position.x - SIZE / 2, y = position.y - SIZE, width = SIZE, height = SIZE }
    if marker and sf2.world.is_marker_active(marker) then
        sf2.world.try_set_marker(marker, { rect = rect, sprite = sprite })
    else
        marker = fighter:mark_sprite(sprite, rect)
    end
end

local function burn(self, fighter, view)
    local s = self.state
    s.burn_tick = s.burn_tick + 1
    if s.burn_tick < BURN_EVERY or not view.opponent then return end
    s.burn_tick = 0
    if math.abs(view.opponent.position.x - view.self.position.x) > RANGE then return end
    local base = s.base_damage > 0 and s.base_damage / 1000000 or DEFAULT_BASE
    fighter.opponent:change_health(-BURN_FRACTION * base * BURN_EVERY / 60)
end

local fields = {
    now = 0, charge = 0, lit = false, aura_phase = 0, aura_tick = 0, burn_tick = 0,
    base_damage = 0, doom_until = 0,
}
for _, kind in ipairs(kinds) do fields["last_" .. kind] = -WINDOW end

local behavior = {
    state = { lifetime = "round", fields = fields },
    on_round_begin = function(self, fighter)
        drop_marker()
        show_meter(self, fighter)
    end,
    on_round_end = function(_, fighter)
        drop_marker()
        fighter:clear_meter(METER_KEY)
    end,
    on_tick = function(self, fighter, event)
        local s = self.state
        s.now = event.frame
        local view = fighter:snapshot()
        if not view or not view.round_active then return end
        -- Dodging through an attack: i-frames while the enemy's attack window is open and near.
        if view.opponent and has_interval(view.self.animation, "invulnerable")
            and has_interval(view.opponent.animation, "attack")
            and math.abs(view.opponent.position.x - view.self.position.x) <= DODGE_REACH then
            use(self, fighter, "dodge")
        end
        if s.doom_until > 0 and s.now >= s.doom_until then settle_doom(self, fighter) end
        if s.lit then
            s.charge = s.charge - event.delta_frames
            if s.charge <= 0 then end_aura(self, fighter) else burn(self, fighter, view) end
            show_meter(self, fighter)
        end
        draw_aura(self, fighter, view)
    end,
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or event.blocked then return end
        local s = self.state
        if event.weapon and not event.critical and event.damage > 0 then
            -- Running average of plain weapon hits stands in for weapon base damage.
            local damage = math.floor(event.damage * 1000000)
            s.base_damage = s.base_damage == 0 and damage or math.floor((s.base_damage * 7 + damage) / 8)
        end
        if event.ranged then
            use(self, fighter, "ranged")
        elseif event.magic then
            use(self, fighter, "magic")
        elseif fighter:animation_is("Throw") then
            use(self, fighter, "throw")
        elseif fighter:animation_is("Kick") then
            -- No hit-zone in the event: judge the head by the contact height above the enemy's feet.
            local view, attack = fighter:snapshot(), event.attack
            if view and view.opponent and attack and view.opponent.position.y - attack.point.y >= HEAD_HEIGHT then
                use(self, fighter, "kick")
            end
        elseif fighter:animation_is("3key") and fighter:animation_is("Weapon") then
            use(self, fighter, "super")
        end
        if event.critical then use(self, fighter, "crit") end
    end,
    on_damage_resolving = function(self, fighter, event)
        local s = self.state
        if s.doom_until > 0 then
            fighter:scale_incoming_damage(0)    -- alive through the grace period
            return
        end
        if not s.lit or s.charge < DOOM_MIN_CHARGE or event.damage <= 0 then return end
        local view = fighter:snapshot()
        if view and event.damage >= view.self.health then
            fighter:scale_incoming_damage(math.max(0, (view.self.health - LEAVE) / event.damage))
            s.doom_until = s.now + DOOM_FRAMES
        end
    end,
}

return sf2.perks.register {
    id = "searing_luminary",
    display_name = words.own("special.searing_luminary.name", "special.searing_luminary.name"),
    description = words.own("special.searing_luminary.description", "special.searing_luminary.description"),
    -- The game's own Searing Luminary orb (PERK_HEAVEN_SET_BURN, Enchantments.EnchantmentBurn).
    icon = sf2.assets.sprite("core:ui/atlases/enchantments.enchantmentburn"),
    kind = "combo",
    behavior = behavior,
}
