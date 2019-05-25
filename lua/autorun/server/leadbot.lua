if game.SinglePlayer() or CLIENT then return end
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

LeadBot.Names = {"Turnverein", "Monothelious", "Aardwolf", "Micawber", "Aardwolf", "Electuary", "GhostkillSomber", "Panegyricon", "Epilate", "Fulgent", "Torfaceous", "Sedilia", "Luminous", "Dysphoria", "TjsinminCotta", "HyrerpwnedHeaume", "Luminous", "Luminous", "Concrew", "Acrimony", "Cosmicrephysx", "Munting", "Anadiplosis", "Dyphone", "Acrimony", "Glacial", "Skintle", "Pruniferous", "Transience", "Abattoir", "Physagogue", "Anatreptic", "Luminous", "Wastive", "Vermiculous", "Misogallic", "Abderian", "Quarterland", "Abderian", "Snooker", "Machinations", "Snicket", "ChessonGizmo", "ScanderLogjam", "BlaboudPaltry", "ElvaelOoshie", "Bovicide", "Hogwash", "Rubberneck", "Pandemonium", "Gobsmacked", "Bifurcate", "Gongoozle", "Donkeyman", "Anemone", "Interrobang", "Balderdash", "DanzhitZonked", "Turducken", "Yokelnel67", "Pussspun", "Vamoose", "Euouaekle4949", "Sousaphone", "Corkscrew", "Jitneyrobs", "Appaloosa", "Ziggurat", "Womynjoe11", "Wasabigie42", "Baksheesh", "Jumbohford64", "Riposte", "Boondocks", "Cockatoo", "Primneys", "Tuberpodky", "Manorexic", "Puppenhaus"}

--[[-----

CONFIG END CONFIG END
CONFIG END CONFIG END
CONFIG END CONFIG END

--]]-----

include("leadbot/base.lua")

if file.Find("leadbot/gamemodes/" .. engine.ActiveGamemode() .. ".lua", "LUA")[1] then
    include("leadbot/gamemodes/" .. engine.ActiveGamemode() .. ".lua")
end