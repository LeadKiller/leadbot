-- TODO: store avatar in dhtml png images or something, alpha fade out is weird with dmodelpanel

local meta = FindMetaTable("Panel")
local oldfunc = meta.SetPlayer
local disabledGamemodes = {}
disabledGamemodes["assassins"] = true

function meta:SetPlayer(ply, size)
    if !IsValid(ply) or !ply:IsPlayer() then return end
    if disabledGamemodes[engine.ActiveGamemode()] then return oldfunc(self, ply, size) end

    if ply:IsBot() and ply:GetNWString("LeadBot_AvatarModel", "none") ~= "none" then
        function self:Paint(w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255))
        end

        local background = vgui.Create("DPanel", self)
        background:Dock(FILL)
        -- background.Texture = Material("entities/monster_scientist.png")

        function background:Paint(w, h)
            if !ispanel(self:GetParent()) then
                self:Remove()
                return
            end

            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255))

            --[[surface.SetMaterial(self.Texture)
            surface.SetDrawColor(255, 255, 255)
            surface.DrawTexturedRect(0, 0, w, h)]]
        end

        local model = vgui.Create("DModelPanel", self)
        model:SetModel("models/player.mdl")
        model:Dock(FILL)
        model.Player = ply

        if !ply.AvatarSeq then
            ply.AvatarSeq = table.Random({"death_01", "death_02", "death_03", "death_04"})
            ply.AvatarCycle = math.Rand(0.025, (ply.AvatarSeq == "death_04" and 0.06) or (ply.AvatarSeq == "death_01" and 0.3) or 0.1)
        end

        local playermodel = ply:GetNWString("LeadBot_AvatarModel", ply:GetModel())

        function model:LayoutEntity(ent)
            if !ispanel(self:GetParent()) then
                self:Remove()
                return
            end

            if !IsValid(self.Player) or !IsValid(ent) or !self.Player:IsPlayer() then return end

            self.ModelCache = self.ModelCache or ""

            if !ent.GetPlayerColor then
                ent.Player = self.Player
                function ent:GetPlayerColor()
                    if !IsValid(self.Player) then return Vector(1, 1, 1) end
                    return self.Player:GetNWVector("LeadBot_AvatarColor", self.Player:GetPlayerColor())
                end
            end

            ent:SetRenderMode(RENDERMODE_TRANSALPHA)
            ent:SetLOD(0)

            -- voicechat fix
            local alpha = 255
            if ispanel(self:GetParent()) and ispanel(self:GetParent():GetParent()) then
                alpha = self:GetParent():GetParent():GetAlpha()
            end

            self:SetColor(Color(255, 255, 255, alpha))

            if self.ModelCache ~= playermodel then
                self:SetModel(playermodel)

                ent = self:GetEntity()

                local seq_name = self.Player.AvatarSeq
                local seq = ent:LookupSequence(seq_name or 0) -- "menu_walk")
                if seq < 0 then
                    seq = ent:LookupSequence("menu_walk") -- "reload_dual_original")
                end

                ent:SetSequence(seq) -- table.Random({"swimming_duel", "zombie_slump_idle_02"})))
                ent:SetCycle(self.Player.AvatarCycle)

                local att = ent:LookupAttachment("eyes")

                if att > 0 then
                    att = ent:GetAttachment(att)
                    if seq_name ~= "death_05" then
                        self:SetFOV(23)
                        self:SetCamPos(att.Pos + att.Ang:Forward() * 36 + att.Ang:Up() * 2)
                        self:SetLookAt(att.Pos - Vector(0, 0, 1))
                    else
                        self:SetFOV(27)
                        self:SetCamPos(att.Pos + att.Ang:Forward() * 36)
                        self:SetLookAt(att.Pos - Vector(0, 0, 3))
                    end
                end


                self.ModelCache = self.Player:GetModel()
            end
        end
    else
        oldfunc(self, ply, size)
    end
end