util.AddNetworkString("leadbot_Flashlight")

local convar = CreateConVar("leadbot_flashlight", "1", {FCVAR_ARCHIVE}, "Flashlight for bots")
local updateply
local updatetime
local updatetime_2 = 0

hook.Add("Think", "leadbot_Flashlight", function()
    if !convar:GetBool() or LeadBot.NoFlashlight then return end

    local tab = player.GetHumans()
    if updatetime_2 < CurTime() and #tab > 0 then
        local ply = table.Random(tab)

        updateply = ply
        updatetime = CurTime() + 0.5

        net.Start("leadbot_Flashlight")
        net.Send(ply)

        updatetime_2 = CurTime() + 0.5
    end
end)

net.Receive("leadbot_Flashlight", function(_, ply)
    if ply ~= updateply then return end
    if updatetime < CurTime() then return end

    local tab = net.ReadTable()
    if !istable(tab) then return end

    for bot, light in pairs(tab) do
        bot.LastLight2 = bot.LastLight2 or 0
        light = Vector(math.Round(light.x, 2), math.Round(light.y, 2), math.Round(light.z, 2))

        local lighton = light == Vector(0, 0, 0)

        if lighton then
            bot.LastLight2 = math.Clamp(bot.LastLight2 + 1, 0, 3)
        else
            bot.LastLight2 = 0
        end

        bot.FlashlightOn = lighton and bot.LastLight2 == 3
    end
end)

hook.Add("StartCommand", "leadbot_Flashlight", function(ply, cmd)
    if ply:IsLBot() and updatetime_2 - 0.1 < CurTime() and (ply.FlashlightOn and !ply:FlashlightIsOn() or !ply.FlashlightOn and ply:FlashlightIsOn()) then
        cmd:SetImpulse(100)
    end
end)