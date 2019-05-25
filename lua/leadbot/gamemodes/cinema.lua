--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = true
LeadBot.Gamemode = "cinema"

--[[GAMEMODE CONFIGURATION END]]--

function LeadBot.PlayerSpawn(bot)
	timer.Simple(0, function()
		bot:SetModel(bot.BotModel)
		bot:SetPlayerColor(bot.BotColor)
		bot:SetSkin(bot.BotSkin)
	end)
end

function LeadBot.StartCommand(bot, cmd)
	cmd:ClearMovement()
	cmd:ClearButtons()

	if IsValid(bot.ControllerBot) then
		bot.ControllerBot:Remove()
	end

	if !bot:InVehicle() then
		local seats = ents.FindByClass("prop_dynamic")

		for k, v in pairs(seats) do
			if !ChairOffsets[v:GetModel()] then
				table.remove(seats, k)
			end
		end

		local seat = table.Random(seats)
		local offset = ChairOffsets[seat:GetModel()]

		if istable(offset) then
			local offsets = table.Random(offset)
			local ang = seat:GetAngles()

			if offsets.Ang then
				ang:RotateAroundAxis(seat:GetForward(), offsets.Ang.p)
				ang:RotateAroundAxis(seat:GetUp(), offsets.Ang.y)
				ang:RotateAroundAxis(seat:GetRight(), offsets.Ang.r)
			else
				ang:RotateAroundAxis(seat:GetUp(), -90)
			end

			local s = CreateSeatAtPos(seat:LocalToWorld(offsets.Pos), ang)

			s:SetParent(seat)
			s:SetOwner(bot)
			s.SeatData = {Ent = seat, Pos = seat:LocalToWorld(offsets.Pos), EntryPoint = bot:GetPos(), EntryAngles = bot:GetAngles()}
			bot:EnterVehicle(s)
		end

		--

	end
end