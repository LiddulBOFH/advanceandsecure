AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("entities/aas_spawnpoint.lua")
include("shared.lua")

local ST = SysTime

-- Initialize

function GM:Initialize()
	RunConsoleCommand("physgun_maxrange", 256)
	RunConsoleCommand("physgun_maxspeed", 400)
	RunConsoleCommand("physgun_maxangular", 400)
	RunConsoleCommand("sv_airaccelerate", 1)

	if not file.Exists("aas","DATA") then
		MsgN("Missing base directory 'aas', making...")

		file.CreateDir("aas/maps")	-- Stores all of the information relevant to maps
		file.CreateDir("aas/dupes")	-- A place to store dupes that will be distributed to players on request
		file.CreateDir("aas/scans")	-- Stores all of the information regarding map scans, which will be sent to players so they may generate a PNG
	end
end

function GM:InitPostEntity()
	GAMEMODE.FirstLoad	= true
	AAS.Funcs.LoadGamemode(AAS.ModeCV:GetString())
end

if GAMEMODE and GAMEMODE.FirstLoad then timer.Simple(0, function() AAS.Funcs.ReloadGamemode() aasMsg({Colors.ErrorCol, "Gamemode reloaded via refresh."}) end) end -- For development purposes

do	-- Organizing stuff :)
	do	-- Net handling
		-- Sends the gamemode info to the client
		net.Receive("AAS.PlayerInit",function(_,ply)
			print("PLAYERINIT: Updating ", ply)

			AAS.Funcs.UpdateState(ply)
		end)

		-- Handles when a player wishes to change teams legitimately, and will block them if they aren't allowed (team misbalance, changing too often)
		net.Receive("AAS.RequestTeamSwap",function(_,ply)
			if ply.NextTeamSwitch and (ply.NextTeamSwitch >= ST()) then
				aasMsg({Colors.ErrorCol, "You can't switch teams for another " .. math.Round(ply.NextTeamSwitch - ST(), 1) .. " seconds!"}, ply)
				return
			end
			local CurTeam = ply:Team()
			local OppTeam = (CurTeam == 1) and 2 or 1

			local OppTeamData	= AAS.Funcs.GetTeamInfo(CurTeam == 1 and 2 or 1)

			if team.NumPlayers(CurTeam) <= team.NumPlayers(CurTeam == 1 and 2 or 1) then
				local TC = OppTeamData.Color
				aasMsg({Color(TC.x, TC.y, TC.z), OppTeamData.Name, Colors.BadCol, " has too many players for you to join!"},ply)
				return
			end

			-- Reset the player's karma if it is over 0 so they have to contribute to get where they were at, otherwise if its low
			if ply:GetNW2Int("Karma", 0) > 0 then AAS.Funcs.SetKarma(ply, 0) end
			ply:SetNW2Int("Requisition", 0)
			ply.NextPay	= ST() + 1

			ply.FirstSpawn = true
			ply:SetTeam(OppTeam)

			local CurTeamData = AAS.Funcs.GetTeamInfo(ply:Team())

			aasMsg({Colors.BasicCol, ply:Nick() .. " switched to ", CurTeamData.Color, CurTeamData.Name, Colors.BasicCol, "."})

			ply:Spawn()
			ply.NextTeamSwitch = ST() + 60
		end)
	end

	do	-- ConCommands
		concommand.Add("aas_editmode",function(ply,cmd,arg)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return end

			local Arg = tobool(arg[1]) or false
			AAS.Funcs.SetEditMode(Arg)
		end)

		concommand.Add("aas_save",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return else AAS.Funcs.SaveMap() end
		end)

		concommand.Add("aas_load",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return else AAS.Funcs.FullReload() end
		end)

		concommand.Add("aas_opensettings",function(ply)
			if ply == NULL then print("You can't run this from rcon!") return end
			if not ply:IsSuperAdmin() then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return end
			if GetGlobalBool("EditMode",false) == false then ply:PrintMessage(HUD_PRINTTALK,"The server is not in edit mode!") return end

			AAS.Funcs.UpdateState(ply)

			timer.Simple(0,function()
				net.Start("AAS.OpenSettings")
				net.WriteTable(AAS.GM.Settings)
				net.Send(ply)
			end)

		end)

		concommand.Add("aas_scan",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol, "You aren't allowed to run that command!"},ply) return else AAS.Funcs.StartScan() end
		end)

		concommand.Add("aas_openvote",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol, "You aren't allowed to run that command!"},ply) return else AAS.Funcs.openVotes() end
		end)

		concommand.Add("aas_status", function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol, "You aren't allowed to run that command!"},ply) return else
				MsgN("===== [AAS STATUS] =====")

				MsgN("Editmode is currently: " .. (GetGlobalBool("EditMode",false) and "ACTIVE" or "INACTIVE"))
				MsgN("Game is currently: " .. (AAS.State.Active and "RUNNING" or "HALTED"))
				MsgN("Gamemode is: " .. AAS.State.Mode)
				MsgN("Ticket balance is: " .. ("BLUFOR: " .. AAS.State.Team.BLUFOR.Tickets) .. " | " .. ("OPFOR: " .. AAS.State.Team.OPFOR.Tickets))

				MsgN("===== [END STATUS] =====")
			end
		end)

		concommand.Add("aas_rebuilddupelist", function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol, "You aren't allowed to run that command!"},ply) return else AAS.Funcs.BuildDupeList() end
		end)
	end
end