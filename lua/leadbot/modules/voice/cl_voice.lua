local convar = CreateClientConVar("leadbot_voice_3d", 0, true, true, "Forces bot voices to be 3D")

net.Receive("botVoiceStart", function()
    local ply = net.ReadEntity()
    local soundn = net.ReadString()
    local time = SoundDuration(soundn) -- - 0.1

    if !IsValid(ply) or !ply:IsBot() or (IsValid(ply.ChattingS) and ply.ChattingS:GetState() == GMOD_CHANNEL_PLAYING) then return end

    if convar:GetInt() == 2 then
        ply:EmitSound(soundn)
        return
    end

    sound.PlayFile("sound/" .. soundn, convar:GetBool() and "3d" or "mono", function(station)
        if IsValid(station) then
            ply.ChattingS = station
            station:SetPlaybackRate(math.random(95, 105) * 0.01)
            station:Set3DFadeDistance(500, 0)
            station:Play()

            if convar:GetBool() and LocalPlayer():EyePos():DistToSqr(ply:EyePos()) > 562500 then
                timer.Simple(time, function()
                    if IsValid(ply) then
                        station:Stop()
                    end
                end)

                return
            end

            hook.Call("PlayerStartVoice", gmod.GetGamemode(), ply)

            timer.Simple(time, function()
                if IsValid(ply) then
                    hook.Call("PlayerEndVoice", gmod.GetGamemode(), ply)
                    station:Stop()
                end
            end)
        end
    end)
end)

local voice = Material("voice/icntlk_pl")

hook.Add("PostPlayerDraw", "LeadBot_VoiceIcon", function(ply)
    if !IsValid(ply) or !ply:IsPlayer() or !ply:IsBot() or !IsValid(ply.ChattingS) or !GetConVar("mp_show_voice_icons"):GetBool() then return end
    local ang = EyeAngles()
    local pos = ply:GetPos() + ply:GetCurrentViewOffset() + Vector(0, 0, 14)
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    cam.Start3D2D(pos, ang, 1)
    surface.SetMaterial(voice)
    surface.SetDrawColor(255, 255, 255)
    surface.DrawTexturedRect(-8, -8, 16, 16)
    cam.End3D2D()
end)

local meta = FindMetaTable("Player")
local oldFunc = meta.VoiceVolume
local oldFunc2 = meta.IsSpeaking

function meta:VoiceVolume()
    if self:IsBot() then
        if IsValid(self.ChattingS) then
            self.ChattingS:SetPos(self:EyePos())
            local vol = self.ChattingS:GetLevel() * 0.6

            if convar:GetBool() then
                vol = Lerp(LocalPlayer():EyePos():DistToSqr(self:EyePos()) / 250000, vol, 0)
            end

            return vol
        else
            return 0
        end
    else
        return oldFunc(self)
    end
end

function meta:IsSpeaking()
    if self:IsBot() then
        return IsValid(self.ChattingS) and (!convar:GetBool() or LocalPlayer():EyePos():DistToSqr(self:EyePos()) <= 250000) or false
    else
        return oldFunc2(self)
    end
end