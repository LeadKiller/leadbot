--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = false
LeadBot.Gamemode = "q3tdm"
LeadBot.TeamPlay = true
LeadBot.LerpAim = false
LeadBot.NoSprint = true
LeadBot.NoFlashlight = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.AddBotOverride(bot)
    if math.random(2) == 1 then
        timer.Simple(math.random(1, 4), function()
            LeadBot.TalkToMe(bot, "join")
        end)
    end

    if #team.GetPlayers(TEAM_RED) > #team.GetPlayers(TEAM_BLUE) then
        bot:SetTeam(TEAM_BLUE)
    else
        bot:SetTeam(TEAM_RED)
    end
end