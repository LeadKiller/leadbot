if game.SinglePlayer() or CLIENT then return end
LeadBot = {}
LeadBot.NoNavMesh = {}

--[[-----
CONFIG START
--]]-----

LeadBot.SteamAPIKey = "" -- Steam API Key used to get friends list's names. You can get it here, but you should never share it to anyone!: https://steamcommunity.com/dev/apikey
LeadBot.UseFriendsListNames = true -- Requires the above to be set, it also requires you to have your friends list public.
LeadBot.Prefix = "BOT " -- Name Prefix
LeadBot.Names = {"Turnverein", "Monothelious", "Aardwolf", "Micawber", "Aardwolf", "Electuary", "GhostkillSomber", "Panegyricon", "Idealism", "Epilate", "Fulgent", "Torfaceous", "Sedilia", "Luminous", "Dysphoria", "TjsinminCotta", "HyrerpwnedHeaume", "Luminous", "Luminous", "Concrew", "Acrimony", "Cosmicrephysx", "Munting", "Anadiplosis", "Dyphone", "Acrimony", "Glacial", "Skintle", "Pruniferous", "Transience", "Abattoir", "Physagogue", "Anatreptic", "Luminous", "Wastive", "Vermiculous", "Misogallic", "Abderian", "Quarterland", "Abderian", "Snooker", "Machinations", "Snicket", "ChessonGizmo", "ScanderLogjam", "BlaboudPaltry", "ElvaelOoshie", "Bovicide", "Hogwash", "Rubberneck", "Pandemonium", "Gobsmacked", "Bifurcate", "Gongoozle", "Donkeyman", "Anemone", "Interrobang", "Balderdash", "DanzhitZonked", "Turducken", "Yokelnel67", "Pussspun", "Vamoose", "Euouaekle4949", "Sousaphone", "Corkscrew", "Jitneyrobs", "Appaloosa", "Ziggurat", "Womynjoe11", "Wasabigie42", "Baksheesh", "Jumbohford64", "Riposte", "Boondocks", "Cockatoo", "Primneys", "Tuberpodky", "Manorexic", "Puppenhaus"} -- Names if friends list is not used
LeadBot.Models = {} -- Models, leave as {} if random is desired

-- No Navmesh Needed Gamemodes
LeadBot.NoNavMesh["nzombies-unlimited"] = true
LeadBot.NoNavMesh["cinema"] = true

--[[-----
CONFIG END
--]]-----

include("leadbot/base.lua")

if file.Find("leadbot/gamemodes/" .. engine.ActiveGamemode() .. ".lua", "LUA")[1] then
    include("leadbot/gamemodes/" .. engine.ActiveGamemode() .. ".lua")
end