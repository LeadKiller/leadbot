--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "hovergearlegacy"
LeadBot.TeamPlay = false
LeadBot.LerpAim = false
LeadBot.SuicideAFK = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
end

function LeadBot.StartCommand(bot, cmd)
    cmd:ClearButtons()
    cmd:ClearMovement()

    local car = bot:GetHoverGear()

    if !IsValid(car) then return end

    local limit = 1250

    if bot.BotStrategy == 0 then -- insane fast
        limit = 1500
        if bot.UpsideDown then
            limit = 1250
        end
    else
        if bot.UpsideDown then
            limit = 1000
        end
    end

    local toofast = car:GetVelocity():Length2D() > limit

    if bot.TD == 1 then
        buttons = IN_MOVERIGHT
    elseif bot.TD == 2 then
        buttons = IN_MOVELEFT
    end

    if !toofast then
        buttons = buttons + IN_FORWARD
    end

    cmd:SetButtons(buttons)
end

local driveCar

function LeadBot.PlayerMove(bot, cmd, mv)
    if !bot:IsInQueue() then
        bot:EnterQueue()
    elseif bot:IsRacing() then
        driveCar(bot, cmd, mv)
    end
end

function driveCar(bot, cmd, mv)
    if !IsValid(bot:GetHoverGear()) then return end

    local controller = bot.ControllerBot
    local car = bot:GetHoverGear()

    -- keep the bot always on edge, and drifting
    bot.TD = 2

    local floor = util.QuickTrace(bot:GetPos(), Vector(0, 0, -1024), {car, bot}).HitPos

    if controller:GetPos() ~= floor then
        controller:SetPos(floor)
    end

    local ourcheckpoint = nil

    ourcheckpoint = GAMEMODE.Checkpoints[bot:GetCheckpoint() + 2]

    -- race ya to the end :D
    if !ourcheckpoint then
        ourcheckpoint = GAMEMODE.Checkpoints[1]
    end

    controller.PosGen = ourcheckpoint

    if !controller.P then
        return
    end

    local segments = controller.P:GetAllSegments()

    if !segments then return end

    local cur_segment = controller.cur_segment or 2
    local curgoal = segments[cur_segment]

    if !curgoal then
        return
    end

    local ep = car:GetPos() + car:GetUp() * 8 + car:GetForward() * 2

    -- decided to use the old system for this, the bot will go for last segment they see rather than every segment
    for i, segment in pairs(segments) do
        if i < 15 and util.QuickTrace(ep, segment.pos - ep, {bot, car}).HitPos == segment.pos and i > cur_segment then
            controller.cur_segment = i
            curgoal = segments[i]
        end
    end

    if cur_segment < 4 and segments[6] then
        cur_segment = 6
    end

    curgoal = segments[cur_segment]

    local targang = (segments[cur_segment - 1].pos - car:GetPos()):Angle()
    targang = Angle(0, targang.y, 0)

    -- camera for afk players, no need for bots since spectating isn't a thing
    if !bot:IsBot() then
        bot:SetEyeAngles(LerpAngle(FrameTime() * 8, bot:EyeAngles(), (curgoal.pos - bot:EyePos()):Angle()))
    end

    local carangtrue = car:GetAngles()
    local carang = Angle(0, car:GetAngles().y, 0)

    if (string.StartWith(carangtrue.r, "-") and carangtrue.r < -45) or (carangtrue.r > 45) then
        carang = Angle(0, car:GetAngles().y + 180, 0)
        bot.UpsideDown = true
    else
        bot.UpsideDown = false
    end

    local diff = math.AngleDifference(carang.y, targang.y)

    if 15 < diff then
        bot.TD = 1
    elseif 15 > diff then
        bot.TD = 2
    end
end