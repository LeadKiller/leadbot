local meta = FindMetaTable("Player")
local oldFunc = meta.Ping
local ping = 0
local fakeping = true
local convar = CreateConVar("leadbot_fakeping", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Enables fakeping (Do not use this in public servers!)\n2 to make it say BOT")

function meta:Ping()
    if convar:GetBool() and self:IsBot() then
        if fakeping then
            self.FakePing = self.FakePing or math.random(35, 105)
            self.OFakePing = self.OFakePing or self.FakePing

            if math.random(125) == 1 then
                self.FakePing = self.OFakePing + math.random(3)
            elseif math.random(125) == 1 then
                self.FakePing = self.OFakePing - math.random(3)
            end

            if convar:GetInt() == 2 then
                self.FakePing = "BOT"
            end

            return self.FakePing
        end

        return ping
    else
        return oldFunc(self)
    end
end