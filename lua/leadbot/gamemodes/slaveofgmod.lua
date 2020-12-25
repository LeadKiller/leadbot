--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = false
LeadBot.TeamPlay = false
LeadBot.LerpAim = false
LeadBot.AFKBotOverride = true

--[[GAMEMODE CONFIGURATION END]]--

BOT_IGNORE_CLASS = true

hook.Add("Move", "LeadBot_SoG", function(ply)
    if ply:IsLBot() then
        return false
    end
end)

function LeadBot.PlayerSpawn(bot)
    local classes = table.Copy(GAMEMODE.Characters)

    for id, class in ipairs(classes) do
        if class.NoMenu or GAMEMODE.UseCharacters and !table.HasValue(GAMEMODE.UseCharacters, class.Reference) or class.GametypeSpecific and class.GametypeSpecific ~= GAMEMODE:GetGametype() then
            classes[id] = nil
        end
    end

    local char = table.Random(classes).Reference
    local oldchar = bot:GetCharacter()
    bot.OldCharacter = oldchar
    bot.CharacterPref = char
    bot.StoreCharacterPref = GAMEMODE:GetCharacterReferenceById(char)

    if GAMEMODE.GametypeOnChangeChar then
        GAMEMODE:GametypeOnChangeChar(bot, char, oldchar)
    end

    if bot:Team() == TEAM_SPECTATOR then
        bot:Freeze(false)
        if GAMEMODE:GetGametype() == "none" and !SINGLEPLAYER then
            bot:SetTeam(TEAM_DM)
            bot:Spawn()
        else
            GAMEMODE:PlayerInitialSpawn(bot)
            bot:Spawn()
        end
    end
end

function LeadBot.Think()
    for _, bot in pairs(player.GetBots()) do
        if bot:IsLBot() then
            if LeadBot.RespawnAllowed and bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
                return
            end
        end
    end
end

function LeadBot.StartCommand(bot, cmd)
    if !bot:Alive() then return end

    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target

    if !IsValid(controller) then return end

    if LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(target) and (target.Execution or math.random(2) == 1 and controller:CanSee(target)) then
        if IsValid(botWeapon) and botWeapon.StoredClip and botWeapon.StoredClip < 1 then
            buttons = buttons + IN_ATTACK2
        end

        buttons = buttons + IN_ATTACK
    end

    if IsValid(target) and target.Knockdown then
        buttons = buttons + IN_JUMP
        buttons = buttons + IN_ATTACK
    end

    if IsValid(bot.TakeWeapon) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK2
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if pos.z > controller:GetPos().z then
            controller.LookAt = Angle(-30, ang.y, 0)
        else
            controller.LookAt = Angle(30, ang.y, 0)
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = buttons + IN_FORWARD
    end

    if controller.NextDuck > CurTime() then
        buttons = buttons + IN_DUCK
    elseif controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    bot:SelectWeapon((IsValid(controller.Target) and controller.Target:GetPos():DistToSqr(controller:GetPos()) < 129000 and "weapon_shotgun") or "weapon_smg1")
    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if !bot:Alive() then return end

    local controller = bot.ControllerBot
    local weapon = bot:GetActiveWeapon()
    local hasweapon = IsValid(weapon) and weapon:GetClass() ~= "sogm_fists"
    local melee = IsValid(weapon) and weapon.Base == "sogm_melee_base"

    if hasweapon then
        bot.TakeWeapon = nil
    end

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    --[[local min, max = controller:GetModelBounds()
    debugoverlay.Box(controller:GetPos(), min, max, 0.1, Color(255, 0, 0, 0), true)]]

    -- force a recompute
    if controller.PosGen and controller.P and controller.TPos ~= controller.PosGen then
        controller.TPos = controller.PosGen
        controller.P:Compute(controller, controller.PosGen)
    end

    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end

    mv:SetForwardSpeed(1200)

    if (bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        for _, ply in ipairs(ents.GetAll()) do
            if ply ~= bot and (ply:IsPlayer() or ply:GetClass() == "sogm_mob") and (!ply.Team or ply:Team() == TEAM_DM or ply:Team() ~= bot:Team()) and ply:GetPos():DistToSqr(bot:GetPos()) < 90000 then
                --[[local targetpos = ply:EyePos() - Vector(0, 0, 10)
                local trace = util.TraceLine({
                    start = bot:GetShootPos(),
                    endpos = targetpos,
                    filter = function(ent) return ent == ply end
                })]]

                if ply:Health() > 0 then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + 2
                end
            end
        end
    elseif controller.ForgetTarget < CurTime() and controller:CanSee(controller.Target) then
        controller.ForgetTarget = CurTime() + 2
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if IsValid(bot.TakeWeapon) or (!hasweapon and bot:LBGetStrategy() == 1 and controller.LastSegmented < CurTime()) or !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        if !hasweapon then
            local dist = 999999999

            for _, weapon in pairs(DROPPED_WEAPONS) do
                local dist2 = weapon:GetPos():DistToSqr(bot:GetPos())
                if (!IsValid(bot.TakeWeapon) or weapon:GetPos():DistToSqr(bot:GetPos()) < bot.TakeWeapon:GetPos():DistToSqr(bot:GetPos())) and dist2 + math.random(250, 400) < dist and (dist2 > 90000 or weapon.NoDamage or weapon.StoredClip and weapon.StoredClip < 1 or guns_only and wep:GetType() ~= "ranged") then
                    dist = dist2
                    bot.TakeWeapon = weapon
                end
            end
        end

        if bot.TakeWeapon then
            controller.PosGen = bot.TakeWeapon:WorldSpaceCenter()
            controller.LastSegmented = CurTime() + 3
        else
            -- find a random spot on the map, and in 10 seconds do it again!
            controller.PosGen = controller:FindSpot("random", {radius = 12500})
            controller.LastSegmented = CurTime() + 5
        end
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= (((melee or controller.Target.Knockdown) and 0) or 9000) then
            mv:SetForwardSpeed(-1200)
        end
    end

    -- movement also has a similar issue, but it's more severe...
    if !controller.P then
        return
    end

    local segments = controller.P:GetAllSegments()

    if !segments then return end

    local cur_segment = controller.cur_segment
    local curgoal = segments[cur_segment]

    -- got nowhere to go, why keep moving?
    if !curgoal then
        mv:SetForwardSpeed(0)
        return
    end

    -- think every step of the way!
    if segments[cur_segment + 1] and Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curgoal.pos.x, curgoal.pos.y)) < 100 then
        controller.cur_segment = controller.cur_segment + 1
        curgoal = segments[controller.cur_segment]
    end

    local goalpos = curgoal.pos

    -- waaay too slow during gamplay
    --[[if bot:GetVelocity():Length2DSqr() <= 225 and controller.NextCenter == 0 and controller.NextCenter < CurTime() then
        controller.NextCenter = CurTime() + math.Rand(0.5, 0.65)
    end

    if controller.NextCenter ~= 0 and controller.NextCenter < CurTime() then
        if bot:GetVelocity():Length2DSqr() <= 225 then
            controller.strafeAngle = ((controller.strafeAngle == 1 and 2) or 1)
        end

        controller.NextCenter = 0
    end]]

    if bot:GetVelocity():Length2DSqr() <= 225 then
        if controller.NextCenter < CurTime() then
            controller.strafeAngle = ((controller.strafeAngle == 1 and 2) or 1)
            controller.NextCenter = CurTime() + math.Rand(0.3, 0.65)
        elseif controller.nextStuckJump < CurTime() then
            if !bot:Crouching() then
                controller.NextJump = 0
            end
            controller.nextStuckJump = CurTime() + math.Rand(1, 2)
        end
    end

    if controller.NextCenter > CurTime() then
        if controller.strafeAngle == 1 then
            mv:SetSideSpeed(1500)
        elseif controller.strafeAngle == 2 then
            mv:SetSideSpeed(-1500)
        else
            mv:SetForwardSpeed(-1500)
        end
    end

    -- jump
    if controller.NextJump ~= 0 and curgoal.type > 1 and controller.NextJump < CurTime() then
        controller.NextJump = 0
    end

    -- duck
    if curgoal.area:GetAttributes() == NAV_MESH_CROUCH then
        controller.NextDuck = CurTime() + 0.1
    end

    controller.goalPos = goalpos

    if GetConVar("developer"):GetBool() then
        controller.P:Draw()
    end

    -- eyesight
    local lerp = FrameTime() * ((TEAM_AXE and bot:Team() == TEAM_AXE and 24) or math.random(8, 10))
    local lerpc = FrameTime() * ((TEAM_AXE and bot:Team() == TEAM_AXE and 24) or 8)

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)

    if IsValid(controller.Target) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
        return
    else
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end
    end
end