--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = true
LeadBot.Gamemode = "thehidden"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true
LeadBot.NoSprint = true
LeadBot.NoFlashlight = false

--[[GAMEMODE CONFIGURATION END]]--

local hiddenvisibility = 0
local noHidden = 0
local squadleader
local roundStart = 0

function LeadBot.Think()
    if GetGlobalInt("RoundState", 0) ~= ROUND_ACTIVE then -- == ROUND_ENDED then
        roundStart = CurTime() + math.Rand(5, 10)
        noHidden = 0
        hiddenvisibility = 0
        squadleader = nil

        for _, bot in ipairs(player.GetBots()) do
            if bot:IsLBot() then
                bot.LeadBot_Config[4] = math.random(0, 1)
            end
        end

        return
    end

    for _, bot in ipairs(player.GetBots()) do
        if bot:IsLBot() then
            local wep = bot:GetActiveWeapon()
            if IsValid(wep) then
                local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                bot:SetAmmo(999, ammoty)
            end
        end
    end

    if !IsValid(squadleader) or !squadleader:Alive() or squadleader:LBGetStrategy() == 1 then
        squadleader = table.Random(team.GetPlayers(1))
        -- if squadleader:IsBot() then
        --    squadleader:Say(table.Random({"Taking point!", "Follow me!", "Keep up!", "Stick together!", "Come on!", "Don't fall behind!", "Don't give up!"}))
        --[[else
            squadleader:ChatPrint("You're the squad leader.")]]
        -- end
    end

    local hidden = team.GetPlayers(TEAM_HIDDEN)[1]
    if !IsValid(hidden) then return end
    local vel = hidden:GetVelocity():Length2DSqr()

    if vel > 12000 and vel < 240000 and hiddenvisibility <= 26 then
        hiddenvisibility = math.Clamp(hiddenvisibility + FrameTime() * Lerp(hiddenvisibility / 16, 20, 0), 2, 100)
    elseif noHidden < CurTime() or hidden.PounceDelay > CurTime() then
        hiddenvisibility = math.Clamp(hiddenvisibility - FrameTime() * ((hidden.PounceDelay > CurTime() and 255) or 20), 2, 100)
    end

    --[[for i = 1, 8 do
        hidden:ChatPrint("\n   ")
    end
    hidden:ChatPrint("(BOT) " .. math.floor(hiddenvisibility) .. "% Visibility")]]
    --print("(BOT) " .. math.floor(hiddenvisibility) .. "% Visibility")
end

function LeadBot.PlayerHurt(ply, bot, hp, dmg)
    local hidden = team.GetPlayers(TEAM_HIDDEN)[1]
    if !IsValid(hidden) then return end

    if bot:IsPlayer() then
        if hp <= dmg and math.random(3) == 1 and bot:IsLBot() then
            LeadBot.TalkToMe(bot, "taunt")
        end

        local controller = ply:GetController()

        if hidden == ply then
            if math.random(5) == 1 then
                controller.PosGen = controller:FindSpot("random", {type = "hiding", radius = 3600, pos = bot:GetPos() - Angle(0, bot:GetAngles().y, 0):Forward() * 128})
                controller.LastSegmented = CurTime() + 5
                controller.NoTarget = CurTime() + 6
                controller.Target = nil

                if math.random(100) <= 35 then
                    hidden:SetEyeAngles(Angle(-35, (ply:EyePos() - bot:GetPos()):Angle().y, 0))
                    hidden:Pounce()
                end

                hiddenvisibility = hiddenvisibility + 10

                if bot.LeadBot then
                    bot.ControllerBot.Target = hidden
                    bot.ControllerBot.ForgetTarget = CurTime() + 1
                end
            end
        else
            controller.LookAtTime = CurTime() + 2
            controller.LookAt = ((bot:GetPos() + VectorRand() * 8) - ply:GetPos()):Angle()
            controller.LastHidden = CurTime() + 0.5
            if math.random(3) == 1 then
                controller.Target = bot
                controller.ForgetTarget = CurTime() + 0.25
            end
            hiddenvisibility = hiddenvisibility + 15
        end
    end
end

hook.Add("EntityEmitSound", "leadbot_Hidden", function(data)
    local ent = data.Entity
    if !IsValid(ent) then return end
    local wep
    if ent:IsWeapon() then wep = ent ent = ent.Owner end
    if !IsValid(ent) or !ent:IsPlayer() then return end

    local hidden = team.GetPlayers(TEAM_HIDDEN)[1]
    if !IsValid(hidden) then return end
    if ent == hidden then
        hiddenvisibility = (string.find(data.OriginalSoundName, "pain") and hiddenvisibility + 5) or (string.StartWith(data.OriginalSoundName, "player/hidden") and 75) or hiddenvisibility + 15
        noHidden = (string.StartWith(data.OriginalSoundName, "player/hidden") and CurTime() + 3) or CurTime() + 0.5
    elseif IsValid(wep) then
        for _, bot in ipairs(player.GetAll()) do
            if bot.LeadBot and !isValid(bot.ControllerBot.Target) and bot:GetPos():DistToSqr(data.Pos) <= 90000 then
                bot.ControllerBot.PosGen = data.Pos + VectorRand() * 128
                bot.ControllerBot.LastSegmented = CurTime() + 5
                bot.LookAt = (data.Pos - bot:EyePos()):Angle()
                bot.LookAtTime = CurTime() + 2
            end
        end
    end
end)

function LeadBot.StartCommand(bot, cmd)
    if !bot:Alive() then return end

    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target
    local hidden = team.GetPlayers(TEAM_HIDDEN)[1]
    local ishidden = bot == hidden

    if !IsValid(controller) or !IsValid(hidden) or ishidden and roundStart > CurTime() then return end

    if LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(target) and (!ishidden and controller:CanSee(target) or ishidden and target:GetPos():DistToSqr(bot:GetPos()) <= 8400) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if pos.z > controller:GetPos().z then
            controller.LookAt = Angle(-30, ang.y, 0)
        else
            controller.LookAt = Angle(30, ang.y, 0)
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = buttons + IN_FORWARD
    end

    if controller.NextDuck > CurTime() then
        buttons = buttons + IN_DUCK
    elseif controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    bot:SelectWeapon((IsValid(controller.Target) and controller.Target:GetPos():DistToSqr(controller:GetPos()) < 129000 and "weapon_shotgun") or "weapon_smg1")
    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if !bot:Alive() then return end

    local controller = bot.ControllerBot
    local hidden = team.GetPlayers(TEAM_HIDDEN)[1]
    local ishidden = bot == hidden
    local issquadleader = bot == squadleader

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    if !IsValid(hidden) or !IsValid(squadleader) then return end

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

    if !ishidden and controller.LookAtTime < CurTime() then
        controller.LookAt = Angle(math.random(-30, 30), math.random(-180, 180), 0)
        controller.LookAtTime = CurTime() + math.Rand(0.5, 1)
    end

    mv:SetForwardSpeed(1200)

    --[[if !IsValid(controller.Target) or (!ishidden and ((bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or controller.ForgetTarget < CurTime()) or controller.Target:Health() < 1) then
        controller.Target = nil
    end]]

    if (bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        if !ishidden then
            if hidden:GetPos():DistToSqr(bot:GetPos()) <= 3600 and controller:CanSee(hidden) then
                controller.Target = hidden
                controller.ForgetTarget = CurTime() + 2
            end

            if !controller.LastHidden or controller.LastHidden < CurTime() then
                for _, ply in ipairs(player.GetAll()) do
                    if ply ~= bot and ply == hidden and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 and math.random(100) <= hiddenvisibility then
                        --[[local targetpos = ply:EyePos() - Vector(0, 0, 10)
                        local trace = util.TraceLine({
                            start = bot:GetShootPos(),
                            endpos = targetpos,
                            filter = function(ent) return ent == ply end
                        })]]

                        if ply:Alive() and controller:CanSee(ply) then
                            controller.Target = ply
                            controller.ForgetTarget = CurTime() + 2
                        end
                    end
                end

                controller.LastHidden = CurTime() + math.Rand(0.8, 1.2)
            end
        elseif !controller.NoTarget or controller.NoTarget < CurTime() then
            --[[local closest = nil
            local distance = 99999999

            for _, ply in ipairs(team.GetPlayers(1)) do
                if !IsValid(ply) or !ply:Alive() or ply:GetPos():DistToSqr(hidden:GetPos()) > 20250000 then continue end

                local dis = ply:GetPos():DistToSqr(bot:GetPos())
                if dis < distance then
                    closest = ply
                    distance = dis
                end
            end]]

            local players = {}
            local strat0 = {}
            local strat1 = {}

            for _, ply in ipairs(team.GetPlayers(1)) do
                if !ply:Alive() or ply:GetPos():DistToSqr(hidden:GetPos()) > 20250000 then continue end
                local strat = ((!ply.LeadBot and math.random(0, 1)) or ply:LBGetStrategy())
                if strat == 1 then
                    table.insert(strat1, ply)
                else
                    table.insert(strat0, ply)
                end
            end

            table.sort(strat0, function(a, b)
                return a:GetPos():DistToSqr(bot:GetPos()) < b:GetPos():DistToSqr(bot:GetPos())
            end)

            table.sort(strat1, function(a, b)
                return a:GetPos():DistToSqr(bot:GetPos()) < b:GetPos():DistToSqr(bot:GetPos())
            end)

            table.Add(players, strat1)
            table.Add(players, strat0)

            controller.Target = players[1] -- table.Random(team.GetPlayers(1))
            controller.ForgetTarget = CurTime() + 1
        end
    --[[elseif controller.ForgetTarget < CurTime() and controller:CanSee(controller.Target) then
        controller.ForgetTarget = CurTime() + 2]]
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) then
        if dt.Entity:GetClass() == "prop_door_rotating" then
            dt.Entity:Fire("OpenAwayFrom", bot, 0)
        elseif dt.Entity:GetClass() == "func_breakable_surf" then
            controller.Target = dt.Entity
            controller.ForgetTarget = CurTime() + 1
        end
    end

    if !IsValid(controller.Target) then
        if (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
            if issquadleader or bot:LBGetStrategy() == 1 then
                -- find a random spot on the map, and in 10 seconds do it again!
                controller.PosGen = controller:FindSpot("random", {radius = 12500})
                controller.LastSegmented = CurTime() + 10
            else
                controller.PosGen = squadleader:GetPos() + VectorRand() * 128
                controller.LastSegmented = CurTime() + math.Rand(0.25, 1)
            end
        end
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= ((ishidden and 6100) or 90000) then
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
            local ang = LerpAngle(FrameTime() * 6, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end
    end
end