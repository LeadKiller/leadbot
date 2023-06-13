LeadBot.RespawnAllowed = true -- allows bots to respawn automatically when dead
LeadBot.PlayerColor = true -- disable this to get the default gmod style players
LeadBot.NoNavMesh = false -- disable the nav mesh check
LeadBot.TeamPlay = false -- don't hurt players on the bots team
LeadBot.LerpAim = true -- interpolate aim (smooth aim)
LeadBot.AFKBotOverride = false -- allows for gamemodes such as Dogfight which use IsBot() to pass real humans as bots
LeadBot.SuicideAFK = false -- kill the player when entering/exiting afk
LeadBot.NoFlashlight = false -- disable flashlight being enabled in dark areas
LeadBot.Strategies = 1 -- how many strategies can the bot pick from

--[[ COMMANDS ]]--

concommand.Add("leadbot_add", function(ply, _, args) if IsValid(ply) and !ply:IsSuperAdmin() then return end local amount = 1 if tonumber(args[1]) then amount = tonumber(args[1]) end for i = 1, amount do timer.Simple(i * 0.1, function() LeadBot.AddBot() end) end end, nil, "Adds a LeadBot")
concommand.Add("leadbot_kick", function(ply, _, args) if !args[1] or IsValid(ply) and !ply:IsSuperAdmin() then return end if args[1] ~= "all" then for k, v in pairs(player.GetBots()) do if string.find(v:GetName(), args[1]) then v:Kick() return end end else for k, v in pairs(player.GetBots()) do v:Kick() end end end, nil, "Kicks LeadBots (all is avaliable!)")
CreateConVar("leadbot_strategy", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables the strategy system for newly created bots.")
CreateConVar("leadbot_names", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot names, seperated by commas.")
CreateConVar("leadbot_models", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot models, seperated by commas.")
CreateConVar("leadbot_name_prefix", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot name prefix")
CreateConVar("leadbot_fov", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "LeadBot FOV\nSet to 0 to use the preset FOV.")

--[[ FUNCTIONS ]]--

local name_Default = {
    alyx = "Alyx Vance",
    kleiner = "Isaac Kleiner",
    breen = "Dr. Wallace Breen",
    gman = "The G-Man",
    odessa = "Odessa Cubbage",
    eli = "Eli Vance",
    monk = "Father Grigori",
    mossman = "Judith Mossman",
    mossmanarctic = "Judith Mossman",
    barney = "Barney Calhoun",
    css_swat = "GIGN",
    css_leet = "Elite Crew",
    css_arctic = "Artic Avengers",
    css_urban = "SEAL Team Six",
    css_riot = "GSG-9",
    css_gasmask = "SAS",
    css_phoenix = "Phoenix Connexion",
    css_guerilla = "Guerilla Warfare",
    dod_american = "American Soldier",
    dod_german = "German Soldier",
    hostage01 = "Art",
    hostage02 = "Sandro",
    hostage03 = "Vance",
    hostage04 = "Cohrt",
    police = "Civil Protection",
    policefem = "Civil Protection",
    chell = "Chell",
    combine = "Combine Soldier",
    combineprison = "Combine Prison Guard",
    combineelite = "Elite Combine Soldier",
    stripped = "Stripped Combine Soldier",
    zombie = "Zombie",
    zombiefast = "Fast Zombie",
    zombine = "Zombine",
    corpse = "Corpse",
    charple = "Charple",
    skeleton = "Skeleton",
    male01 = "Van",
    male02 = "Ted",
    male03 = "Joe",
    male04 = "Eric",
    male05 = "Art",
    male06 = "Sandro",
    male07 = "Mike",
    male08 = "Vance",
    male09 = "Erdin",
    male10 = "Van",
    male11 = "Ted",
    male12 = "Joe",
    male13 = "Eric",
    male14 = "Art",
    male15 = "Sandro",
    male16 = "Mike",
    male17 = "Vance",
    male18 = "Erdin",
    female01 = "Joey",
    female02 = "Kanisha",
    female03 = "Kim",
    female04 = "Chau",
    female05 = "Naomi",
    female06 = "Lakeetra",
    female07 = "Joey",
    female08 = "Kanisha",
    female09 = "Kim",
    female10 = "Chau",
    female11 = "Naomi",
    female12 = "Lakeetra",
    medic01 = "Van",
    medic02 = "Ted",
    medic03 = "Joe",
    medic04 = "Eric",
    medic05 = "Art",
    medic06 = "Sandro",
    medic07 = "Mike",
    medic08 = "Vance",
    medic09 = "Erdin",
    medic10 = "Joey",
    medic11 = "Kanisha",
    medic12 = "Kim",
    medic13 = "Chau",
    medic14 = "Naomi",
    medic15 = "Lakeetra",
    refugee01 = "Ted",
    refugee02 = "Eric",
    refugee03 = "Sandro",
    refugee04 = "Vance",
}

function LeadBot.AddBot()
    if !FindMetaTable("NextBot").GetFOV then
        ErrorNoHalt("You must be using the dev version of Garry's mod!\nhttps://wiki.facepunch.com/gmod/Dev_Branch\n")
        return
    end

    if !navmesh.IsLoaded() and !LeadBot.NoNavMesh then
        ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
        return
    end

    if player.GetCount() == game.MaxPlayers() then
        MsgN("[LeadBot] Player limit reached!")
        return
    end

    local original_name
    local generated = "Leadbot #" .. #player.GetBots() + 1
    local model = ""
    local color = Vector(-1, -1, -1)
    local weaponcolor = Vector(0.30, 1.80, 2.10)
    local strategy = 0

    if GetConVar("leadbot_names"):GetString() ~= "" then
        generated = table.Random(string.Split(GetConVar("leadbot_names"):GetString(), ","))
    elseif GetConVar("leadbot_models"):GetString() == "" then
        local name, _ = table.Random(player_manager.AllValidModels())
        local translate = player_manager.TranslateToPlayerModelName(name)
        name = translate

        for _, ply in pairs(player.GetBots()) do
            if ply.OriginalName == name or string.lower(ply:Nick()) == name or name_Default[name] and ply:Nick() == name_Default[name] then
                name = ""
            end
        end

        if name == "" then
            local i = 0
            while name == "" do
                i = i + 1
                local str = player_manager.TranslateToPlayerModelName(table.Random(player_manager.AllValidModels()))
                for _, ply in pairs(player.GetBots()) do
                    if ply.OriginalName == str or string.lower(ply:Nick()) == str or name_Default[str] and ply:Nick() == name_Default[str] then
                        str = ""
                    end
                end

                if str == "" and i < #player_manager.AllValidModels() then continue end
                name = str
            end
        end

        original_name = name
        model = name
        name = string.lower(name)
        name = name_Default[name] or name

        local name_Generated = string.Split(name, "/")
        name_Generated = name_Generated[#name_Generated]
        name_Generated = string.Split(name_Generated, " ")

        for i, namestr in pairs(name_Generated) do
            name_Generated[i] = string.upper(string.sub(namestr, 1, 1)) .. string.sub(namestr, 2)
        end

        name_Generated = table.concat(name_Generated, " ")
        generated = name_Generated
    end

    if LeadBot.PlayerColor == "default" then
        generated = "Kleiner"
    end

    generated = GetConVar("leadbot_name_prefix"):GetString() .. generated

    local name = LeadBot.Prefix .. generated
    local bot = player.CreateNextBot(name)

    if !IsValid(bot) then
        MsgN("[LeadBot] Unable to create bot!")
        return
    end

    if GetConVar("leadbot_strategy"):GetBool() then
        strategy = math.random(0, LeadBot.Strategies)
    end

    if LeadBot.PlayerColor ~= "default" then
        if model == "" then
            if GetConVar("leadbot_models"):GetString() ~= "" then
                model = table.Random(string.Split(GetConVar("leadbot_models"):GetString(), ","))
            else
                model = player_manager.TranslateToPlayerModelName(table.Random(player_manager.AllValidModels()))
            end
        end

        if color == Vector(-1, -1, -1) then
            local botcolor = ColorRand()
            local botweaponcolor = ColorRand()
            color = Vector(botcolor.r / 255, botcolor.g / 255, botcolor.b / 255)
            weaponcolor = Vector(botweaponcolor.r / 255, botweaponcolor.g / 255, botweaponcolor.b / 255)
        end
    else
        model = "kleiner"
        color = Vector(0.24, 0.34, 0.41)
    end

    bot.LeadBot_Config = {model, color, weaponcolor, strategy, math.random(3)}

    -- for legacy purposes, will be removed soon when gamemodes are updated
    bot.BotStrategy = strategy
    bot.OriginalName = original_name
    bot.ControllerBot = ents.Create("leadbot_navigator")
    bot.ControllerBot:Spawn()
    bot.ControllerBot:SetOwner(bot)
    bot.LeadBot = true
    LeadBot.AddBotOverride(bot)
    LeadBot.AddBotControllerOverride(bot, bot.ControllerBot)
    bot:Spawn()
    MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
end

--[[ DEFAULT DM AI ]]--

function LeadBot.AddBotOverride(bot)
    if math.random(2) == 1 then
        timer.Simple(math.random(1, 4), function()
            LeadBot.TalkToMe(bot, "join")
        end)
    end
end

function LeadBot.AddBotControllerOverride(bot, controller)
end

function LeadBot.PlayerSpawn(bot)
end

function LeadBot.Think()
    for _, bot in pairs(player.GetAll()) do
        if bot:IsLBot() then
            if LeadBot.RespawnAllowed and bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
                return
            end

            if bot:IsLBot(true) then
                local wep = bot:GetActiveWeapon()
                if IsValid(wep) then
                    local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                    bot:SetAmmo(999, ammoty)
                end
            end
        end
    end
end

function LeadBot.PostPlayerDeath(bot)
end

function LeadBot.PlayerHurt(ply, bot, hp, dmg)
    if bot:IsPlayer() or bot:IsNPC() then
        if hp <= dmg and math.random(3) == 1 and bot:IsLBot() then
            LeadBot.TalkToMe(bot, "taunt")
        end

        local controller = ply:GetController()
        if IsValid(controller.Target) then return end
        controller.LookAtTime = CurTime() + math.Rand(0.4, 0.8)
        controller.LookAt = ((bot:GetPos() + VectorRand() * 128) - ply:GetPos()):Angle()
    end
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target
    local dist = IsValid(target) and bot:GetPos():DistToSqr(target:GetPos())

    -- wait for the ai to exist
    if !IsValid(controller) then return end

    -- wait for the bot to be alive
    if !bot:Alive() then
        if math.random(2) == 1 then
            cmd:SetButtons(IN_ATTACK)
        end

        return
    end

    -- do not sprint if we aren't supposed to
    if LeadBot.NoSprint or IsValid(target) then
        buttons = 0
    end

    -- reload if we must
    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(target) and (controller.ForgetTarget + 2 < CurTime() or botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2)) then
        buttons = buttons + IN_RELOAD
    end

    -- attack, but don't hold down attack since it's slow with most weapons
    if IsValid(target) and util.QuickTrace(bot:EyePos(), target:WorldSpaceCenter() - bot:EyePos(), bot).Entity == target and math.random(2) == 1 and dist <= 1440000 then
        buttons = buttons + IN_ATTACK
    end

    -- climb CS:S ladders
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

    -- crouch/jump if we have to
    if controller.NextDuck > CurTime() then
        buttons = buttons + IN_DUCK
    elseif controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    -- crouch if we are jumping so we can do a crouch jump
    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    -- select weapon
    bot:SelectWeapon("weapon_ar2")

    -- send buttons to clients when afk so anims don't break
    bot.LeadBot_Keys = buttons

    -- simulate pressing keys
    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    local controller = bot.ControllerBot

    -- bot shouldn't think while not alive
    if !bot:Alive() then return end

    local time = SysTime()

    -- create ai if it doesn't exist
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

    -- set ai to compute at bot pos
    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    -- set ai to see from bot eyes
    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end

    -- bot moves forward
    mv:SetForwardSpeed(1200)

    -- bot forgets targets when spawning, target doesn't exist or target is dead
    if (bot.NextSpawnTime and bot.NextSpawnTime > CurTime()) or !IsValid(controller.Target) or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    -- bot searches for targets every so often
    if controller.LastSearched < CurTime() then
        local closest
        local distance = math.huge

        controller.VisibleTargets = {}

        for _, ply in ipairs(ents.GetAll()) do
            if !ply:IsPlayer() and !ply:IsNPC() then continue end
            if ply.Team and (!LeadBot.TeamPlay or ply:Team() ~= bot:Team()) or ply:IsNPC() and ply:Disposition(bot) == D_HT then
                local dist = bot:GetPos():DistToSqr(ply:GetPos())

                if dist < 4194304 and ply:Health() > 0 and (controller:CanSee(ply) or bot:GetEyeTrace().Entity == ply) then
                    controller.VisibleTargets[ply] = true

                    if dist < distance then
                        closest = ply
                        distance = dist
                    end
                end
            end
        end

        if IsValid(closest) then
            controller.Target = closest
            controller.ForgetTarget = CurTime() + 2
        end

        controller.LastSearched = CurTime() + 0.1
    end

    -- dodge/strafe every so often like in timesplitters
    if !controller.LastDodge or controller.LastDodge < CurTime() then
        if IsValid(controller.Target) and math.random(100) <= 30 then
            controller.DodgeAngle = math.random(2)
            controller.DodgeTime = CurTime() + math.Rand(1, 2)
        end

        controller.LastDodge = CurTime() + math.Rand(1, 2)
    end

    if controller.DodgeTime and controller.DodgeTime > CurTime() then
        mv:SetSideSpeed(controller.DodgeAngle == 1 and -2000 or 2000)
    end

    -- forget targets if we can't see them
    if controller.ForgetTarget < CurTime() then
        if IsValid(controller.Target) and util.QuickTrace(bot:EyePos(), controller.Target:WorldSpaceCenter() - bot:EyePos(), bot).Entity == controller.Target then
            controller.ForgetTarget = CurTime() + 2
        else
            controller.Target = nil
            controller.LastSearched = CurTime()
        end
    end

    -- open doors
    if !controller.LastDoorTrace or controller.LastDoorTrace < CurTime() then
        local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

        if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
            dt.Entity:Fire("OpenAwayFrom", bot, 0)
        end

        controller.LastDoorTrace = CurTime() + 0.25
    end

    -- patrol around the map if we don't have a target, otherwise try to back up if they are close
    if !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        -- find a random spot on the map, and in 10 seconds do it again!
        controller.PosGen = controller:FindSpot("random", {radius = 12500})
        controller.LastSegmented = CurTime() + 10
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- very randomly back up if target is close
        if distance <= (controller.RetreatDistance or 90000) and math.random(100) <= 15 then
            controller.RetreatTime = CurTime() + math.Rand(1, 1.5)
            controller.RetreatAngle = math.random(-1000, 1000)
            controller.RetreatDistance = math.random(30000, 90000)
            local mins, maxs = bot:GetHull()

            local pos = util.TraceHull({
                start = bot:GetPos(),
                endpos = bot:GetPos() + Angle(0, bot:EyeAngles().y, 0):Forward() * -600 + Angle(0, bot:EyeAngles().y, 0):Right() * controller.RetreatAngle,
                mins = mins,
                maxs = maxs,
                mask = MASK_PLAYERSOLID,
                filter = bot
            }).HitPos

            local tr = util.TraceHull({
                start = pos,
                endpos = pos,
                mins = mins,
                maxs = maxs,
                mask = MASK_PLAYERSOLID,
                filter = nil
            })

            controller.RetreatPos = !tr.StartSolid and !tr.AllSolid and !tr.HitWorld and !tr.Hit and pos
        end

        if controller.RetreatTime and controller.RetreatTime > CurTime() then
            -- while findspot is really cool, it only finds the same spots on big maps every time
            -- controller.PosGen = controller:FindSpot("random", {pos = util.QuickTrace(bot:GetPos(), Angle(0, bot:EyeAngles().y, 0):Forward() * -600 + Angle(0, bot:EyeAngles().y, 0):Right() * 150, bot).HitPos, radius = 300})
            --[[mv:SetForwardSpeed(-2000)
            mv:SetSideSpeed(controller.RetreatAngle)]]

            if controller.RetreatPos then
                controller.PosGen = controller.RetreatPos
            else
                mv:SetForwardSpeed(-2000)
                mv:SetSideSpeed(controller.RetreatAngle)
                controller.PosGen = controller.Target:GetPos()
            end
        elseif distance <= 30000 then
            mv:SetForwardSpeed(-2000)
        end
    end

    -- if we cannot compute, just stop
    if !controller.P then return end
    local segments = controller.segments or controller.P:GetAllSegments()
    // controller.Segments = controller.Segments or controller.P:GetAllSegments()
    if !segments then return end

    local segs2 = {}
    
    for _, seg in ipairs(segments) do
        debugoverlay.Text(seg.pos, _, 0.1, false)
        segs2[_] = seg.pos
    end

    /*local realsegs = {}

    for _, seg in ipairs(segs2) do
        table.insert(realsegs, seg)
        if !segs2[_ + 2] or !segs2[_ - 2] then continue end
        table.insert(realsegs, math.BSplinePoint(0.75, {segs2[_ - 2] and segs2[_ - 2], segs2[_ - 1], segs2[_ + 1], segs2[_ + 2]}, 1))
    end

    for _, seg in ipairs(realsegs) do
        debugoverlay.Text(seg, "!" .. _, 0.1, false)
        // segs2[_] = seg.pos
        segments[_] = {
            pos = seg,
            type = 0,
            area = navmesh.GetNavArea(seg, 0)
        }
    end

    debugoverlay.Text(math.BSplinePoint(0.5, {segs2[1], segs2[1], segs2[2], segs2[2]}, 1), "TEST")*/

    local cur_segment = controller.cur_segment
    debugoverlay.Text(bot:EyePos() + VectorRand(), cur_segment, 0.1, false)
    local curgoal = segments[cur_segment]
    local difficulty = bot:LBGetDifficulty()

    -- setup interpolation values so we don't snap to targets
    local lerp = FrameTime() * math.Rand(Lerp(difficulty, 5, 6), Lerp(difficulty, 7, 8))
    local lerpc = FrameTime() * 5

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    -- stop if we have nowhere to go
    if !curgoal then
        mv:SetForwardSpeed(0)

        -- make sure we still aim at our target
        if IsValid(controller.Target) then
            local ang = LerpAngle(lerp, bot:EyeAngles(), (controller.Target:WorldSpaceCenter() - bot:GetShootPos()):Angle())
            bot:SetEyeAngles(Angle(ang.p + math.sin(CurTime() * 4) * 0.25, ang.y + math.sin(CurTime() * 2) * 0.5, 0))
        end

        return
    end

    -- go to the next segment of our path if we are close to our current segment
    if segments[cur_segment + 1] and Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curgoal.pos.x, curgoal.pos.y)) < 100 then
        controller.cur_segment = controller.cur_segment + 1
        curgoal = segments[controller.cur_segment]
    end

    local goalpos = curgoal.pos
    local i = 1
    for _, tab in ipairs(segments) do
        if _ > 2 and i <= 5 and util.QuickTrace(bot:EyePos(), tab.pos - bot:EyePos(), bot).HitPos:DistToSqr(tab.pos) <= 1 and tab.pos.z - bot:GetPos().z < 8 then
            goalpos = tab.pos
            i = i + 1
        end
    end

    debugoverlay.Text(goalpos, "GOAL", 1, false)

    -- make sure we don't get stuck on corners by strafing if we aren't moving
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

    -- jump if the navmesh has a jump
    if controller.NextJump ~= 0 and curgoal.type > 1 and controller.NextJump < CurTime() then
        controller.NextJump = 0
    end

    -- duck if navmesh requires ducking
    if curgoal.area:GetAttributes() == NAV_MESH_CROUCH then
        controller.NextDuck = CurTime() + 0.1
    end

    -- tell the ai our goal position
    controller.goalPos = goalpos

    -- draw path if developer is enabled
    if GetConVar("developer"):GetBool() then
        controller.P:Draw()
    end

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()
    local projectile = IsValid(bot:GetActiveWeapon()) and bot:GetActiveWeapon():GetClass() == "weapon_crossbow"

    -- move our legs where we need to go while we can look directly at target
    mv:SetMoveAngles(mva)

    debugoverlay.Text(bot:EyePos() + Vector(0, 0, 8) + VectorRand() * 8, string.sub((SysTime() - time) * 100, 1, 4), 1.25, false)

    if (SysTime() - time) * 100 > 0.1 then
        debugoverlay.Box(bot:GetPos(), Vector(-16, -16, 0), Vector(16, 16, 72), 0.1, Color(255, 0, 0, 0))

        for i = 1, 24 do
            debugoverlay.Text(bot:EyePos() + VectorRand() * 64, SysTime() - time, 0.1, false)
        end
    end

    -- look at our target, or our path
    if IsValid(controller.Target) then
        local ang = LerpAngle(lerp, bot:EyeAngles(), (controller.Target:WorldSpaceCenter() + (controller.Target:GetVelocity() * (projectile and math.Rand(0.2, 0.3) or Lerp(difficulty, math.Rand(-0.1, 0.1), math.Rand(-0.01, 0.01)))) - bot:GetShootPos()):Angle())
        bot:SetEyeAngles(Angle(ang.p + math.sin(CurTime() * 4) * Lerp(difficulty, 0.075, 0.025), ang.y + math.sin(CurTime() * 2) * Lerp(difficulty, 0.25, 0.012), 0) + bot:GetViewPunchAngles() * Lerp(difficulty, 0.3, 0.1))
        return
    else
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            -- look ahead to make sure we don't snap our view every segment
            local pos = controller.EyePosition or curgoal.pos -- segments[2] and segments[2].pos or segments[1].pos
            if !controller.LastEyePosition or controller.LastEyePosition < CurTime() then
                local i = 1
                for _, tab in ipairs(segments) do
                    if i <= 5 and util.QuickTrace(bot:EyePos(), tab.pos - bot:EyePos(), bot).HitPos:DistToSqr(tab.pos) <= 150 then
                        controller.EyePosition = tab.pos
                        i = i + 1
                    end
                end
                controller.LastEyePosition = CurTime() + 0.25
            end
            --[[local i = 1
            for _, tab in ipairs(segments) do
                if i <= 5 and util.QuickTrace(bot:EyePos(), tab.pos - bot:EyePos(), bot).HitPos:DistToSqr(tab.pos) <= 150 then
                    pos = tab.pos
                    i = i + 1
                end
            end]]
            local ang = (pos + bot:GetCurrentViewOffset() - bot:EyePos()):Angle()
            ang = LerpAngle(lerpc, bot:EyeAngles(), ang)
            bot:SetEyeAngles(Angle(ang.p + math.sin(CurTime() * 4) * 0.05, ang.y + math.sin(CurTime() * 2) * 0.1, 0))
        end
    end
end

--[[ HOOKS ]]--

hook.Add("PlayerDisconnected", "LeadBot_Disconnect", function(bot)
    if IsValid(bot.ControllerBot) then
        bot.ControllerBot:Remove()
    end
end)

hook.Add("SetupMove", "LeadBot_Control", function(bot, mv, cmd)
    if bot:IsLBot() then
        LeadBot.PlayerMove(bot, cmd, mv)
    end
end)

hook.Add("StartCommand", "LeadBot_Control", function(bot, cmd)
    if bot:IsLBot() then
        LeadBot.StartCommand(bot, cmd)
    end
end)

hook.Add("PostPlayerDeath", "LeadBot_Death", function(bot)
    if bot:IsLBot() then
        LeadBot.PostPlayerDeath(bot)
    end
end)

hook.Add("EntityTakeDamage", "LeadBot_Hurt", function(ply, dmgi)
    local bot = dmgi:GetAttacker()
    local hp = ply:Health()
    local dmg = dmgi:GetDamage()

    if IsValid(ply) and ply:IsPlayer() and ply:IsLBot() then
        LeadBot.PlayerHurt(ply, bot, hp, dmg)
    end
end)

hook.Add("Think", "LeadBot_Think", function()
    LeadBot.Think()
end)

hook.Add("PlayerSpawn", "LeadBot_Spawn", function(bot)
    if bot:IsLBot() then
        LeadBot.PlayerSpawn(bot)
    end
end)

--[[ META ]]--

local player_meta = FindMetaTable("Player")
local oldInfo = player_meta.GetInfo

function player_meta.IsLBot(self, realbotsonly)
    if realbotsonly == true then
        return self.LeadBot and self:IsBot() or false
    end

    return self.LeadBot or false
end

function player_meta.LBGetStrategy(self)
    if self.LeadBot_Config then
        return self.LeadBot_Config[4]
    else
        return 0
    end
end

function player_meta.LBGetModel(self)
    if self.LeadBot_Config then
        return self.LeadBot_Config[1]
    else
        return "kleiner"
    end
end

function player_meta.LBGetColor(self, weapon)
    if self.LeadBot_Config then
        if weapon == true then
            return self.LeadBot_Config[3]
        else
            return self.LeadBot_Config[2]
        end
    else
        return Vector(0, 0, 0)
    end
end

function player_meta.LBGetDifficulty(self)
    if self.LeadBot_Config then
        return self.LeadBot_Config[5] / 3
    else
        return 0
    end
end

LeadBot.Convars = {}
LeadBot.Convars["cl_hl2mp_playermodel"] = function(self)
    self.Combine = self.Combine or math.random(2)
    return self.Combine ~= 1 and table.Random(GAMEMODE.Models_Rebel) or table.Random(GAMEMODE.Models_Combine)
end

function player_meta.GetInfo(self, convar)
    if self:IsBot() and self:IsLBot() then
        if convar == "cl_playermodel" then
            return self:LBGetModel() --self.LeadBot_Config[1]
        elseif convar == "cl_playercolor" then
            return self:LBGetColor() --self.LeadBot_Config[2]
        elseif convar == "cl_weaponcolor" then
            return self:LBGetColor(true) --self.LeadBot_Config[3]
        elseif LeadBot.Convars[convar] then
            return LeadBot.Convars[convar](self)
        else
            return ""
        end
    else
        return oldInfo(self, convar)
    end
end

function player_meta.GetController(self)
    if self:IsLBot() then
        return self.ControllerBot
    end
end