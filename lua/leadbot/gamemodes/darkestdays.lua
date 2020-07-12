--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = true
LeadBot.Gamemode = "darkestdays"
LeadBot.TeamPlay = false
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.AddBotOverride(bot)
    if math.random(2) == 1 then
        timer.Simple(math.random(1, 4), function()
            LeadBot.TalkToMe(bot, "join")
        end)
    end

    if GAMEMODE:GetGametype() == "ffa" then
        bot:SetTeam(TEAM_FFA)
    elseif GAMEMODE:GetGametype() == "ts" then
        if GAMEMODE.DeadPeople[tostring(bot:SteamID())] or IsValid(GetHillEntity()) and GetHillEntity():GetTimer() <= TS_TIME * (1 - TS_DEADLINE) then
            bot:SetTeam(TEAM_THUG)
        else
            bot:SetTeam(TEAM_BLUE)
        end
    else
        if bot:CanJoinTeam(TEAM_RED) then
            bot:SetTeam(TEAM_RED)
        else
            bot:SetTeam(TEAM_BLUE)
        end
    end
end

function LeadBot.PlayerSpawn(bot)
    local primaries = {}
    local secondaries = {}
    local _, spell1 = table.Random(Spells)
    local _, spell2 = table.Random(Spells)
    local _, perk = table.Random(Perks)
    local build = table.Random(Builds)

    for class, wep in pairs(Weapons) do
        if wep.Melee then
            table.insert(secondaries, class)
        else
            table.insert(primaries, class)
        end
    end

    local primary, secondary = table.Random(primaries), table.Random(secondaries)

    -- melee only person
    if math.random(5) == 1 then
        primary = "none"
        build = Builds[table.Random({"healthy", "agile"})]
        perk = "adrenaline"
    end

    bot.Loadout = {primary, secondary}
    bot.SpellsToGive = {spell1, spell2}

    if math.random(5) == 1 or perk == "adrenaline" then
        bot.PerksToGive = {perk}
    else
        bot.PerksToGive = {"none"}
    end

    build.OnSet(bot)
end

local gametype

function LeadBot.Think()
    if !gametype then
        LeadBot.TeamPlay = GAMEMODE:GetGametype() ~= "ffa"
        gametype = GAMEMODE:GetGametype()
    end

    for _, bot in pairs(player.GetAll()) do
        if bot:IsLBot() then
            if bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
                return
            end

            local wep = bot:GetActiveWeapon()
            if IsValid(wep) then
                local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                bot:SetAmmo(wep.Primary.DefaultClip, ammoty)
            end
        end
    end
end

function LeadBot.FindClosest(controller)
    local players = team.GetPlayers(TEAM_BLUE)
    local distance = 9999
    local playing = players[1]
    local distanceplayer = 9999999
    for k, v in pairs(players) do
        distanceplayer = v:GetPos():DistToSqr(controller:GetPos())
        if distance > distanceplayer and v ~= controller then
            distance = distanceplayer
            playing = v
        end
    end

    controller.Target = playing
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target

    if LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) then
        if (botWeapon:Clip1() == 0 or !IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
            buttons = buttons + IN_RELOAD
        end

        if IsValid(target) and (math.random(2) == 1 or botWeapon:GetClass() == "dd_striker") then
            bot:SwitchSpell()
            buttons = buttons + IN_ATTACK + ((!bot:IsThug() and IN_ATTACK2) or 0)
            if math.random((botWeapon.Base == "dd_meleebase" and 6) or 16) == 1 then
                buttons = buttons + IN_USE
            end
        end
    end

    if controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    --[[if controller.MovingBack and math.random(6) == 1 then
        buttons = buttons + IN_USE
    end]]

    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    -- bot:SelectWeapon((IsValid(controller.Target) and controller.Target:GetPos():DistToSqr(controller:GetPos()) < 129000 and "weapon_shotgun") or "weapon_smg1")
    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    local wep = bot:GetActiveWeapon()

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

    local zombies = gametype == "ts"

    if (!zombies or zombies and bot:Team() ~= TEAM_THUG) and ((bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or !controller.Target:Alive()) then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        if zombies and bot:Team() == TEAM_THUG then
            LeadBot.FindClosest(controller)
        else
            for _, ply in ipairs(player.GetAll()) do
                if ply ~= bot and ((ply:IsPlayer() and (!LeadBot.TeamPlay or (LeadBot.TeamPlay and (ply:Team() ~= bot:Team())))) or ply:IsNPC()) and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 then
                    --[[local targetpos = ply:EyePos() - Vector(0, 0, 10)
                    local trace = util.TraceLine({
                        start = bot:GetShootPos(),
                        endpos = targetpos,
                        filter = function(ent) return ent == ply end
                    })]]

                    if ply:Alive() and controller:IsAbleToSee(ply) then
                        controller.Target = ply
                        controller.ForgetTarget = CurTime() + 2
                    end
                end
            end
        end
    elseif controller.ForgetTarget < CurTime() and controller:IsAbleToSee(controller.Target) then
        controller.ForgetTarget = CurTime() + 2
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("Open","",0)
    end

    -- controller.MovingBack = false

    if !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        if gametype == "koth" then
            local rand = VectorRand() * (ents.FindByClass("koth_point")[1]:GetRadius() - 4)
            controller.PosGen = ents.FindByClass("koth_point")[1]:GetPos() + Vector(rand.x, rand.y, 0)
            controller.LastSegmented = CurTime() + math.random(3, 6)
        else
            -- find a random spot on the map, and in 10 seconds do it again!
            controller.PosGen = controller:FindSpot("random", {radius = 12500})
            controller.LastSegmented = CurTime() + 10
        end
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if IsValid(wep) and wep.Base ~= "dd_meleebase" and distance <= 90000 then
            -- controller.MovingBack = true
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
    local vel = bot:GetVelocity()
    vel = Vector(math.floor(vel.x, 2), math.floor(vel.y, 2), 0)

    if vel == Vector(0, 0, 0) or controller.NextCenter > CurTime() then
        curgoal.pos = curgoal.area:GetCenter()
        goalpos = segments[controller.cur_segment - 1].area:GetCenter()
        if vel == Vector(0, 0, 0) then
            controller.NextCenter = CurTime() + 0.25
        end
    end

    -- jump
    if controller.NextJump ~= 0 and goalpos.z > (bot:GetPos().z + 16) and controller.NextJump < CurTime() then
        controller.NextJump = 0
    end

    if GetConVar("developer"):GetBool() then
        controller.P:Draw()
    end

    -- eyesight
    local lerp = FrameTime() * math.random(8, 10)
    local lerpc = FrameTime() * 8

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    local mva = ((goalpos + bot:GetViewOffset()) - bot:GetShootPos()):Angle()

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