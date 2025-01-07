MsgN("+ Leveling system loaded")

-- Changes here will affect player levels
local Constant	= 0.8
AAS.Funcs.XPToLevel	= function(XP)
	return math.floor(Constant * math.sqrt(XP))
end

AAS.Funcs.XPToNextLevel	= function(CurrentLevel)
	return math.floor(((CurrentLevel + 1) / Constant) ^ 2)
end

if SERVER then

	--[[
		When player loads:
			Figure out current level from stored experience, and then required experience for next level
	]]

	-- Current formula:
	-- constant = 0.8
	-- Level = math.floor(constant * math.sqrt(experience))

	-- Store info by SteamID (not 64, as util.SetPData uses the converter internally)
	-- Grab XP from GetPData for a player, and calculate level using that, and store both
	-- As player gains experience, check if the level would increase, and notify them
	-- Be sure that this doesn't trigger when they load in
	-- On certain events, save the data
	-- Player leaving: Trigger a save
	-- Game winning: Trigger a save
	local PlayerXP	= {}

	AAS.Funcs.AddPlayerXP	= function(ply, XP)
		if (not IsValid(ply)) or (ply == NULL) then return end
		local ID	= ply:SteamID()
		if not PlayerXP[ID] then AAS.Funcs.LoadPlayerXP(ply) end

		local OldXP = PlayerXP[ID] or 0
		PlayerXP[ID]	= OldXP + math.abs(XP)

		AAS.Funcs.UpdatePlayerLevel(ply, true)
	end

	AAS.Funcs.AddTeamXP		= function(teamid, XP)
		for _,v in ipairs(team.GetPlayers(teamid)) do
			AAS.Funcs.AddPlayerXP(v, XP)
		end
	end

	AAS.Funcs.SavePlayerXP	= function(ply)
		if (not IsValid(ply)) or (ply == NULL) then return end
		local ID	= ply:SteamID()
		util.SetPData(ID, "AAS.XP", PlayerXP[ID])
	end

	AAS.Funcs.LoadPlayerXP	= function(ply)
		if (not IsValid(ply)) or (ply == NULL) then return end
		local ID	= ply:SteamID()
		local XP	= util.GetPData(ID, "AAS.XP", 0)

		PlayerXP[ID] = XP
		AAS.Funcs.UpdatePlayerLevel(ply, false)
	end

	-- Actually set the player's level
	AAS.Funcs.UpdatePlayerLevel	= function(ply, notify)
		local OldLevel	= ply:GetNW2Int("AAS.Level", 1)
		local NewLevel	= AAS.Funcs.XPToLevel(PlayerXP[ply:SteamID()])
		ply:SetNW2Int("AAS.Level", NewLevel)

		if notify and (OldLevel ~= NewLevel) then
			net.Start("AAS.LevelNotify")
				net.WriteUInt(NewLevel, 16)
			net.Send(ply)
		end
	end

	-- Save XP stored in the PlayerXP table, and remove any disconnected players afterwards
	AAS.Funcs.FlushXPList	= function()
		local ActiveIDs	= {}
		for _, ply in ipairs(player.GetHumans()) do
			ActiveIDs[ply:SteamID()] = true
		end

		for id, xp in pairs(PlayerXP) do
			util.SetPData(id, "AAS.XP", xp)

			if not ActiveIDs[id] then ActiveIDs[id] = nil end
		end
	end

	hook.Add("PlayerDisconnected", "AAS.SaveLevel", function()
		AAS.Funcs.FlushXPList()
	end)

	hook.Add("PlayerSpawn", "AAS.LoadLevel", function(ply)
		if PlayerXP[ply:SteamID()] then return end

		AAS.Funcs.LoadPlayerXP(ply)
	end)
else
	local LevelPanel
	local function LevelNotification(Level)
		if LevelPanel then LevelPanel:Remove() end

		LevelPanel = vgui.Create("DNotify")
		LevelPanel:SetSize(200, 50)
		LevelPanel:CenterVertical(0.65)
		LevelPanel:CenterHorizontal(0.5)
		LevelPanel:SetLife(3)

		local back	= vgui.Create("Panel", LevelPanel)
		back:Dock(FILL)
		back.time	= CurTime()
		back.Paint	= function(panel, w, h)
			draw.RoundedBox(8, 0, 0, w, h, Color(65, 65, 65, 200))

			local perc	= math.Clamp(((panel.time + LevelPanel:GetLife()) - CurTime()) / LevelPanel:GetLife(), 0, 1)
			draw.SimpleTextOutlined("You are now level " .. Level .. "!", "BasicFontLarge", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

			surface.SetDrawColor(0, 255, 0)
			surface.DrawRect(4, h - 8, (1 - perc) * (w - 8), 4)
		end

		surface.PlaySound("garrysmod/save_load4.wav")

		LevelPanel:AddItem(back)
	end

	net.Receive("AAS.LevelNotify", function()
		LevelNotification(net.ReadUInt(16))
	end)
end