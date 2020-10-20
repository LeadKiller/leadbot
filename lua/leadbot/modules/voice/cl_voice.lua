net.Receive("botVoiceStart", function()
    local ply = net.ReadEntity()
    local soundn = net.ReadString()
    local time = SoundDuration(soundn) -- - 0.1

    if !IsValid(ply) or !ply:IsBot() or (IsValid(ply.ChattingS) and ply.ChattingS:GetState() == GMOD_CHANNEL_PLAYING) then return end

    -- tts tests
    -- sound.PlayURL([[https://translate.google.com/translate_tts?ie=UTF-8&tl=en-us&client=tw-ob&q="]] .. voiceline .. [["]], "mono", function(station)
    sound.PlayFile("sound/" .. soundn, "mono", function(station)
        if IsValid(station) then
            ply.ChattingS = station
            station:SetPlaybackRate(math.random(95, 105) * 0.01)
            station:Play()
            hook.Call("PlayerStartVoice", gmod.GetGamemode(), ply)

            timer.Simple(time, function()
                if IsValid(ply) then
                    hook.Call("PlayerEndVoice", gmod.GetGamemode(), ply)
                    station:Stop()
                    --ply.ChattingB = false
                end
            end)
        end
    end)
end)

local voice = Material("voice/icntlk_pl")
-- is there no way to force this on?
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
            return self.ChattingS:GetLevel() * 0.6
        else
            return 0
        end
    else
        return oldFunc(self)
    end
end

function meta:IsSpeaking()
    if self:IsBot() then
        return IsValid(self.ChattingS) or false
    else
        return oldFunc2(self)
    end
end