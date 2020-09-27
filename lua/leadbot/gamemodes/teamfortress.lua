--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = false
LeadBot.Gamemode = "teamfortress"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true
local classtb = {"scout", "soldier", "pyro", "heavy", "demoman", "sniper", "engineer"} -- "scout", "soldier", "pyro", "engineer", "heavy", "demoman", "sniper", "medic", "spy"
local classtbmvm = {"scout","scout","scout","soldier","soldier","soldier","soldier","pyro","pyro","pyro","pyro","pyro","pyro","demoman","demoman","demoman","demoman","demoman","heavy","heavy","heavy","heavy","heavy","spy","spy","spy","sniper","sniper","engineer","engineer","engineer","engineer","engineer","engineer","medic","medic","medic","medic","sentrybuster","sentrybuster","sentrybuster","giantscout","giantpyro","giantheavy","giantsoldier","giantmedic","superscout","giantheavyshotgun","giantheavyheater","giantsoldierrapidfire","giantsoldiercharged","soldierbuffed","soldierblackbox","soldierblackbox","soldierblackbox","soldierblackbox","soldierblackbox","soldierblackbox","soldierblackbox","soldierblackbox","soldierblackbox","soldierbuffed","soldierbuffed","demoknight","demoknight","demoknight","demoknight","demoknight","demoknight","demoknight","soldierbuffed","soldierbuffed","soldierbuffed","heavyshotgun","heavyshotgun","heavyshotgun","heavyshotgun","heavyweightchamp","heavyweightchamp","heavyweightchamp","heavyweightchamp","melee_scout","melee_scout_sandman","melee_scout_sandman","melee_scout_sandman","melee_scout_sandman","melee_scout","melee_scout","melee_scout","melee_scout","melee_scout","melee_scout","melee_scout","melee_scout","ubermedic","ubermedic","ubermedic","ubermedic","ubermedic","ubermedic"}
 
function LeadBot.PlayerSpawn(bot)
    -- no class, pick one!
    if bot.LeadBot and bot:IsBot() and bot:GetPlayerClass() == "gmodplayer" then
		local class = table.Random(classtb)
		bot:SetPlayerClass(class)
    end
end

function LeadBot.PostPlayerDeath(bot)
	bot.BuildingStuff = false

	timer.Simple(7, function()
		if IsValid(bot) and LeadBot.RespawnAllowed and !bot:Alive() then
			bot:Spawn()
		end
	end)
end

function LeadBot.StartCommand(bot, cmd)

    local controller = bot.ControllerBot
 	cmd:ClearMovement()
	cmd:ClearButtons()

    local target = controller.Target
	if bot.ControllerBot:GetPos() ~= bot:GetPos() then
		bot.ControllerBot:SetPos( bot:GetPos() )
	end

	bot.TargetEnt = nil
	bot.LastBuildTime = bot.LastBuildTime or CurTime() + 7 + math.random(0, 30)

	if bot.BuildingStuff then return end

	bot.TargetEnt = nil

	cmd:SetForwardMove(250)

	------------------------------
	-----[[ENTITY DETECTION]]-----
	------------------------------

	for k, v in pairs(ents.GetAll()) do
		if v:IsPlayer() and v ~= bot and v:GetPos():Distance(bot:GetPos()) < 1500 then
			local targetpos = v:EyePos() or v:GetPos()

			if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v and !v:IsFriendly(bot) then
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

    if IsValid(target) then
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

	if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt and !bot.TargetEnt:IsFriendly(bot) then
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


function LeadBot.AddBot()
    if !FindMetaTable("NextBot").GetFOV then
        ErrorNoHalt("You must be using the dev version of Garry's mod!\nhttps://wiki.facepunch.com/gmod/Dev_Branch\n")
        return
    end

    if !navmesh.IsLoaded() and !LeadBot.NoNavMesh then
        ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
        return
    end

    if #player.GetAll() == game.MaxPlayers() then
        MsgN("[LeadBot] Player limit reached!")
        return
    end

    local original_name
    local generated = "Leadbot #" .. #player.GetBots() + 1
    local model = ""
    local color = Vector(-1, -1, -1)
    local weaponcolor = Vector(0.30, 1.80, 2.10)
    local strategy = 0

    if GetConVar("leadbot_names"):GetString() ~= "" then
        generated = table.Random(string.Split(GetConVar("leadbot_names"):GetString(), ","))
    elseif GetConVar("leadbot_models"):GetString() == "" then
        name = "TFBot" 
    end

    if LeadBot.PlayerColor == "default" then
        generated = "Kleiner"
    end

    generated = GetConVar("leadbot_name_prefix"):GetString() .. generated

    local name = LeadBot.Prefix .. generated
    local bot = player.CreateNextBot(name)

    if !IsValid(bot) then
        MsgN("[LeadBot] Unable to create bot!")
        return
    end

    bot.LeadBot_Config = {}
    bot.LeadBot_Config[1] = model
    bot.LeadBot_Config[2] = color
    bot.LeadBot_Config[3] = weaponcolor
    bot.LeadBot_Config[4] = strategy

    -- for legacy purposes, will be removed soon when gamemodes are updated
    bot.BotStrategy = strategy
    bot.OriginalName = original_name
    bot.ControllerBot = ents.Create("leadbot_navigator")
    bot.ControllerBot:Spawn()
    bot.ControllerBot:SetOwner(bot)
    bot.LeadBot = true
	timer.Simple(0.1, function()
		bot:TakeDamage(bot:Health())
	end)
    LeadBot.AddBotOverride(bot)
    LeadBot.AddBotControllerOverride(bot, bot.ControllerBot)
    MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
end

function LeadBot.PlayerMove(bot, cmd, mv)
    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end
	
    --[[local min, max = controller:GetModelBounds()
    debugoverlay.Box(controller:GetPos(), min, max, 0.1, Color(255, 0, 0, 0), true)]]

    -- force a recompute
    if controller.PosGen and controller.P and controller.TPos ~= controller.PosGen then
        controller.TPos = controller.PosGen
        controller.P:Compute(controller, controller.PosGen)
    end

    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end

    mv:SetForwardSpeed(1200)

    if (bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= bot and ((ply:IsPlayer() and (!LeadBot.TeamPlay or (LeadBot.TeamPlay and (ply:Team() ~= bot:Team())))) or ply:IsNPC()) and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 then
                --[[local targetpos = ply:EyePos() - Vector(0, 0, 10)
                local trace = util.TraceLine({
                    start = bot:GetShootPos(),
                    endpos = targetpos,
                    filter = function(ent) return ent == ply end
                })]]

                if ply:Alive() and controller:IsAbleToSee(ply) then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + 2
                end
            end
        end
    elseif controller.ForgetTarget < CurTime() and controller:IsAbleToSee(controller.Target) then
        controller.ForgetTarget = CurTime() + 2
    end
	if string.find(game.GetMap(), "ctf_") then -- CTF AI
		for k, v in pairs(ents.FindByClass("item_teamflag")) do
			if v.TeamNum ~= bot:Team() then
				intel = v
			else
				fintel = v
			end
		end

		for k, v in pairs(ents.FindByClass("func_capturezone")) do
			if v.TeamNum ~= bot:Team() then
				intelcap = v
			else
				fintelcap = v
			end
		end

		if !intel.Carrier and !fintel.Carrier then -- neither intel has a capture
			targetpos2 = intel:GetPos() -- goto enemy intel
			ignoreback = true
		elseif intel.Carrier == bot then -- or if friendly intelligence has capture
			targetpos2 = fintelcap.Pos -- goto friendly cap spot
			ignoreback = true
		elseif intel.Carrier then -- or else if we have it already carried
			targetpos2 = intel.Carrier:GetPos() -- follow that man
		end
	end
	if string.find(game.GetMap(), "mvm_") then -- CTF AI
		for k, v in pairs(ents.FindByClass("item_teamflag_mvm")) do
			if v.TeamNum ~= bot:Team() then
				intel = v
				fintel = v
			end
		end

		for k, v in pairs(ents.FindByClass("func_capturezone")) do
			if v.TeamNum ~= bot:Team() then
				intelcap = v
			else
				fintelcap = v
			end
		end

		if !intel.Carrier and !fintel.Carrier then -- neither intel has a capture
			targetpos2 = intel:GetPos() -- goto enemy intel
			ignoreback = true
		elseif intel.Carrier == bot then -- or if friendly intelligence has capture
			targetpos2 = fintelcap.Pos -- goto friendly cap spot
			ignoreback = true
		elseif intel.Carrier then -- or else if we have it already carried
			targetpos2 = intel.Carrier:GetPos() -- follow that man
		end
	end
	bot.botPos = targetpos2
    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        -- find a random spot on the map, and in 10 seconds do it again!
        controller.PosGen = controller:FindSpot("random", {radius = 12500})
        controller.LastSegmented = CurTime() + 10
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= 90000 then
            mv:SetForwardSpeed(-1200)
        end
    end

    -- movement also has a similar issue, but it's more severe...
    if !controller.P then
        return
    end

    local segments = controller.P:GetAllSegments()

    if !segments then return end

    local cur_segment = controller.cur_segment
    local curgoal = segments[cur_segment]

    -- got nowhere to go, why keep moving?
    if !curgoal then
        mv:SetForwardSpeed(0)
        return
    end

    -- think every step of the way!
    if segments[cur_segment + 1] and Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curgoal.pos.x, curgoal.pos.y)) < 100 then
        controller.cur_segment = controller.cur_segment + 1
        curgoal = segments[controller.cur_segment]
    end

    local goalpos = curgoal.pos

    -- waaay too slow during gamplay
    --[[if bot:GetVelocity():Length2DSqr() <= 225 and controller.NextCenter == 0 and controller.NextCenter < CurTime() then
        controller.NextCenter = CurTime() + math.Rand(0.5, 0.65)
    end

    if controller.NextCenter ~= 0 and controller.NextCenter < CurTime() then
        if bot:GetVelocity():Length2DSqr() <= 225 then
            controller.strafeAngle = ((controller.strafeAngle == 1 and 2) or 1)
        end

        controller.NextCenter = 0
    end]]

    if bot:GetVelocity():Length2DSqr() <= 225 then
        if controller.NextCenter < CurTime() then
            controller.strafeAngle = ((controller.strafeAngle == 1 and 2) or 1)
            controller.NextCenter = CurTime() + math.Rand(0.3, 0.65)
        elseif controller.nextStuckJump < CurTime() then
            if !bot:Crouching() then
                controller.NextJump = 0
            end
            controller.nextStuckJump = CurTime() + math.Rand(1, 2)
        end
    end

    if controller.NextCenter > CurTime() then
        if controller.strafeAngle == 1 then
            mv:SetSideSpeed(1500)
        elseif controller.strafeAngle == 2 then
            mv:SetSideSpeed(-1500)
        else
            mv:SetForwardSpeed(-1500)
        end
    end

    -- jump
    if controller.NextJump ~= 0 and curgoal.type > 1 and controller.NextJump < CurTime() then
        controller.NextJump = 0
    end

    -- duck
    if curgoal.area:GetAttributes() == NAV_MESH_CROUCH then
        controller.NextDuck = CurTime() + 0.1
    end

    controller.goalPos = goalpos

    if GetConVar("developer"):GetBool() then
        controller.P:Draw()
    end

    -- eyesight
    local lerp = FrameTime() * math.random(8, 10)
    local lerpc = FrameTime() * 8

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)

    if IsValid(controller.Target) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
        return
    else
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end
    end
end
