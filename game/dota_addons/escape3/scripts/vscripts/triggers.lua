function OnStartSafety(trigger)
	local ent = trigger.activator
	if not ent then return end
	--print(ent:GetName(), " has stepped on trigger")
	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = true
		ent:SetBaseMagicalResistanceValue(100)
		return
	end
end

function OnEndSafety(trigger)
	local ent = trigger.activator
	print(ent:GetName(), " has initially stepped off trigger")
	if not ent then return end

	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = false

		-- Dealing with toss
		--print(ent:HasModifier("modifier_tiny_toss"))
		if ent:HasModifier("modifier_tiny_toss") then
			local tickRate = 0.1
			local tickDelay = 0.05

			Timers:CreateTimer(0, function()
				--print(ent:HasModifier("modifier_tiny_toss"))
				if ent:HasModifier("modifier_tiny_toss") then
					return tickRate
				else
					Timers:CreateTimer(tickDelay, function()
						if ent:GetAbsOrigin().z > 500 then
							print("Landed on map border, killing now")
							ent.tossDeath = true
							ent:SetBaseMagicalResistanceValue(25)
						else
							if ent.isSafe then
								print("Landed on safe after toss")
								ent.tossDeath = false
							else
								print("Landed on lava after toss, killing now")
								ent.tossDeath = true
								ent:SetBaseMagicalResistanceValue(25)
							end
						end	
						return
					end)
					return
				end
			end)
		else
			print(ent:GetName(), " will be killed", ent:GetAbsOrigin().z)
			ent:SetBaseMagicalResistanceValue(25)
		end

		return
	end
end

function OnStartKill(trigger)
	local ent = trigger.activator
	if not ent then return end
	--print(ent:GetName(), " has stepped on trigger")
	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = false
		ent.tossDeath = true
		ent:SetBaseMagicalResistanceValue(25)
		return
	end
end

function UpdateCheckpoint(trigger)
	print("---------UpdateCheckpoint trigger activated--------")
	local trigblock = trigger.caller
	local position = trigblock:GetAbsOrigin()
	--print("Checkpoint was:", GameRules.Checkpoint)
	GameRules.Checkpoint = position
	local name = trigblock:GetName()
	local level = tonumber(string.sub(name, -1))
	if GameRules.CLevel < level then
		GameRules.CLevel = level
		print("Checkpoint updated to:", position)
		print("Level updated to:", level)
		local msg = {
			text = "Level " .. tostring(level) .. "!",
			duration = 8.0,
			style={color="white", ["font-size"]="96px"}
		}       
		if level < 7 then
			Notifications:TopToAll(msg)
			GameRules:SendCustomMessage("Level " .. tostring(level) .. "!", 0, 1)
		end
		if level > 1 and level < 7 then
			barebones:ReviveAll()
			barebones:RemoveAllSkills()
			barebones:CleanLevel(level-1)
			barebones:SetUpLevel(level)
			Timers:CreateTimer(1, function()
				barebones:MoveCreeps(level, {})
			end)
			WebApi:UpdateTimeSplit(level)
		elseif level == 7 then
			GameRules.Ongoing = false
			WebApi:UpdateTimeSplit(level)
			Timers:CreateTimer(0.1, function()
				WebApi:FinalizeGameScoreAndSend()
				WebApi:SendDeleteRequest()
				Timers:CreateTimer(2, function()
					GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
					GameRules:SetSafeToLeave(true)
				end)
			end)
		end
		print("---------UpdateCheckpoint trigger finished--------")
	end
end

function GiveSkill(trigger)
	print("Skill trigger triggered")
	local hero = trigger.activator
	local trig = trigger.caller

	local name = trig:GetName()
	local level = tonumber(string.sub(name, 1, 1))
	local slot = tonumber(string.sub(name, 2, 2))
	local abilName = string.sub(name, 3)

	if trig and level == GameRules.CLevel then
		-- Adding skill if somehow doesnt have
		if not hero:FindAbilityByName(abilName) then
			print("Giving skill to player")
			local tempAbil = hero:AddAbility(abilName)
			tempAbil:SetHidden(true)
			tempAbil:SetLevel(1)
		end

		local abil = hero:FindAbilityByName(abilName)
		local abilSlot = abil:GetAbilityIndex()

		print("Current slot for ", abil:GetAbilityName(), slot, abilSlot + 1)
		-- Checking proper slot
		if slot ~= (abilSlot + 1) then
			hero:SwapAbilities(abilName, "barebones_empty" .. slot, true, false)

			-- Particles for spell
			local partname = "particles/generic_hero_status/hero_levelup.vpcf"
			local part = ParticleManager:CreateParticle(partname, PATTACH_ABSORIGIN_FOLLOW, hero)
		end
	end
end

function RemoveSkill(trigger)
	print("Remove skill trigger triggered")
	local hero = trigger.activator
	local trig = trigger.caller
	if trig then
		local trigName = trig:GetName()
		local removeName = string.sub(trigName, 3)
		
    for i = 0,4 do
      local abil = hero:GetAbilityByIndex(i)
      local abilName = abil:GetAbilityName()
			
			print(i, removeName, abilName)
      if removeName == abilName then
        hero:SwapAbilities(abilName, "barebones_empty" .. (i+1), false, true)
      end
    end
	end
end