--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "dogfightarcade"
LeadBot.TeamPlay = true
LeadBot.LerpAim = false
LeadBot.NoNavMesh = true
LeadBot.AFKBotOverride = true
LeadBot.SuicideAFK = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
    bot.PlaneDamage = bot:Health()
    bot.LastChat = CurTime() + 5

    timer.Simple(0, function()
        if bot:GetNWString("botnick") ~= "" then
            bot:SetNWString("botnick", "")
        end
    end)
end

function LeadBot.StartCommand(bot, cmd)
    if IsValid(bot.ControllerBot) then
        bot.ControllerBot:Remove()
    end
end

hook.Add("Think", "LeadBot_DFA", function()
    for _, bot in pairs(player.GetBots()) do
        if bot.LeadBot and !bot:Alive() and bot.NextSpawnTime < CurTime() then
            bot:Spawn()
        end
    end
end)

local driverGas
local br
local rr

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot.BotStrategy == 1 then
        driverGas(bot, cmd, mv)
    end
end

function driverGas(bot, cmd, mv)
    if !bot:Alive() and bot.targetFuel then
        bot.targetFuel = nil
        return
    end

    if !IsValid(bot:GetPlane()) or !IsValid(bot:GetPlane():GetAIDriver()) then return end

    local plane = bot:GetPlane()
    local driver = plane:GetAIDriver()
    local fuel = bot.targetFuel

    if plane:GetDamage() ~= bot.PlaneDamage then
        bot.PlaneDamage = plane:GetDamage()

        if bot.LastChat < CurTime() then
            if math.random(3) == 1 then
                LeadBot.TalkToMe(bot, "help")
            end
            bot.LastChat = CurTime() + 15
        end
    end

    if !IsValid(br) or !IsValid(rr) then
        if #ents.FindByClass("df_blue_rocket") ~= 0 then
            br = ents.FindByClass("df_blue_rocket")[1]
            rr = ents.FindByClass("df_red_rocket")[1]
        end

        return
    end

    if !IsValid(fuel) or (IsValid(fuel.dt.OwnerPlane) and fuel.dt.OwnerPlane ~= bot) or fuel:GetTeam() == bot:Team() then
        bot.targetFuel = nil
    end

    if IsValid(plane.ePod) then
        local tr = rr
        if bot:Team() == 2 then
            tr = br
        end

        local targ_ang = ((tr:GetPos() + tr:GetUp() * 135) - driver:GetPos()):Angle()
        plane.y_diff = math.NormalizeAngle(targ_ang.y - plane:GetAngles().y)
        plane.p_diff = math.NormalizeAngle(targ_ang.p - 5 - plane:GetAngles().p)
    elseif !IsValid(fuel) then
        local potentials = {}
        for _, pod in pairs(ents.FindByClass("df_fuel_pod")) do
            if !IsValid(pod.dt.OwnerPlane) and pod:GetTeam() ~= bot:Team() then
                table.insert(potentials, pod)
            end
        end
        bot.targetFuel = table.Random(potentials)
    elseif !IsValid(fuel.dt.OwnerPlane) then
        local targ_ang = ((fuel:GetPos() + fuel:GetUp() * 20) - driver:GetPos()):Angle()
        plane.y_diff = math.NormalizeAngle(targ_ang.y - plane:GetAngles().y)
        plane.p_diff = math.NormalizeAngle(targ_ang.p + 15 - plane:GetAngles().p)

        -- might have to do this for now, bots keep spining around it :(
        if driver:GetPos():DistToSqr(fuel:GetPos()) <= 250000 then
            fuel:StartTouch(plane)
            LeadBot.TalkToMe(bot, "taunt")
        end
    end

    -- no fuel left, go back to defending
    if !IsValid(fuel) then
        return
    end

    driver:SetTarget(nil)
    plane.in_attack = false
end