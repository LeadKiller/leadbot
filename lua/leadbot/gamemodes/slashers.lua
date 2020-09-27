--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "slashers"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true
LeadBot.NoSprint = true
LeadBot.NoFlashlight = true

--[[GAMEMODE CONFIGURATION END]]--

local survivorcmd
local killercmd

local survivormove
local killermove

local HidingSpots = {}

local function addSpots()
    local areas = navmesh.GetAllNavAreas()
    local hidingspots = {}
    local spotsReset = {}

    for _, area in pairs(areas) do
        local spots = area:GetHidingSpots(1)
        local spots2 = area:GetHidingSpots(8)
        local spotsReset2 = {}

        for _, spot in pairs(spots) do
            if !util.QuickTrace(spot, Vector(0, 0, 72)).Hit and !util.QuickTrace(spot, Vector(0, 0, 72)).Hit and !util.TraceHull({start = spot, endpos = spot + Vector(0, 0, 72), mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72)}).HitWorld then
                table.Add(hidingspots, spots)
                table.insert(spotsReset2, spot)
            end
        end

        table.insert(spotsReset, {area, spotsReset2})

        -- table.Add(hidingspots, spots2)

        -- the reason why we don't use spots2 is because these are barely hidden
        -- we should only use it when there are not enough normal hiding spots to diversify hiding places
    end

    MsgN("Found " .. #hidingspots .. " default hiding spots!")
    if #hidingspots < 1 then return end
    --[[MsgN("Teleporting to one...")
    ply:SetPos(table.Random(hidingspots))]]

    HidingSpots = spotsReset
end

function LeadBot.StartCommand(bot, cmd)
    if bot:Team() == TEAM_SURVIVORS then
        survivorcmd(bot, cmd)
    else
        killercmd(bot, cmd)
    end
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if #HidingSpots < 1 then
        addSpots()
    end

    if bot:Team() == TEAM_SURVIVORS then
        survivormove(bot, cmd, mv)
    else
        killermove(bot, cmd, mv)
    end
end

function killercmd(bot, cmd)
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

    if IsValid(target) and math.random(2) == 1 and target:GetPos():DistToSqr(bot:GetPos()) <= 8400 then
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

function killermove(bot, cmd, mv)
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
            if ply ~= bot and ply:GetPos():DistToSqr(bot:GetPos()) < 144000000 then
                if ply:Alive() and controller:IsAbleToSee(ply) then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + 5
                end
            end
        end
    elseif controller.ForgetTarget - 0.1 < CurTime() and controller:IsAbleToSee(controller.Target) then
        controller.ForgetTarget = CurTime() + 5
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        -- find a random spot on the map, and in 10 seconds do it again!
        controller.PosGen = controller:FindSpot("random", {radius = 30000})
        controller.LastSegmented = CurTime() + 10
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= 350 then
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

    if !IsValid(controller.UseTarget) and !IsValid(controller.Target) and controller.LookAtTime < CurTime() then
        controller.LookAt = Angle(math.random(-5, 5), math.random(-30, 30), 0)
        controller.LookAtTime = CurTime() + math.Rand(0.5, 1)
    end

    if IsValid(controller.Target) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
        return
    else
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva + controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end
    end
end

function survivorcmd(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target

    if !IsValid(controller) then return end

    if !GAMEMODE.ROUND.Escape and !IsValid(target) then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
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

function survivormove(bot, cmd, mv)
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

    local objective = "gas"
    local ent = "sls_jerrican"

    if CurrentObjective == "activate_generator" then
        objective = "generator"
        ent = "sls_generator"
    elseif CurrentObjective == "activate_radio" then
        objective = "radio"
        ent = "sls_radio"
    elseif GAMEMODE.ROUND.Escape then
        objective = "escape"
        ent = nil
    elseif CurrentObjective == "wainting_police" then
        objective = "police"
        ent = nil
    end

    if (bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= bot and ply:Team() ~= bot:Team() and ply:GetPos():DistToSqr(bot:GetPos()) < 4500000 then
                --[[local targetpos = ply:EyePos() - Vector(0, 0, 10)
                local trace = util.TraceLine({
                    start = bot:GetShootPos(),
                    endpos = targetpos,
                    filter = function(ent) return ent == ply end
                })]]

                if ply:Alive() and controller:IsAbleToSee(ply) then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + 10
                end
            end
        end

        if ent and !IsValid(controller.Target) and !controller.UseTarget then
            for _, gas in ipairs(ents.FindByClass(ent)) do
                if util.QuickTrace(bot:EyePos(), gas:WorldSpaceCenter() - bot:EyePos(), bot).Entity == gas then
                    controller.UseTarget = gas
                end
            end
        end
    elseif controller.ForgetTarget - 0.1 < CurTime() and util.QuickTrace(bot:EyePos(), controller.Target:WorldSpaceCenter() - bot:EyePos(), bot).Entity == controller.Target then
        controller.ForgetTarget = CurTime() + 10
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if !IsValid(controller.Target) and IsValid(controller.UseTarget) then
        controller.PosGen = controller.UseTarget:GetPos()

        if bot:GetPos():DistToSqr(controller.UseTarget:GetPos()) < ((ent == "sls_generator" and 8000) or 2500) then
            controller.UseTarget:Use(bot, bot, USE_TOGGLE, -1)
            controller.UseTarget = nil
        end
    elseif !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 and objective ~= "police" or controller.LastSegmented < CurTime()) then
        if bot:LBGetStrategy() == 1 or objective == "escape" then
            if !bot.Unchecked then
                bot.Unchecked = {
                    ["gas"] = {},
                    ["generator"] = {},
                    ["radio"] = {}
                }

                for _, objective in ipairs(GAMEMODE.MAP.Goal.Generator) do
                    table.insert(bot.Unchecked.generator, objective.pos)
                end

                for _, objective in ipairs(GAMEMODE.MAP.Goal.Jerrican) do
                    table.insert(bot.Unchecked.gas, objective.pos)
                end

                for _, objective in ipairs(GAMEMODE.MAP.Goal.Radio) do
                    table.insert(bot.Unchecked.radio, objective.pos)
                end
            end

            if objective == "police" then
                if !bot.hidingspot then
                    local area = table.Random(HidingSpots)
                    if #area[2] > 0 and controller.loco:IsAreaTraversable(area[1]) then
                        local spot = table.Random(area[2])
                        bot.hidingspot = spot
                    end
                else
                    local dist = bot:GetPos():DistToSqr(bot.hidingspot)
                    if dist < 1200 then -- we're here
                        controller.PosGen = nil
                    else -- we need to run...
                        controller.PosGen = bot.hidingspot
                    end
                end
                controller.LastSegmented = CurTime() + 1
            elseif objective == "escape" then
                local ent2 = ents.FindByName("trigger_escape")[1]
                local distance = 9999999999

                for _, ent in ipairs(ents.FindByName("trigger_escape")) do
                    local dist = ent:GetPos():DistToSqr(bot:GetPos())
                    local nav = navmesh.GetNavArea(ent:GetPos(), 0)
                    if dist < distance and IsValid(nav) and controller.loco:IsAreaTraversable(nav) then
                        ent2 = ent
                        distance = dist
                    end
                end

                controller.PosGen = ent2:GetPos()
                controller.LastSegmented = CurTime() + 1
            else
                if controller.PosGen and bot:GetPos():DistToSqr(controller.PosGen) < 1000 then
                    table.RemoveByValue(bot.Unchecked[objective], controller.PosGen)
                end

                controller.PosGen = table.Random(bot.Unchecked[objective])
                controller.LastSegmented = CurTime() + 30
            end
        else
            -- find a random spot on the map, and in 10 seconds do it again!
            controller.PosGen = controller:FindSpot("random", {radius = 20000})
            controller.LastSegmented = CurTime() + 10
        end
    elseif IsValid(controller.Target) and controller.LastSegmented < CurTime() then
        if !bot.hidingspot or util.QuickTrace(bot:EyePos(), controller.Target:WorldSpaceCenter() - bot:EyePos(), bot).Entity == controller.Target then
            local hidingspots = table.Copy(HidingSpots)
            local players = player.GetAll()

            for id, spot in ipairs(hidingspots) do
                if #spot[2] > 0 then
                    local closest = bot
                    local distance = 999999999999
                    local area = spot[1]

                    spot = table.Random(spot[2])

                    for _, ply in ipairs(players) do
                        local dist = ply:GetPos():DistToSqr(spot)
                        if dist < distance then
                            distance = dist
                            closest = ply
                        end
                    end

                    if !controller.loco:IsAreaTraversable(area) or spot:DistToSqr(bot:GetPos()) > 1000000 or closest:Team() == TEAM_KILLER or (team.GetPlayers(TEAM_KILLER)[1]:VisibleVec(spot)) then
                        hidingspots[id] = nil
                        continue
                    end
                else
                    hidingspots[id] = nil
                end
            end

            local area = table.Random(hidingspots)
            local spot = table.Random(area[2])

            bot.hidingspot = spot
            controller.PosGen = bot.hidingspot
        end

        controller.LastSegmented = CurTime() + 5
    end

    if IsValid(controller.Target) and bot.hidingspot and bot:GetPos():DistToSqr(bot.hidingspot) <= 5625 then
        controller.PosGen = nil
        mv:SetForwardSpeed(0)
        controller.NextCenter = CurTime()
        controller.nextStuckJump = CurTime() + 0.5
        controller.cur_segment = {}

        if controller.LookAtTime < CurTime() then
            controller.LookAt = Angle(math.random(-30, 30), math.random(-180, 180), 0)
            controller.LookAtTime = CurTime() + math.Rand(0.5, 1)
        elseif controller.LookAtTime > CurTime() and controller.LookAt then
            local ang = LerpAngle(FrameTime() * 3, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end

        return
    end

    if !IsValid(controller.UseTarget) and !IsValid(controller.Target) and controller.LookAtTime < CurTime() then
        if math.random(100) <= 75 then
            controller.LookAt = Angle(math.random(-30, 30), math.random(-180, 180), 0)
            controller.LookAtTime = CurTime() + math.Rand(0.5, 1)
        else
            controller.LookAt = nil
            controller.LookAtTime = CurTime() + math.Rand(1.5, 2)
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
    local lerpc2 = FrameTime() * 3

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)

    if controller.LookAtTime > CurTime() and controller.LookAt then
        local ang = LerpAngle(lerpc2, bot:EyeAngles(), controller.LookAt)
        bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
    else
        local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
        bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
    end
end

function LeadBot.PostPlayerDeath(bot)
    bot.hidingspot = nil
    bot.Unchecked = nil
    bot.LeadBot_Config[4] = math.random(0, 1)
end