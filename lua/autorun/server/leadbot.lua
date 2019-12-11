--if game.SinglePlayer() or CLIENT then return end

LeadBot = {}
LeadBot.NoNavMesh = {}
LeadBot.Models = {} -- Models, leave as {} if random is desired

--[[-----

CONFIG START CONFIG START
CONFIG START CONFIG START
CONFIG START CONFIG START

--]]-----

-- Name Prefix

LeadBot.Prefix = ""

-- No Navmesh Check Gamemodes

LeadBot.NoNavMesh["nzombies-unlimited"] = true
LeadBot.NoNavMesh["cinema"] = true

-- Names for bots

LeadBot.Names = {"Turnverein", "Monothelious", "Micawber", "Aardwolf", "Electuary", "GhostkillSomber", "Panegyricon", "Epilate", "Fulgent", "Torfaceous", "Sedilia", "Luminous", "Dysphoria", "TjsinminCotta", "HyrerpwnedHeaume", "Luminous", "Luminous", "Concrew", "Acrimony", "Cosmicrephysx", "Munting", "Anadiplosis", "Dyphone", "Acrimony", "Glacial", "Skintle", "Pruniferous", "Transience", "Abattoir", "Physagogue", "Anatreptic", "Luminous", "Wastive", "Vermiculous", "Misogallic", "Abderian", "Quarterland", "Abderian", "Snooker", "Machinations", "Snicket", "ChessonGizmo", "ScanderLogjam", "BlaboudPaltry", "ElvaelOoshie", "Bovicide", "Hogwash", "Rubberneck", "Pandemonium", "Gobsmacked", "Bifurcate", "Gongoozle", "Donkeyman", "Anemone", "Interrobang", "Balderdash", "DanzhitZonked", "Turducken", "Yokelnel67", "Pussspun", "Vamoose", "Euouaekle4949", "Sousaphone", "Corkscrew", "Jitneyrobs", "Appaloosa", "Ziggurat", "Womynjoe11", "Wasabigie42", "Baksheesh", "Jumbohford64", "Riposte", "Boondocks", "Cockatoo", "Primneys", "Tuberpodky", "Manorexic", "Puppenhaus"}

-- Fake ping

LeadBot.FakePing = true

--[[-----

CONFIG END CONFIG END
CONFIG END CONFIG END
CONFIG END CONFIG END

--]]-----

include("leadbot/base.lua")

-- Modules

local _, dir = file.Find("leadbot/modules/*", "LUA")

for k, v in pairs(dir) do
    local f = table.Add(file.Find("leadbot/modules/" .. v .. "/sv_*.lua", "LUA"), file.Find("leadbot/modules/" .. v .. "/sh_*.lua", "LUA"))
    f = table.Add(f, file.Find("leadbot/modules/" .. v .. "/cl_*.lua", "LUA"))
    for i, o in pairs(f) do
        local file = "leadbot/modules/" .. v .. "/" .. o

        if string.StartWith(o, "cl_") then
            AddCSLuaFile(file)
        else
            include(file)
            if string.StartWith(o, "sh_") then
                AddCSLuaFile(file)
            end
        end
    end
end

-- Gamemode Configs

if file.Find("leadbot/gamemodes/" .. engine.ActiveGamemode() .. ".lua", "LUA")[1] then
    include("leadbot/gamemodes/" .. engine.ActiveGamemode() .. ".lua")
end