local sf2 = require("sf2")
local words = require("content.text")

-- Authority: Assets/DExml/perks.xml, PERK_MASTER_OF_STYLE / PERK_RELENTLESS;
-- rank payloads: Assets/DExml/CharacterProgress.xml, Progress/Perks.
-- The archive is research input only. This module executes no XML.

local master_icon = sf2.assets.sprite("core:ui/skills/IconMasterOfStyle")
local master_buff = sf2.assets.sprite("core:ui/skills/IconMasterOfStyle_Blue")
local relentless_icon = sf2.assets.sprite("core:ui/skills/IconCrackedApple")
local relentless_buff = sf2.assets.sprite("core:ui/skills/IconCrackedApple_Blue")

local function frame(fighter)
    local snapshot = fighter:snapshot()
    assert(snapshot, "DE combat perks require a combat clock snapshot.")
    return snapshot.frame
end

local function clear_master(self, fighter)
    self.state.expires = 0
    fighter:clear_status_icon("MasterReward")
end

-- Behavior tables are registered under the ID of the perk that first uses them,
-- so each keeps its historical behavior ID ("master_of_style", "relentless").
local master_behavior = {
    parameters = {
        active_frames = 300,
        drain = 0.1,
    },
    state = { lifetime = "round", fields = {
        expires = 0,
    } },
    on_style_changed = function(self, fighter, event)
        -- XML ORs Min=Brutal, Min=Aggressive, Min=Crazy. Brutal is native rank 2.
        -- The archived English text instead says Aggressive; do not change the trigger.
        if event.style_rank >= 2 then
            self.state.expires = frame(fighter) + self.params.active_frames
            fighter:show_status_icon("MasterReward", master_buff, self.params.active_frames)
        end
    end,
    on_hit_post_crit = function(self, fighter, event)
        if self.state.expires <= frame(fighter) then return end
        if (event.target == "self" and not event.blocked) or
            (event.target == "opponent" and (event.ranged or event.magic)) then
            clear_master(self, fighter)
        end
    end,
    on_post_hit = function(self, fighter, event)
        if self.state.expires > frame(fighter) and event.target == "opponent" and
            not event.blocked and (event.weapon or event.unarmed) then
            -- Native Root[Hit.Damage + Drain] is addition in normalized health units.
            fighter:add_outgoing_damage(self.params.drain)
            clear_master(self, fighter)
        end
    end,
    on_tick = function(self, fighter, event)
        if self.state.expires > 0 and event.frame >= self.state.expires then clear_master(self, fighter) end
    end,
    on_round_end = clear_master,
}

local function clear_relentless(self, fighter)
    self.state.expires = 0
    fighter:clear_status_icon("BuffRelentless")
end

local relentless_behavior = {
    parameters = {
        active_time = 300,
        combo_min_count = 3,
        combo_max_count = 15,
        damage_per_stack = 0.01,
    },
    state = { lifetime = "round", fields = {
        combo_count = 0,
        expires = 0,
    } },
    on_round_begin = function(self, fighter)
        self.state.combo_count = 0
        clear_relentless(self, fighter)
    end,
    on_combo_changed = function(self, fighter, event)
        local now = frame(fighter)
        if now >= self.state.expires and event.combo >= self.params.combo_min_count then
            if event.combo == self.params.combo_min_count then
                self.state.combo_count = self.params.combo_min_count
            else
                self.state.combo_count = math.min(self.state.combo_count + 1, self.params.combo_max_count)
            end
        end
        if event.combo == 0 and self.state.combo_count >= self.params.combo_min_count then
            self.state.expires = now + self.params.active_time
            fighter:show_status_icon("BuffRelentless", relentless_buff, self.params.active_time, self.state.combo_count)
        end
    end,
    on_post_hit = function(self, fighter, event)
        if event.target == "opponent" and self.state.expires > frame(fighter) then
            -- XML has no Block/Animation filter: the next outgoing hit consumes it.
            fighter:scale_outgoing_damage(1 + self.params.damage_per_stack * self.state.combo_count)
            clear_relentless(self, fighter)
        end
    end,
    on_tick = function(self, fighter, event)
        if self.state.expires > 0 and event.frame >= self.state.expires then clear_relentless(self, fighter) end
    end,
    on_round_end = clear_relentless,
}

local master_upgrades, relentless_upgrades = {}, {}
for rank = 1, 5 do
    -- The game's description templates with this rank's value filled in.
    master_upgrades[rank] = {
        level = rank,
        description = words.fill("perk.master_of_style.rank_" .. rank, "PERKDESCRIPTION_MASTER_OF_STYLE", rank * 2),
        parameters = { drain = rank * 0.02 },
    }
    relentless_upgrades[rank] = {
        level = rank,
        description = words.fill("perk.relentless.rank_" .. rank, "PERKDESCRIPTION_RELENTLESS", rank),
        parameters = { damage_per_stack = rank * 0.01 },
    }
end

local master = sf2.perks.register {
    id = "master_of_style", behavior = master_behavior,
    display_name = words.own("perk.master_of_style.name", "PERK_MASTER_OF_STYLE"),
    description = master_upgrades[5].description, icon = master_icon,
    upgrades = master_upgrades, initial_upgrade = 1,
}
local relentless = sf2.perks.register {
    id = "relentless", behavior = relentless_behavior,
    display_name = words.own("perk.relentless.name", "PERK_RELENTLESS"),
    description = relentless_upgrades[1].description, icon = relentless_icon,
    upgrades = relentless_upgrades, initial_upgrade = 1,
}

return { master_of_style = master, relentless = relentless }
