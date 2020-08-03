--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
    if bot:Team() == 3 then
        timer.Simple(math.Rand(0.5, 1.5), function()
            if IsValid(bot) then
                local props = ents.FindByClass("prop_physics*")
                local prop = table.Random(props)
                local rand = VectorRand() * 3

                bot:SetPos(util.QuickTrace(bot:GetPos(), Vector(0, 0, -2048), bot).HitPos)
                bot:DisguiseAsProp(prop)
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

function LeadBot.StartCommand(bot, cmd)
    if bot:Alive() and math.random(500) == 1 and (!bot.Taunting or bot.Taunting < CurTime()) then
        local taunts = {}
        for _, taunt in pairs(Taunts) do
            if (taunt.sex and taunt.sex ~= bot.ModelSex) or (taunt.team and taunt.team ~= bot:Team()) then continue end
            table.insert(taunts, taunt)
        end

        local taunt = table.Random(taunts)
        local snd = table.Random(taunt.sound)

        bot:EmitSound(snd)
        bot.Taunting = CurTime() + (taunt.soundDurationOverride or SoundDuration(snd))
    end
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot:Team() ~= 3 then
        bot:SetTeam(3)
        bot:Spawn()
        bot:StripWeapons()
    end
end