-- This function calls the CreepPatrol thinker for the creeps
function barebones:MoveCreeps(level)
  print("----------Creep moving starting----------")
  for i,entvals in pairs(EntList[level]) do
    if entvals[ENT_TYPEN] == ENT_PATRL or entvals[ENT_TYPEN] == ENT_BIGPT or entvals[ENT_TYPEN] == ENT_PATTR then
      local entid = entvals[ENT_INDEX]
      local vecnum = entvals[PAT_VECNM]
      local delay = entvals[PAT_DELAY]
      local ms = entvals[PAT_MVSPD]
      local turnDelay = entvals[PAT_TURND] or 0.5
      --print("Turn Delay, ", turnDelay)
      local unit = EntIndexToHScript(entid)
      if entvals[ENT_TYPEN] == ENT_BIGPT then
        table.insert(Linked, unit)
        Timers:CreateTimer(delay, function()
          barebones:CreepPatrolLinked(unit, vecnum, turnDelay)
        end)  
      else
        Timers:CreateTimer(delay, function()
          barebones:CreepPatrol(unit, vecnum, turnDelay)
        end)
      end
      print(unit:GetUnitName(), "(", entid, ") start patrol after delay of", delay)    
    end
  end
  print("----------Creep moving done----------")
end

-- This function does patrols for multiple waypoints
function barebones:CreepPatrol(unit, idx, turnDelay)
  local waypoints = MultVector[idx]
  local newpos = CopyTable(waypoints)
  local first = table.remove(newpos, 1)
  table.insert(newpos, first)
  --print(idx)

  unit.goal = newpos[1]
  Timers:CreateTimer(function()
    if IsValidEntity(unit) then
      for i,waypoint in pairs(waypoints) do
        local posU = unit:GetAbsOrigin()
        if CalcDist(posU, waypoint) < 5 then
          unit:MoveToPosition(newpos[i])
          unit.goal = newpos[i]
        end
      end
      unit:MoveToPosition(unit.goal)
      return turnDelay
    else
      return
    end
  end)
end

-- This function initializes values for the patrol creeps
function barebones:PatrolInitial(unit, entvals)
  --print("Values initialized for ", unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
  unit:SetBaseMoveSpeed(entvals[PAT_MVSPD])
  unit:FindAbilityByName("kill_radius_lua"):SetLevel(1)
  if entvals[PAT_MVSPD] > 550 then
    unit:AddNewModifier(unit, nil, "modifier_dark_seer_surge", {})
  end
end

-- This function is a thinker for a gate to move upon full mana
function barebones:GateThinker(unit, entvals)
  print("Gate Thinker has started on unit", unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
  local pos = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local mana = entvals[GAT_NUMBR]
  local hullRadius = 80

  unit.moved = false
  unit:SetMaxMana(mana)
  unit:SetHullRadius(hullRadius)
  unit:SetForwardVector(entvals[GAT_ORIEN])
  local abil = unit:FindAbilityByName("gate_unit_passive")
  Timers:CreateTimer(function()
    if IsValidEntity(unit) then
      -- print("Has mana?", abil:IsOwnersManaEnough(), unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
      if unit:GetMana() == mana then
        unit:SetBaseMoveSpeed(100)
        unit:CastAbilityImmediately(abil, -1)
        unit:SetHullRadius(25)
        unit.moved = true
      end
      if not unit.moved then
        if CalcDist2D(unit:GetAbsOrigin(), pos) > 100 and RandomFloat(0, 1) > 0.75 then
          unit:MoveToPosition(pos)
        end

        -- Check for phase boots through
        local foundUnits = FindUnitsInRadius(DOTA_TEAM_GOODGUYS,
                                             unit:GetAbsOrigin(),
                                             nil,
                                             hullRadius,
                                             DOTA_UNIT_TARGET_TEAM_FRIENDLY,
                                             DOTA_UNIT_TARGET_HERO,
                                             DOTA_UNIT_TARGET_FLAG_NONE,
                                             FIND_ANY_ORDER,
                                             false)
        for _,foundUnit in pairs(foundUnits) do
          --print("Found", foundUnit:GetName())
          local posU = unit:GetAbsOrigin()
          local posF = foundUnit:GetAbsOrigin()

          if posF.z < 130 then
            local shift = -(hullRadius - CalcDist2D(posU, posF) + 25)
            local forwardVec = foundUnit:GetForwardVector():Normalized()
            local newOrigin = posF + forwardVec*shift
            foundUnit:SetAbsOrigin(newOrigin)
          end
        end
      end
      return 0.03
    else
      return
    end
  end)
end

-- This function casts Linas LSA ability
function barebones:CastLSA(unit, castPos, emitSound)
  local partRad = 225
  local killRad = 200

  local part = ParticleManager:CreateParticle("particles/misc/light_strike.vpcf", PATTACH_ABSORIGIN, unit)
  ParticleManager:SetParticleControl(part, 0, castPos)
  ParticleManager:SetParticleControl(part, 1, Vector(partRad, 0, 0))

  if emitSound then
    EmitSoundOnLocationWithCaster(castPos, "Ability.LightStrikeArray", unit)
  end

  local targets = FindUnitsInRadius(DOTA_TEAM_GOODGUYS,
                                    castPos, 
                                    nil, 
                                    killRad, 
                                    DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
                                    DOTA_UNIT_TARGET_ALL, 
                                    DOTA_UNIT_TARGET_FLAG_NONE, 
                                    FIND_ANY_ORDER, 
                                    false)
  for _,target in pairs(targets) do
    --target:SetBaseMagicalResistanceValue(25)
    target:ForceKill(true)
  end
end

-- This function is for the AOE spell caster
function barebones:AOEThinker(unit, entvals)
  print("AOE Thinker has started on unit", unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
  local pos = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local rate = entvals[AOE_RATES]
  local delay = entvals[AOE_DELAY]
  local emitSound = entvals[AOE_SOUND]

  unit:FindAbilityByName("dummy_unit"):SetLevel(1)

  Timers:CreateTimer(delay, function()
    if IsValidEntity(unit) then
      barebones:CastLSA(unit, pos, emitSound)
      return rate
    else
      return
    end
  end)
end

-- This function is for the static zombie thinker
function barebones:StaticThinker(unit, entvals)
  print("Thinker has started on static zombie (", unit:GetEntityIndex(), ")")
  local pos = unit:GetAbsOrigin()
  local minwait = 2
  local maxwait = 5

  unit:FindAbilityByName("kill_radius_lua"):SetLevel(2)
  Timers:CreateTimer(1, function()
    if IsValidEntity(unit) then
      local xrand = RandomFloat(-1, 1)
      local yrand = RandomFloat(-1, 1)
      unit:SetForwardVector(Vector(xrand, yrand, 0))

      if CalcDist2D(unit:GetAbsOrigin(), pos) > 10 then
        Timers:CreateTimer(1, function()
          unit:MoveToPosition(pos)
        end)
      end

      return RandomFloat(minwait, maxwait)
    else
      return
    end
  end)
end

-- This function is for the magnus thinker
function barebones:MagnusThinker(unit, entvals)
  print("Magnus thinker started")
  local spawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local goal = Entities:FindByName(nil, entvals[MAG_GOALS]):GetAbsOrigin()
  local rate = entvals[MAG_RATES]
  local delay = entvals[MAG_DELAY]
  
  unit.pos = goal
  local abil = unit:AddAbility("magnataur_skewer_custom")
  abil:SetLevel(1)

  Timers:CreateTimer(delay, function()
    if IsValidEntity(unit) then
      unit:CastAbilityOnPosition(unit.pos, abil, -1)
      unit.pos = unit.pos == spawn and goal or spawn
      return rate
    else
      return
    end
  end)
end

-- This function is for creating a wall patrol
function barebones:WallPatrolThinker(bl, tr, dir, numUnits, level, ms)
  print("Wall Patrol Thinker started")
  local units = {}

  -- dir: true=horizontal, up/down, false=vertical left/right
  local dist = dir and (tr.x - bl.x) or (tr.y - bl.y)
  local spacing
  
  if numUnits <= 1 then
    numUnits = math.ceil(dist/50) + 1
    spacing = dist/(numUnits - 1)
  else
    spacing = dist/(numUnits - 1)
  end
  local inc = dir and Vector(spacing, 0, 0) or Vector(0, spacing, 0)

  for i = 1,numUnits do
    local pos1 = bl + inc*(i-1)
    local pos2 = tr - inc*(numUnits-i)
    local unit = CreateUnitByName("npc_creep_patrol_torso", pos1, true, nil, nil, DOTA_TEAM_ZOMBIES)
    unit:SetBaseMoveSpeed(ms)
    unit.waypoints = {pos1, pos2}
    unit.goal = pos2
    table.insert(units, unit)

    if ms > 550 then
      unit:AddNewModifier(unit, nil, "modifier_dark_seer_surge", {})
    end
  end

  Timers:CreateTimer(0.5, function()
    if GameRules.CLevel == level then
      local count = 0

      for _,ent in pairs(units) do
        ent:MoveToPosition(ent.goal)
        if CalcDist2D(ent:GetAbsOrigin(), ent.goal) < 5 then
          count = count + 1
        end
      end
      if count == #units then
        for _,ent in pairs(units) do
          ent.goal = ent.waypoints[1]

          local newtable = CopyTable(ent.waypoints)
          local first = table.remove(newtable, 1)
          table.insert(newtable, first)
          ent.waypoints = newtable
        end
      end
      return 0.25
    else
      for _,ent in pairs(units) do
        ent:ForceKill(true)
      end
      return
    end
  end)
end

-- This fucntion is for the lightstrike thinker
function barebones:LightStrikeThinker()
  print("Lightstrike thinker started")
  local spawn = Entities:FindByName(nil, "ls2_linea"):GetAbsOrigin()
  local goal = Entities:FindByName(nil, "ls2_lineb"):GetAbsOrigin()
  local dist = 250
  local rateFull = 4.5
  local rateLS = 0.4

  local unit = CreateUnitByName("npc_dummy_unit", goal, true, nil, nil, DOTA_TEAM_ZOMBIES)
  unit:FindAbilityByName("dummy_unit"):SetLevel(1)

  Timers:CreateTimer(0, function()
    if GameRules.CLevel == 2 then
      local y = spawn.y

      Timers:CreateTimer(0, function()
        if y > goal.y then
          local castPos = Vector(spawn.x, y, 128)
          barebones:CastLSA(unit, castPos, false)
          y = y - dist
          return rateLS
        else
          return
        end
      end)
      return rateFull
    else
      return
    end
  end)
end

-- This function is for the mango thinker
function barebones:MangoThinker(unit, entvals)
  local boundsIndex = 1
  local posTL = Entities:FindByName(nil, "techiesTL"):GetAbsOrigin()
  local posBR = Entities:FindByName(nil, "techiesBR"):GetAbsOrigin()
  local pos = unit:GetAbsOrigin()

  unit.prevPos = pos

  local dummy_mango = CreateItem("item_mango_custom_dummy", nil, nil)
  local dummy_ent = CreateItemOnPositionSync(pos, dummy_mango)
  --print(dummy_ent, dummy_ent:GetEntityIndex(), dummy_ent:GetClassname())

  Timers:CreateTimer(1, function()
    if IsValidEntity(unit) then
      local pos = unit:GetAbsOrigin()
      local isInside = not OutsideRectangle(unit, posTL, posBR)
      local notMoved = pos == unit.prevPos

      --print(pos, unit.prevPos)
      if not notMoved and IsValidEntity(dummy_ent) then
        dummy_ent:RemoveSelf()
      end

      if isInside and notMoved then
        -- Creating the mango
        local newItem = CreateItem("item_mango_custom", nil, nil)
        CreateItemOnPositionSync(pos, newItem) 

        -- Removing the unit dummy unit without killing (bugs)
        unit:SetAbsOrigin(Vector(0, 0, 0))
        unit:AddNewModifier(unit, nil, "modifier_invisible", {})
        --unit:ForceKill(true)
        --unit:RemoveSelf()
        return
      else
        unit.prevPos = pos
        return 0.1
      end
    else
      return
    end
  end)
end

-- This function is for the techies thinker
function barebones:TechiesThinker()
  print("Techies thinker has started")
  local spawn = Entities:FindByName(nil, "techies_1a"):GetAbsOrigin()
  local goal = Entities:FindByName(nil, "techies_1b"):GetAbsOrigin()

  local posTL = Entities:FindByName(nil, "techiesTL"):GetAbsOrigin()
  local posBR = Entities:FindByName(nil, "techiesBR"):GetAbsOrigin()

  local c = 0
  local rate = 0.50
  local movespeed = 325

  Timers:CreateTimer(1, function()
    if GameRules.CLevel == 2 then
      if not (c % 5 == 0) then
        local unit = CreateUnitByName("npc_techies", spawn, true, nil, nil, DOTA_TEAM_ZOMBIES)
        unit:SetBaseMoveSpeed(movespeed)
        unit:FindAbilityByName("kill_radius_lua"):SetLevel(1)
        Timers:CreateTimer(0.2, function()
          unit:MoveToPosition(goal)
        end)

        Timers:CreateTimer(0.5, function()
          if IsValidEntity(unit) then
            local isInside = not OutsideRectangle(unit, posTL, posBR)
            local abil = unit:FindAbilityByName("techies_suicide_custom")
            local posUnit = unit:GetAbsOrigin()

            if isInside then
              local x = RandomFloat(posTL.x, posBR.x)
              local y = RandomFloat(posTL.y, posBR.y)
              local castPos = Vector(x, y, 128)

              unit:CastAbilityOnPosition(castPos, abil, -1)
              return
            elseif CalcDist(posUnit, goal) < 10 then
              --local castPos = Vector(goal.x, goal.y - RandomFloat(500, 1500), 128)
              --unit:CastAbilityOnPosition(castPos, abil, -1)
              unit:ForceKill(true)
              return
            else
              return 1
            end
          else
            return
          end
        end)
      end

      c = c + 1
      return rate
    else
      return
    end
  end)
end

-- This function is for the carty system
function barebones:CartyThinker()
  print("Carty thinker has started")
  local spawn = Entities:FindByName(nil, "carty3_1a"):GetAbsOrigin()
  local goal = Entities:FindByName(nil, "carty3_1b"):GetAbsOrigin()
  local offset = 105
  local carts = 4
  local moveSpeed = 345
  local rate = 6.5

  Timers:CreateTimer(0.1, function()
    if GameRules.CLevel == 3 then
      for i = 1,carts do
        local pos1 = Vector(spawn.x, spawn.y - offset*(i-1), spawn.z)
        local pos2 = Vector(goal.x, goal.y - offset*(i-1), goal.z)
        local unit = CreateUnitByName("npc_carty", pos1, true, nil, nil, DOTA_TEAM_ZOMBIES)
        unit:SetBaseMoveSpeed(moveSpeed)
        unit:AddNewModifier(unit, nil, "modifier_spectre_spectral_dagger_path_phased", {})
        unit:FindAbilityByName("kill_radius_lua"):SetLevel(2)

        Timers:CreateTimer(0.1, function()
          if IsValidEntity(unit) then
            unit:MoveToPosition(pos2)
            if CalcDist(unit:GetAbsOrigin(), pos2) < 10 then
              unit:RemoveSelf()
            end
            return 0.1
          else
            return
          end
        end)
      end
      return rate
    else
      return
    end
  end)
end

-- This function is for the red light green light thinker
function barebones:RedGreenLightThinker()
  print("Red light green light thinker has started")
  local posTL = Entities:FindByName(nil, "voidTL"):GetAbsOrigin()
  local posBR = Entities:FindByName(nil, "voidBR"):GetAbsOrigin()

  local posAetherL = Entities:FindByName(nil, "aetherL"):GetAbsOrigin()
  local posAetherR = Entities:FindByName(nil, "aetherR"):GetAbsOrigin()

  local rad = math.floor((posTL.y - posBR.y)/2)
  local spawn = Vector(posBR.x - 900, posBR.y, 128)

  local unit = CreateUnitByName("npc_void_spirit", spawn, true, nil, nil, DOTA_TEAM_ZOMBIES)
  local abil_q = unit:AddAbility("void_spirit_aether_remnant_custom")
  local abil_w = unit:AddAbility("void_spirit_dissimilate_custom")
  local abil_e = unit:AddAbility("void_spirit_resonant_pulse_custom")
  local abil_r = unit:AddAbility("void_spirit_astral_step_custom")
  abil_q:SetLevel(1)
  abil_w:SetLevel(1)
  abil_e:SetLevel(1)
  abil_r:SetLevel(1)

  local phaseTimes = {2.5, 3.25, 3.25, 3.25}
  local choose = {}
  local killTime = 2
  local phaseDelay = 0.1
  local killDelay = phaseDelay + 0.45

  -- Dummy
  local dummy = CreateUnitByName("npc_dummy_unit", unit:GetAbsOrigin(), true, nil, nil, DOTA_TEAM_ZOMBIES)
  dummy:SetAbsOrigin(Vector(0, 0, 0))
  dummy:FindAbilityByName("dummy_unit"):SetLevel(1)

  local c = 0
  Timers:CreateTimer(0, function()
    if GameRules.CLevel == 4 then
      -- Choose random time to dissimilate for, remove from table
      if TableLength(choose) < 1 then
        choose = ShallowCopyTable(phaseTimes)
      end
      local key = GetRandomTableKey(choose)
      local phaseTime = choose[key]
      table.remove(choose, key)

      -- Casting aether remnant
      local castQX = RandomFloat(posAetherL.x, posAetherR.x)
      local castQY = posAetherL.y
      local castQPos = Vector(castQX, castQY, 128)

      unit:CastAbilityOnPosition(castQPos, abil_q, -1)

      local aetherPartName = "particles/econ/taunts/void_spirit/void_spirit_taunt_dust_impact.vpcf"
      local aetherPart = ParticleManager:CreateParticle(aetherPartName, PATTACH_CUSTOMORIGIN, dummy) 
      ParticleManager:SetParticleControl(aetherPart, 0, castQPos)

      -- Moving position if on sides or far away
      local pos = unit:GetAbsOrigin()
      local avgX = 0
      local insideTable = GetHeroesInsideRectangle(posTL, posBR, false)
      if TableLength(insideTable) > 0 then
        for _,hero in pairs(insideTable) do
          avgX = avgX + hero:GetAbsOrigin().x
        end
        avgX = avgX/TableLength(insideTable)
      else
        avgX = -9999
      end

      local blinkPos = pos
      local castBlink = false

      if math.abs(pos.y - posTL.y) > 1 and math.abs(pos.y - posBR.y) > 1 then
        --print("On the sides, blinking")
        blinkPos.y = GetRandomTableElement({posTL.y, posBR.y})

        castBlink = true
      elseif pos.x < avgX then
        --print("On the left, moving to the right, blinking")
        local dist = math.floor(math.abs(pos.x - avgX)/5)
        blinkPos.x = math.min(blinkPos.x + dist, posBR.x)

        castBlink = true
      end

      if castBlink then
        local blinkPartStart = "particles/econ/events/ti7/blink_dagger_start_ti7.vpcf"
        local blinkPartEnd = "particles/econ/events/ti7/blink_dagger_end_ti7.vpcf"
        local part1 = ParticleManager:CreateParticle(blinkPartStart, PATTACH_CUSTOMORIGIN, dummy)
        ParticleManager:SetParticleControl(part1, 0, unit:GetAbsOrigin())

        unit:SetAbsOrigin(blinkPos)
        local part2 = ParticleManager:CreateParticle(blinkPartEnd, PATTACH_CUSTOMORIGIN, dummy)
        ParticleManager:SetParticleControl(part2, 0, blinkPos)
      end

      -- Casting phase/dissimilate
      abil_w:SetLevel(phaseTime)
      Timers:CreateTimer(phaseDelay, function()
        unit:CastAbilityImmediately(abil_w, -1)

        --print(c, abil_w:GetSpecialValueFor("phase_duration"))
      end)

      local dotaTime = GameRules:GetDOTATime(false, false)
      local startKillTime = dotaTime + phaseTime + killDelay
      local endTime = dotaTime + phaseTime + killTime + phaseDelay

      local hasCastedE = false

      --print("Starting one think timer...")
      c = c + 1
      Timers:CreateTimer(0, function()
        local currentTime = GameRules:GetDOTATime(false, false)
        -- Casting resonant pulse (E) right after phase
        if not hasCastedE then
          unit:CastAbilityImmediately(abil_e, -1)
          hasCastedE = true
        end

        --print(c, phaseTime, currentTime, startKillTime, endTime)
        -- Start killing after delay time
        if currentTime > startKillTime and currentTime < endTime then
          -- Find a moving target that is the furthest ahead
          --print("Finding targets...")
          local target = nil
          local inside = GetHeroesInsideRectangle(posTL, posBR, true)
          for _,hero in pairs(inside) do
            local furthest = target and target:GetAbsOrigin().x or posBR.x
            if hero:IsMoving() and hero:GetAbsOrigin().x < furthest then
              target = hero
            end
          end

          -- Kill furthest hero by astraling across
          if target then
            print("Found target to kill")
            local unitPos = unit:GetAbsOrigin()
            local targetPos = target:GetAbsOrigin()

            local castRY = math.abs(unitPos.y - posTL.y) < rad/2 and posBR.y or posTL.y

            local m = (targetPos.y - unitPos.y)/(targetPos.x - unitPos.x)
            local castRX = unitPos.x - (unitPos.y - castRY)/m

            if castRX < posTL.x then
              castRX = posTL.x
              castRY = unitPos.y - m*(unitPos.x - castRX)
            elseif castRX > posBR.x then
              castRX = posBR.x
              castRY = unitPos.y - m*(unitPos.x - castRX)
            end
            local castRPos = Vector(castRX, castRY, 128)

            if not abil_r:IsInAbilityPhase() then
              unit:CastAbilityOnPosition(castRPos, abil_r, -1)
            end
            --print(unitPos, targetPos, castRPos)
          end
        elseif currentTime > endTime then
          return
        end
        return 0.25
      end)

      return (phaseTime + killTime + 0.05)
    else
      unit:ForceKill(true)
      unit:RemoveSelf()
      return
    end
  end)
end

-- This function is for the wall thinker
function barebones:WallThinker()
  print("Wall thinker has started")
  local boundsBR = Entities:FindByName(nil, "wall5a"):GetAbsOrigin()
  local boundsTL = Entities:FindByName(nil, "wall5b"):GetAbsOrigin()

  local units = 15
  local spacing = (boundsTL.y - boundsBR.y)/(units - 1)

  local rate = 5
  local movespeed = 230

  Timers:CreateTimer(1, function()
    if GameRules.CLevel == 5 then
      for i = 1,units do
        local x = boundsBR.x
        local y = boundsBR.y + spacing*(i-1)
        local spawn = Vector(x, y, 128)
        local goal = Vector(boundsTL.x, y, 128)

        local unit = CreateUnitByName("npc_creep_patrol_torso", spawn, true, nil, nil, DOTA_TEAM_ZOMBIES)
        unit:SetBaseMoveSpeed(movespeed)
        unit:AddNewModifier(unit, nil, "modifier_spectre_spectral_dagger_path_phased", {})

        Timers:CreateTimer(0, function()
          if IsValidEntity(unit) then
            if CalcDist2D(unit:GetAbsOrigin(), goal) < 5 then
              unit:ForceKill(true)
              return
            else
              unit:MoveToPosition(goal)
              return 0.1
            end
          else
            unit:RemoveSelf()
            return
          end
        end)
      end
      return rate
    else
      return
    end
  end)
end

-- This function is for the circular thinker
function barebones:CircularThinker()
  print("Circular thinker started")
  local center = Entities:FindByName(nil, "circular"):GetAbsOrigin()
  local unitTable = {}
  local c = 0
  local expand = true

  -- Max radius to corner 3128, to edge 2212
  local numProngs = 7
  local numRings = 5
  local ringSpacing = 200
  local startSpacing = 250
  local maxSpacing = 575
  local minSpacing = 250

  local spacingLimitOffset = 40
  local baseRotatePause = 0.8

  local movespeed = 900

  local baseSpacingMove = 7
  local baseAngleMove = math.rad(1.2)
  local returnRate = 0.075

  local newAngle = 0

  local angleMove

  -- Creating all the units, adding to table
  for i = 1,numRings do
    unitTable[i] = {}
    local r = startSpacing + ringSpacing*(i-1)

    local units = numProngs
    for j = 1,units do
      local angle = math.rad((360/units) * j)
      local pos = Vector(center.x + r*math.cos(angle), center.y + r*math.sin(angle), 128)
      local unit = CreateUnitByName("npc_creep_patrol_torso", pos, true, nil, nil, DOTA_TEAM_ZOMBIES)
      unit:AddItemByName("item_force_boots")
      unit:SetBaseMoveSpeed(movespeed)
      table.insert(unitTable[i], unit)
    end
  end

  -- Thinker to move in pattern
  Timers:CreateTimer(2, function()
    if GameRules.CLevel == 6 then
      -- Reversing rotation
      local rotationTicks = 400

      local modValue = math.floor(c % rotationTicks)
      local intervalValue = math.floor(c/rotationTicks)

      local tempAngleMove = angleMove
      angleMove =  intervalValue % 2 == 0 and baseAngleMove or -baseAngleMove

      local rotatePause = tempAngleMove ~= angleMove and baseRotatePause or 0

      spacingMove = baseSpacingMove
      --spacingMove = (modValue % 2 == 0) and baseSpacingMove or 0


      -- Translational
      local centerR = 200
      local angleAdj = math.rad(c*4.5)
      local centerShift = Vector(centerR*math.cos(angleAdj), centerR*math.sin(angleAdj), 0)
      local centerAdj = center + centerShift


      -- Dilational
      local val = expand and spacingMove or -spacingMove
      ringSpacing = ringSpacing + val

      if expand and ringSpacing >= (maxSpacing + spacingLimitOffset) then
        expand = false
      elseif not expand and ringSpacing <= (minSpacing - spacingLimitOffset) then
        expand = true
      end


      -- Moving unit
      newAngle = newAngle + angleMove
      for i = 1,numRings do
        local ringSpacingAdj = ringSpacing
        ringSpacingAdj = math.min(ringSpacingAdj, maxSpacing)
        ringSpacingAdj = math.max(ringSpacingAdj, minSpacing)

        local r = startSpacing + ringSpacingAdj*(i-1)

        local units = numProngs
        for j,unit in pairs(unitTable[i]) do
          local angle = math.rad((360/units) * j) + newAngle
          local newPos = Vector(centerAdj.x + r*math.cos(angle), centerAdj.y + r*math.sin(angle), 128)
          unit:MoveToPosition(newPos)
          --unit:SetAbsOrigin(newPos)
        end
      end      


      c = c + 1
      --print("Circular", c, center, ringSpacing, newAngle, math.deg(newAngle))
      return returnRate + rotatePause
    else
      return
    end
  end)
end