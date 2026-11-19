local sf2 = require("sf2")
local chain = require("content.lightning_chain")

-- Lightning Chain's rules on top of its recharge (content.lightning_chain has the plan, the
-- numbers and the bolts): every landed hit charges the enemy, 6 charges call a lightning strike
-- that knocks it down, and a row that connects starts Raiden mode.
local TUNING = chain.tuning
local CAST = "de128:moves/lightning_chain_player"

local charge_roll = sf2.random.stream("de128", "lightning_chain_charge")
local spot_roll = sf2.random.stream("de128", "lightning_chain_spots")
local raiden_icon = sf2.assets.sprite("core:ui/skills/IconLightning_Blue")

-- The new strike child is placed by its centre; this is the bolt clip's centre height (the
-- average of its four nodes), where Hermit's bolt would be, whatever height the player is at.
local BOLT_Y = -424

-- Charge art (Seby, 2026-11-19): ten frames of one small discharge, looped at a random spot on
-- the enemy's body, one per charge. The frames differ in size (pixels below) and are drawn at
-- SCALE units a pixel, about 47 units across at the largest. Each starts at its own frame.
local STEP = 3                              -- ticks per art frame
local SCALE = 0.1
local SIZES = { { 166, 172 }, { 196, 200 }, { 328, 338 }, { 422, 408 }, { 448, 450 },
    { 460, 472 }, { 472, 494 }, { 452, 464 }, { 394, 402 }, { 344, 304 } }
local FRAMES = {}
for index = 1, #SIZES do
    FRAMES[index] = sf2.assets.sprite(string.format("sprites/lightning_charge/magic_lightning_discharge_%02d", index))
end
-- Body points a charge can sit on, one charge each, a few units off the point.
local SPOTS = { "head", "neck", "chest", "stomach", "pelvis", "left_shoulder", "right_shoulder",
    "left_elbow", "right_elbow", "left_hip", "right_hip", "left_knee", "right_knee" }
local SPREAD = 10

local METER_KEY = "lightning_charge"
local METER_COLOR = "#8FD8FF"

-- The charges on show, oldest first: { node, x, y, tick, frame, marker }. Art only, so the
-- marker handles live here, not in saved state. Only the player wears the enchantment.
local marks = {}

local function drop_marks(count)
    for _ = 1, math.min(count, #marks) do
        local mark = table.remove(marks, 1)
        if mark.marker then sf2.world.remove_marker(mark.marker) end
    end
end

local function free_spot()
    local free = {}
    for _, name in ipairs(SPOTS) do
        local taken = false
        for _, mark in ipairs(marks) do taken = taken or mark.node == name end
        if not taken then free[#free + 1] = name end
    end
    return spot_roll:pick(free)
end

-- A frame's rectangle, centred on the mark's spot (measured from its node).
local function frame_rect(mark, frame)
    local width, height = SIZES[frame][1] * SCALE, SIZES[frame][2] * SCALE
    return { x = mark.x - width / 2, y = mark.y - height / 2, width = width, height = height }
end

-- Shows `count` charges on the enemy and moves each one's discharge on a frame.
local function draw_marks(fighter, count)
    drop_marks(#marks - count)
    while #marks < count do
        marks[#marks + 1] = { node = free_spot(), x = spot_roll:integer(-SPREAD, SPREAD),
            y = spot_roll:integer(-SPREAD, SPREAD), tick = spot_roll:integer(0, #FRAMES * STEP - 1), frame = 0 }
    end
    for _, mark in ipairs(marks) do
        mark.tick = mark.tick + 1
        local frame = math.floor(mark.tick / STEP) % #FRAMES + 1
        if not mark.marker then
            local rect = frame_rect(mark, frame)
            rect.node, rect.of = mark.node, "enemy"
            mark.marker = fighter:mark_sprite(FRAMES[frame], rect)
            mark.frame = frame
        elseif frame ~= mark.frame then
            mark.frame = frame
            -- A closed marker (the round is over) is made again on the next tick.
            if not sf2.world.try_set_marker(mark.marker, { rect = frame_rect(mark, frame), sprite = FRAMES[frame] }) then
                mark.marker = nil
            end
        end
    end
end

local function show_charge(self, fighter)
    local shown = math.min(self.state.charge, TUNING.strike_cost)
    if shown == self.state.shown then return end
    self.state.shown = shown
    fighter:set_meter(METER_KEY, { value = shown / TUNING.strike_cost, segments = TUNING.strike_cost,
        color = METER_COLOR, label = shown .. "/" .. TUNING.strike_cost })
end

local function add_charge(self)
    local s = self.state
    local range = s.now < s.raiden_until and TUNING.raiden_charge_per_hit or TUNING.charge_per_hit
    s.charge = s.charge + charge_roll:integer(range[1], range[2])
end

-- Spawn offsets are from the player's centre along the arena's axes, at most 1000 each way.
local function clamp(offset)
    return math.max(-1000, math.min(1000, offset))
end

local function strike(self, fighter, view)
    local s = self.state
    s.next_strike = s.now + TUNING.strike_gap
    local receipt = fighter:spawn_projectile(chain.strike, clamp(view.opponent.position.x - view.self.position.x),
        clamp(BOLT_Y - view.self.position.y))
    if receipt.status == "failed" then
        sf2.log.warn("Lightning Chain strike: " .. tostring(receipt.error))
        return
    end
    s.charge = s.charge - TUNING.strike_cost
    drop_marks(TUNING.strike_cost)
end

local function is_row(source)
    return source:sub(1, #chain.row_move) == chain.row_move
end

return {
    state = { now = 0, charge = 0, shown = -1, next_strike = 0, raiden_until = 0, row_charged = true },

    on_round_begin = function()
        drop_marks(#marks)
    end,

    on_round_end = function(_, fighter)
        drop_marks(#marks)
        fighter:clear_meter(METER_KEY)
    end,

    -- A new cast may charge the enemy once more.
    on_animation_start = function(self, fighter, event)
        if event.target == "self" and event.animation_name == CAST then self.state.row_charged = false end
    end,

    on_tick = function(self, fighter, event)
        local s = self.state
        s.now = event.frame
        local view = fighter:snapshot()
        if not view or not view.round_active then return end
        if s.charge >= TUNING.strike_cost and s.now >= s.next_strike and view.opponent then
            strike(self, fighter, view)
        end
        show_charge(self, fighter)
        draw_marks(fighter, math.min(s.charge, TUNING.strike_cost))
    end,

    -- Every landed hit charges the enemy, except the strike's. The row charges once, like one
    -- hit, on its first bolt to connect, and that hit starts Raiden mode.
    on_post_hit = function(self, fighter, event)
        if event.target ~= "opponent" or event.blocked then return end
        local s = self.state
        local source = event.attack and event.attack.animation_name or ""
        if source == chain.strike_move then return end
        if is_row(source) then
            if s.row_charged then return end
            s.row_charged = true
            add_charge(self)
            s.raiden_until = s.now + TUNING.raiden_frames
            fighter:show_status_icon("raiden", raiden_icon, TUNING.raiden_frames)
            return
        end
        add_charge(self)
    end,
}
