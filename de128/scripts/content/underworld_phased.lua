local sf2 = require("sf2")
local widow_teleportation = require("content.widow_teleportation")
local boss_abilities = require("content.boss_abilities")

-- Prototype: Volcano as a phased Eternal. The shield is split into four seals and each
-- seal is one round with its own twist, in a fixed order so the fight can be learned:
--   1 Duel           no twist.
--   2 Scorched earth you burn whenever you go two seconds without landing a hit.
--   3 Molten armour  plain hits do 40% damage; hitting him while he attacks does 160%.
--   4 Eruption       both fighters deal double damage.
-- Breaking a seal wins the round. If the 60-second phase timer runs out the seal holds,
-- Volcano takes the round, and the same phase comes back. He regains one bar of shield
-- at the start of every round (the game's health_recovery), so a failed phase costs
-- ground. Four broken seals win the raid; four rounds lost to him end it.

local SHIELD = 12
local SEAL_SIZE = 3
local SEALS = math.floor(SHIELD / SEAL_SIZE)
local BURN_AFTER = 120      -- frames without landing a hit before the burn starts
local BURN_EVERY = 20       -- frames between burn ticks
local BURN_DAMAGE = 0.006   -- player health per tick (0.018 per second)

local PHASES = {
    { name = "DUEL", hint = "Break the seal." },
    { name = "SCORCHED EARTH", hint = "Keep landing hits or the ground burns you." },
    { name = "MOLTEN ARMOUR", hint = "Hit him while he attacks. Plain hits barely scratch him." },
    { name = "ERUPTION", hint = "Everything hits twice as hard. Finish him." },
}

local function threshold(seal) return SHIELD - SEAL_SIZE * (seal + 1) end

local hud
local function close_hud()
    if hud and sf2.ui.is_open(hud) then sf2.ui.close(hud) end
    hud = nil
end

local function open_hud(seal)
    close_hud()
    local phase = PHASES[seal + 1]
    hud = sf2.ui.open { id = "phased_volcano", mount = "hud",
        placement = { anchor = "top", x = 0, y = 132 },
        root = { kind = "column", width = 520, height = 92, gap = 2,
            style = { background_color = "#140c08c8" }, children = {
                { id = "phase", kind = "text", width = 520, height = 34,
                    text = "SEAL " .. (seal + 1) .. " / " .. SEALS .. "  ·  " .. phase.name,
                    style = { text_color = "#f2c46b", font_size = 22 } },
                { id = "hint", kind = "text", width = 520, height = 26, text = phase.hint,
                    style = { text_color = "#ecd1a1", font_size = 15 } },
                { id = "left", kind = "text", width = 520, height = 26, text = "",
                    style = { text_color = "#ecd1a1", font_size = 15 } },
            } },
    }
end

local controller = {
    state = { lifetime = "fight", fields = {
        seal = { type = "integer", default = 0 },
        requested = { type = "boolean", default = false },
        idle = { type = "integer", default = 0 },
        burn = { type = "integer", default = 0 },
    } },
    on_round_begin = function(self)
        self.state.requested = false
        self.state.idle = 0
        self.state.burn = 0
        open_hud(self.state.seal)
    end,
    on_tick = function(self, fighter, tick)
        local view = fighter:snapshot()
        if not view or not view.round_active or not view.opponent then return end
        local seal = self.state.seal
        local remaining = view.opponent.health - threshold(seal)
        if hud and sf2.ui.is_open(hud) then
            sf2.ui.set_text(hud, "left", seal + 1 < SEALS
                and string.format("Seal holds for %.1f more bars", math.max(0, remaining))
                or string.format("%.1f bars of shield left", math.max(0, view.opponent.health)))
        end
        -- The last seal ends with the shield itself: the knockout wins the round natively.
        if seal + 1 < SEALS and remaining <= 0 and not self.state.requested then
            -- The seal advances in on_round_end: a native result (both down on the same
            -- frame) takes precedence over this request.
            if fighter:end_round("win") then self.state.requested = true end
            return
        end
        if seal == 1 then
            self.state.idle = self.state.idle + tick.delta_frames
            if self.state.idle >= BURN_AFTER then
                self.state.burn = self.state.burn + tick.delta_frames
                if self.state.burn >= BURN_EVERY then
                    self.state.burn = 0
                    fighter:change_health(-BURN_DAMAGE)
                    fighter:set_model_color("#ff8a4a", BURN_EVERY + 2)
                end
            end
        end
    end,
    on_damage_dealt = function(self, _, event)
        if (event.damage or 0) > 0 then
            self.state.idle = 0
            self.state.burn = 0
        end
    end,
    on_damage_dealing = function(self, fighter)
        local seal = self.state.seal
        if seal == 2 then
            local view = fighter:snapshot()
            local attacking = view and view.opponent and view.opponent.animation
                and view.opponent.animation.type == "attack"
            fighter:scale_outgoing_damage(attacking and 1.6 or 0.4)
        elseif seal == 3 then
            fighter:scale_outgoing_damage(2)
        end
    end,
    on_damage_resolving = function(self, fighter)
        if self.state.seal == 3 then fighter:scale_incoming_damage(2) end
    end,
    on_round_end = function(self, fighter)
        close_hud()
        local view = self.state.requested and fighter:snapshot()
        if view and view.self and view.self.health > 0 then self.state.seal = self.state.seal + 1 end
        self.state.requested = false
    end,
    on_fight_end = close_hud,
}

local function install(underworld, raid_charge_rule)
    local text = function(key) return sf2.text.get("uw_phased." .. key) end
    local zone = assert(underworld.zones[1], "Underworld tier 1 is missing")
    local volcano = assert(underworld.templates["Man_Volcano"], "Volcano's template is missing")
    local tactic = widow_teleportation.normal
    local perks = { { perk = sf2.perks.get("core:perks/PERK_TELEPORTATION"), frames = 600 } }
    local pace = boss_abilities.pace_perk_for(tactic)
    if pace then perks[#perks + 1] = pace end
    -- The opponent is written inline; the fight is named "1", so its ID is uw_phased_volcano_1.
    local boss = {
        id = "uw_phased_volcano", fighter = volcano, tactic = tactic,
        health_bars = SHIELD, visible_health_bars = SHIELD,
        attributes = { MagicInitialCharge = 5000, WarriorPower = 51 },
        attribute_alignments = { { factor = 0, shift = 0, priority = 1 }, { factor = 1, shift = -10, priority = 1 } },
        perks = perks,
    }
    sf2.battles.register {
        id = "uw_phased_volcano", page = zone, type = "final", x = -95, y = -115,
        alias = text("alias"), title = text("title"), description = text("description"),
        icon = "vulcan_raid", preview = "preview_raid_base.vulcan_raid",
        location = "core:locations/vulcan_raid", music = sf2.assets.audio("audio/underworld/vulcan"),
        power_mode = "normal",
        fights = {
            {
                name = "1", rounds = SEALS, round_time = 60, opponents = { boss },
                rewards = {
                    [0] = { prize_base = 1 },
                    [1] = { prize_base = 1, experience = 1, gems = 17 },
                },
                rules = {
                    { kind = "perk", perk = sf2.perks.get("core:perks/PERK_ANTI_SHOCK"), target = "opponent" },
                    raid_charge_rule,
                    { kind = "behavior", behavior = controller, target = "player", controls_outcome = true },
                },
            },
        },
    }
end

return { install = install }
