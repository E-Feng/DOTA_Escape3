-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode
BAREBONES_VERSION = "2.0.9"

-- Selection library (by Noya) provides player selection inspection and management from server lua
require('libraries/selection')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')
-- filters.lua
require('filters')

require('core_mechanics')
require('unit_mechanics')
require('items')
require('abilities')
require('triggers')

--[[
  This function should be used to set up Async precache calls at the beginning of the gameplay.

  In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
  after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
  be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will 
  precache the precache{} block statement of the unit and all precache{} block statements for every Ability# 
  defined on the unit.

  This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
  time, you can call the functions individually (for example if you want to precache units in a new wave of
  holdout).

  This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function barebones:PostLoadPrecache()
	DebugPrint("[BAREBONES] Performing Post-Load precache.")
	--PrecacheItemByNameAsync("item_example_item", function(...) end)
	--PrecacheItemByNameAsync("example_ability", function(...) end)

	--PrecacheUnitByNameAsync("npc_dota_hero_viper", function(...) end)
	--PrecacheUnitByNameAsync("npc_dota_hero_enigma", function(...) end)
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function barebones:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game.")
  
  -- Force Random a hero for every play that didnt pick a hero when time runs out
  local delay = HERO_SELECTION_TIME + HERO_SELECTION_PENALTY_TIME + STRATEGY_TIME - 0.1
  if ENABLE_BANNING_PHASE then
    delay = delay + BANNING_PHASE_TIME
  end
  Timers:CreateTimer(delay, function()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
      if PlayerResource:IsValidPlayerID(playerID) then
        -- If this player still hasn't picked a hero, random one
        -- PlayerResource:IsConnected(index) is custom-made; can be found in 'player_resource.lua' library
        if not PlayerResource:HasSelectedHero(playerID) and PlayerResource:IsConnected(playerID) and (not PlayerResource:IsBroadcaster(playerID)) then
          PlayerResource:GetPlayer(playerID):MakeRandomHeroSelection() -- this will cause an error if player is disconnected
          PlayerResource:SetHasRandomed(playerID)
          PlayerResource:SetCanRepick(playerID, false)
          DebugPrint("[BAREBONES] Randomed a hero for a player number "..playerID)
        end
      end
    end
  end)
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function barebones:OnGameInProgress()
	DebugPrint("[BAREBONES] The game has officially begun.")

	-- Sets it to be nighttime, cycle disabled so 24/7 night
	GameRules:SetTimeOfDay(4)

	-- Constant running thinker to revive players
	Timers:CreateTimer(function()
		barebones:ReviveThinker()
		return 0.1
	end)

		-- Starts the thinker to check if everyones dead and to revive
	Timers:CreateTimer(4, function()
		if GameRules.Ongoing then
			barebones:CheckpointThinker()
			return 2
		end
	end)   

	-- Setting up gamescore data collection
	WebApi:InitGameScore()
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function barebones:InitGameMode()
	DebugPrint("[BAREBONES] Starting to load Game Rules.")
	-- Grabbing data from DB first thing
	Timers:CreateTimer(0.1, function()
		print("LEADERBOARD: Running function initially")
		WebApi:GetLeaderboard()
		--GameRules:BotPopulate()
	end)

	local attempts = 0
	local MAX_ATTEMPTS = 5

	Timers:CreateTimer(0.2, function()
		print("PATREONS: Running function initially")
		if not WebApi.patreonsLoaded and attempts < MAX_ATTEMPTS then
			WebApi:GetPatreons()
		else
			return
		end
		attempts = attempts + 1
		return 10
	end)

	-- Setup rules
	GameRules:SetSameHeroSelectionEnabled(ALLOW_SAME_HERO_SELECTION)
	GameRules:SetUseUniversalShopMode(UNIVERSAL_SHOP_MODE)
	GameRules:SetHeroRespawnEnabled(ENABLE_HERO_RESPAWN)

	GameRules:SetHeroSelectionTime(HERO_SELECTION_TIME) --THIS IS IGNORED when "EnablePickRules" is "1" in 'addoninfo.txt' !
	GameRules:SetHeroSelectPenaltyTime(HERO_SELECTION_PENALTY_TIME)
	
	GameRules:SetPreGameTime(PRE_GAME_TIME)
	GameRules:SetPostGameTime(POST_GAME_TIME)
	GameRules:SetShowcaseTime(SHOWCASE_TIME)
	GameRules:SetStrategyTime(STRATEGY_TIME)

	GameRules:SetTreeRegrowTime(TREE_REGROW_TIME)

	GameRules:SetCustomGameEndDelay(10)

	if USE_CUSTOM_HERO_LEVELS then
		GameRules:SetUseCustomHeroXPValues(true)
	end

	--GameRules:SetGoldPerTick(GOLD_PER_TICK) -- Doesn't work 24.2.2020
	--GameRules:SetGoldTickTime(GOLD_TICK_TIME) -- Doesn't work 24.2.2020
	GameRules:SetStartingGold(NORMAL_START_GOLD)

	if USE_CUSTOM_HERO_GOLD_BOUNTY then
		GameRules:SetUseBaseGoldBountyOnHeroes(false) -- if true Heroes will use their default base gold bounty which is similar to creep gold bounty, rather than DOTA specific formulas
	end

	GameRules:SetHeroMinimapIconScale(MINIMAP_ICON_SIZE)
	GameRules:SetCreepMinimapIconScale(MINIMAP_CREEP_ICON_SIZE)
	GameRules:SetRuneMinimapIconScale(MINIMAP_RUNE_ICON_SIZE)
	GameRules:SetFirstBloodActive(ENABLE_FIRST_BLOOD)
	GameRules:SetHideKillMessageHeaders(HIDE_KILL_BANNERS)
	GameRules:LockCustomGameSetupTeamAssignment(LOCK_TEAMS)

	-- This is multi-team configuration stuff
	if USE_AUTOMATIC_PLAYERS_PER_TEAM then
		local num = math.floor(10/MAX_NUMBER_OF_TEAMS)
		local count = 0
		for team,number in pairs(TEAM_COLORS) do
			if count >= MAX_NUMBER_OF_TEAMS then
				GameRules:SetCustomGameTeamMaxPlayers(team, 0)
			else
				GameRules:SetCustomGameTeamMaxPlayers(team, num)
			end
			count = count + 1
		end
	else
		local count = 0
		for team,number in pairs(CUSTOM_TEAM_PLAYER_COUNT) do
			if count >= MAX_NUMBER_OF_TEAMS then
				GameRules:SetCustomGameTeamMaxPlayers(team, 0)
			else
				GameRules:SetCustomGameTeamMaxPlayers(team, number)
			end
			count = count + 1
		end
	end

	if USE_CUSTOM_TEAM_COLORS then
		for team,color in pairs(TEAM_COLORS) do
			SetTeamCustomHealthbarColor(team, color[1], color[2], color[3])
		end
	end

	DebugPrint("[BAREBONES] Done with setting Game Rules.")

	-- Event Hooks / Listeners
	ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(barebones, 'OnPlayerLevelUp'), self)
	ListenToGameEvent('dota_player_learned_ability', Dynamic_Wrap(barebones, 'OnPlayerLearnedAbility'), self)
	ListenToGameEvent('entity_killed', Dynamic_Wrap(barebones, 'OnEntityKilled'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(barebones, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(barebones, 'OnDisconnect'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(barebones, 'OnItemPickedUp'), self)
	ListenToGameEvent('last_hit', Dynamic_Wrap(barebones, 'OnLastHit'), self)
	ListenToGameEvent('dota_rune_activated_server', Dynamic_Wrap(barebones, 'OnRuneActivated'), self)
	ListenToGameEvent('tree_cut', Dynamic_Wrap(barebones, 'OnTreeCut'), self)

	ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(barebones, 'OnAbilityUsed'), self)
	ListenToGameEvent('dota_non_player_used_ability', Dynamic_Wrap(barebones, 'OnAbilityUsed'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(barebones, 'OnGameRulesStateChange'), self)
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(barebones, 'OnNPCSpawned'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(barebones, 'OnPlayerPickHero'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(barebones, 'OnPlayerReconnect'), self)
	ListenToGameEvent("player_chat", Dynamic_Wrap(barebones, 'OnPlayerChat'), self)

	ListenToGameEvent("dota_tower_kill", Dynamic_Wrap(barebones, 'OnTowerKill'), self)
	ListenToGameEvent("dota_player_selected_custom_team", Dynamic_Wrap(barebones, 'OnPlayerSelectedCustomTeam'), self)
	ListenToGameEvent("dota_npc_goal_reached", Dynamic_Wrap(barebones, 'OnNPCGoalReached'), self)


	-- Change random seed for math.random function
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))

	DebugPrint("[BAREBONES] Setting filters.")

	local gamemode = GameRules:GetGameModeEntity()

	-- Setting the Order filter 
	gamemode:SetExecuteOrderFilter(Dynamic_Wrap(barebones, "OrderFilter"), self)

	-- Setting the Damage filter
	gamemode:SetDamageFilter(Dynamic_Wrap(barebones, "DamageFilter"), self)

	-- Setting the Modifier filter
	gamemode:SetModifierGainedFilter(Dynamic_Wrap(barebones, "ModifierFilter"), self)

	-- Setting the Experience filter
	gamemode:SetModifyExperienceFilter(Dynamic_Wrap(barebones, "ExperienceFilter"), self)

	-- Setting the Tracking Projectile filter
	gamemode:SetTrackingProjectileFilter(Dynamic_Wrap(barebones, "ProjectileFilter"), self)

	-- Setting the rune spawn filter
	gamemode:SetRuneSpawnFilter(Dynamic_Wrap(barebones, "RuneSpawnFilter"), self)

	-- Setting the bounty rune pickup filter
	gamemode:SetBountyRunePickupFilter(Dynamic_Wrap(barebones, "BountyRuneFilter"), self)

	-- Setting the Healing filter
	gamemode:SetHealingFilter(Dynamic_Wrap(barebones, "HealingFilter"), self)

	-- Setting the Gold Filter
	gamemode:SetModifyGoldFilter(Dynamic_Wrap(barebones, "GoldFilter"), self)

	-- Setting the Inventory filter
	gamemode:SetItemAddedToInventoryFilter(Dynamic_Wrap(barebones, "InventoryFilter"), self)

	DebugPrint("[BAREBONES] Done with setting Filters.")

	-- Global Lua Modifiers
	LinkLuaModifier("modifier_custom_invulnerable", "modifiers/modifier_custom_invulnerable", LUA_MODIFIER_MOTION_NONE)

	print("[BAREBONES] initialized.")
	DebugPrint("[BAREBONES] Done loading the game mode!\n\n")
	
	-- Increase/decrease maximum item limit per hero
	Convars:SetInt('dota_max_physical_items_purchase_limit', 64)


	-- Setting up the game, variables and tables
  Players = {}
  Extras = {}
  MultVector = {}
	Linked = {}
	_G.Cheeses = {}

	Vote = {}
	votesNeeded = 6
	GameRules.Ongoing = true
	GameRules.VoteOngoing = false

	_G.patreonUsed = false

  GameRules.Lives = 6
  GameRules.CLevel = 0
	GameRules.Checkpoint = Vector(0, 0, 0)

	SpellList = {"techies_suicide_custom", 
							 "void_spirit_astral_step_custom",
							 "void_spirit_resonant_pulse_custom",
							}

  DOTA_TEAM_ZOMBIES = DOTA_TEAM_BADGUYS

  TeamColors = {}
  TeamColors[0] = {61, 210, 150} -- Teal
  TeamColors[1] = {243, 201, 9}  -- Yellow
  TeamColors[2] = {197, 77, 168} -- Pink
  TeamColors[3] = {255, 108, 0}  -- Orange
  TeamColors[4] = {52, 85, 255}  -- Blue
  TeamColors[5] = {101, 212, 19} -- Green
  TeamColors[6] = {129, 83, 54}  -- Brown
  TeamColors[7] = {77, 0, 1}     -- Dred (Dark Red)
  TeamColors[8] = {199, 228, 13} -- Olive
  TeamColors[9] = {140, 42, 244} -- Purple

  BeaconPart = {}
  BeaconPart[0] = "particles/beacons/kunkka_x_marks_teal.vpcf"
  BeaconPart[1] = "particles/beacons/kunkka_x_marks_yellow.vpcf" 
  BeaconPart[2] = "particles/beacons/kunkka_x_marks_pink.vpcf" 
  BeaconPart[3] = "particles/beacons/kunkka_x_marks_orange.vpcf" 
  BeaconPart[4] = "particles/beacons/kunkka_x_marks_blue.vpcf" 
  BeaconPart[5] = "particles/beacons/kunkka_x_marks_green.vpcf" 
  BeaconPart[6] = "particles/beacons/kunkka_x_marks_brown.vpcf" 
  BeaconPart[7] = "particles/beacons/kunkka_x_marks_dred.vpcf" 
  BeaconPart[8] = "particles/beacons/kunkka_x_marks_olive.vpcf" 
  BeaconPart[9] = "particles/beacons/kunkka_x_marks_purple.vpcf" 

  -- Table for multiple patrol creeps {"waypoint1", "waypoint2", "etc"}
  MultPatrol = {
                 {"p1_1_1a",  "p1_1_1b"}, -- 1
                 {"p1_2_1a",  "p1_2_1b"},
                 {"p1_2_2a",  "p1_2_2b"},
                 {"p1_2_3a",  "p1_2_3b"},
                 {"p1_2_4a",  "p1_2_4b"}, -- 5
                 {"p1_2_5a",  "p1_2_5b"}, 
                 {"p1_2_6a",  "p1_2_6b"},
                 {"p1_2_7a",  "p1_2_7b"},
                 {"p1_2_8a",  "p1_2_8b"},
                 {"p1_2_9a",  "p1_2_9b"}, -- 10
                 {"p1_2_10a", "p1_2_10b"},
                 {"p1_3_1a",  "p1_3_1b"},
                 {"p1_4_1a",  "p1_4_1b"},
                 {"p1_4_2a",  "p1_4_2b"},
                 {"p1_4_3a",  "p1_4_3b"}, -- 15
                 {"p1_4_4a",  "p1_4_4b"},
                 {"p1_4_5a",  "p1_4_5b"},
                 {"p1_4_6a",  "p1_4_6b"},
								 {"p1_4_7a",  "p1_4_7b"},
								 {"p1_5_1a",  "p1_5_1b"}, -- 20
                 {"p1_5_2a",  "p1_5_2b"},
                 {"p1_5_3a",  "p1_5_3b"}, 
                 {"p1_5_4a",  "p1_5_4b"},
                 {"p1_5_5a",  "p1_5_5b"},
                 {"p1_5_6a",  "p1_5_6b"}, -- 25
                 {"p1_5_7a",  "p1_5_7b"},
                 {"p3_1a", "p3_1b"},
								 {"p3_2a", "p3_2b"},
								 {"p3_1_1a", "p3_1_1b"},
								 {"p3_1_2a", "p3_1_2b"}, -- 30
								 {"p3_1_3a", "p3_1_3b"},
								 {"p3_1_4a", "p3_1_4b"},
								 {"p3_1_5a", "p3_1_5b"}, 
								 {"p3_1_6a", "p3_1_6b"},
								 {"p3_3a", "p3_3b"}, -- 35
								 {"p3_3a", "p3_3b"}, -- Removed
								 {"p4_1a", "p4_1b"},
								 {"p4_2a", "p4_2b"},
								 {"p4_3a", "p4_3b"},
								 {"p4_4a", "p4_4b", "p4_4c", "p4_4d"}, -- 40
								 {"p4_5a", "p4_5b", "p4_5c", "p4_5d"},
								 {"p4_6a", "p4_6b"},
								 {"p4_7a", "p4_7b"},
								 {"p5_1a", "p5_1b"},
								 {"p5_2_1a", "p5_2_1b"}, -- 45
								 {"p5_2_2a", "p5_2_2b"}, 
								 {"p5_2_3a", "p5_2_3b"},
								 {"p5_4_1a", "p5_4_1b"}, 
								 {"p5_4_2a", "p5_4_2b"},
								 {"p5_5_1a", "p5_5_1b"}, -- 50
								 {"p5_5_2a", "p5_5_2b"},
								 {"p5_2_4a", "p5_2_4b"}, 
								 {"p5_2_5a", "p5_2_5b"},
								 {"p5_3_1a", "p5_3_1b"},
               }

  -- Table for ent names
  Ents = {
           "item_mango_custom",
           "item_cheese_custom",
           "npc_creep_patrol",
					 "npc_gate",
					 "npc_dummy_unit",
					 "npc_zombie_static",
					 "npc_dummy_mango",
					 "npc_magnus",
         }

	ENT_MANGO = 1; ENT_CHEES = 2; ENT_PATRL = 3;  ENT_GATES = 4; ENT_AOELS = 5; ENT_ZSTAT = 6;
	ENT_UMANG = 7; ENT_MAGNS = 8;

  -- Table for all ents (exc pat creeps) {item/unit/part, ent#, entindex, spawn, function, etc}
  EntList = {
							{ -- Level 1
								{1, ENT_CHEES, 0, "cheese1_1", nil},
                {1, ENT_MANGO, 0, "mango1_1", nil, false},
                {2, ENT_PATRL, 0, "p1_1_1a",  "PatrolInitial", 1,  0.03, 375, 0.5},
                {2, ENT_PATRL, 0, "p1_2_1a",  "PatrolInitial", 2,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_2a",  "PatrolInitial", 3,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_3a",  "PatrolInitial", 4,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_4a",  "PatrolInitial", 5,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_5a",  "PatrolInitial", 6,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_6a",  "PatrolInitial", 7,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_7a",  "PatrolInitial", 8,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_8a",  "PatrolInitial", 9,  0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_9a",  "PatrolInitial", 10, 0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_2_10a", "PatrolInitial", 11, 0.03, 325, 0.5},
                {2, ENT_PATRL, 0, "p1_3_1a", "PatrolInitial",  12, 0.03, 325, 0.5},
                {2, ENT_GATES, 0, "gate1_1a", "GateThinker", "gate1_1b", Vector(0, -1, 0), 1},
                {1, ENT_MANGO, 0, "mango1_2", nil, false},
                {2, ENT_PATRL, 0, "p1_4_1a",  "PatrolInitial", 13,  8.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_4_2b",  "PatrolInitial", 14,  0.03, 451, 0.5},
                {2, ENT_PATRL, 0, "p1_4_3a",  "PatrolInitial", 15,  4.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_4_4a",  "PatrolInitial", 16,  0.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_4_5b",  "PatrolInitial", 17,  0.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_4_6a",  "PatrolInitial", 18,  8.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_4_7b",  "PatrolInitial", 19,  0.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_5_1b",  "PatrolInitial", 20,  0.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_5_2a",  "PatrolInitial", 21,  8.03, 451, 0.5},
                {2, ENT_PATRL, 0, "p1_5_3b",  "PatrolInitial", 22,  0.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_5_4a",  "PatrolInitial", 23,  0.03, 451, 0.5},
                {2, ENT_PATRL, 0, "p1_5_5a",  "PatrolInitial", 24,  8.03, 451, 0.5},
								{2, ENT_PATRL, 0, "p1_5_6b",  "PatrolInitial", 25,  0.03, 451, 0.5},
                {2, ENT_PATRL, 0, "p1_5_7a",  "PatrolInitial", 26,  4.03, 451, 0.5},
                {2, ENT_GATES, 0, "gate1_2a", "GateThinker", "gate1_2b", Vector(1, 0, 0), 1},                
              },
							{ -- Level 2
								{1, ENT_CHEES, 0, "cheese2_1", nil},      
								{2, ENT_AOELS, 0, "lsa2_1", "AOEThinker", 2.5, 0.67, true},  -- Rate, delay
								{2, ENT_AOELS, 0, "lsa2_2", "AOEThinker", 2.2, 0, true},  
								{2, ENT_AOELS, 0, "lsa2_3", "AOEThinker", 2.2, 1.1, true},  
								{2, ENT_AOELS, 0, "lsa2_4", "AOEThinker", 2.5, 0, true},  
								{2, ENT_AOELS, 0, "lsa2_5", "AOEThinker", 2.0, 0, true},  
								{1, ENT_MANGO, 0, "mango2_1", nil, false},
								{2, ENT_GATES, 0, "gate2_1a", "GateThinker", "gate2_1b", Vector(1, 0, 0), 1},
								{2, ENT_ZSTAT, 0, "zstat2_1", "StaticThinker"},         
								{2, ENT_ZSTAT, 0, "zstat2_2", "StaticThinker"},          
								{2, ENT_ZSTAT, 0, "zstat2_3", "StaticThinker"},           
                {2, ENT_UMANG, 0, "mango2_2", "MangoThinker"},
                {2, ENT_UMANG, 0, "mango2_3", "MangoThinker"},
                {2, ENT_UMANG, 0, "mango2_4", "MangoThinker"},
								{2, ENT_UMANG, 0, "mango2_5", "MangoThinker"},  
								{2, ENT_UMANG, 0, "mango2_6", "MangoThinker"},
                {2, ENT_UMANG, 0, "mango2_7", "MangoThinker"},
                {2, ENT_UMANG, 0, "mango2_8", "MangoThinker"},
								{2, ENT_UMANG, 0, "mango2_9", "MangoThinker"},
								{2, ENT_GATES, 0, "gate2_2a", "GateThinker", "gate2_2b", Vector(0, -1, 0), 8},
								{2, ENT_AOELS, 0, "lsa2_2_1", "AOEThinker", 2, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_2", "AOEThinker", 2, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_3", "AOEThinker", 2, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_4", "AOEThinker", 2, 0, false},       
              },
							{ -- Level 3
								{1, ENT_CHEES, 0, "cheese3_1", nil}, 
								{2, ENT_MAGNS, 0, "mag3_1a", "MagnusThinker", "mag3_1b", 2, 0},
								{2, ENT_MAGNS, 0, "mag3_2a", "MagnusThinker", "mag3_2b", 4, 2},
								{2, ENT_PATRL, 0, "p3_1a", "PatrolInitial", 27, 0.03, 400},
								{1, ENT_MANGO, 0, "mango3_1", nil, false},
								{2, ENT_GATES, 0, "gate3_1a", "GateThinker", "gate3_1b", Vector(-1, 0, 0), 1},
								{2, ENT_PATRL, 0, "p3_2a", "PatrolInitial", 28, 0.03, 400, 0.5},
								{2, ENT_PATRL, 0, "p3_1_1a", "PatrolInitial", 29, 0.03, 300, 0.5}, 
								{2, ENT_PATRL, 0, "p3_1_2a", "PatrolInitial", 30, 0.03, 300, 0.5},
								{2, ENT_PATRL, 0, "p3_1_3a", "PatrolInitial", 31, 0.03, 300, 0.5},
								{1, ENT_MANGO, 0, "mango3_2", nil, false},
								{2, ENT_GATES, 0, "gate3_2a", "GateThinker", "gate3_2b", Vector(-1, 0, 0), 2},
								{2, ENT_PATRL, 0, "p3_1_4a", "PatrolInitial", 32, 0.03, 300, 0.5}, 
								{2, ENT_PATRL, 0, "p3_1_5a", "PatrolInitial", 33, 0.03, 300, 0.5},
								{2, ENT_PATRL, 0, "p3_1_6a", "PatrolInitial", 34, 0.03, 300, 0.5},
								{2, ENT_PATRL, 0, "p3_3a", "PatrolInitial", 35, 0.03, 350, 0.25},
								{2, ENT_AOELS, 0, "lsa3_1", "AOEThinker", 4, 0, true},  
								{1, ENT_MANGO, 0, "mango3_3", nil, false},
                {1, ENT_MANGO, 0, "mango3_4", nil, false},
                {1, ENT_MANGO, 0, "mango3_5", nil, false},
                {1, ENT_MANGO, 0, "mango3_6", nil, false},
                {1, ENT_MANGO, 0, "mango3_7", nil, false},
                {1, ENT_MANGO, 0, "mango3_8", nil, false},
                {1, ENT_MANGO, 0, "mango3_9", nil, false},
                {1, ENT_MANGO, 0, "mango3_10", nil, false},
                {1, ENT_MANGO, 0, "mango3_11", nil, false},
                {1, ENT_MANGO, 0, "mango3_12", nil, false},
								{2, ENT_GATES, 0, "gate3_3a", "GateThinker", "gate3_3b", Vector(0, -1, 0), 9},       
              },
							{ -- Level 4 
								{1, ENT_CHEES, 0, "cheese4_1", nil},
								{1, ENT_MANGO, 0, "mango4_1", nil, false},
								{2, ENT_GATES, 0, "gate4_1a", "GateThinker", "gate4_1b", Vector(0, 1, 0), 1},    
								{2, ENT_PATRL, 0, "p4_1a", "PatrolInitial", 37, 0.03, 450, 0.5},
								{2, ENT_PATRL, 0, "p4_2a", "PatrolInitial", 38, 0.03, 400, 0.5},
								{2, ENT_PATRL, 0, "p4_3a", "PatrolInitial", 39, 0.03, 400, 0.5},
								{2, ENT_PATRL, 0, "p4_4a", "PatrolInitial", 40, 0.03, 400, 0.25},
								{2, ENT_PATRL, 0, "p4_5a", "PatrolInitial", 41, 0.03, 495, 0.25},
								{2, ENT_PATRL, 0, "p4_6a", "PatrolInitial", 42, 0.03, 250, 0.5},
								{2, ENT_PATRL, 0, "p4_7a", "PatrolInitial", 43, 0.03, 250, 0.5},
								{2, ENT_AOELS, 0, "lsa4_1", "AOEThinker", 5, 0, true},  
								{2, ENT_AOELS, 0, "lsa4_2", "AOEThinker", 5, 2.5, true},  
              },
							{ -- Level 5
								{2, ENT_PATRL, 0, "p5_1a", "PatrolInitial", 44, 0.03, 500, 0.05},
								{2, ENT_PATRL, 0, "p5_1a", "PatrolInitial", 44, 0.40, 500, 0.05},
								{2, ENT_PATRL, 0, "p5_1a", "PatrolInitial", 44, 0.80, 500, 0.05},
								{2, ENT_PATRL, 0, "p5_1a", "PatrolInitial", 44, 1.20, 500, 0.05},
								{2, ENT_PATRL, 0, "p5_1a", "PatrolInitial", 44, 1.60, 500, 0.05},
								{2, ENT_GATES, 0, "gate5_1a", "GateThinker", "gate5_1b", Vector(-1, 0, 0), 8},
								{1, ENT_MANGO, 0, "mango5_1", nil, true},
                {1, ENT_MANGO, 0, "mango5_2", nil, true},
                {1, ENT_MANGO, 0, "mango5_3", nil, true},
								{1, ENT_MANGO, 0, "mango5_4", nil, true},
								{1, ENT_MANGO, 0, "mango5_5", nil, true},
								{1, ENT_MANGO, 0, "mango5_6", nil, true},
								{1, ENT_MANGO, 0, "mango5_7", nil, true},
								{1, ENT_MANGO, 0, "mango5_8", nil, true},
								{2, ENT_PATRL, 0, "p5_2_1a", "PatrolInitial", 45, 0.03, 625, 0.45},
								{2, ENT_PATRL, 0, "p5_2_2a", "PatrolInitial", 46, 0.03, 625, 0.45},
								{2, ENT_PATRL, 0, "p5_2_3a", "PatrolInitial", 47, 0.03, 625, 0.45},
								{2, ENT_PATRL, 0, "p5_2_4a", "PatrolInitial", 52, 0.03, 625, 0.45},
								{2, ENT_PATRL, 0, "p5_2_5a", "PatrolInitial", 53, 0.03, 625, 0.45},
								{2, ENT_AOELS, 0, "lsa5_1", "AOEThinker", 5.5, 0, true}, 
								{2, ENT_AOELS, 0, "lsa5_2", "AOEThinker", 6, 0, true},   
								{2, ENT_PATRL, 0, "p5_4_1a", "PatrolInitial", 48, 0.03, 300, 0.5},
								{2, ENT_PATRL, 0, "p5_4_2a", "PatrolInitial", 49, 0.03, 300, 0.5},
								{2, ENT_PATRL, 0, "p5_5_1a", "PatrolInitial", 50, 0.03, 300, 0.5},
								{2, ENT_PATRL, 0, "p5_5_2a", "PatrolInitial", 51, 0.03, 300, 0.5},
								{2, ENT_AOELS, 0, "lsa5_3", "AOEThinker", 6, 3, true},   
								{2, ENT_AOELS, 0, "lsa5_4", "AOEThinker", 6, 0, true},  
								{2, ENT_PATRL, 0, "p5_3_1a", "PatrolInitial", 54, 0.03, 400, 0.5},
              },
              { -- Level 6
								{1, ENT_MANGO, 0, "mango6_1", nil, false},
								{1, ENT_MANGO, 0, "mango6_2", nil, false},
                {1, ENT_MANGO, 0, "mango6_3", nil, false},
                {1, ENT_MANGO, 0, "mango6_4", nil, false},
                {1, ENT_MANGO, 0, "mango6_5", nil, false},
                {1, ENT_MANGO, 0, "mango6_6", nil, false},
                {1, ENT_MANGO, 0, "mango6_7", nil, false},
                {1, ENT_MANGO, 0, "mango6_8", nil, false},
                {1, ENT_MANGO, 0, "mango6_9", nil, false},
								{1, ENT_MANGO, 0, "mango6_10", nil, false},
								{1, ENT_MANGO, 0, "mango6_11", nil, false},
								{1, ENT_MANGO, 0, "mango6_12", nil, false},
                {2, ENT_GATES, 0, "gate6_1a", "GateThinker", "gate6_1b", Vector(0, 1, 0), 12},
              }
            }

  -- Table for particles to spawn for each level {partname, ent location, part cp, savekey}
  PartList = {
               { -- Level 1
                 {},
               },
               { -- Level 2
								 {0, "particles/misc/ring1.vpcf", "21pudge_meat_hook_custom", 0},
								 {0, "particles/misc/ring2.vpcf", "00pudge_meat_hook_custom", 0},
               },
               { -- Level 3
							 {0, "particles/misc/ring1.vpcf", "33dark_seer_surge_custom", 0},
							},
							 { -- Level 4
							 	 {},
               },
               { -- Level 5
								 {0, "particles/misc/ring1.vpcf", "52tiny_toss_custom", 0},
								 --{0, "particles/misc/ring1.vpcf", "53pa_phantom_strike_custom", 0},
               },
               { -- Level 6
                 {},
               },
             }

  -- Constants for EntList table and PartList
  ENT_UNTIM = 1; ENT_TYPEN = 2; ENT_INDEX = 3; ENT_SPAWN = 4; ENT_RFUNC = 5;
  PAR_INDEX = 1; PAR_FNAME = 2; PAR_SPAWN = 3; PAR_CTRLP = 4;

	PAT_VECNM = 6; PAT_DELAY = 7; PAT_MVSPD = 8; PAT_TURND = 9;
	MNG_RSPWN = 6;
	GAT_MOVES = 6; GAT_ORIEN = 7; GAT_NUMBR = 8;
	AOE_RATES = 6; AOE_DELAY = 7; AOE_SOUND = 8;
	MAG_GOALS = 6; MAG_RATES = 7; MAG_DELAY = 8;

  -- Table for functions to run for each level
  FuncList = {
            {"ExtraLifeSpawn"},                 -- Level 1
            {"LightStrikeThinker", "TechiesThinker"},       -- Level 2
            {"CartyThinker"},      -- Level 3
            {"RedGreenLightThinker"},              -- Level 4
            {"SetupLevel5"},                 -- Level 5
            {"CircularThinker"},                   -- Level 6
					}

	-- Messages for each level
	_G.MsgList = {
		{},     -- Level 1
		{},     -- Level 2
		{},     -- Level 3
		{"Red Light, Green Light<br/>(Stand still and move when dissimilated)"},     -- Level 4
		{},     -- Level 5
		{},     -- Level 6
	}

  -- Loads the level
	barebones:SetupMap()
end

function barebones:SetupMap()
	DebugPrint("[BAREBONES] Setting up initial map")
  -- Setting up the beginning level (1)
	local level = 1
	if USE_LEVEL_DEBUG then
		level = LEVEL_DEBUG
		GameRules.CLevel = LEVEL_DEBUG
	end

  barebones:InitializeVectors()
	barebones:SetUpLevel(level)

	Timers:CreateTimer(3, function()
		-- Moving creeps for level 1
		barebones:MoveCreeps(level, {})	
	end)
	
	DebugPrint("[BAREBONES] Done setting up map")
end

-- This function turns the "name" table into vector table
function barebones:InitializeVectors()
	DebugPrint("[BAREBONES] Initializing Vectors")
  for i,list in pairs(MultPatrol) do
    MultVector[i] = {}
		for j,entloc in pairs(list) do
			--print("Initializing vector ", j, entloc)
      local pos = Entities:FindByName(nil, entloc):GetAbsOrigin()
      MultVector[i][j] = pos
    end
  end
	DebugPrint("[BAREBONES] Finished Initializing Vectors")
end

-- This function is called as the first player loads and sets up the game mode parameters
function barebones:CaptureGameMode()
	print("CaptureGameMode starting")
	local gamemode = GameRules:GetGameModeEntity()

	-- Set GameMode parameters
	gamemode:SetRecommendedItemsDisabled(RECOMMENDED_BUILDS_DISABLED)
	gamemode:SetCameraDistanceOverride(CAMERA_DISTANCE_OVERRIDE)
	gamemode:SetBuybackEnabled(BUYBACK_ENABLED)
	gamemode:SetCustomBuybackCostEnabled(CUSTOM_BUYBACK_COST_ENABLED)
	gamemode:SetCustomBuybackCooldownEnabled(CUSTOM_BUYBACK_COOLDOWN_ENABLED)
	gamemode:SetTopBarTeamValuesOverride(USE_CUSTOM_TOP_BAR_VALUES)
	gamemode:SetTopBarTeamValuesVisible(TOP_BAR_VISIBLE)

	if USE_CUSTOM_XP_VALUES then
		gamemode:SetUseCustomHeroLevels(true)
		gamemode:SetCustomXPRequiredToReachNextLevel(XP_PER_LEVEL_TABLE)
	end

	gamemode:SetBotThinkingEnabled(USE_STANDARD_DOTA_BOT_THINKING)
	gamemode:SetTowerBackdoorProtectionEnabled(ENABLE_TOWER_BACKDOOR_PROTECTION)

	gamemode:SetFogOfWarDisabled(DISABLE_FOG_OF_WAR_ENTIRELY)
	gamemode:SetGoldSoundDisabled(DISABLE_GOLD_SOUNDS)
	--gamemode:SetRemoveIllusionsOnDeath(REMOVE_ILLUSIONS_ON_DEATH)

	gamemode:SetAlwaysShowPlayerInventory(SHOW_ONLY_PLAYER_INVENTORY)
	gamemode:SetAnnouncerDisabled(DISABLE_ANNOUNCER)
	if FORCE_PICKED_HERO ~= nil then
		gamemode:SetCustomGameForceHero(FORCE_PICKED_HERO) -- THIS WILL NOT WORK when "EnablePickRules" is "1" in 'addoninfo.txt' !
	else
		gamemode:SetDraftingHeroPickSelectTimeOverride(HERO_SELECTION_TIME)
		gamemode:SetDraftingBanningTimeOverride(0)
		if ENABLE_BANNING_PHASE then
			gamemode:SetDraftingBanningTimeOverride(BANNING_PHASE_TIME)
		end
	end
	gamemode:SetFixedRespawnTime(FIXED_RESPAWN_TIME)
	gamemode:SetFountainConstantManaRegen(FOUNTAIN_CONSTANT_MANA_REGEN)
	gamemode:SetFountainPercentageHealthRegen(FOUNTAIN_PERCENTAGE_HEALTH_REGEN)
	gamemode:SetFountainPercentageManaRegen(FOUNTAIN_PERCENTAGE_MANA_REGEN)
	gamemode:SetLoseGoldOnDeath(LOSE_GOLD_ON_DEATH)
	gamemode:SetMaximumAttackSpeed(MAXIMUM_ATTACK_SPEED)
	gamemode:SetMinimumAttackSpeed(MINIMUM_ATTACK_SPEED)
	gamemode:SetStashPurchasingDisabled(DISABLE_STASH_PURCHASING)

	if USE_DEFAULT_RUNE_SYSTEM then
		gamemode:SetUseDefaultDOTARuneSpawnLogic(true)
	else
		-- Most runes are broken by Valve, RuneSpawnFilter also doesn't work
		for rune, spawn in pairs(ENABLED_RUNES) do
			gamemode:SetRuneEnabled(rune, spawn)
		end
		gamemode:SetBountyRuneSpawnInterval(BOUNTY_RUNE_SPAWN_INTERVAL)
		gamemode:SetPowerRuneSpawnInterval(POWER_RUNE_SPAWN_INTERVAL)
	end

	gamemode:SetUnseenFogOfWarEnabled(USE_UNSEEN_FOG_OF_WAR)
	gamemode:SetDaynightCycleDisabled(DISABLE_DAY_NIGHT_CYCLE)
	gamemode:SetKillingSpreeAnnouncerDisabled(DISABLE_KILLING_SPREE_ANNOUNCER)
	gamemode:SetStickyItemDisabled(DISABLE_STICKY_ITEM)
	gamemode:SetPauseEnabled(ENABLE_PAUSING)
	gamemode:SetCustomScanCooldown(CUSTOM_SCAN_COOLDOWN)
	gamemode:SetCustomGlyphCooldown(CUSTOM_GLYPH_COOLDOWN)
	gamemode:DisableHudFlip(FORCE_MINIMAP_ON_THE_LEFT)

	if DEFAULT_DOTA_COURIER then
		gamemode:SetFreeCourierModeEnabled(true)
	end
end
