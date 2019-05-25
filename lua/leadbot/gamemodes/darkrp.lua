--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = false
LeadBot.Gamemode = "darkrp"

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
	timer.Simple(0, function()
		bot:SetPlayerColor(bot.BotColor)
	end)
end

function LeadBot.StartCommand(bot, cmd)
	cmd:ClearMovement()
	cmd:ClearButtons()

	if bot.ControllerBot:GetPos() ~= bot:GetPos() then
		bot.ControllerBot:SetPos( bot:GetPos() )
	end

	cmd:SetForwardMove(250)

	------------------------------
	-----[[ENTITY DETECTION]]-----
	------------------------------

	for k, v in pairs(ents.GetAll()) do
		if v:GetClass() == "prop_door_rotating" and v:GetPos():Distance(bot:GetPos()) < 70 then
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

	bot:SelectWeapon("weapon_keys")

	--[[if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
		buttons = buttons + IN_RELOAD
	end]]--

	-- Half-Life 2 has a auto-reload system

	if (!bot.botPos or bot:GetPos():Distance(bot.botPos) < 60 or math.abs(Entity(2).LastSegmented - CurTime()) > 10) then
		bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 12500})
		bot.LastSegmented = CurTime()
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

	if bot:GetPos():Distance(curgoal.pos) > 20 then
		bot:SetEyeAngles(LerpAngle(0.4, bot:EyeAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))
	end
end