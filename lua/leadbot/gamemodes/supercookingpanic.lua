--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.Gamemode = "supercookingpanic"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

local teampots = {}
local props = {}
local lastpropindex = 0

function LeadBot.AddBotOverride(bot)
    hook.Call("AutoTeam", gmod.GetGamemode(), bot)
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = (bot:LBGetStrategy() == 1 and IN_SPEED) or 0
    local controller = bot.ControllerBot

    if !IsValid(controller) then return end

    if IsValid(bot.PropGrab) and math.random(2) == 1 then
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

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.Think()
    if lastpropindex < CurTime() then
        props = {}
        for _, ent in pairs(ents.GetAll()) do
            if ent:IsIngredient() then
                table.insert(props, ent)
            end
        end

        lastpropindex = CurTime() + 1
    end

    for _, bot in pairs(player.GetAll()) do
        if bot:IsLBot() and bot:Team() ~= TEAM_SPECTATOR then
            if !IsValid(teampots[bot:Team()]) then
                for _, pot in pairs(ents.FindByClass("scookp_cooking_pot")) do
                    if pot:GetTeam() == bot:Team() then
                        teampots[bot:Team()] = pot
                    end
                end
            end

            if bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
            end
        end
    end
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if !IsValid(teampots[bot:Team()]) then return end

    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

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

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) then
        if dt.Entity:GetClass() == "prop_door_rotating" then
            dt.Entity:Fire("OpenAwayFrom", bot, 0)
        elseif dt.Entity:IsIngredient() and IsValid(bot:GetActiveWeapon()) then
            if !dt.Entity.StuckIngredient then
                dt.Entity.StuckIngredient = CurTime() + 1
            elseif dt.Entity.StuckIngredient + 0.1 < CurTime() then
                dt.Entity.StuckIngredient = nil
            elseif dt.Entity.StuckIngredient < CurTime() then
                local worldcenter = dt.Entity:WorldSpaceCenter()
                local eyepos = bot:EyePos()
                dt.Entity.StuckIngredient = CurTime() + 1
                bot:SetEyeAngles((eyepos - worldcenter):Angle())
                bot:GetActiveWeapon():DropIngredient()
                bot:SetEyeAngles((worldcenter - eyepos):Angle())
                bot:GetActiveWeapon():GrabIngredient()
            end
        end
    end

    if bot:IsHoldingIngredient() then
        controller.PosGen = teampots[bot:Team()]:GetPos()
    elseif IsValid(bot.PropGrab) then
        controller.PosGen = bot.PropGrab:GetPos()

        if bot.PropGiveUp and bot.PropGiveUp < CurTime() then
            bot.PropGrab = nil
        end
    elseif !controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime() then
        -- find a random spot on the map, and in 10 seconds do it again!
        controller.PosGen = controller:FindSpot("random", {radius = 12500})
        controller.LastSegmented = CurTime() + 10
        controller.LookAtTime = CurTime() + 0.5
        controller.LookAt = Angle(math.random(-20, 20), math.random(-180, 180), 0)
    end

    bot.PropAttempt = bot.PropAttempt or 0

    if bot.PropAttempt < CurTime() and !IsValid(bot.PropGrab) then
        local closest = nil
        local distance = 99999999

        for _, prop in pairs(props) do
            if !IsValid(prop) or prop:IsPlayer() or util.QuickTrace(bot:EyePos(), prop:WorldSpaceCenter() - bot:EyePos(), bot).Entity ~= prop then continue end

            local dis = prop:GetPos():DistToSqr(bot:GetPos())
            if dis < distance then
                closest = prop
                distance = dis
            end
        end

        if IsValid(closest) and closest ~= bot.PropLast then
            bot.PropGrab = closest
            bot.PropLast = closest
            bot.PropGiveUp = CurTime() + 3
        end

        -- TODO: Powerup Support
        if bot:HasPowerUP() then
            bot:DropPowerUP()
        end

        bot.PropAttempt = CurTime() + 1
    end

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
    local ft = FrameTime()
    local lerp = ft * math.random(6, 8)
    local lerpc = ft * 3

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)

    if bot:IsHoldingIngredient() and util.QuickTrace(bot:EyePos(), teampots[bot:Team()]:WorldSpaceCenter() - bot:EyePos(), bot).Entity == teampots[bot:Team()] then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (teampots[bot:Team()]:WorldSpaceCenter() - bot:GetShootPos()):Angle()))
    elseif !bot:IsHoldingIngredient() and IsValid(bot.PropGrab) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (bot.PropGrab:WorldSpaceCenter() - bot:GetShootPos()):Angle()))
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