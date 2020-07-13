LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "zombieplague"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

local DEBUG = false
local HidingSpots = {}

function LeadBot.AddBotOverride(bot)
    RoundManager:AddPlayerToPlay(bot)
end

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

function LeadBot.PlayerMove(bot, cmd, mv)
    if #HidingSpots < 1 then
        addSpots()
    end

    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

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
            if ply ~= bot and ((ply:IsPlayer() and (ply:Team() ~= bot:Team())) or ply:IsNPC()) and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 then
                if ply:Alive() and controller:IsAbleToSee(ply) then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + 2
                end
            end
        end
    elseif controller.ForgetTarget < CurTime() and controller:IsAbleToSee(controller.Target) then
        controller.ForgetTarget = CurTime() + 2
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if bot:Team() ~= TEAM_HUMANS and bot.hidingspot then
        bot.hidingspot = nil
    end

    if DEBUG then
        debugoverlay.Text(bot:EyePos(), bot:Nick(), 0.03, false)
        local min, max = bot:GetHull()
        debugoverlay.Box(bot:GetPos(), min, max, 0.03, Color(255, 255, 255, 0))

        if bot.hidingspot then
            debugoverlay.Text(bot.hidingspot, bot:Nick() .. "'s hiding spot!", 0.1, false)
        end
    end

    if !IsValid(controller.Target) and ((bot:Team() ~= TEAM_HUMANS and (!controller.PosGen or (controller.PosGen and bot:GetPos():DistToSqr(controller.PosGen) < 5000))) or bot:Team() == TEAM_HUMANS or controller.LastSegmented < CurTime()) then
        if bot:Team() == TEAM_HUMANS then
            -- hiding ai
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

            controller.LastSegmented = CurTime() + 3
        else
            -- search all hiding spots we know of...
            local area = table.Random(HidingSpots)

            if #area[2] > 0 and controller.loco:IsAreaTraversable(area[1]) then
                local spot = table.Random(area[2])
                controller.PosGen =  spot
            end

            controller.LastSegmented = CurTime() + 10
        end
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if bot:Team() ~= TEAM_ZOMBIES and distance <= 160000 then
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
    local curgoal = (controller.PosGen and segments[cur_segment])

    -- eyesight
    local lerp = FrameTime() * math.random(8, 10)
    local lerpc = FrameTime() * 8
    local mva

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    -- got nowhere to go, why keep moving?
    if curgoal then
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
        if controller.NextJump ~= 0 and segments[controller.cur_segment].type ~= 0 and controller.NextJump < CurTime() then
            controller.NextJump = 0
        end

        controller.goalPos = goalpos

        if DEBUG then
            controller.P:Draw()
        end

        mva = ((goalpos + bot:GetViewOffset()) - bot:GetShootPos()):Angle()

        mv:SetMoveAngles(mva)
    else
        mv:SetForwardSpeed(0)
    end

    if IsValid(controller.Target) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
        return
    elseif curgoal then
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end
    elseif bot.hidingspot then
        bot.NextSearch = bot.NextSearch or CurTime()
        bot.SearchAngle = bot.SearchAngle or Angle(0, 0, 0)

        if bot.NextSearch < CurTime() then
            bot.NextSearch = CurTime() + math.random(2, 3)
            bot.SearchAngle = Angle(math.random(-40, 40), math.random(-180, 180), 0)
        end

        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), bot.SearchAngle))
    end
end

function LeadBot.PostPlayerDeath(bot)
    bot.hidingspot = nil
end

if !DEBUG then return end

concommand.Add("hidingSpot", function(ply, _, args)
    addSpots()
end)