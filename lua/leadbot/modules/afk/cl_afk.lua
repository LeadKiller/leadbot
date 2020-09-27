surface.CreateFont("LeadBot_AFK", {
    font = "Roboto",
    size = 34,
    weight = 500
})

surface.CreateFont("LeadBot_AFK2", {
    font = "Roboto",
    size = 30,
    weight = 500
})

hook.Add("HUDPaint", "AFKT", function()
    if LocalPlayer():GetNWBool("LeadBot_AFK") then
        draw.SimpleTextOutlined("You are AFK.", "LeadBot_AFK", ScrW() / 2, ScrH() / 2.85, Color(255, 255, 255, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1,  Color(0, 0, 0, 255))
        draw.SimpleTextOutlined("Press any key to rejoin.", "LeadBot_AFK2", ScrW() / 2, ScrH() / 2.675, Color(255, 255, 255, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 255))
    end
end)

local tp = false
local last_TP = false
local newangle = Angle(0, 0, 0)
local scroll = 0
local lastsend = CurTime()
local tp_Gamemodes = {}
local NoAFKCamera = {}
tp_Gamemodes["sandbox"] = true
tp_Gamemodes["darkestdays"] = true
NoAFKCamera["assassins"] = true
NoAFKCamera["cavefight"] = true

hook.Add("CreateMove", "LeadBot_AFK", function(cmd)
    local ply = LocalPlayer()

    if ply:GetNWBool("LeadBot_AFK") then
        if lastsend < CurTime() and cmd:GetButtons() ~= 0 and !cmd:KeyDown(IN_ATTACK) and !cmd:KeyDown(IN_WALK) and !cmd:KeyDown(IN_SCORE) then
            net.Start("LeadBot_AFK_Off")
            net.SendToServer()
            lastsend = CurTime() + 0.1
        end

        if cmd:KeyDown(IN_ATTACK) and tp_Gamemodes[engine.ActiveGamemode()] then
            if !last_TP then
                tp = !tp
                last_TP = true
            end
        else
            last_TP = false
        end

        if input.WasMousePressed(MOUSE_WHEEL_DOWN) then
            scroll = math.Clamp(scroll + 4, -35, 45)
        elseif input.WasMousePressed(MOUSE_WHEEL_UP) then
            scroll = math.Clamp(scroll - 4, -35, 45)
        end

        if tp then
            local s = GetConVar("m_pitch"):GetFloat()
            newangle.pitch = math.Clamp(newangle.pitch + cmd:GetMouseY() * s, -90, 90)
            newangle.yaw = newangle.yaw - cmd:GetMouseX() * s
        end

        cmd:ClearButtons()
        cmd:ClearMovement()
        cmd:SetImpulse(0)

        cmd:SetMouseX(0)
        cmd:SetMouseY(0)
    end
end)

hook.Add("InputMouseApply", "LeadBot_AFK", function(cmd)
    if LocalPlayer():GetNWBool("LeadBot_AFK") then
        cmd:SetMouseX(0)
        cmd:SetMouseY(0)
        return true
    end
end)

hook.Add("HUDShouldDraw", "LeadBot_AFK", function(hud)
    if hud == "CHudWeaponSelection" and LocalPlayer():GetNWBool("LeadBot_AFK") then
        return false
    end
end)

local ang
local lerp = 0

hook.Add("CalcView", "LeadBot_AFK", function(ply, origin, angles)
    if !ang then ang = angles end

    if ply:ShouldDrawLocalPlayer() or !ply:GetNWBool("LeadBot_AFK") or NoAFKCamera[engine.ActiveGamemode()] then return end

    local view = {}

    if tp or lerp ~= 0 then
        if tp then
            lerp = math.Clamp(lerp + FrameTime() * 5, 0, 1)
        else
            lerp = math.Clamp(lerp - FrameTime() * 5, 0, 1)
        end

        local pos = ply:EyePos()
        local trace = util.TraceHull({
            start = pos + newangle:Forward() * Lerp(lerp, 0, -5),
            endpos = pos + newangle:Forward() * Lerp(lerp, 0, -75 - scroll),
            filter = ply,
            mins = Vector(-8, -8, -8),
            maxs = Vector(8, 8, 8),
        })

        view.angles = newangle
        view.origin = trace.HitPos
        view.drawviewer = true
    else
        ang = LerpAngle(FrameTime() * 16, ang, angles)
        ang = Angle(ang.p, ang.y, 0)
        newangle = ang
        view.angles = ang
    end

    return view
end)

hook.Add("CalcViewModelView", "LeadBot_AFK", function(wep, vm, oldpos, oldang, newpos, newang)
    local ply = LocalPlayer()

    if ply:ShouldDrawLocalPlayer() or !ply:GetNWBool("LeadBot_AFK") or NoAFKCamera[engine.ActiveGamemode()] then return end

    if wep.GetViewModelPosition then
        newpos, newang = wep:GetViewModelPosition(newpos, newang)
    end

    if wep.CalcViewModelView then
        newpos, newang = wep:CalcViewModelView(vm, oldpos, oldang, newpos, newang)
    end

    return newpos, ang
end)