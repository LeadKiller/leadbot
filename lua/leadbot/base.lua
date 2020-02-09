LeadBot.RespawnAllowed = true
LeadBot.SetModel = true
LeadBot.NoNavMesh = false
LeadBot.TeamPlay = false
LeadBot.LerpAim = true
LeadBot.AFKBotOverride = false
LeadBot.SuicideAFK = false

--[[ COMMANDS ]]--

concommand.Add("leadbot_add", function(_, _, args) local amount = 1 if tonumber(args[1]) then amount = tonumber(args[1]) end for i = 1, amount do LeadBot.AddBot() end end, nil, "Adds a LeadBot")
concommand.Add("leadbot_kick", function(_, _, args) if args[1] ~= "all" then for k, v in pairs(player.GetAll()) do if string.find(v:GetName(), args[1]) then v:Kick() return end end else for k, v in pairs(player.GetBots()) do v:Kick() end end end, nil, "Kicks LeadBots (all is avaliable!)")
CreateConVar("leadbot_strategy", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables the strategy system for newly created bots.")
CreateConVar("leadbot_names", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot names, seperated by commas.")
CreateConVar("leadbot_name_prefix", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot name prefix")

--[[ FUNCTIONS ]]--

function LeadBot.AddBot()
    if !navmesh.IsLoaded() and !LeadBot.NoNavMesh then
        ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
        return
    end

    if #player.GetAll() == game.MaxPlayers() then MsgN("[LeadBot] Player limit reached!") return end

    local generated = "Leadbot #" .. #player.GetBots() + 1

    if GetConVar("leadbot_names"):GetString() ~= "" then
        generated = table.Random(string.Split(GetConVar("leadbot_names"):GetString(), ","))
    end

    generated = GetConVar("leadbot_name_prefix"):GetString() .. generated

    local name = LeadBot.Prefix .. generated
    local bot = player.CreateNextBot(name)

    if !IsValid(bot) then MsgN("[LeadBot] Unable to create bot!") return end

    bot.BotModel = player_manager.TranslatePlayerModel(table.Random(LeadBot.Models))
    bot.BotColor = Vector(tonumber(0 .. "." .. math.random(0, 9999)), tonumber(0 .. "." .. math.random(0, 9999)), tonumber(0 .. "." .. math.random(0, 9999)))
    bot.BotWColor = Vector(tonumber(0 .. "." .. math.random(0, 9999)), tonumber(0 .. "." .. math.random(0, 9999)), tonumber(0 .. "." .. math.random(0, 9999)))
    bot.BotSkin = math.random(0, 1)
    bot.LastSegmented = CurTime()

    if !LeadBot.Models[1] then
        bot.BotModel = table.Random(player_manager.AllValidModels())
    end

    if LeadBot.PlayerColor == "default" then
        bot.BotColor = Vector(0.24, 0.34, 0.41)
        bot.BotWColor = Vector(0.30, 1.80, 2.10)
        bot.BotSkin = 0
        bot.BotModel = "kleiner"
    end

    if LeadBot.SetModel then
        bot:SetModel(bot.BotModel)
        bot:SetPlayerColor(bot.BotColor)
    end

    bot:SetWeaponColor(bot.BotWColor)

    bot.ControllerBot = ents.Create("leadbot_navigator")
    bot.ControllerBot:Spawn()
    bot.ControllerBot:SetOwner(bot)

    bot.LastPath = nil
    bot.CurSegment = 2
    bot.LeadBot = true

    if GetConVar("leadbot_strategy"):GetBool() then
        bot.BotStrategy = math.random(0, 1)
    else
        bot.BotStrategy = 0
    end

    LeadBot.AddBotOverride(bot)

    if math.random(2) == 1 then
        timer.Simple(math.random(1, 4), function()
            LeadBot.TalkToMe(bot, "join")
        end)
    end

    MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
end

--[[ HOOKS ]]--

--[[hook.Add("InitPostEntity", "LeadBot_InitPostEntity", function()
    if LeadBot.SteamAPIKey ~= "" then
        LeadBot.Names = {}
    end
end)]]--

hook.Add("PostCleanupMap", "LeadBot_PostCleanup", function()
    for k, v in pairs(player.GetBots()) do
        if v.LeadBot then
            v.ControllerBot = ents.Create("leadbot_navigator")
            v.ControllerBot:Spawn()
        end
    end
end)

hook.Add("PlayerDisconnected", "LeadBot_Disconnect", function(bot)
    if IsValid(bot.ControllerBot) then
        bot.ControllerBot:Remove()
    end
end)

hook.Add("SetupMove", "LeadBot_Control", function(bot, mv, cmd)
    if bot.LeadBot then
        LeadBot.PlayerMove(bot, cmd, mv)
    end
end)

hook.Add("StartCommand", "LeadBot_Control", function(bot, cmd)
    if bot.LeadBot then
        LeadBot.StartCommand(bot, cmd)
    end
end)

hook.Add("PostPlayerDeath", "LeadBot_Death", function(bot)
    if bot.LeadBot then
        LeadBot.PostPlayerDeath(bot)
    end
end)

hook.Add("PlayerHurt", "LeadBot_Death", function(ply, bot, hp, dmg)
    if bot.LeadBot then
        LeadBot.PlayerHurt(ply, bot, hp, dmg)
    end
end)

hook.Add("Think", "LeadBot_Think", function()
    LeadBot.Think()
end)

hook.Add("PlayerSpawn", "LeadBot_Spawn", function(bot)
    if bot.LeadBot then
        LeadBot.PlayerSpawn(bot)
    end
end)

--[[ DEFAULT DM AI ]]--

function LeadBot.AddBotOverride(bot)
end

function LeadBot.PlayerSpawn(bot)
    timer.Simple(0, function()
        if LeadBot.SetModel then
            bot:SetModel(bot.BotModel)
        end
        bot:SetPlayerColor(bot.BotColor)
        bot:SetSkin(bot.BotSkin)
        bot:SetWeaponColor(bot.BotWColor)
    end)
end

function LeadBot.FindClosest(bot)
    local players = player.GetHumans()
    local distance = 9999
    local playing = player.GetHumans()[1]
    local distanceplayer = 9999
    for k, v in pairs(players) do
        distanceplayer = v:GetPos():Distance(bot:GetPos())
        if distance > distanceplayer and v ~= bot then
            distance = distanceplayer
            playing = v
        end
    end

    bot.TargetEnt = playing
end

function LeadBot.Think()
    for _, bot in pairs(player.GetBots()) do
        if bot.LeadBot then
            if IsValid(bot:GetActiveWeapon()) then
                local wep = bot:GetActiveWeapon()
                local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                bot:SetAmmo(999, ammoty)
            end

            --[[if !bot:Alive() and LeadBot.ForceRespawn then
                bot:Spawn()
            end]]
        end
    end
end

function LeadBot.PostPlayerDeath(bot)
    timer.Simple(2, function()
        if IsValid(bot) and LeadBot.RespawnAllowed and !bot:Alive() then
            bot:Spawn()
        end
    end)
end

function LeadBot.PlayerHurt(ply, bot, hp, dmg)
    if hp < 1 and math.random(2) == 1 then
        LeadBot.TalkToMe(bot, "taunt")
    end
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()

    if !LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(bot.TargetEnt) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(bot.TargetEnt) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot.ControllerBot:GetPos() ~= bot:GetPos() then
        bot.ControllerBot:SetPos(bot:GetPos())
    end

    bot.TargetEnt = nil

    --cmd:SetForwardMove(250)

    ------------------------------
    -----[[ENTITY DETECTION]]-----
    ------------------------------

    for k, v in pairs(ents.GetAll()) do
        if v:IsPlayer() and v ~= bot and v:GetPos():Distance(bot:GetPos()) < 1500 then
            if (LeadBot.TeamPlay and (v:Team() ~= bot:Team() and bot:Team() ~= TEAM_UNASSIGNED) or bot:Team() == TEAM_UNASSIGNED) or !LeadBot.TeamPlay then -- TODO: find a better way to do this
                local targetpos = v:EyePos() - Vector(0, 0, 10) -- bot eye check, don't start shooting targets just because we barely see their head
                local trace = util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end})

                if trace.Entity == v then -- TODO: FOV Check
                    bot.TargetEnt = v
                end
            end
        elseif v:GetClass() == "prop_door_rotating" and v:GetPos():Distance(bot:GetPos()) < 70 then
            -- open a door if we see one blocking our path
            local targetpos = v:GetPos() + Vector(0, 0, 45)

            if util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end}).Entity == v then
                v:Fire("Open","",0)
            end
        end
    end

    ------------------------------
    --------[[BOT LOGIC]]---------
    ------------------------------

    bot:SelectWeapon("weapon_smg1")

    mv:SetForwardSpeed(1200)

    if !IsValid(bot.TargetEnt) and (!bot.botPos or bot:GetPos():Distance(bot.botPos) < 60 or math.abs(bot.LastSegmented - CurTime()) > 10) then
        -- find a random spot on the map, and in 10 seconds do it again!
        bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 12500})
        bot.LastSegmented = CurTime()
    elseif IsValid(bot.TargetEnt) then
        -- move to our target
        local distance = bot.TargetEnt:GetPos():Distance(bot:GetPos())
        bot.botPos = bot.TargetEnt:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        if distance <= 300 then
            mv:SetForwardSpeed(-1200)
        end
    end

    bot.ControllerBot.PosGen = bot.botPos

    if bot.ControllerBot.P then
        bot.LastPath = bot.ControllerBot.P:GetAllSegments()
    end

    if !bot.ControllerBot.P then
        return
    end

    if bot.CurSegment ~= 2 and !table.EqualValues( bot.LastPath, bot.ControllerBot.P:GetAllSegments() ) then
        bot.CurSegment = 2
    end

    if !bot.LastPath then return end
    local curgoal = bot.LastPath[bot.CurSegment]
    if !curgoal then return end

    -- think one step ahead!
    if bot:GetPos():Distance(curgoal.pos) < 50 and bot.LastPath[bot.CurSegment + 1] then
        curgoal = bot.LastPath[bot.CurSegment + 1]
    end

    ------------------------------
    --------[[BOT EYES]]---------
    ------------------------------

    local lerp = 0.4
    local lerpc = 0.08

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    mv:SetMoveAngles(LerpAngle(lerp, mv:GetMoveAngles(), ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()))

    if IsValid(bot.TargetEnt) and bot:GetEyeTrace().Entity ~= bot.TargetEnt then
        local shouldvegoneforthehead = bot.TargetEnt:EyePos()
        local group = math.random(0, bot.TargetEnt:GetHitBoxGroupCount() - 1)
        local bone = bot.TargetEnt:GetHitBoxBone(math.random(0, bot.TargetEnt:GetHitBoxCount(group) - 1), group) or 0
        shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bone)
        local cang = LerpAngle(lerp, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle())
        bot:SetEyeAngles(Angle(cang.p, cang.y, 0)) --[[+ bot:GetViewPunchAngles()]]
        return
    elseif bot:GetPos():Distance(curgoal.pos) > 20 then
        local ang2 = ((curgoal.pos + Vector(0, 0, 65)) - bot:GetShootPos()):Angle()
        local ang = LerpAngle(lerp, mv:GetMoveAngles(), ang2)
        local cang = LerpAngle(lerpc, bot:EyeAngles(), ang2)
        bot:SetEyeAngles(Angle(cang.p, cang.y, 0))
        mv:SetMoveAngles(ang)
    end
end