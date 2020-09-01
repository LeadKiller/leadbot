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
            --[[ply:SetNoCollideWithTeammates(true)
            ply:SetAvoidPlayers(false)]]
            ply:Give(SETTINGS.StartWeapon)
        end
    end)
end)

hook.Add("nzu_GameStarted", "leadbot_Restart", function()
    --[[for k, v in pairs(player.GetBots()) do
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
    end]]
end)

hook.Add("nzu_PlayerDowned", "leadbot_Downed", function(bot)
    if bot.LeadBot then
        LeadBot.TalkToMe(bot, "downed")
    end
end)

function LeadBot.Think()
    for _, bot in pairs(player.GetBots()) do
        if bot.LeadBot then
            if bot.LeadBot and !bot:Alive() then bot:ReadyUp() end --and ROUND.State == ROUND_ONGOING then round:Spawn() end
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

    if bot:GetMoveType() == MOVETYPE_LADDER and math.random(2) == 1 then
        buttons = buttons + IN_JUMP
    end

    if IsValid(bot.TargetEnt) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
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
            if v.Base == "nzu_zombie_base" then -- Zombie
                local targetpos = v:EyePos() or v:GetPos()
                if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v then
                    bot.TargetEnt = v
                end
            elseif v:IsPlayer() and v:GetPos():Distance(bot:GetPos()) < 320 and v:GetIsDowned() then
                bot.UseTarget = v
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

    if controller.NextCenter > CurTime() then
        if controller.strafeAngle == 1 then
            mv:SetSideSpeed(1500)
        elseif controller.strafeAngle == 2 then
            mv:SetSideSpeed(-1500)
        else
            mv:SetForwardSpeed(-1500)
        end
    end

    if !IsValid(bot.TargetEnt) and !IsValid(bot.UseEnt) and (!controller.PosGen or bot:GetPos():Distance(controller.PosGen) < 60 or math.abs(controller.LastSegmented- CurTime()) > 10) then
        -- find a random spot on the map, and in 10 seconds do it again!
        if strategy == 1 then
            controller.PosGen = bot.ControllerBot:FindSpot("random", {radius = 12500})
            controller.LastSegmented= CurTime()
        else
            controller.PosGen = bot.FollowPly:GetPos() + VectorRand() * 248
        end
    elseif IsValid(bot.UseEnt) and !IsValid(bot.TargetEnt) then
        controller.PosGen = bot.UseEnt:GetPos()

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
        controller.PosGen = bot.TargetEnt:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        if distance <= 300 then
            mv:SetForwardSpeed(-1200)
        end
    end

    bot.ControllerBot.PosGen = controller.PosGen

    if bot.ControllerBot.P then
        bot.LastPath = bot.ControllerBot.P:GetAllSegments()
    end

    if !bot.ControllerBot.P then
        return
    end

    --[[if bot.CurSegment ~= 2 and !table.EqualValues( bot.LastPath, bot.ControllerBot.P:GetAllSegments() ) then
        bot.CurSegment = 2
    end]]

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

    ------------------------------
    --------[[BOT EYES]]---------
    ------------------------------

    local lerp = 1
    local lerp = FrameTime() * math.random(8, 10)
    local lerpc = FrameTime() * 8

    mv:SetMoveAngles(LerpAngle(lerpc, mv:GetMoveAngles(), ((goalpos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))

    if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt then
        local shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bot.TargetEnt:LookupBone("ValveBiped.Bip01_Head1")) or bot.TargetEnt:EyePos()
        local cang = LerpAngle(lerp, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle())
        bot:SetEyeAngles(Angle(cang.p, cang.y, 0)) --[[+ bot:GetViewPunchAngles()]]
        return
    elseif bot:GetPos():Distance(goalpos) > 20 then
        local ang2 = ((goalpos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()
        local ang = LerpAngle(lerpc, mv:GetMoveAngles(), ang2)
        --local cang = LerpAngle(lerpc, bot:EyeAngles(), ang2)
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), Angle(ang2.p, ang2.y, 0)))
        mv:SetMoveAngles(ang)
    end
end