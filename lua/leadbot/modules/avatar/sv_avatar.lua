local oldAddBot = LeadBot.AddBotOverride

function LeadBot.AddBotOverride(bot)
    oldAddBot(bot)

    timer.Simple(0, function()
        if IsValid(bot) then
            bot:SetNWString("LeadBot_AvatarModel", player_manager.TranslatePlayerModel(bot:LBGetModel()))
            bot:SetNWVector("LeadBot_AvatarColor", bot:LBGetColor())
        end
    end)
end