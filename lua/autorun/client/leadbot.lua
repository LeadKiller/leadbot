--if game.SinglePlayer() or SERVER then return end

-- Modules

local _, dir = file.Find("leadbot/modules/*", "LUA")

for k, v in pairs(dir) do
    local f = table.Add(file.Find("leadbot/modules/" .. v .. "/cl_*.lua", "LUA"), file.Find("leadbot/modules/" .. v .. "/sh_*.lua", "LUA"))

    for i, o in pairs(f) do
        local file = "leadbot/modules/" .. v .. "/" .. o

        include(file)
    end
end