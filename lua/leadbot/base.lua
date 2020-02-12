LeadBot.RespawnAllowed = true -- allows bots to respawn automatically when dead
LeadBot.PlayerColor = true -- disable this to get the default gmod style players
LeadBot.NoNavMesh = false -- disable the nav mesh check
LeadBot.TeamPlay = false -- don't hurt players on the bots team
LeadBot.LerpAim = true -- interpolate aim (smooth aim)
LeadBot.AFKBotOverride = false -- allows for gamemodes such as Dogfight which use IsBot() to pass real humans as bots
LeadBot.SuicideAFK = false -- kill the player when entering/exiting afk
LeadBot.Strategies = 1 -- how many strategies can the bot pick from

--[[ COMMANDS ]]--

concommand.Add("leadbot_add", function(_, _, args) local amount = 1 if tonumber(args[1]) then amount = tonumber(args[1]) end for i = 1, amount do LeadBot.AddBot() end end, nil, "Adds a LeadBot")
concommand.Add("leadbot_kick", function(_, _, args) if args[1] ~= "all" then for k, v in pairs(player.GetAll()) do if string.find(v:GetName(), args[1]) then v:Kick() return end end else for k, v in pairs(player.GetBots()) do v:Kick() end end end, nil, "Kicks LeadBots (all is avaliable!)")
CreateConVar("leadbot_strategy", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables the strategy system for newly created bots.")
CreateConVar("leadbot_names", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot names, seperated by commas.")
CreateConVar("leadbot_models", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot models, seperated by commas.")
CreateConVar("leadbot_name_prefix", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot name prefix")

--[[ FUNCTIONS ]]--

function LeadBot.AddBot()
    if !navmesh.IsLoaded() and !LeadBot.NoNavMesh then
        ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
        return
    end

    if #player.GetAll() == game.MaxPlayers() then
        MsgN("[LeadBot] Player limit reached!")
        return
    end

    local generated = "Leadbot #" .. #player.GetBots() + 1

    if GetConVar("leadbot_names"):GetString() ~= "" then
        generated = table.Random(string.Split(GetConVar("leadbot_names"):GetString(), ","))
    end

    generated = GetConVar("leadbot_name_prefix"):GetString() .. generated

    local name = LeadBot.Prefix .. generated
    local bot = player.CreateNextBot(name)

    if !IsValid(bot) then
        MsgN("[LeadBot] Unable to create bot!")
        return
    end

    local model = "kleiner"
    local color = Vector(0.24, 0.34, 0.41)
    local weaponcolor = Vector(0.30, 1.80, 2.10)
    local strategy = 0

    if GetConVar("leadbot_strategy"):GetBool() then
        strategy = math.random(0, LeadBot.Strategies)
    end

    if LeadBot.PlayerColor ~= "default" then
        if GetConVar("leadbot_names"):GetString() ~= "" then
            model = table.Random(string.Split(GetConVar("leadbot_models"):GetString(), ","))
        else
            model = player_manager.TranslateToPlayerModelName(table.Random(player_manager.AllValidModels()))
        end
        local botcolor = ColorRand()
        local botweaponcolor = ColorRand()
        color = Vector(botcolor.r / 255, botcolor.g / 255, botcolor.b / 255)
        weaponcolor = Vector(botweaponcolor.r / 255, botweaponcolor.g / 255, botweaponcolor.b / 255)
    end

    bot.LeadBot_Config = {}
    bot.LeadBot_Config[1] = model
    bot.LeadBot_Config[2] = color
    bot.LeadBot_Config[3] = weaponcolor
    bot.LeadBot_Config[4] = strategy

    -- for legacy purposes, will be removed soon when gamemodes are updated
    bot.BotStrategy = strategy
    bot.ControllerBot = ents.Create("leadbot_navigator")
    bot.ControllerBot:Spawn()
    bot.ControllerBot:SetOwner(bot)
    bot.LeadBot = true
    LeadBot.AddBotOverride(bot)
    LeadBot.AddBotControllerOverride(bot, bot.ControllerBot)
    MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
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

hook.Add("PlayerHurt", "LeadBot_Death", function(ply, bot, hp, dmg)
    if bot:IsLBot() then
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
    for _, bot in pairs(player.GetBots()) do
        if bot:IsLBot() then
            if LeadBot.RespawnAllowed and !bot:Alive() and bot.NextSpawnTime < CurTime() then
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

function LeadBot.PostPlayerDeath(bot)
end

function LeadBot.PlayerHurt(ply, bot, hp, dmg)
    if hp < 1 and math.random(2) == 1 then
        LeadBot.TalkToMe(bot, "taunt")
    end
end

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target

    if LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(botWeapon) and (botWeapon:Clip1() == 0 or !IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) then
        buttons = buttons + IN_RELOAD
    end

    if IsValid(target) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    if controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    bot:SelectWeapon("weapon_smg1")
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

    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    mv:SetForwardSpeed(1200)
    -- main thing that's keeping the bots from being lag free is seeking targets
    -- losing about 4-25 fps with this
    -- for now, using player.GetAll() rather than ents.GetAll()
    -- having no npc support is bad, but I think most people will use this for dm
    if bot.NextSpawnTime + 1 > CurTime() or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        for _, ply in pairs(player.GetAll()) do
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
                end
            end
        end
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("Open","",0)
    end

    if !IsValid(controller.Target) and (!controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime()) then
        -- find a random spot on the map, and in 10 seconds do it again!
        controller.PosGen = controller:FindSpot("random", {radius = 12500})
        controller.LastSegmented = CurTime() + 10
    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= 90000 then
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

    -- jump
    if controller.NextJump ~= 0 and curgoal.pos.z > (bot:GetPos().z + 16) and controller.NextJump < CurTime() then
        controller.NextJump = 0
    end

    -- think every step of the way!
    -- TODO: corner turning like nextbot npcs
    if Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curgoal.pos.x, curgoal.pos.y)) < 100 then
        controller.cur_segment = controller.cur_segment + 1
        curgoal = segments[controller.cur_segment]
    end

    if !curgoal then return end

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

    if IsValid(controller.Target) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - bot:GetShootPos()):Angle()))
        return
    else
        local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
        bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
    end
end

--[[ META ]]--

local player_meta = FindMetaTable("Player")
local oldInfo = player_meta.GetInfo

function player_meta.IsLBot(self, realbotsonly)
    if realbotsonly == true then
        return self.LeadBot and self:IsBot()
    end

    return self.LeadBot
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

function player_meta.GetInfo(self, convar)
    if self:IsBot() and self:IsLBot() then
        if convar == "cl_playermodel" then
            return self:LBGetModel() --self.LeadBot_Config[1]
        elseif convar == "cl_playercolor" then
            return self:LBGetColor() --self.LeadBot_Config[2]
        elseif convar == "cl_weaponcolor" then
            return self:LBGetColor(true) --self.LeadBot_Config[3]
        else
            return ""
        end
    else
        return oldInfo(self, convar)
    end
end