local ROUND = {}
local SETTINGS = {}

--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.Gamemode = "nzombies-unlimited"

--[[GAMEMODE CONFIGURATION END]]--

hook.Add("InitPostEntity", "nzbotInit", function()
	if nzu then
		ROUND = nzu.Round
		SETTINGS = nzu.GetExtension("Core").Settings
	end
end)

if nzu then
	ROUND = nzu.Round
	SETTINGS = nzu.GetExtension("Core").Settings
end

function LeadBot.FindClosest(bot)
	if bot.BotStrategy == 1 then
		local zombies = ents.FindByClass("nzu_zombie")
		local distancez = 9999
		local zombie = ents.FindByClass("nzu_zombie")[1]
		local distancezombie = 9999
		for k, v in pairs(zombies) do
			distancez = v:GetPos():Distance(bot:GetPos())
			if distancez > distancezombie and v ~= bot and v:Health() > 1 then
				distancez = distancezombie
				zombie = v
			end
		end

		bot.FollowZombie = zombie
	end

	local players = player.GetHumans()
	local distance = 9999
	local playing = player.GetHumans()[1]
	local distanceplayer = 9999
	for k, v in pairs(players) do
		distanceplayer = v:GetPos():Distance(bot:GetPos())
		if distance > distanceplayer and v ~= bot then
			distance = distanceplayer
			playing = v
		end
	end

	bot.FollowPly = playing
end

hook.Add("PlayerSpawn", "leadbot_spawn", function(ply)
	timer.Simple(0.1, function()
		if ply.LeadBot and ROUND.State ~= ROUND_WAITING then
			ply.LastGunPrice = 0
			ply:SetNoCollideWithTeammates(true)
			ply:SetAvoidPlayers(false)
			ply:Give(SETTINGS.StartWeapon)
		end
	end)
end)

hook.Add("nzu_GameStarted", "leadbot_Restart", function()
	for k, v in pairs(player.GetBots()) do
	local ply = v
	timer.Simple(0.1, function()
		if ply.LeadBot then
			ply:Spawn()
			ply.LastGunPrice = 0
			ply:SetNoCollideWithTeammates(true)
			ply:SetAvoidPlayers(false)
			ply:Give(SETTINGS.StartWeapon)
		end
	end)
	end
end)

function LeadBot.Think()
	for _, bot in pairs(player.GetBots()) do
		if bot.LeadBot then
			if bot.LeadBot and !bot:Alive() and ROUND.State == ROUND_WAITING then bot:Spawn() end
			if IsValid(bot:GetActiveWeapon()) then
				local wep = bot:GetActiveWeapon()
				local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
				bot:SetAmmo(999, ammoty)
				if !wep.Cocked and wep.CockAfterShot then
					wep:CockLogic()
				end
			end
		end
	end
end

function LeadBot.StartCommand(bot, cmd)
	if bot.LeadBot and ROUND.State ~= ROUND_WAITING then
		cmd:ClearMovement()
		cmd:ClearButtons()

		if bot.ControllerBot:GetPos() ~= bot:GetPos() then
			bot.ControllerBot:SetPos( bot:GetPos() )
		end

		bot.TargetEnt = nil
		bot.UseTarget = nil
		bot.FollowPly = Entity(1)

		if #player.GetHumans() > 0 then
			LeadBot.FindClosest(bot)
		end

		local FollowPlyDistance = bot:GetPos():Distance(bot.FollowPly:GetPos())
		local weapon = bot:GetActiveWeapon()

		cmd:SetForwardMove(250)

		------------------------------
		-----[[ENTITY DETECTION]]-----
		------------------------------

		for k, v in pairs(ents.GetAll()) do
			if IsValid(weapon) and !v:IsPlayer() and v:GetPos():Distance(bot:GetPos()) < 180 then
				local class = v:GetClass()
				local data = v:GetDoorData()

				if v.Base == "nzu_zombie_base" then -- Zombie
					local targetpos = v:EyePos() or v:GetPos()

					if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v then
						bot.TargetEnt = v
					end
				elseif FollowPlyDistance < 300 then
					if istable(data) and data.Price <= bot:GetPoints() then -- Door
					-- nzu.BuyDoor( v, bot )
						bot.UseTarget = v
					--elseif class == "nzu_wallbuy" and v:GetPrice() <= bot:GetPoints() and weapon:GetClass() ~= v:GetWeaponClass() and bot.LastGunPrice <= v:GetPrice() then -- Gun
						--print(v:GetWepClass())
						-- v:Use(bot, bot, USE_SET, 1)
						 --bot.UseTarget = v
						-- bot.LastGunPrice = tonumber(v:GetPrice())
						-- timer.Simple(0.1, function() bot:SelectWeapon(v:GetWeaponClass()) end)
					elseif ((class == "nzu_barricade" and v:GetCanBeRepaired()) or (class == "nzu_wallbuy" and v:GetPrice() <= bot:GetPoints() and weapon:GetClass() ~= v:GetWeaponClass() and bot.LastGunPrice <= v:GetPrice())) and !bot.TargetEnt then -- Misc
						bot.UseTarget = v
					end
				end
			elseif v:IsPlayer() then
				if v:GetPos():Distance(bot:GetPos()) < 320 and v:GetIsDowned() then
					bot.UseTarget = v
				end

				if !IsValid(bot.FollowZombie) and v:Alive() and !v:IsBot() and bot:GetPos():Distance(v:GetPos()) < 100 and !IsValid(bot.UseTarget) then
					cmd:SetForwardMove(-250)
				end
			end
		end

		------------------------------
		--------[[BOT LOGIC]]---------
		------------------------------

		if bot.FollowPly:Crouching() then
			cmd:SetButtons(IN_DUCK)
		else
			cmd:SetButtons(IN_SPEED)
		end


		if IsValid(bot.TargetEnt) then
			if bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 200 then
				cmd:SetForwardMove(-250)
			end

			if IsValid(weapon) and math.random(2) == 1 then
				cmd:SetButtons(IN_ATTACK)
			end
		end

		if IsValid(weapon) and weapon:Clip1() == 0 and math.random(2) == 1 then
			cmd:SetButtons(IN_RELOAD)
		end

		local botPos = bot.FollowPly:GetPos()

		if IsValid(bot.FollowZombie) then
			botPos = bot.FollowZombie:GetPos()
		end

		if IsValid(bot.UseTarget) and !IsValid(bot.TargetEnt) then
			cmd:SetButtons(IN_USE)

			botPos = bot.UseTarget:GetPos()
			local class = bot.UseTarget:GetClass()

			if bot:GetPos():Distance(bot.UseTarget:GetPos()) <= 50 then
				if !bot.UseTarget:IsPlayer() then -- dumb bots cant even use planks right
					bot:SetEyeAngles(((bot.UseTarget:GetPos() + Vector(0, 0, 40)) - bot:GetShootPos()):Angle())
					bot.UseTarget:Use(bot, bot, USE_SET, 1)
					return -- don't ruin the little performance we have
				end

				cmd:SetForwardMove(-250)
			elseif (class == "nzu_wallbuy" or bot.UseTarget:GetDoorData()) and bot:GetPos():Distance(bot.UseTarget:GetPos()) <= 100 then
				if class == "nzu_wallbuy" then
					bot.LastGunPrice = tonumber(bot.UseTarget:GetPrice())
					bot.UseTarget:Use(bot, bot, USE_SET, 1)
				else
					nzu.BuyDoor(bot.UseTarget, bot)
				end

				bot:SetEyeAngles(((bot.UseTarget:GetPos() + Vector(0, 0, 40)) - bot:GetShootPos()):Angle())
			end
		end

		bot.ControllerBot.PosGen = botPos -- navmesh.GetNavArea(Entity(1):GetPos(), 1):GetCenter() or Entity(1):GetPos()

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
		if !curgoal then return end -- why tf does this not work??

		if bot:GetPos():Distance(curgoal.pos) < 50 and bot.LastPath[bot.CurSegment + 1] then
			curgoal = bot.LastPath[bot.CurSegment + 1] -- does this work? hell if I know!
		end

		------------------------------
		--------[[BOT EYES]]---------
		------------------------------

		if IsValid(bot.TargetEnt) then
			local shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bot.TargetEnt:LookupBone("ValveBiped.Bip01_Head1")) or bot.TargetEnt:EyePos()
			bot:SetEyeAngles((shouldvegoneforthehead - bot:GetShootPos()):Angle())
		elseif IsValid(bot.UseTarget) and bot.UseTarget:IsPlayer() then
			bot:SetEyeAngles((bot.UseTarget:GetPos() - bot:GetShootPos()):Angle())
		elseif curgoal and bot:GetPos():Distance(curgoal.pos) > 20 then
			bot:SetEyeAngles(((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle())
		end
	end
end