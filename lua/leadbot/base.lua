
LeadBot.RespawnAllowed = true
LeadBot.SetModel = true

--[[ COMMANDS ]]--

concommand.Add("leadbot_add", function(_, _, args) LeadBot.AddBot() end, nil, "Adds a LeadBot")
concommand.Add("leadbot_kick", function(_, _, args) if args[1] ~= "all" then for k, v in pairs(player.GetAll()) do if string.find(v:GetName(), args[1]) then v:Kick() end end else for k, v in pairs(player.GetBots()) do v:Kick() end end end, nil, "Kicks LeadBots (all is avaliable!)")
CreateConVar("leadbot_strategy", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables the strategy system for newly created bots.")

--[[ FUNCTIONS ]]--

function LeadBot.AddBot()
	if !navmesh.IsLoaded() and !LeadBot.NoNavMesh[engine.ActiveGamemode()] then
		MsgN("There is no navmesh! Generate one using \"nav_generate\"!")
		return
	end

	local name = LeadBot.Prefix .. table.Random(LeadBot.Names)
	local bot = player.CreateNextBot(name)

	bot.BotModel = player_manager.TranslatePlayerModel(table.Random(LeadBot.Models))
	bot.BotColor = Vector(tonumber(0 .. "." .. math.random(0, 9999)), tonumber(0 .. "." .. math.random(0, 9999)), tonumber(0 .. "." .. math.random(0, 9999)))
	bot.BotSkin = math.random(0, 1)
	bot.LastSegmented = CurTime()

	if !LeadBot.Models[1] then
		bot.BotModel = table.Random(player_manager.AllValidModels())
	end

	if LeadBot.SetModel then
		bot:SetModel(bot.BotModel)
		bot:SetPlayerColor(bot.BotColor)
	end

	bot.ControllerBot = ents.Create("leadbot_navigator")
	bot.ControllerBot:Spawn()
	bot.ControllerBot:SetOwner(bot)

	bot.LastPath = nil
	bot.CurSegment = 2
	bot.LeadBot = true

	if GetConVar("leadbot_strategy"):GetBool() then
	    bot.BotStrategy = math.random(0, 1)
	else
		bot.BotStrategy = 0
	end
end

--[[ HOOKS ]]--

hook.Add("InitPostEntity", "LeadBot_InitPostEntity", function()
	if LeadBot.SteamAPIKey ~= "" then
		LeadBot.Names = {}
	end
end)

hook.Add("PostCleanupMap", "LeadBot_PostCleanup", function()
	for k, v in pairs(player.GetBots()) do
		if v.LeadBot then
			v.ControllerBot = ents.Create("leadbot_navigator")
			v.ControllerBot:Spawn()
		end
	end
end)

hook.Add("PlayerDisconnected", "LeadBot_Disconnect", function(bot)
	if IsValid(bot.ControllerBot) then
		bot.ControllerBot:Remove()
	end
end)

hook.Add("StartCommand", "LeadBot_Control", function(bot, cmd)
	if bot.LeadBot then
		LeadBot.StartCommand(bot, cmd)
	end
end)

hook.Add("PostPlayerDeath", "LeadBot_Death", function(bot)
	if bot.LeadBot then
		LeadBot.PostPlayerDeath(bot)
	end
end)

hook.Add("Think", "LeadBot_Think", function()
	LeadBot.Think()
end)

hook.Add("PlayerSpawn", "LeadBot_Spawn", function(bot)
	if bot.LeadBot then
		LeadBot.PlayerSpawn(bot)
	end
end)

--[[ DEFAULT DM AI ]]--

function LeadBot.PlayerSpawn(bot)
	timer.Simple(0, function()
		bot:SetModel(bot.BotModel)
		bot:SetPlayerColor(bot.BotColor)
		bot:SetSkin(bot.BotSkin)
	end)
end

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

	bot.TargetEnt = playing
end

function LeadBot.Think()
	for _, bot in pairs(player.GetBots()) do
		if bot.LeadBot and IsValid(bot:GetActiveWeapon()) then
			local wep = bot:GetActiveWeapon()
			local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
			bot:SetAmmo(999, ammoty)
		end
	end
end

function LeadBot.PostPlayerDeath(bot)
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

	local botWeapon = bot:GetActiveWeapon()

	cmd:SetForwardMove(250)

	------------------------------
	-----[[ENTITY DETECTION]]-----
	------------------------------

	for k, v in pairs(ents.GetAll()) do
		if v:IsPlayer() and v ~= bot and v:GetPos():Distance(bot:GetPos()) < 1500 then
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

	bot:SelectWeapon("weapon_ar2")

	if bot:GetEyeTrace().Entity == bot.TargetEnt then
		buttons = buttons + IN_ATTACK
	end


	--[[if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
		buttons = buttons + IN_RELOAD
	end]]--

	-- Half-Life 2 has a auto-reload system

	if !IsValid(bot.TargetEnt) and (!bot.botPos or bot:GetPos():Distance(bot.botPos) < 60 or math.abs(Entity(2).LastSegmented - CurTime()) > 10) then
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
		local shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bot.TargetEnt:LookupBone("ValveBiped.Bip01_Head1")) or bot.TargetEnt:EyePos()
		local group = math.random(0, bot.TargetEnt:GetHitBoxGroupCount()-1)
		local bone = bot.TargetEnt:GetHitBoxBone(math.random(0, bot.TargetEnt:GetHitBoxCount(group)-1), group) or 0
		shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bone)


		bot:SetEyeAngles(LerpAngle(0.4, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle()))
	elseif bot:GetPos():Distance(curgoal.pos) > 20 then
		bot:SetEyeAngles(LerpAngle(0.4, bot:EyeAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))
	end
end