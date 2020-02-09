hook.Add("HUDPaint", "AFKT", function()
    if LocalPlayer():GetNWBool("LeadBot_AFK") then
        local aa = 200 + math.sin(CurTime() * 5) * 50
        draw.SimpleTextOutlined("You are currently AFK", "DermaLarge", ScrW() / 2, ScrH() / 1.7, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1,  Color(0, 0, 0,255))
        draw.SimpleTextOutlined("Jump to get out of AFK", "DermaLarge", ScrW() / 2, ScrH() / 1.6, Color(255, 255, 255, aa), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, aa))
    end
end)

-- local tp = false
-- local NA = Angle(0, 0, 0)
local lastsend = CurTime()

hook.Add("CreateMove", "LeadBot_AFK", function(cmd)
    if LocalPlayer():GetNWBool("LeadBot_AFK") then
        if lastsend < CurTime() and cmd:KeyDown(IN_JUMP) or cmd:KeyDown(IN_FORWARD) then
            net.Start("LeadBot_AFK_Off")
            net.SendToServer()
            lastsend = CurTime() + 5
        end

        cmd:ClearButtons()
        cmd:ClearMovement()
    end

    --[[if LocalPlayer():KeyReleased(IN_ATTACK) then
        -- tp = !tp
    end

    if tp then
        local s = GetConVar("m_pitch"):GetFloat()
        NA.pitch = math.Clamp(NA.pitch + cmd:GetMouseY() * s, -90, 90)
        NA.yaw = NA.yaw - cmd:GetMouseX() * s
    end]]
end)

-- looked pretty bad :(

--[[local ang

hook.Add("CalcView", "LeadBot_AFK", function(ply, origin, angles)
    if !ang then ang = angles end

    if !LocalPlayer():GetNWBool("LeadBot_AFK") then return end

    local view = {}

    if tp then
        local trace = util.TraceHull({
            start = origin + NA:Forward() * -5,
            endpos = origin + NA:Forward() * -75,
            filter = ply,
            mins = Vector(-8, -8, -8),
            maxs = Vector(8, 8, 8),
        })

        view.angles = NA
        view.origin = trace.HitPos
        view.drawviewer = true
    else
        ang = LerpAngle(0.2, ang, angles)
        ang = Angle(ang.p, ang.y, 0)
        NA = ang
        view.angles = ang
    end

    return view
end)

hook.Add("CalcViewModelView", "LeadBot_AFK", function(wep, vm, oldpos, oldang, newpos, newang)
    if !LocalPlayer():GetNWBool("LeadBot_AFK") then return end
    return oldpos, ang
end)]]