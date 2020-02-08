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
    -- bot.NextJump = CurTime()

    if math.random(4) == 1 then
        timer.Simple(math.random(1, 3), function()
            if IsValid(bot) then
                LeadBot.TalkToMe(bot, "join")
            end
        end)
    end

    timer.Simple(0, function()
        if LeadBot.SetModel then
            bot:SetModel(bot.BotModel)
        end
        bot:SetPlayerColor(bot.BotColor)
        bot:SetSkin(bot.BotSkin)
        bot:SetWeaponColor(bot.BotWColor)
    end)
end

function LeadBot.Think()
end

function LeadBot.StartCommand(bot, cmd)
    if !bot:Alive() then return end

    local buttons = IN_SPEED

    --[[if bot.SNB then
        buttons = 0
    end]]
    -- run when they're near!

    --[[if bot.NextJump == 0 then
        bot.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP -- + IN_DUCK
    end]]

    local wep = bot:GetActiveWeapon()

    if ((!bot.SNB and !wep:GetSwitch()) or (bot.SNB and wep:GetSwitch())) and math.random(2) == 1 then
        buttons = IN_ATTACK
    end

    if IsValid(bot.TPage) and math.random(2) == 1 then
        buttons = buttons + IN_USE
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
        timer.Simple(3,function()
            gamemode.Call("CheckSlenderman")
        end)
    end
end

hook.Add("PlayerUse", "Leadbot_StopItSlender!", function(bot, ent)
    if bot:IsBot() and math.random(3) == 1 and ent:GetClass() == "page" and bot.LastChat < CurTime() then
        LeadBot.TalkToMe(bot, "taunt")
        bot.LastChat = CurTime() + 1
    end
end)

function humenai(bot, cmd, mv)
    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    bot.FollowPly = table.Random(player.GetHumans())
    bot.UseEnt = nil

    local ghost = ents.FindByClass("slendy")[1] or team.GetPlayers(TEAM_SLENDER)[1]
    local ghostDis = 99999
    local ghostvis = false

    if IsValid(ghost) then
        ghostDis = bot:GetPos():Distance(ghost:GetPos())
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

    bot.SNB = ghostDis < 650 and ghostvis and bot.Caution > CurTime() -- and util.QuickTrace(bot:EyePos(), ghost:EyePos() - bot:EyePos(), bot).Entity == ghost

    -- antistuck test?

    --cmd:SetForwardMove(250)

    -- pages
    -- todo: skill system, some players know where pages exactly are (pretty unfun tho)
    if !IsValid(bot.TPage) then
        for _, page in pairs(ents.FindByClass("page")) do
            if !table.HasValue(page.Players, bot) and util.QuickTrace(bot:EyePos(), page:GetPos() - bot:EyePos(), bot).HitPos == page:GetPos() and page:GetPos():Distance(bot:GetPos()) <= 5012 then
                bot.TPage = page
            end
        end
    elseif table.HasValue(bot.TPage.Players, bot) then
        bot.TPage = nil
    end

    -- movement
    -- todo: don't search in places with prev pages
    mv:SetForwardSpeed(1200)

    if (!bot.SNB and !IsValid(bot.TPage)) and !IsValid(bot.UseEnt) and (!isvector(bot.botPos) or bot:GetPos():Distance(bot.botPos) < 60 or math.abs(bot.LastSegmented - CurTime()) > 10) then
        bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 12500})
        bot.LastSegmented = CurTime()
    elseif IsValid(bot.TPage) then
        bot.botPos = bot.TPage:GetPos()
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

    --[[if bot.LastPath[bot.CurSegment + 1] and bot.LastPath[bot.CurSegment + 1].pos.z > bot:GetPos().z + 6 and bot.NextJump < CurTime() then
        bot.NextJump = 0
    end]]

    if bot:GetPos():Distance(curgoal.pos) < 50 and bot.LastPath[bot.CurSegment + 1] then
        curgoal = bot.LastPath[bot.CurSegment + 1]
    end

    -- eyes 👀

    local lerp = 0.1

    mv:SetMoveAngles(LerpAngle(lerp, mv:GetMoveAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))

    if IsValid(bot.TPage) and bot:GetEyeTrace().Entity ~= bot.TPage then
        local shouldvegoneforthehead = bot.TPage:GetPos()
        local cang = --[[LerpAngle(lerp, bot:EyeAngles(), ]](shouldvegoneforthehead - bot:GetShootPos()):Angle() --)
        bot:SetEyeAngles(Angle(cang.p, cang.y, 0)) --[[+ bot:GetViewPunchAngles()]]
        return
    elseif bot:GetPos():Distance(curgoal.pos) > 20 then
        local ang2 = ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()
        local ang = LerpAngle(lerp, mv:GetMoveAngles(), ang2)
        local tang = ang
        if bot.SNB then --bot.Caution > CurTime() and ghostvis and ghost:GetPos():Distance(bot:GetPos()) < 1000 then
            tang = LerpAngle(0.025, bot:EyeAngles(), (bot:EyePos() - ghost:GetPos()):Angle()) -- (bot:EyePos() - slender:GetPos()):Angle() + Angle(0, 180, 0)
        end

        --[[if (string.StartWith(tang.y, "-") and -math.abs(bot:EyeAngles().y))then
        print("spinning", tang.y -
        end]]

        --local cang = LerpAngle(lerpc, bot:EyeAngles(), ang2)
        bot:SetEyeAngles(tang) --Angle(ang2.p, ang2.y, 0))
        mv:SetMoveAngles(ang)
    end
end