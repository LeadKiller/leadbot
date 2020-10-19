--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = true
LeadBot.Gamemode = "sandbox"
LeadBot.TeamPlay = false
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

if SERVER or CLIENT then return end

concommand.Add("leadbot_savedupe", function(ply)
	local filen = "leadbot/dupe_" .. math.random(1, 99999999) .. ".txt"
	file.CreateDir("leadbot")
	file.Write(filen, util.TableToJSON(ply.CurrentDupe))
	ply:ChatPrint("Dupe " .. filen .. " was saved!")
end)

local function MingeBag(ply)
	local filenn = table.Random(file.Find("e2files/mingebag_*.txt", "DATA"))
	local filen = string.Split(file.Read("e2files/" .. filenn, "DATA"), "|")
	local MingebagTimer = 0
	local origin = ply:GetEyeTrace().HitPos
	local OriginMingebag

	for k, v in pairs(filen) do
		if string.find(v, "model") then
			timer.Simple(MingebagTimer, function()
				local model, pos, ang = v, util.StringToType(string.Replace(filen[k + 1], ",", " "), "vector"), util.StringToType(string.Replace(filen[k + 2], ",", " "), "angle")
				local prop = ents.Create("prop_physics")
				prop:SetModel(model)
				prop:SetPos(origin + pos)
				prop:SetAngles(ang)
				prop:Spawn()
				prop:Activate()
				-- local prop = MakeProp(ply, origin + pos, ang, model, _, {})

				if !IsValid(prop) then return end

				if !IsValid(OriginMingebag) then
					OriginMingebag = prop
				else
					constraint.Weld(OriginMingebag, prop, 0, 0, 0, 0, true )
				end

				local physics = prop:GetPhysicsObject()

				if IsValid(physics) then
					physics:EnableMotion(false)
				end
			end)

			MingebagTimer = MingebagTimer -- + tonumber("0." .. math.random(01, 025))
		end
	end

	timer.Simple(MingebagTimer + 0.25, function()
		OriginMingebag = nil
	end)
end

concommand.Add("leadbot_convertmingebag", function(ply)
	MingeBag(ply)
end)

function LeadBot.PostPlayerDeath(bot)
	bot.BuildingStuff = false

	timer.Simple(2, function()
		if IsValid(bot) and LeadBot.RespawnAllowed and !bot:Alive() then
			bot:Spawn()
		end
	end)
end

function LeadBot.StartCommand(bot, cmd)
	cmd:ClearMovement()
	cmd:ClearButtons()

	if bot.ControllerBot:GetPos() ~= bot:GetPos() then
		bot.ControllerBot:SetPos( bot:GetPos() )
	end

	bot.TargetEnt = nil
	bot.LastBuildTime = bot.LastBuildTime or CurTime() + 7 + math.random(0, 30)

	if bot.BotStrategy == 1 and !bot.BuildingStuff and bot.LastBuildTime < CurTime() and bot:Alive() then
		--[[local dupef = table.Random(file.Find("leadbot/dupe_*.txt", "DATA"))
		local dupe = util.JSONToTable(file.Read("leadbot/" .. dupef, "DATA"))]]
		local buildpos = bot.ControllerBot:FindSpot("random", {radius = 2000, stepup = 0, stepdown = 0})

		if !buildpos then return end

		bot.LastBuildTime = CurTime() + 7 + math.random(30)
		bot.BuildingStuff = true

		bot:SelectWeapon("gmod_tool")
		timer.Simple(0.25, function()
			if IsValid(bot) and bot.BuildingStuff then
				bot:SetEyeAngles((buildpos - bot:GetShootPos()):Angle())

				timer.Simple(0.75, function()
					if IsValid(bot) and bot.BuildingStuff and IsValid(bot:GetActiveWeapon()) and bot:GetActiveWeapon():GetClass() == "gmod_tool" then
						local trace = bot:GetEyeTrace()
						bot:GetActiveWeapon():DoShootEffect(trace.HitPos, trace.HitNormal, trace.Entity, trace.PhysicsBone, IsFirstTimePredicted())
						-- duplicator.SetLocalPos(Vector(trace.HitPos.x, trace.HitPos.y, trace.HitPos.z - dupe.Mins.z))
						-- duplicator.SetLocalAng(Angle(0, bot:EyeAngles().y, 0))
						-- duplicator.Paste(bot, dupe.Entities, dupe.Constraints)
						MingeBag(bot)
						timer.Simple(0.5, function()
							if IsValid(bot) and bot.BuildingStuff then
								bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 12500})
								bot.BuildingStuff = false
							end
						end)
					end
				end)
			end
		end)
	end

	if bot.BuildingStuff then return end

	bot.TargetEnt = nil

	cmd:SetForwardMove(250)

	------------------------------
	-----[[ENTITY DETECTION]]-----
	------------------------------

	for k, v in pairs(ents.GetAll()) do
		if bot.BotStrategy ~= 1 and v:IsPlayer() and v ~= bot and v:GetPos():Distance(bot:GetPos()) < 1500 then
			local targetpos = v:EyePos() or v:GetPos()

			if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v then
				bot.TargetEnt = v
			end
		elseif v:GetClass() == "prop_door_rotating" and v:GetPos():Distance(bot:GetPos()) < 70 then
			local targetpos = v:GetPos() + Vector(0, 0, 45)

			if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v then
				v:Fire("Open","",0)
			end
		end
	end

	------------------------------
	--------[[BOT LOGIC]]---------
	------------------------------

	local buttons = IN_SPEED

	if bot.BotStrategy ~= 1 then
		bot:SelectWeapon("weapon_ar2")
	else
		bot:SelectWeapon("weapon_physgun")
	end

	if bot:GetEyeTrace().Entity == bot.TargetEnt then
		buttons = buttons + IN_ATTACK
	end


	--[[if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
		buttons = buttons + IN_RELOAD
	end]]--

	-- Half-Life 2 has a auto-reload system

	if !IsValid(bot.TargetEnt) and (!bot.botPos or bot:GetPos():Distance(bot.botPos) < 60 or math.abs(bot.LastSegmented - CurTime()) > 10) then
		bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 12500})
		bot.LastSegmented = CurTime()
	elseif IsValid(bot.TargetEnt) then
		bot.botPos = bot.TargetEnt:GetPos()
	end

	bot.ControllerBot.PosGen = bot.botPos

	if bot.ControllerBot.P then
		bot.LastPath = bot.ControllerBot.P:GetAllSegments()
	end

	if !bot.ControllerBot.P then
		return
	end

	if bot.CurSegment ~= 2 and !table.EqualValues( bot.LastPath, bot.ControllerBot.P:GetAllSegments() ) then
		bot.CurSegment = 2
	end

	if !bot.LastPath then return end
	local curgoal = bot.LastPath[bot.CurSegment]
	if !curgoal then return end

	if bot:GetPos():Distance(curgoal.pos) < 50 and bot.LastPath[bot.CurSegment + 1] then
		curgoal = bot.LastPath[bot.CurSegment + 1]
	end

	cmd:SetButtons(buttons)

	------------------------------
	--------[[BOT EYES]]---------
	------------------------------

	if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt then
		local shouldvegoneforthehead = bot.TargetEnt:EyePos()
		local group = math.random(0, bot.TargetEnt:GetHitBoxGroupCount() - 1)
		local bone = bot.TargetEnt:GetHitBoxBone(math.random(0, bot.TargetEnt:GetHitBoxCount(group) - 1), group) or 0
		shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bone)

		bot:SetEyeAngles((shouldvegoneforthehead - bot:GetShootPos()):Angle())
		return
	elseif bot:GetPos():Distance(curgoal.pos) > 20 then
		bot:SetEyeAngles(LerpAngle(0.4, bot:EyeAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))
	end
end