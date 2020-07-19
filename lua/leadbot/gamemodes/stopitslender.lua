--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = true
LeadBot.Gamemode = "stopitslender"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
    bot.LHP = bot:Health()
    bot.Caution = CurTime() + 30
    bot.LastChat = CurTime()
    if math.random(4) == 1 then
        timer.Simple(math.random(1, 3), function()
            if IsValid(bot) then
                LeadBot.TalkToMe(bot, "join")
            end
        end)
    end
end

function LeadBot.Think()
end

function LeadBot.StartCommand(bot, cmd)
    local controller = bot.ControllerBot

    if !IsValid(controller) then return end

    bot.LHP = bot.LHP or bot:Health()
    bot.Caution = bot.Caution or CurTime() + 30
    bot.LastChat = bot.LastChat or CurTime()

    if !bot:Alive() then return end

    local buttons = IN_SPEED
    local wep = bot:GetActiveWeapon()

    if ((!bot.SNB and !wep:GetSwitch()) or (bot.SNB and wep:GetSwitch())) and math.random(2) == 1 then
        buttons = IN_ATTACK
    end

    if IsValid(bot.TPage) and math.random(2) == 1 then
        buttons = buttons + IN_USE
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

local humenai

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot:Team() == TEAM_HUMENS then
        humenai(bot, cmd, mv)
    elseif bot:Team() == TEAM_SLENDER then
        bot:SetTeam(TEAM_SPECTATOR)
        timer.Simple(3, function()
            hook.Call("CheckSlenderman", gmod.GetGamemode())
        end)
    end
end

hook.Add("PlayerUse", "Leadbot_StopItSlender!", function(bot, ent)
    if ent:GetClass() == "page" and bot:IsLBot() and math.random(3) == 1 and bot.LastChat < CurTime() then
        LeadBot.TalkToMe(bot, "taunt")
        bot.LastChat = CurTime() + 1
    end
end)

function humenai(bot, cmd, mv)
    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end

    local ghost = ents.FindByClass("slendy")[1] or team.GetPlayers(TEAM_SLENDER)[1]
    local ghostDis = 99999
    local ghostvis = false

    if IsValid(ghost) then
        ghostDis = bot:GetPos():DistToSqr(ghost:GetPos())
        ghostvis = (ghost:GetClass() == "slendy" or ghost:IsSlenderVisible())
    end

    if bot:Health() ~= bot.LHP then
        bot.Caution = CurTime() + math.random(20, 40)
        bot.LHP = bot:Health()

        if bot:Health() == 0 then
            LeadBot.TalkToMe(bot, "downed")
            bot.LastChat = CurTime() + 35
        else
            if bot.LastChat < CurTime() then -- don't spam
                if math.random(3) == 1 then
                    LeadBot.TalkToMe(bot, "help")
                end
                bot.LastChat = CurTime() + 10
            end
        end
    end

    bot.SNB = ghostDis < 422500 and ghostvis and bot.Caution > CurTime()

    -- pages
    -- todo: skill system, some players know where pages exactly are (pretty unfun tho)
    if !IsValid(bot.TPage) then
        for _, page in pairs(ents.FindByClass("page")) do
            if !table.HasValue(page.Players, bot) and util.QuickTrace(bot:EyePos(), page:GetPos() - bot:EyePos(), bot).HitPos == page:GetPos() and page:GetPos():DistToSqr(bot:GetPos()) <= 25120144 then
                bot.TPage = page
            end
        end
    elseif table.HasValue(bot.TPage.Players, bot) then
        bot.TPage = nil
    end

    -- movement
    -- todo: don't search in places with prev pages
    mv:SetForwardSpeed(1200)

    if (!bot.SNB and !IsValid(bot.TPage)) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        controller.PosGen = controller:FindSpot("random", {radius = 12500})
        controller.LastSegmented = CurTime() + 10
    elseif IsValid(bot.TPage) then
        controller.PosGen = bot.TPage:GetPos()
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and string.find(dt.Entity:GetClass(), "door") then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if !controller.P then
        return
    end

    local segments = controller.P:GetAllSegments()

    if !segments then return end

    local cur_segment = controller.cur_segment
    local curgoal = segments[cur_segment]

    if !curgoal then
        mv:SetForwardSpeed(0)
        return
    end

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

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()
    mv:SetMoveAngles(mva)

    if controller.LookAtTime < CurTime() then
        controller.LookAt = Angle(math.random(-5, 5), math.random(-45, 45), 0)
        controller.LookAtTime = CurTime() + math.Rand(0.9, 1.3)
    end

    local addang = controller.LookAt + (AngleRand() * 0.01)

    if IsValid(bot.TPage) and bot.TPage:GetPos():DistToSqr(bot:GetPos()) <= 160000 then
        bot:SetEyeAngles(LerpAngle(FrameTime() * 7, bot:EyeAngles(), (bot.TPage:GetPos() - bot:GetShootPos()):Angle() + (AngleRand() * 0.02))) --[[+ bot:GetViewPunchAngles()]]
        return
    else
        local lerp = 7
        local ang = Angle(0, 0, 0)

        if bot.SNB then
            lerp = 5
            ang = Angle(0, (bot:EyePos() - ghost:GetPos()):Angle().y, 0)
        else
            ang = mva
        end

        ang = LerpAngle(FrameTime() * lerp, bot:EyeAngles(), ang + addang)
        bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
    end
end

concommand.Add("leadbot_slender", function(ply)
    if !ply:Alive() then ply:Spawn() end

    local ent = ents.FindByClass("slendy")[1]
    if IsValid(ent) then
        ent:Remove()
    end

    ply:SetTeam(TEAM_SLENDER)
    gmod.GetGamemode().LastSlender = ply
    game.GetWorld():SetDTEntity(2, ply)
    ply:CollisionRulesChanged()
    ply:Spawn()
end)