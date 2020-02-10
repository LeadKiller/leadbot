-- this MUST support all classes (excluding crafter).

LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "noxctf"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

local archerclasses = {[1] = true}
local meleeclasses = {[2] = true}
local classes = {1}

local spellai
local meleeai
local meleeaicmd
local archerai
local archeraicmd

function LeadBot.PlayerSpawn()
    -- no class, pick one!
    if bot.LeadBot and bot:GetPlayerClass() < 1 then
        hook.Call("ChangeClass", gmod.GetGamemode(), bot, _, _, table.Random(classes))
    end
end

function LeadBot.StartCommand(bot, cmd)
    if archerclasses[bot:GetPlayerClass()] then
        archeraicmd(bot, cmd)
    elseif meleeclasses[bot:GetPlayerClass()] then
        meleeaicmd(bot, cmd)
    end
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if archerclasses[bot:GetPlayerClass()] then
        archerai(bot, cmd, mv)
    elseif meleeclasses[bot:GetPlayerClass()] then
        meleeai(bot, cmd, mv)
    end

    spellai(bot, cmd, mv)
end

local function spellai(bot, cmd, mv)
    local spells = bot:GetCastableSpells()

    -- casting is done with EmulatedCast(bot, _, spellname)
    -- archers should just use vampiric and fire, i think like EmulatedCast(bot, _, "Fire Arrow")?
end

local function meleeai(bot, cmd, mv)
end

local function meleeaicmd(bot, cmd)
end

local function archeraicmd(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()

    if !LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(bot.TargetEnt) and bot.SeeTarget and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    if bot.NextJump == 0 then
        bot.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and bot.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

local function archerai(bot, cmd, mv)
    if !IsValid(bot.ControllerBot) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
    end

    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    --cmd:SetForwardMove(250)

    ------------------------------
    -----[[ENTITY DETECTION]]-----
    ------------------------------

    bot.Forget = bot.Forget or CurTime()
    bot.NextJump = bot.NextJump or CurTime()

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

    ------------------------------
    --------[[BOT LOGIC]]---------
    ------------------------------

    mv:SetForwardSpeed(1200)

    if !IsValid(bot.TargetEnt) and (!bot.botPos or bot:GetPos():DistToSqr(bot.botPos) < 25000 --[[3600]] or math.abs(bot.LastSegmented - CurTime()) > 10) then
        -- find a random spot on the map, and in 10 seconds do it again!
        bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 22500})
        bot.LastSegmented = CurTime()
    elseif IsValid(bot.TargetEnt) then
        -- move to our target
        local distance = bot.TargetEnt:GetPos():DistToSqr(bot:GetPos())
        bot.botPos = bot.TargetEnt:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        if distance <= 240000 then
            mv:SetForwardSpeed(-1200)
        end
    end

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
        -- util.QuickTrace(bot:EyePos(), (segment.pos - bot:EyePos()), bot).HitPos == segment.pos caused lag :(
        if bot:VisibleVec(segment.pos) and i > cur_segment then
            cur_segment = i
        end
    end

    curgoal = segments[cur_segment]


    ------------------------------
    --------[[BOT EYES]]---------
    ------------------------------

    local lerp = 3
    local lerpc = 2

    if !LeadBot.LerpAim then
        lerp = 100
        lerpc = 100
    end

    local mva = ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(LerpAngle(FrameTime() * 65, mv:GetMoveAngles(), mva))

    if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt then
        local shouldvegoneforthehead = bot.TargetEnt:EyePos()
        local group = math.random(0, bot.TargetEnt:GetHitBoxGroupCount() - 1)
        local bone = bot.TargetEnt:GetHitBoxBone(math.random(0, bot.TargetEnt:GetHitBoxCount(group) - 1), group) or 0
        shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bone)
        bot:SetEyeAngles(LerpAngle(FrameTime() * lerp, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle() + Angle(-8, 0, 0))) --[[+ bot:GetViewPunchAngles()]]
    elseif bot:GetPos():DistToSqr(curgoal.pos) > 400 then
        bot:SetEyeAngles(LerpAngle(FrameTime() * lerpc, bot:EyeAngles(), mva))
    end

    local eyea = bot:EyeAngles()

    bot:SetEyeAngles(Angle(eyea.p, eyea.y, 0))
end