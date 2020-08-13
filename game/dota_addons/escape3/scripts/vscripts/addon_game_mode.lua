-- This is the entry-point to your game mode and should be used primarily to precache models/particles/sounds/etc

-- Creating a global gamemode class variable;
if barebones == nil then
	_G.barebones = class({})
else
	DebugPrint("[BAREBONES] barebones class name is already in use, change the name if this is the first time you launch the game!")
	DebugPrint("[BAREBONES] If this is not your first time, you probably used script_reload in console.")
end

require('webapi')
require('util')
require('libraries/timers')                      -- Core lua library
require('libraries/player_resource')             -- Core lua library
require('libraries/notifications')               -- Core lua library
require('gamemode')                              -- Core barebones file

function Precache(context)
--[[
  This function is used to precache resources/units/items/abilities that will be needed
  for sure in your game and that will not be precached by hero selection.  When a hero
  is selected from the hero selection screen, the game will precache that hero's assets,
  any equipped cosmetics, and perform the data-driven precaching defined in that hero's
  precache{} block, as well as the precache{} block for any equipped abilities.

  See GameMode:PostLoadPrecache() in gamemode.lua for more information
  ]]

	DebugPrint("[BAREBONES] Performing pre-load precache")

	-- Particles can be precached individually or by folder
	-- It it likely that precaching a single particle system will precache all of its children, but this may not be guaranteed
  PrecacheResource("particle", "particles/econ/generic/generic_aoe_explosion_sphere_1/generic_aoe_explosion_sphere_1.vpcf", context)
  PrecacheResource("particle", "particles/econ/items/kunkka/divine_anchor/hero_kunkka_dafx_skills/kunkka_spell_x_spot_mark_fxset.vpcf", context)
  PrecacheResource("particle", "particles/units/heroes/hero_omniknight/omniknight_purification.vpcf", context)
  PrecacheResource("particle", "particles/items3_fx/mango_active.vpcf", context)
  PrecacheResource("particle", "particles/units/heroes/hero_lina/lina_spell_light_strike_array.vpcf", context)
  PrecacheResource("particle", "particles/addons_gameplay/pit_lava_sparks.vpcf", context)
  PrecacheResource("particle", "particles/units/heroes/hero_dark_seer/dark_seer_surge.vpcf", context)
  PrecacheResource("particle", "particles/units/heroes/hero_dark_seer/dark_seer_loadout_surge_rope.vpcf", context)
  PrecacheResource("particle_folder", "particles/misc", context)
  PrecacheResource("particle_folder", "particles/beacons", context)

	-- Models can also be precached by folder or individually
	-- PrecacheModel should generally used over PrecacheResource for individual models
  --PrecacheResource("model_folder", "particles/heroes/antimage", context)
  PrecacheModel("models/heroes/undying/undying.vmdl", context)
  PrecacheModel("models/heroes/undying/undying_minion.vmdl", context)
  PrecacheModel("models/props_gameplay/mango.vmdl", context)
  PrecacheModel("models/heroes/undying/undying_flesh_golem.vmdl", context)
  PrecacheModel("models/heroes/undying/undying_minion_torso.vmdl", context)

  PrecacheModel("models/items/undying/flesh_golem/frostivus_2018_undying_accursed_draugr_golem/frostivus_2018_undying_accursed_draugr_golem.vmdl", context)
  PrecacheModel("models/heroes/techies/techies.vmdl", context)

	-- Sounds can precached here like anything else
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_omniknight.vsndevts", context)
  
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pudge.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_techies.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_slark.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lina.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_magnataur.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dark_seer.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tiny.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_ui_imported.vsndevts", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
	-- Entire items can be precached by name
	-- Abilities can also be precached in this way despite the name
  PrecacheItemByNameSync("item_mango_custom", context)
  PrecacheItemByNameSync("item_cheese_custom", context)

  PrecacheItemByNameSync("item_patreon_chest", context)
  PrecacheItemByNameSync("item_patreon_get_cheese1", context)
  PrecacheItemByNameSync("item_patreon_get_cheese2", context)
  PrecacheItemByNameSync("item_patreon_larger_x", context)
  PrecacheItemByNameSync("item_patreon_wind_lace", context)
  PrecacheItemByNameSync("item_patreon_phoenix_ash", context)
  PrecacheItemByNameSync("item_patreon_phase", context)

  PrecacheItemByNameSync("pudge_meat_hook_custom", context)
  PrecacheItemByNameSync("techies_suicide_custom", context)
  PrecacheItemByNameSync("slark_pounce_custom", context)
  PrecacheItemByNameSync("dark_seer_surge_custom", context)
  PrecacheItemByNameSync("magnataur_skewer_custom", context)
  PrecacheItemByNameSync("void_spirit_dissimilate_custom", context)
  PrecacheItemByNameSync("void_spirit_astral_step_custom", context)

	-- Entire heroes (sound effects/voice/models/particles) can be precached with PrecacheUnitByNameSync
	-- Custom units from npc_units_custom.txt can also have all of their abilities and precache{} blocks precached in this way
  PrecacheUnitByNameSync("npc_dummy_unit", context)
  PrecacheUnitByNameSync("npc_creep_patrol", context)
  PrecacheUnitByNameSync("npc_gate", context)  
  PrecacheUnitByNameSync("npc_carty", context)  
  PrecacheUnitByNameSync("npc_creep_patrol_torso", context)  
  PrecacheUnitByNameSync("npc_creep_patrol_no_turn", context)  
  PrecacheUnitByNameSync("npc_creep_patrol_no_turn", context)  

  PrecacheUnitByNameSync("npc_zombie_static", context)  
  PrecacheUnitByNameSync("npc_techies", context)  
  PrecacheUnitByNameSync("npc_magnus", context)  
  PrecacheUnitByNameSync("npc_void_spirit", context)  
end

-- Create the game mode when we activate
function Activate()
	DebugPrint("[BAREBONES] Activating ...")
	print("Your custom game is activating.")
	barebones:InitGameMode()
end
