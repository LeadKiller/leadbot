local meta = FindMetaTable("Player")
local oldFunc = meta.Ping
local ping = -1

function meta:Ping()
    if self:IsBot() then
        return ping
    else
        return oldFunc(self)
    end
end