function GateMove(event)
    print("GateMove started, gate moving now")
    local gate_move = EntIndexToHScript(event.caster_entindex)
    local origin = gate_move:GetAbsOrigin()
    local level = GameRules.CLevel
    gate_move:SetMana(0)
    for i,entvals in pairs(EntList[level]) do
        if entvals[ENT_INDEX] == event.caster_entindex then
            local pos = Entities:FindByName(nil, entvals[GAT_MOVES]):GetAbsOrigin()
            gate_move:AddAbility("gate_unselectable"):SetLevel(1)
            gate_move:MoveToPosition(pos)
        end
    end
end


-----------------
-- Kill Radius --
-----------------

kill_radius_lua = kill_radius_lua or class({})
LinkLuaModifier("modifier_kill_radius", "abilities", LUA_MODIFIER_MOTION_NONE)

function kill_radius_lua:GetIntrinsicModifierName()
	return "modifier_kill_radius"
end

modifier_kill_radius = modifier_kill_radius or class({})
function modifier_kill_radius:RemoveOnDeath() return true end


function modifier_kill_radius:OnRefresh()
	if IsServer() then
		self:OnCreated()
	end
end

function modifier_kill_radius:OnCreated()
  if IsServer() then
    self.radius = self:GetAbility():GetSpecialValueFor("radius")
    self.rate = self:GetAbility():GetSpecialValueFor("rate")

    --print("Level of mod", self:GetAbility():GetLevel())

    if not self.timer then
      --print("Starting timer level", self:GetAbility():GetLevel())
      self:StartIntervalThink(self.rate)
      self.timer = true
    end
  end
end

function modifier_kill_radius:OnIntervalThink()
  if IsServer() then
    local caster = self:GetCaster()

    if caster:IsAlive() then
      local targets = FindUnitsInRadius(DOTA_TEAM_GOODGUYS,
        caster:GetAbsOrigin(), 
        nil, 
        self.radius, 
        DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
        DOTA_UNIT_TARGET_HERO, 
        DOTA_UNIT_TARGET_FLAG_NONE, 
        FIND_ANY_ORDER, 
        false)
          
      for _,target in pairs(targets) do
        --if target:GetAbsOrigin().z < 130 then
        if math.abs(target:GetAbsOrigin().z - caster:GetAbsOrigin().z) < 5 then
          --target:SetBaseMagicalResistanceValue(25)
          target.isSafe = true
          target.tossDeath = false
          target:ForceKill(true)
        end
      end       
    end 
  end
end