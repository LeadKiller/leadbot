if SERVER then AddCSLuaFile() end

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

function ENT:Initialize()
	if CLIENT then return end

	self:SetModel("models/player.mdl")
	self:SetSolid(SOLID_NONE)
	self:SetNoDraw(true)

	local fov_convar = GetConVar("leadbot_fov")

	self:SetFOV((fov_convar:GetBool() and math.Clamp(fov_convar:GetInt(), 75, 100)) or 90)
	self.PosGen = nil
	self.NextJump = -1
	self.NextDuck = 0
	self.cur_segment = 2
	self.Target = nil
	self.LastSegmented = 0
	self.LastSearched = 0
	self.ForgetTarget = 0
	self.NextCenter = 0
	self.LookAt = Angle(0, 0, 0)
	self.LookAtTime = 0
	self.goalPos = Vector(0, 0, 0)
	self.strafeAngle = 0
	self.nextStuckJump = 0
	self.Difficulty = math.Rand(0.75, 1.5)

	if LeadBot.AddControllerOverride then
		LeadBot.AddControllerOverride(self)
	end
end

local function cansee(self, pos1, pos2)
	return util.QuickTrace(pos1, pos2 - pos1, self:GetOwner()).HitPos:DistToSqr(pos2) < 100
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
			self.segments = self.P:GetAllSegments()

			local segs = {}
			for _, seg in ipairs(self.segments) do
				local add = false

				// ErrorNoHalt("GO")

				if !self.segments[_ + 1] or !self.segments[_ - 1] then
					add = true
				else
					if cansee(self, seg.pos, self.segments[_ + 1].pos) and cansee(self, seg.pos, self.segments[_ - 1].pos) then
						// print("SEEEEEEEE")
						// ErrorNoHalt("SEE")
					else
						add = true
					end
				end

				if add then
					table.insert(segs, add)
				end
			end
			self.cur_segment = 2
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

function ENT:Draw()
end

local function PointWithinViewAngle(pos, targetpos, lookdir, fov)
	pos = targetpos - pos
	local diff = lookdir:Dot(pos)
	if diff < 0 then return false end
	local len = pos:LengthSqr()
	return diff * diff > len * fov * fov
end

function ENT:InFOV(pos, fov)
	local owner = self:GetOwner()

	if IsEntity(pos) then
		-- TODO: check corners of hull instead
		if PointWithinViewAngle(owner:EyePos(), pos:WorldSpaceCenter(), owner:GetAimVector(), fov) then
			return true
		end

		return PointWithinViewAngle(owner:EyePos(), pos:EyePos(), owner:GetAimVector(), fov)
	else
		return PointWithinViewAngle(owner:EyePos(), pos, owner:GetAimVector(), fov)
	end
end

function ENT:CanSee(ply, fov)
	if ply:GetPos():DistToSqr(self:GetPos()) > self:GetMaxVisionRange() * self:GetMaxVisionRange() then
		return false
	end

	-- TODO: check fog farz and compare with distance
	fov = fov or true

	if fov and !self:InFOV(ply, math.cos(0.5 * (self:GetFOV() or 90) * math.pi / 180)) then
		return false
	end

	-- TODO: we really should check worldspacecenter too
	local owner = self:GetOwner()
	return util.QuickTrace(owner:EyePos(), ply:EyePos() - owner:EyePos(), {owner, self}).Entity == ply
end

function ENT:RunBehaviour()
	while (true) do
		if self.PosGen then
			self:ChasePos({})
		end

		coroutine.yield()
	end
end