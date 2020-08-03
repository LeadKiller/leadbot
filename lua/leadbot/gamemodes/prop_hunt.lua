--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

-- NOTE BEHAVIOR:
-- TODO SUPPORT ALL PROP HUNT GAMEMODES
--   PROP:
--    ITS OK TO HAVE THINGS TELEPORT, SEEKERS WONT SEE IT
--    TODO HAVE A SYSTEM FOR PRESET PROP SPOTS, AND HAVE MANY BY DEFAULT
--    TODO WALK UP TO A PROP ON THE MAP, BECOME IT AND MOVE IT OUT OF THE WAY (SOMEWHERE ELSE)
--    TODO WHEN SHOT, RUN AWAY TO A SMALL PROP AND BECOME IT
--    TODO RUN AWAY IF HUNTER LOOKS AT US FOR MORE THAN 5 SECONDS
--    TODO STRATEGY 0: NEW, NEARBY PROPS GET KNOCKED OVER WITHOUT ANY CARE
--    TODO STRATEGY 1: PERSISTENT, ATTEMPT TO USE SMALL PROPS MORE OFTEN
--    TODO STRATEGY 2: CAREFUL, ATTEMPTS TO SWITCH SPOTS OFTEN
--   HUNTER:
--    TODO STEP/MOVE ALL UNKNOWN PROPS
--    TODO INDEX ALL KNOWN SAFE PROPS (RANDOMLY REMOVE SOME, HIGHER CHANCE OUT OF SIGHT, TO "FORGET")
--    TODO FORGET HUNTED PROPS THAT STOP MOVING SOMEWHERE OUT OF SIGHT
--    TODO STRATEGY 0: SHOOT PROPS RARELY
--    TODO STRATEGY 1: PLAY IT SAFE, DON'T SHOOT PROPS UNLESS IF WE KNOW THEY ARE PLAYER
--    TODO HUNTERS SHOULD INVESTIGATE TAUNTS

function LeadBot.PlayerSpawn(bot)
    if bot:Team() == TEAM_PROPS then
        timer.Simple(math.Rand(0.5, 1.5), function()
            if IsValid(bot) then
                local props = ents.FindByClass("prop_physics*")
                local prop = table.Random(props)
                local rand = VectorRand() * 3

                bot:SetPos(util.QuickTrace(bot:GetPos(), Vector(0, 0, -2048), bot).HitPos)
                hook.Call("PlayerExchangeProp", gmod.GetGamemode(), bot, prop)
                bot:SetPos(prop:GetPos() + Vector(rand.x, rand.y, 0))
                bot:SetEyeAngles(prop:GetAngles() + Angle(0, math.random(-8, 8), 0))
                prop:Remove()

                for _, prop2 in pairs(props) do
                    if prop2:GetPos():DistToSqr(bot:GetPos()) < 45000 then
                        prop2:GetPhysicsObject():AddVelocity(Vector(0, 0, 4))
                        prop2:GetPhysicsObject():AddVelocity(VectorRand() * 64)

                        if math.random(3) == 1 then
                            prop2:TakeDamage(3, bot, bot)
                        end
                    end
                end
            end
        end)
    end
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot:Team() == TEAM_HUNTERS then
        bot:SetTeam(TEAM_PROPS)
        bot:Spawn()
    end

    if bot:Team() ~= TEAM_HUNTERS then return end
end

hook.Add("Initialize", "leadbot_Team_PropHunt", function()
    local oldfunc = hook.GetTable()["OnPlayerChangedTeam"]["TeamChange_switchLimitter"]

    hook.Add("OnPlayerChangedTeam", "TeamChange_switchLimitter", function(ply, old, new)
        if !bot:IsBot() and !bot:IsLBot() then
            oldfunc(ply, old, new)
        end
    end)
end)