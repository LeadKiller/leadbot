local convar1 = CreateConVar("leadbot_quota", "0", {FCVAR_ARCHIVE}, "TF2 Style Quota for bots\nUse leadbot_add if you want unkickable bots")
local nextCheck = 0

cvars.AddChangeCallback("leadbot_quota", function(_, oldval, val)
    oldval = tonumber(oldval)
    val = tonumber(val)

    if oldval and val and oldval > 0 and val < 1 then
        RunConsoleCommand("leadbot_kick", "all")
    end
end)

hook.Add("Think", "LeadBot_Quota", function()
    if !convar1:GetBool() or LeadBot.AFKBotOverride then return end

    if nextCheck < CurTime() then
        local bots = {}
        local max = convar1:GetInt() - #player.GetHumans()

        for _, ply in pairs(player.GetBots()) do
            if ply:IsLBot(true) then
                table.insert(bots, ply)
            end
        end

        for i = 1, #bots do
            if i >= convar1:GetInt() then
                bots[i]:Kick()
            end
        end

        if #bots < max then
            nextCheck = CurTime() + 0.5

            for i = 1, max - #bots do
                timer.Simple(0.1 + (i * 0.5), function()
                    LeadBot.AddBot()
                end)

                nextCheck = nextCheck + 0.5
            end
        else
            nextCheck = CurTime() + 1
        end
    end
end)