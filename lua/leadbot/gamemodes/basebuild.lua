LeadBot.RespawnAllowed = true
LeadBot.PlayerColor = false
LeadBot.TeamPlay = true
LeadBot.LerpAim = true
LeadBot.SuicideAFK = false
LeadBot.Strategies = 1

local nextPlayers = 0
local playerTab

function LeadBot.AddBotOverride(bot)
    local red = 1
    local blue = 2
    local selected = red
    local teams = {[1] = {}, [2] = {}}
    for _, ply in pairs(playerTab) do
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
end

function LeadBot.Think()
    if nextPlayers < CurTime() then
        playerTab = player.GetAll()
        nextPlayers = CurTime() + 0.3
    end

    for _, bot in ipairs(player.GetBots()) do
        if bot:IsLBot() then
            if LeadBot.RespawnAllowed and bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
                return
            end
        end
    end
end

function LeadBot.SelectWeapon(bot)
    local strat = bot.LeadBot_Config[4]

    if strat == 1 then -- resource gatherer
        local controller = bot.ControllerBot
        if IsValid(controller.TargetRes2) then
            bot:SelectWeapon("weapon_physcannon")
        else
            bot:SelectWeapon("weapon_crowbar")
        end
    end
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = 0
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target
    local strat = bot.LeadBot_Config[4]

    if IsValid(botWeapon) then
        if (botWeapon:Clip1() == 0 or !IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
            buttons = buttons + IN_RELOAD
        end

        if IsValid(target) or IsValid(controller.TargetRes) then
            local dis = 9999999
            local addbuttons = 0

            if IsValid(controller.TargetRes) then
                target = controller.TargetRes
                dis = 140000
                addbuttons = IN_DUCK
            end

            if math.random(2) == 1 and bot:GetPos():DistToSqr(target:GetPos()) <= dis then
                buttons = buttons + IN_ATTACK + addbuttons
            end

            -- buttons = buttons + IN_ATTACK2
        elseif IsValid(controller.TargetRes2) then 
            if !controller.TargetRes2:IsPlayerHolding() then
                buttons = buttons + IN_ATTACK2
            elseif controller.PuntPos then
                if controller.LastPunt < CurTime() then
                    buttons = buttons + IN_ATTACK
                    controller.TargetRes2 = nil
                    controller.PuntPos = nil
                    controller.LastPunt = nil
                end
            end
        end
    end

    -- sprint with no target
    if !IsValid(target) then
        -- buttons = IN_SPEED
    end

    if controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    -- whatever, just use curtime delay -_-
    if !bot.LBT_WeaponSwitch or bot.LBT_WeaponSwitch < CurTime() then
        LeadBot.SelectWeapon(bot)
        bot.LBT_WeaponSwitch = CurTime() + 1 + (math.random(50, 100) * 0.01)
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

local redgravgun = Vector(3563.870361, 1024.177734, -100.365662)
local nextcheck = 0
local trees = {}
local rocks = {}
local ores = {}
local teamtargets = {}
teamtargets[0] = 1
teamtargets[1] = 1
local entnames = {}
entnames[1] = "wood_*"
entnames[2] = "rock_*"
entnames[3] = "iron_ore_*"

hook.Add("PlayerSay", "LeadBot_Chat", function(ply, txt, team)
    if team then
        if txt == "wood" then
            teamtargets[ply:Team()] = 1
            ply:ChatPrint("Bots will now go for Wood!")
        elseif txt == "stone" then
            teamtargets[ply:Team()] = 2
            ply:ChatPrint("Bots will now go for Stone!")
        elseif txt == "iron" or txt == "iron ore" then
            teamtargets[ply:Team()] = 3
            ply:ChatPrint("Bots will now go for Iron Ore!")
        end
    end
end)

function LeadBot.PlayerMove(bot, cmd, mv)
    if !playerTab then return end

    local controller = bot.ControllerBot
    local strat = bot.LeadBot_Config[4]

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    mv:SetForwardSpeed(1200)
    -- main thing that's keeping the bots from being lag free is seeking targets
    -- losing about 4-25 fps with this
    -- for now, using player.GetAll() rather than ents.GetAll()
    -- having no npc support is bad, but I think most people will use this for dm
    if (bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !bot:Alive() then return end

    if nextcheck < CurTime() then
        nextcheck = CurTime() + 5
        trees = {}
        stones = {}
        ores = {}
        for _, breakable in pairs(ents.FindByClass("func_breakable")) do
            local ohno = ents.FindInSphere(breakable:GetPos(), 16)[1]
            if IsValid(ohno) and ohno:GetClass() == "prop_dynamic" then
                local mdl = ohno:GetModel()
                if string.find(mdl, "tree") then
                    table.insert(trees, breakable)
                elseif string.find(mdl, "granite") then
                    table.insert(ores, breakable)
                elseif string.find(mdl, "rock") then
                    table.insert(stones, breakable)
                end
            end
        end
    end

    if !IsValid(controller.Target) and strat == 0 then
        for _, ply in ipairs(playerTab) do
            if ply ~= bot and ((ply:IsPlayer() and (!LeadBot.TeamPlay or (LeadBot.TeamPlay and (ply:Team() ~= bot:Team())))) or ply:IsNPC()) and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 then
                local targetpos = ply:EyePos() - Vector(0, 0, 10)
                local trace = util.TraceLine({
                    start = bot:GetShootPos(),
                    endpos = targetpos,
                    filter = function(ent) return ent == ply end
                })

                if trace.Entity == ply then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + 2
                    hook.Call("SendRadioCommand", gmod.GetGamemode(), bot, 1, 1)
                end
            end
        end
    end

    if strat == 1 then
        if !IsValid(controller.TargetRes2) then
            if IsValid(controller.TargetRes) and controller.TargetRes:Health() < 1 then
                controller.TargetRes = nil
            end

            if !IsValid(controller.TargetRes) and !controller.Chasing then
                local tab = trees

                local t = teamtargets[bot:Team()]
                if t == 2 then
                    tab = rocks
                elseif t == 3 then
                    tab = ores
                end
                local closest = tab[1]

                if !IsValid(closest) then
                    teamtargets[bot:Team()] = 1
                    return
                end

                local dis = closest:GetPos():DistToSqr(bot:GetPos())
                for _, ent in pairs(tab) do
                    if !IsValid(ent) then return end
                    local dis2 = ent:GetPos():DistToSqr(bot:GetPos())
                    if dis2 < dis then
                        closest = ent
                        dis = dis2
                    end
                end

                controller.TargetRes = closest
                controller.Chasing = true
            elseif !IsValid(controller.TargetRes) and controller.Chasing then
                controller.TargetRes = nil
                local res = ents.FindByName(entnames[teamtargets[bot:Team()]])
                if !IsValid(res[1]) then controller.TargetRes = nil controller.TargetRes2 = nil controller.Chasing = false return end
                local closest = res[1]
                local dis = closest:GetPos():DistToSqr(bot:GetPos())
                for _, ent in pairs(res) do
                    local dis2 = ent:GetPos():DistToSqr(bot:GetPos())
                    if dis2 < dis then
                        closest = ent
                        dis = dis2
                    end
                end

                if closest:GetPos():DistToSqr(bot:GetPos()) < 160000 then
                    controller.TargetRes = nil
                    controller.TargetRes2 = closest
                    controller.Chasing = false
                end
            end
        elseif IsValid(controller.TargetRes2) and controller.TargetRes2:IsPlayerHolding() then
            controller.PosGen = redgravgun

            if !controller.PuntPos and bot:GetPos():DistToSqr(redgravgun) < 5600000 and bot:VisibleVec(redgravgun) then
                controller.PuntPos = redgravgun
                controller.LastPunt = CurTime() + 1
                -- controller.TargetRes2 = nil
                print("f")
            end
        end
    end

    if strat ~= 1 and !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        -- find a random spot on the map, and in 10 seconds do it again!
        controller.PosGen = controller:FindSpot("random", {radius = 12500})
        controller.LastSegmented = CurTime() + 10
    elseif IsValid(controller.Target) or IsValid(controller.TargetRes) then
        local target = controller.Target or controller.TargetRes
        -- push towards our target
        local distance = target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = target:GetPos()

        if target ~= controller.TargetRes and distance <= 90000 then
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

    -- i'm feeling very still
    if !curgoal then
        mv:SetForwardSpeed(0)
        return
    end

    if segments[cur_segment + 1] and Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curgoal.pos.x, curgoal.pos.y)) < 100 then
        controller.cur_segment = controller.cur_segment + 1
        curgoal = segments[controller.cur_segment]
    end

    -- jump
    if controller.NextJump ~= 0 and curgoal.pos.z > (bot:GetPos().z + 16) and controller.NextJump < CurTime() then
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

    local mva = ((curgoal.pos + bot:GetViewOffset()) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)


    if controller.PuntPos then
        -- bot:SetEyeAngles((controller.PuntPos - bot:GetShootPos()):Angle())
        bot:SetEyeAngles(LerpAngle(FrameTime() * 10, bot:EyeAngles(), (controller.PuntPos - bot:GetShootPos()):Angle()))
    elseif IsValid(controller.Target) or IsValid(controller.TargetRes) or (IsValid(controller.TargetRes2) and !controller.TargetRes2:IsPlayerHolding()) then
        local target = controller.Target or controller.TargetRes or controller.TargetRes2
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (target:EyePos() - bot:GetShootPos()):Angle()))
    else
        local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
        local target = Angle(0, ang.y, 0)

        if ang.p >= 3 or ang.p <= -3 then
            target = Angle(ang.p, ang.y, 0)
        end

        bot:SetEyeAngles(target)
    end
end