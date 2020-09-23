concommand.Add("leadbot_afk", function(ply, _, args) LeadBot.Botize(ply) end, nil, "Adds a LeadBot ;)")

local time = CreateConVar("leadbot_afk_timetoafk", "300", {FCVAR_ARCHIVE})
local meta = FindMetaTable("Player")
local oldFunc = meta.IsBot

util.AddNetworkString("LeadBot_AFK_Off")

net.Receive("LeadBot_AFK_Off", function(_, ply)
    LeadBot.Botize(ply, false)
    ply.LastAFKCheck = CurTime() + time:GetFloat()
end)

hook.Add("PlayerTick", "LeadBot_AFK", function(ply)
    if !time:GetBool() then return end

    ply.LastAFKCheck = ply.LastAFKCheck or CurTime() + time:GetFloat()

    if ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT) or ply:KeyDown(IN_ATTACK) then
        ply.LastAFKCheck = CurTime() + time:GetFloat()
    end

    if ply.LastAFKCheck < CurTime() and !ply:IsBot() and !ply:GetNWBool("LeadBot_AFK") then
        LeadBot.Botize(ply, true)
    end
end)

function LeadBot.Botize(ply, togg)
    if togg == nil then togg = !ply.LeadBot end

    if ((!togg and ply:IsLBot()) or (togg and !ply:IsLBot())) and LeadBot.SuicideAFK and ply:Alive() then
        ply:Kill()
    end

    if !togg then
        ply:SetNWBool("LeadBot_AFK", false)
        ply.LeadBot = false
        if IsValid(ply.ControllerBot) then
            ply.ControllerBot:Remove()
        end
        ply.LastSegmented = CurTime()
        ply.CurSegment = 2
    else
        ply:SetNWBool("LeadBot_AFK", true)
        ply.LeadBot = true
        ply.BotColor = ply:GetPlayerColor()
        ply.BotSkin = ply:GetSkin()
        ply.BotModel = ply:GetModel()
        ply.BotWColor = ply:GetWeaponColor()
        ply.ControllerBot = ents.Create("leadbot_navigator")
        ply.ControllerBot:Spawn()
        ply.ControllerBot:SetOwner(ply)
        ply.ControllerBot:SetFOV(ply:GetFOV())
        ply.LastSegmented = CurTime()
        ply.CurSegment = 2
        if GetConVar("leadbot_strategy"):GetBool() then
            ply.BotStrategy = math.random(0, LeadBot.Strategies)
        end
        ply.LeadBot_Config = {}
        ply.LeadBot_Config[1] = ply.BotModel
        ply.LeadBot_Config[2] = ply.BotColor
        ply.LeadBot_Config[3] = ply.BotWColor
        ply.LeadBot_Config[4] = ply.BotStrategy
    end
end

function meta:IsBot()
    if self:IsLBot() and LeadBot.AFKBotOverride then
        return true
    else
        return oldFunc(self)
    end
end