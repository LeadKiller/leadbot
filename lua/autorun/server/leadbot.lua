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