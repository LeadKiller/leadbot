LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "zombieplague"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

function LeadBot.AddBotOverride(bot)
    RoundManager:AddPlayerToPlay(bot)
end

local humancmd
local zombiecmd
local humanmove
local zombiemove

function LeadBot.StartCommand(bot, cmd)
    local buttons = 0
    local hbuttons = 0

    if bot.NextJump == 0 then
        bot.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and bot.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    if bot:Team() == TEAM_HUMANS then
        hbuttons = humancmd(bot, cmd)
    else
        hbuttons = zombiecmd(bot, cmd)
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons + hbuttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    bot.Forget = bot.Forget or CurTime()
    bot.NextJump = bot.NextJump or CurTime()

    if !IsValid(bot.ControllerBot) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
    end

    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    if bot:Team() == TEAM_HUMANS then
        humanmove(bot, cmd, mv)
    else
        zombiemove(bot, cmd, mv)
    end
end

function zombiecmd(bot, cmd)
    local buttons = 0

    if IsValid(bot.TargetEnt) and bot.SeeTarget then
        local attack = IN_ATTACK
        if math.random(2) == 1 then
            attack = IN_ATTACK2
        end
        buttons = buttons + attack
    end

    return buttons
end

function humancmd(bot, cmd)
    local buttons = IN_SPEED

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(bot.TargetEnt) and bot.SeeTarget and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    return buttons
end

local function navigate(bot, cmd, mv, goal, segments)
    mv:SetForwardSpeed(1200)
    bot.ControllerBot.PosGen = bot.botPos

    if !bot.ControllerBot.P then
        return
    end

    local segments = bot.ControllerBot.P:GetAllSegments()

    if !segments then return end

    local curgoal = segments[2]

    if !curgoal then return end

    if segments[3] and segments[3].pos.z > bot:GetPos().z + 6 and bot.NextJump < CurTime() then
        bot.NextJump = 0
    end

    local cur_segment = 1

    -- think 15 steps ahead!
    for i, segment in pairs(segments) do
        if i < 5 then
            if bot:VisibleVec(segment.pos) and i > cur_segment then
                cur_segment = i
            end
        end
    end

    curgoal = segments[cur_segment]

    if bot == Entity(1) then
        bot.ControllerBot.P:Draw()
    end

    local lerp = 3
    local lerpc = 2

    if !LeadBot.LerpAim then
        lerp = 100
        lerpc = 100
    end

    local mva = ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()

    if Vector(curgoal.pos.x, curgoal.pos.y, 0):DistToSqr(Vector(bot:GetPos().x, bot:GetPos().y, 0)) < 500 then
        if segments[cur_segment + 1] then
            curgoal = segments[cur_segment + 1]
        else
            mva = Angle(0, 0, 0)
            mv:SetForwardSpeed(0)
        end
        
        -- recalculating
    end

    if mva ~= Angle(0, 0, 0) then
        mv:SetMoveAngles(mva)
    else
        mv:SetForwardSpeed(0)
    end

    if mv:GetForwardSpeed() == 0 then return end

    if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt then
        local shouldvegoneforthehead = bot.TargetEnt:EyePos()
        local group = math.random(0, bot.TargetEnt:GetHitBoxGroupCount() - 1)
        local bone = bot.TargetEnt:GetHitBoxBone(math.random(0, bot.TargetEnt:GetHitBoxCount(group) - 1), group) or 0
        shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bone)
        bot:SetEyeAngles(LerpAngle(FrameTime() * lerp, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle())) --[[+ bot:GetViewPunchAngles()]]
    elseif bot:GetPos():DistToSqr(curgoal.pos) > 400 then
        bot:SetEyeAngles(LerpAngle(FrameTime() * lerpc, bot:EyeAngles(), mva))
    end

    local eyea = bot:EyeAngles()

    bot:SetEyeAngles(Angle(eyea.p, eyea.y, 0))
end

local function doorai(bot)
    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("Open","",0)
    end
end

local function targetai(bot)
    bot.SeeTarget = false
    if IsValid(bot.TargetEnt) then
        bot.SeeTarget = util.TraceLine({start = bot:GetShootPos(), endpos = bot.TargetEnt:EyePos() - Vector(0, 0, 10), filter = function(ent) return ent == bot.TargetEnt end}).Entity == bot.TargetEnt
    end

    if !IsValid(bot.TargetEnt) then
        for _, ply in pairs(player.GetAll()) do
            if ply ~= bot --[[and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000]] and ply:Team() ~= bot:Team() then
                local targetpos = ply:EyePos() - Vector(0, 0, 10)
                local trace = util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function(ent) return ent == ply end})

                if trace.Entity == ply then
                    bot.TargetEnt = ply
                end
            end
        end
    elseif !bot.TargetEnt:Alive() or bot.TargetEnt:Team() == bot:Team() or bot.Forget < CurTime() and !bot.SeeTarget then
        bot.TargetEnt = nil
    elseif bot.Forget < CurTime() then
        bot.Forget = CurTime() + 3
    end
end

local function movementai(bot, cmd, mv)
    if !IsValid(bot.TargetEnt) and (!bot.botPos or bot:GetPos():DistToSqr(bot.botPos) < 25000 --[[3600]] or math.abs(bot.LastSegmented - CurTime()) > 10) then
        bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 22500})
        bot.LastSegmented = CurTime()
    elseif IsValid(bot.TargetEnt) then
        local distance = bot.TargetEnt:GetPos():DistToSqr(bot:GetPos())
        bot.botPos = bot.TargetEnt:GetPos()

        if (bot:Team() == TEAM_ZOMBIES and distance <= 2000) or distance <= 160000 then
            mv:SetForwardSpeed(-1200)
        end
    end
end

function zombiemove(bot, cmd, mv)
    targetai(bot)
    doorai(bot)
    movementai(bot, cmd, mv)
    navigate(bot, cmd, mv)
end

function humanmove(bot, cmd, mv)
    targetai(bot)
    doorai(bot)
    movementai(bot, cmd, mv)
    navigate(bot, cmd, mv)
end