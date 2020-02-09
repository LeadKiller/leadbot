if SERVER then AddCSLuaFile() end

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

function ENT:Initialize()
	self:SetModel("models/gman.mdl")
	self:SetNoDraw(true)
	self:SetSolid(SOLID_NONE)
	self.PosGen = nil
end

function ENT:ChasePos()
	self.P = Path("Follow")
	self.P:SetMinLookAheadDistance(10)
	self.P:SetGoalTolerance(20)
	self.P:Compute(self, self.PosGen)

	if !self.P:IsValid() then return end

	while self.P:IsValid() do
		if self.PosGen then
			self.P:Compute(self, self.PosGen)
		end

		coroutine.wait(1)
		coroutine.yield()
	end
end

function ENT:OnInjured()
	return false
end

function ENT:OnKilled()
	return false
end

function ENT:IsNPC()
	return false
end

function ENT:Health()
	return nil
end

function ENT:RunBehaviour()
	while (true) do
		if self.PosGen then
			self:ChasePos({})
		end

		coroutine.yield()
	end
end