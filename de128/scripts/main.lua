local sf2 = require("sf2")

assert(type(sf2.game) == "table" and type(sf2.game.disable) == "function",
    "DE128 requires the public sf2.game.disable API.")
assert(type(sf2.game.timers) == "function",
    "DE128 requires the public sf2.game.timers API.")

-- Module order is explicit. Eclipse commits these declarations together.
require("content.map_buttons")
require("content.menu_art")
require("content.services")
require("content.timers")
require("content.forge")
require("content.shocking_strike")
require("content.hex_shield")
require("content.equipment")
require("content.combat_equipment")
-- Rifle and Musket Super Slash recharge for 3 seconds; the Musket ball flies faster.
require("content.rifle_musket")
require("content.chinese_swords")
require("content.restored_weapons")
require("content.sphere1")
require("content.sphere2")
require("content.sphere3")
require("content.combo_sphere3")
require("content.mind_throw")
require("content.restored_equipment")
require("content.shared_moves")
require("content.unarmed_moves")
require("content.shadow_cloak")
require("content.wasp_fly")
require("content.butcher_earthquake")
require("content.hermit_storm")
require("content.war_whirl")
require("content.gatekeeper_power_field")
require("content.cronos_power_field")
require("content.blackness_grasp")
require("content.saturn_blaster")
require("content.dandy_lightning_chain")
require("content.shop")
require("content.underworld_equipment")
require("content.titan_reward_equipment")
-- Ranged throws recharge for 4 s and a ranged hit silences the opponent's magic for 5 s.
require("content.ranged_recharge")
require("content.rewards")
require("content.progression")
require("content.campaign_music")
require("content.map_positions")
-- Owner stages.xml (2026-11) deltas for core battles.
require("content.stages_2026_11")
require("content.dojo_changer")
-- After the story Titan: a dojo button to change the player's portrait.
require("content.avatar_changer")
-- Options > Mod settings: bladed weapons can use the old knife swing sounds.
require("content.old_knife_sounds")
-- Options > Mod settings: story fights can use the Special Edition locations.
require("content.se_locations")
-- Owner battle previews (2026-11) for single fights that share a stage picture.
require("content.battle_previews")
-- Per-save difficulty: Easy, Medium (DE128 as designed), Hard and Very Hard.
require("content.difficulty")
-- Sensei story: guard templates and RaidCharge availability are synthesized from
-- archive evidence (see sensei_guard_templates.lua, sensei_raid_charge_state.lua).
require("content.sensei_story").install_default()
-- Underworld: all eight archived tiers, sharing the story's RaidCharge rule, plus
-- the archived intro (after Lynx 2), toggle gating and the 32 bosses' dialogues.
local raid_charge = require("content.sensei_raid_charge").register(require("content.sensei_raid_charge_state").create())
local underworld = require("content.underworld").install(raid_charge)
-- Prototype: Volcano rebuilt as a phased Eternal (four seals, one twist each).
require("content.underworld_phased").install(underworld, raid_charge)
require("content.underworld_story").install(underworld)
-- Challengers: seven post-Titan duels whose first win grants the opponent's weapon.
require("content.challengers").install(raid_charge)
-- Deterministic forge: choose-mode recipes; reads the bosses registered above.
require("content.forge_choice").install(underworld)
-- Disabled at the owner's request. Keep the prototype out of the active mod.
-- require("content.ascension")

sf2.log.info("DE128 " .. sf2.mod.version .. " registered.")
