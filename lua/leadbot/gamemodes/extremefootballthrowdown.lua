--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = true
LeadBot.Gamemode = "extremefootballthrowdown"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
end

function LeadBot.Think()
end

function LeadBot.StartCommand(bot, cmd)
    if !bot:CanCharge() and IsValid(bot.TargetEnt) and bot.TargetEnt:GetPos():DistToSqr(bot:GetPos()) < 2400 and math.random(2) == 1 then
        cmd:SetButtons(IN_ATTACK)
    end
end

local footballAI
local football
local strategy1
local movePos

function LeadBot.PlayerMove(bot, cmd, mv)
    if !IsValid(bot.ControllerBot) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
    end

    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    mv:SetForwardSpeed(1200)

    if !IsValid(football) then
        football = ents.FindByClass("prop_ball")[1]
    end

    if football:GetCarrier() == bot then
        footballAI(bot, cmd, mv)
    else
        strategy1(bot, cmd, mv, IsValid(football:GetCarrier()))
    end
end

function strategy1(bot, cmd, mv, force)
    bot.botPos = football:GetPos()

    movePos(bot, cmd, mv, force)
end

function footballAI(bot, cmd, mv)
    local tgoal

    for _, goal in pairs(ents.FindByClass("trigger_goal")) do
        if goal:GetTeamID() ~= bot:Team() then
            tgoal = goal
        end
    end

    bot.botPos = tgoal:LocalToWorld(tgoal:OBBCenter())

    movePos(bot, cmd, mv, true)
end

function movePos(bot, cmd, mv, force)
    bot.ControllerBot.PosGen = bot.botPos

    if !bot.ControllerBot.P then
        return
    end

    local segments = bot.ControllerBot.P:GetAllSegments()

    if !segments then return end

    local curgoal = segments[2]

    if !curgoal then return end

    if segments[3] and segments[3].pos.z > bot:GetPos().z + 6 and bot.NextJump < CurTime() then
        bot.NextJump = 0
    end

    local cur_segment = 2

    -- think 15 steps ahead!
    if force then
        for i, segment in pairs(segments) do
            if bot:VisibleVec(segment.pos) and i > cur_segment then
                cur_segment = i
            end
        end
    end

    curgoal = segments[cur_segment]

    local lerpc = 2

    local mva = ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)

    if bot:GetPos():DistToSqr(curgoal.pos) > 400 then
        bot:SetEyeAngles(LerpAngle(FrameTime() * lerpc, bot:EyeAngles(), mva))
    end

    local eyea = bot:EyeAngles()

    bot:SetEyeAngles(Angle(eyea.p, eyea.y, 0))
end