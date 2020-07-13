net.Receive("leadbot_Flashlight", function()
    local flashlights = {}
    for _, ply in pairs(player.GetAll()) do
        flashlights[ply] = render.GetLightColor(ply:EyePos())
    end

    net.Start("leadbot_Flashlight")
    net.WriteTable(flashlights)
    net.SendToServer()
end)