--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = true
LeadBot.Gamemode = "nzombies-unlimited"
LeadBot.TeamPlay = true
LeadBot.LerpAim = false
LeadBot.NoNavMesh = true

--[[GAMEMODE CONFIGURATION END]]--
local ROUND = {}
local SETTINGS = {}

--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.Gamemode = "nzombies-unlimited"

--[[GAMEMODE CONFIGURATION END]]--

hook.Add("InitPostEntity", "nzbotInit", function()
    if nzu and nzu.GetExtension("Core") then
        ROUND = nzu.Round
        SETTINGS = nzu.GetExtension("Core").Settings
    elseif nzu and nzu.GetExtension("core") then
        ROUND = nzu.Round
        SETTINGS = nzu.GetExtension("core").Settings
    end
end)

if nzu and nzu.GetExtension("Core") then
    ROUND = nzu.Round
    SETTINGS = nzu.GetExtension("Core").Settings
elseif nzu and nzu.GetExtension("core") then
    ROUND = nzu.Round
    SETTINGS = nzu.GetExtension("core").Settings
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
        if ply.LeadBot and ROUND.State ~= ROUND_ONGOING then
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

hook.Add("nzu_PlayerDowned", "leadbot_Downed", function(bot)
	if bot.LeadBot then
		LeadBot.TalkToMe(bot, "downed")
	end
end)

function LeadBot.Think()
    for _, bot in pairs(player.GetBots()) do
        if bot.LeadBot then
            if bot.LeadBot and !bot:Alive() and ROUND.State ~= ROUND_ONGOING then bot:Spawn() end
            if IsValid(bot:GetActiveWeapon()) then
                local wep = bot:GetActiveWeapon()
                local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                print(wep:Clip1())
                bot:SetAmmo(999, ammoty)
                if !wep.Cocked and wep.CockAfterShot then
                    wep:CockLogic()
                end
            end
        end
    end
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()

    if !LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) and math.random(2) == 1 then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(bot.UseEnt) and math.random(2) == 1 then
        buttons = buttons + IN_USE
    end

    if IsValid(bot.TargetEnt) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    bot.TargetEnt = nil
    bot.FollowPly = Entity(1)
    bot.UseEnt = nil

    local plyDis = bot:GetPos():Distance(bot.FollowPly:GetPos())
    local weapon = bot:GetActiveWeapon()

    --cmd:SetForwardMove(250)

    ------------------------------
    -----[[ENTITY DETECTION]]-----
    ------------------------------

    for k, v in pairs(ents.GetAll()) do
        if IsValid(weapon) and !v:IsPlayer() and v:GetPos():Distance(bot:GetPos()) < 180 then
            local class = v:GetClass()
            local data = v:GetDoorData()
			--[[if v:IsPlayer() and v:GetPos():Distance(bot:GetPos()) < 320 and v:GetIsDowned() then
				bot.UseTarget = v
            else]]if v.Base == "nzu_zombie_base" then -- Zombie
                local targetpos = v:EyePos() or v:GetPos()
                if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v then
                    bot.TargetEnt = v
                end
			elseif plyDis < 300 then
                if istable(data) and data.Price <= bot:GetPoints() then -- Door
                    bot.UseEnt = v
                elseif ((class == "nzu_barricade" and v:GetCanBeRepaired()) or (class == "nzu_wallbuy" and v:GetPrice() <= bot:GetPoints() and weapon:GetClass() ~= v:GetWeaponClass() and bot.LastGunPrice <= v:GetPrice())) and !bot.TargetEnt then -- Misc
                    bot.UseEnt = v
                end
            end
        end
    end

    ------------------------------
    --------[[BOT LOGIC]]---------
    ------------------------------

    mv:SetForwardSpeed(1200)

    if !IsValid(bot.TargetEnt) and !IsValid(bot.UseEnt) and (!bot.botPos or bot:GetPos():Distance(bot.botPos) < 60 or math.abs(bot.LastSegmented - CurTime()) > 10) then
        -- find a random spot on the map, and in 10 seconds do it again!
        if strategy == 1 then
            bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 12500})
            bot.LastSegmented = CurTime()
        else
            bot.botPos = bot.FollowPly:GetPos()
        end
    elseif IsValid(bot.UseEnt) and !IsValid(bot.TargetEnt) then
        bot.botPos = bot.UseEnt:GetPos()

        local class = bot.UseEnt:GetClass()

        if bot:GetPos():Distance(bot.UseEnt:GetPos()) <= 50 then
            if !bot.UseEnt:IsPlayer() then
                bot:SetEyeAngles(((bot.UseEnt:GetPos() + Vector(0, 0, 40)) - bot:GetShootPos()):Angle())
                bot.UseEnt:Use(bot, bot, USE_SET, 1)
                return
            end
            cmd:SetForwardMove(-250)
        elseif (class == "nzu_wallbuy" or bot.UseEnt:GetDoorData()) and bot:GetPos():Distance(bot.UseEnt:GetPos()) <= 450 then
            if class == "nzu_wallbuy" then
                bot.LastGunPrice = tonumber(bot.UseEnt:GetPrice())
                bot.UseEnt:Use(bot, bot, USE_SET, 1)
            else
                nzu.BuyDoor(bot.UseEnt, bot)
            end
            bot:SetEyeAngles(((bot.UseEnt:GetPos() + Vector(0, 0, 40)) - bot:GetShootPos()):Angle())
        end
    elseif IsValid(bot.TargetEnt) then
        local distance = bot.TargetEnt:GetPos():Distance(bot:GetPos())
        bot.botPos = bot.TargetEnt:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        if distance <= 300 then
            mv:SetForwardSpeed(-1200)
        end
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

    -- think one step ahead!
    if bot:GetPos():Distance(curgoal.pos) < 50 and bot.LastPath[bot.CurSegment + 1] then
        curgoal = bot.LastPath[bot.CurSegment + 1]
    end

    ------------------------------
    --------[[BOT EYES]]---------
    ------------------------------

    local lerp = 1

    mv:SetMoveAngles(LerpAngle(lerp, mv:GetMoveAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))

    if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt then
        local shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bot.TargetEnt:LookupBone("ValveBiped.Bip01_Head1")) or bot.TargetEnt:EyePos()
        local cang = --[[LerpAngle(lerp, bot:EyeAngles(), ]](shouldvegoneforthehead - bot:GetShootPos()):Angle() --)
        bot:SetEyeAngles(Angle(cang.p, cang.y, 0)) --[[+ bot:GetViewPunchAngles()]]
        return
    elseif bot:GetPos():Distance(curgoal.pos) > 20 then
        local ang2 = ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()
        local ang = LerpAngle(lerp, mv:GetMoveAngles(), ang2)
        --local cang = LerpAngle(lerpc, bot:EyeAngles(), ang2)
        bot:SetEyeAngles(Angle(ang2.p, ang2.y, 0))
        mv:SetMoveAngles(ang)
    end
end