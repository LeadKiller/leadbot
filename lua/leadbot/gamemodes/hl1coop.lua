--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.Gamemode = "hl1coop"
LeadBot.SetModel = false
LeadBot.LerpAim = false

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.FindClosest(bot)
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
		if ply.LeadBot then
			ply:SetNoCollideWithTeammates(true)
			ply:SetAvoidPlayers(false)
		end
	end)
end)

function LeadBot.Think()
	for _, bot in pairs(player.GetBots()) do
		if bot.LeadBot then
			if bot.LeadBot and !bot:Alive() then bot:Spawn() end
			if IsValid(bot:GetActiveWeapon()) then
				local wep = bot:GetActiveWeapon()
				local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
				bot:SetAmmo(999, ammoty)
			end
		end
	end
end

function LeadBot.StartCommand(bot, cmd)
	cmd:ClearMovement()
	cmd:ClearButtons()

	LeadBot.FindClosest(bot)

	if bot.ControllerBot:GetPos() ~= bot:GetPos() then
		bot.ControllerBot:SetPos( bot:GetPos() )
	end

	bot.TargetEnt = nil

	cmd:SetForwardMove(500)

	------------------------------
	-----[[ENTITY DETECTION]]-----
	------------------------------

	for k, v in pairs(ents.GetAll()) do
		if v:GetClass() == "trigger_changelevel" then
			bot.TargetPos = v:GetPos()
		end
	end

	------------------------------
	--------[[BOT LOGIC]]---------
	------------------------------

	local buttons = 0

	bot:SelectWeapon("weapon_crowbar")

	if bot:GetEyeTrace().Entity == bot.TargetEnt then
		buttons = buttons + IN_ATTACK
	end


	--[[if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
		buttons = buttons + IN_RELOAD
	end]]--

	if bot.TargetPos then
		bot.botPos = bot.TargetPos
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

	if bot:GetPos():Distance(curgoal.pos) < 175 and bot.LastPath[bot.CurSegment + 1] then
		curgoal = bot.LastPath[bot.CurSegment]
	end

	debugoverlay.Text(bot:GetPos(), bot:GetPos():Distance(curgoal.pos), 0.02, true)

	cmd:SetButtons(buttons)

	------------------------------
	--------[[BOT EYES]]---------
	------------------------------

	local lerp = 0.4

	if !LeadBot.LerpAim then
		lerp = 1
	end

	if bot:GetPos():Distance(curgoal.pos) > 10 then
		bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))
	end
end