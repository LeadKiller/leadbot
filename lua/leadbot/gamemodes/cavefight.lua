--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = true
LeadBot.Gamemode = "cavefight"
LeadBot.TeamPlay = false
LeadBot.LerpAim = true
LeadBot.NoNavMesh = true
LeadBot.NoSprint = true
LeadBot.NoFlashlight = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_FORWARD
    local target = bot.Target
    local ship = bot:GetShip()

    bot.LastLook = bot.LastLook or 0
    bot.TargetAngle = bot.TargetAngle or Angle(0, 0, 0)

    if !IsValid(ship) then return end

    -- look at our attacker when hit
    if !ship.OldOnTakeDamage then
        ship.OldOnTakeDamage = ship.OnTakeDamage
        function ship:OnTakeDamage(dmg)
            local attacker = dmg:GetAttacker()
            if IsValid(attacker) and attacker:IsPlayer() then
                if self:GetDriver():IsLBot() then
                    bot.TargetAngle = Angle(0, (dmg:GetAttacker():GetShip():GetPos() - self:GetPos()):Angle().y, 0)
                    bot.LastLook = CurTime() + math.Rand(1.1, 1.2)
                end

                if ship:Health() <= dmg:GetDamage() and math.random(12) == 1 and attacker:IsLBot() then
                    LeadBot.TalkToMe(attacker, "taunt")
                end
            end

            self:OldOnTakeDamage(dmg)
        end
    end

    local ship_pos = ship:GetPos()

    -- Forget our target if we can't see them for a few seconds.
    if !IsValid(bot.Target) or bot.ForgetTarget < CurTime() or IsValid(bot.Target:GetShip()) and bot.Target:GetShip():Health() <= 0 then
        bot.Target = nil
    end

    -- Target system.
    if !IsValid(bot.Target) then
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= bot and IsValid(ply:GetShip()) and !ply:GetShip().invis and ply:GetShip():GetPos():DistToSqr(ship_pos) <= 1440000 and bot:GetAimVector():Dot((Vector(ply:GetShip():GetPos().x, ply:GetShip():GetPos().y, 0) - Vector(ship_pos.x, ship_pos.y, 0)):GetNormalized()) > 0.7 then
                local ship2 = ply:GetShip()
                local trace = util.TraceLine({
                    start = ship_pos,
                    endpos = ship2:GetPos(),
                    filter = ship2 -- function(ent) return ent == ply:GetShip() and ent:GetClass() ~= "chunk" end
                })

                -- debugoverlay.Line(trace.StartPos, trace.HitPos, 0.1, Color(255, 255, 255), true)

                if trace.HitPos:DistToSqr(ship2:GetPos()) <= 250 then
                    bot.Target = ply
                    bot.ForgetTarget = CurTime() + 2
                end
            end
        end
    end

    if IsValid(target) then
        buttons = buttons + IN_ATTACK
    end

    --[[debugoverlay.Line(ship_pos, ship_pos + Vector(0, 0, -100) + bot:EyeAngles():Forward() * 300, 0.1, Color(255, 0, 0), true)
    debugoverlay.Cross(ship_pos + Vector(0, 0, -100) + bot:EyeAngles():Forward() * 300, 1, 0.1, Color(255, 255, 255), true)]]

    -- Move up or down if we get to close to the ceiling/floor.
    if util.QuickTrace(ship_pos, Vector(0, 0, -100), ship).Hit then -- or util.QuickTrace(ship_pos, Vector(0, 0, -50) + bot:EyeAngles():Forward() * 200, ship).Hit then
        buttons = buttons + IN_JUMP
    else
    end

    if IsValid(target) and IsValid(target:GetShip()) then
        bot.TargetAngle = Angle(0, (target:GetShip():GetPos() - ship_pos):Angle().y, 0)
    elseif bot.LastLook < CurTime() then
        bot.TargetAngle = Angle(0, math.random(-180, 180), 0)
        bot.LastLook = CurTime() + math.Rand(4, 7)
    end

    -- Antistuck, turn around if we are stuck.
    if util.QuickTrace(ship_pos, bot:EyeAngles():Forward() * 24, ship).Hit then
        if !bot.Stuck then
            bot.Stuck = CurTime() + 2
        elseif bot.Stuck and bot.Stuck + 0.1 < CurTime() then
            bot.Stuck = nil
        elseif bot.Stuck < CurTime() then
            bot.Stuck = CurTime() + 2
            bot.TargetAngle = -bot.TargetAngle
        end
    end

    bot:SetEyeAngles(LerpAngle(FrameTime() * 8, bot:EyeAngles(), bot.TargetAngle))
    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
end

if !oldcaveCalcView then
    oldcaveCalcView = caveCalcView
end

caveCalcView = function(ply, pos, ang)
    if ply:IsLBot() and IsValid(ply.Target) and IsValid(ply.Target:GetShip()) then
        local ship = ply.Target:GetShip()
        local ship2 = ply:GetShip()

        return ship2:GetPos(), (ship:LocalToWorld(ship.EngineMuzzlePos) - ship2:GetPos()):Angle()
    else
        return oldcaveCalcView(ply, pos, ang)
    end
end