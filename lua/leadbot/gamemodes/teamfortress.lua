--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.SetModel = true
LeadBot.Gamemode = "teamfortress"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true
LeadBot.NoSprint = true
LeadBot.NoFlashlight = true

--[[GAMEMODE CONFIGURATION END]]--

-- TODO: when seeing friendly medic and low on health, yell medic and follow them for a few seconds before giving up
-- TODO: predict where players are moving when using projectile weapon
-- TODO: look into tf leak?
-- TODO: add legacy tf_bot commands as aliases
-- TODO: use the retreat thing from slashers bots when fighting a stronger class or lots of enemies

LeadBot.TF_Classes = {"scout", "soldier", "pyro", "heavy", "demoman", "sniper"}
LeadBot.TF_Objectives = {}

function LeadBot.AddBotOverride(bot)
    if math.random(2) == 1 then
        timer.Simple(math.random(1, 4), function()
            LeadBot.TalkToMe(bot, "join")
        end)
    end

    local red = TEAM_RED
    local blue = TEAM_BLU
    local selected = red
    local teams = {[1] = {}, [2] = {}}
    for _, ply in pairs(player.GetAll()) do
        if ply:Team() == red then
            table.insert(teams[1], ply)
        elseif ply:Team() == blue then
            table.insert(teams[2], ply)
        end
    end

    if #teams[2] < #teams[1] then
        selected = blue
    else
        selected = red
    end

    bot:SetTeam(selected)
    bot.PreferredClass = table.Random(LeadBot.TF_Classes)

    timer.Simple(0, function()
        bot:SetPlayerClass(bot.PreferredClass)
        bot:Spawn()
    end)
end

function LeadBot.PostPlayerDeath(bot)
    if math.random(100) <= 30 then
        bot.PreferredClass = table.Random(LeadBot.TF_Classes)
    end

    bot:SetPlayerClass(bot.PreferredClass)
end

function LeadBot.Think()
    if (string.StartWith(game.GetMap(), "ctf_") or string.StartWith(game.GetMap(), "mvm_")) and #LeadBot.TF_Objectives < 1 then
        local redintel
        local bluintel
        local redcap
        local blucap

        for _, ent in ipairs(ents.FindByClass("item_teamflag")) do
            if ent.TeamNum == TEAM_RED then
                bluintel = ent
            else
                redintel = ent
            end
        end

        for _, ent in ipairs(ents.FindByClass("item_teamflag_mvm")) do
            if ent.TeamNum == TEAM_RED then
                bluintel = ent
            else
                redintel = ent
            end
        end

        for _, ent in ipairs(ents.FindByClass("func_capturezone")) do
            if ent.TeamNum == TEAM_RED then
                redcap = ent
            else
                blucap = ent
            end
        end

        LeadBot.TF_Objectives[TEAM_RED] = {intel = redintel, cap = redcap}
        LeadBot.TF_Objectives[TEAM_BLU] = {intel = bluintel, cap = blucap}
    end

    for _, bot in pairs(player.GetBots()) do
        if bot:IsLBot() then
            if LeadBot.RespawnAllowed and bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
                return
            end

            local wep = bot:GetActiveWeapon()
            if IsValid(wep) then
                local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                bot:SetAmmo(999, ammoty)
            end
        end
    end
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target

    if !IsValid(controller) then return end

    if LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(target) and (math.random(2) == 1 and bot.PreferredClass ~= "pyro" or bot.PreferredClass == "heavy" or bot.PreferredClass == "pyro" and target:GetPos():DistToSqr(bot:GetPos()) <= 75625) then
        buttons = buttons + IN_ATTACK
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
    local controller = bot.ControllerBot

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
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= bot and ((ply:IsPlayer() and (!LeadBot.TeamPlay or (LeadBot.TeamPlay and (ply:Team() ~= bot:Team())))) or ply:IsNPC()) and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 then
                --[[local targetpos = ply:EyePos() - Vector(0, 0, 10)
                local trace = util.TraceLine({
                    start = bot:GetShootPos(),
                    endpos = targetpos,
                    filter = function(ent) return ent == ply end
                })]]

                if ply:Alive() and controller:CanSee(ply) then
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

    local objective = LeadBot.TF_Objectives[bot:Team()]
    local intel = objective.intel

    if intel.Carrier == bot or !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        if bot:LBGetStrategy() == 2 then
            -- find a random spot on the map, and in 10 seconds do it again!
            controller.PosGen = controller:FindSpot("random", {radius = 12500})
            controller.LastSegmented = CurTime() + 10
        elseif controller.LastSegmented < CurTime() then
            local our_objective = LeadBot.TF_Objectives[(bot:Team() == TEAM_RED and TEAM_BLU) or TEAM_RED]
            local cap = objective.cap
            local our_intel = our_objective.intel

            if !intel.Carrier and !our_intel.Carrier then -- no one has intel, let's get enemy intel
                controller.PosGen = intel:GetPos()
            elseif intel.Carrier == bot then -- have intel, go cap
                controller.PosGen = cap.Pos
            elseif bot:LBGetStrategy() == 1 and our_intel.Carrier then -- defend
                controller.PosGen = our_intel:GetPos()
            elseif intel.Carrier then -- someone has our intel, let's take it back
                controller.PosGen = intel:GetPos()
            end

            controller.LastSegmented = CurTime() + math.Rand(0.5, 1)
        end
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= (bot.PreferredClass == "pyro" and 62500 or 90000) then
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
    local lerp = FrameTime() * math.random(8, 10)
    local lerpc = FrameTime() * 8

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