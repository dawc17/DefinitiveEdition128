-- Rules each ability enchantment adds on top of its recharge, by ability key. A module
-- returns a table of callbacks and an optional `state` table of round-lifetime fields.
-- Modules must not require content.boss_abilities at load time (it requires this file).
return {
    earthquake = require("content.special_earthquake"),
    power_field = require("content.special_power_field"),
    war_whirl = require("content.special_war_whirl"),
    teleportation = require("content.special_teleportation"),
    rat_wave = require("content.special_rat_wave"),
    assistants = require("content.special_assistants"),
}
