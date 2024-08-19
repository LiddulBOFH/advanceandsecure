AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("entities/aas_spawnpoint.lua")
include("shared.lua")

local ST = SysTime
AAS.Halt = false

-- Initialize

function GM:Initialize()
	GAMEMODE.ACFLoaded = false
	GAMEMODE.EditMode = GAMEMODE.EditMode or false
	if ACF then
		GAMEMODE.ACFLoaded = true
	else print("ACF is not loaded, what are you even playing this for?") end

	if not CPPI then error("No CPPI-compliant prop protection loaded, this is required!") end

	RunConsoleCommand("physgun_maxrange", 256)
	RunConsoleCommand("physgun_maxspeed", 400)
	RunConsoleCommand("physgun_maxangular", 400)
	RunConsoleCommand("sv_airaccelerate", 1)

	if not file.Exists("aas","DATA") then
		MsgN("Missing base directory 'aas', making...")
		file.CreateDir("aas/maps")
	end

	AAS.Funcs.SetEditMode(GAMEMODE.EditMode)
end

local function HandleKill(victim,inflictor,attacker)
	if GetGlobalBool("EditMode",false) then victim:SetNW2Float("NextSpawn",CurTime() + 1) return end

	if victim:IsPlayer() then
		if not victim.FirstSpawn then -- normal death, with some adjustment depending on how the player has acted
			victim:SetNW2Float("NextSpawn",CurTime() + math.Clamp( 5 + (-5 * (victim:GetNW2Int("karma",0) / 100)) ,2.5,10))
		else
			victim:SetNW2Float("NextSpawn",CurTime() + 1) -- First time spawning, so no extensive respawn
		end
	end

	if not ((victim:IsPlayer() or victim:IsNextBot()) and attacker:IsPlayer()) then return end

	if victim == attacker then return end

	if (victim:Team() == attacker:Team()) then
		attacker:SetFrags(attacker:Frags() - 2)

		AAS.Funcs.AdjustKarma(attacker,-25)
		aasMsg({Colors.BadCol,"You just teamkilled " .. victim:Nick() .. "!"},attacker)

		if victim:IsPlayer() then victim:SetNW2Float("NextSpawn",CurTime() + 1) end -- pity respawn timer for the player that got teamkilled
	end
end

local function Payday(ply) -- gives targetted player (or all players if nil is given) a regular income of requisition
	if not AAS.CurrentProperties then return end
	local MaxGain = AAS.CurrentProperties["RequisitionGain"]
	local Time = ST()

	if ply == nil then
		for k,v in ipairs(player.GetAll()) do
			if v.NextPay and (v.NextPay > Time) then continue end
			local Gain = math.Round(math.Clamp((MaxGain / 2) + ((v:GetNW2Int("Karma",0) / 100) * (MaxGain / 2)),0,MaxGain))
			AAS.Funcs.ChargeRequisition(v,-Gain)

			v.NextPay = Time + 60
		end
	else
		if ply.NextPay and (ply.NextPay > Time) then return end
		local Gain = math.Round(math.Clamp((MaxGain / 2) + ((ply:GetNW2Int("Karma",0) / 100) * (MaxGain / 2)),0,MaxGain))
		AAS.Funcs.ChargeRequisition(ply,-Gain)

		ply.NextPay = Time + 60
	end
end

local function BalanceTeams()
	local TeamDiff = team.NumPlayers(1) - team.NumPlayers(2)
	local LargerTeam = (TeamDiff > 0) and 1 or 2
	local SmallerTeam = (TeamDiff > 0) and 2 or 1

	if math.abs(TeamDiff) <= 1 then return end

	local Team = team.GetPlayers(LargerTeam)

	local I = 0
	local NumToBalance = math.ceil(math.abs(TeamDiff / 2))
	local Moving = {}
	while I < NumToBalance do
		local PlyIn = math.random(#Team)
		local Ply = Team[PlyIn]
		Moving[#Moving + 1] = Ply
		table.remove(Team,PlyIn)

		I = I + 1
	end

	for _,ply in ipairs(Moving) do
		ply:SetTeam(SmallerTeam)
		ply:StripWeapons()
		ply:StripAmmo()
		ply:Spawn()
		aasMsg({Colors.BasicCol,"Moving " .. ply:Nick() .. " to ", AAS.TeamData[SmallerTeam].Color, AAS.TeamData[SmallerTeam].Name, Colors.BasicCol,"!"})
	end
end

local AutoBalance = false
local AutoBalanceTick = 5

local function DeathCountdown(ply)
	if ply.DeathCountdown == nil then return end -- something else, like a round restart, set this to nil
	if PlyInEnemySafezone(ply,ply:GetPos()) then
		aasMsg({Colors.ErrorCol,"You have " .. ply.DeathCountdown .. " seconds to leave the enemy safezone."},ply)
		ply.DeathCountdown = ply.DeathCountdown - 1

		if ply.DeathCountdown >= 0 then
			AAS.Funcs.AdjustKarma(ply,-10) -- steeply punish the player for being in the enemy safezone
			timer.Simple(1,function() DeathCountdown(ply) end)
		else
			ply.DeathCountdown = nil
			ply:Kill()
		end
	else
		aasMsg({Colors.BasicCol,"You have ",Colors.GoodCol,"left", Colors.BasicCol," the ",Colors.BadCol,"enemy",Colors.BasicCol," safezone."},ply)
		ply.DeathCountdown = nil
	end
end

-- Lodsa commands

do	-- Organizing stuff :)
	do	-- Hooks, arr

		-- Ugly mess, handles everything from payday to checking wins if point updates didn't catch it
		local NextLongThink		= ST()
		local ShortThink		= ST()
		local NextTicketThink	= ST()
		local DoTicketChange	= AAS.Funcs.DoTicketChange
		hook.Add("Think","GameThink",function()
			if AAS.Halt == true then return end
			if not AAS.RAASFinished then return end

			if (ST() > ShortThink) and AAS.RAASFinished then

				for _,ply in pairs(player.GetAll()) do
					local state = PlyInSafezone(ply,ply:GetPos())
					if ply:GetNW2Bool("InSafezone") ~= state then
						if state then
							aasMsg({Colors.BasicCol,"You have ",Colors.GoodCol,"entered",Colors.BasicCol," the safezone."},ply)
						else
							aasMsg({Colors.BasicCol,"You have ",Colors.BadCol,"left",Colors.BasicCol," the safezone."},ply)
						end

						ply:SetNW2Bool("InSafezone",state) -- this doesn't affect anything right now except for what the client sees, InSafezone is checked for every damage interaction again
					end

					if PlyInEnemySafezone(ply,ply:GetPos()) and (GetGlobalBool("EditMode",false) == false) and (not ply.DeathCountdown and ply:Alive()) then
						aasMsg({Colors.BasicCol,"You have ",Colors.BadCol,"entered", Colors.BasicCol," the ",Colors.BadCol,"enemy",Colors.BasicCol," safezone."},ply)
						ply.DeathCountdown = 5
						DeathCountdown(ply)
					end
				end

				ShortThink = ST() + 0.5
			end

			if ST() > NextTicketThink then
				if AAS.RAASFinished then
					local TeamACaps = 0
					local TeamBCaps = 0
					local Points = ents.FindByClass("aas_point")
					local TotalPoints = #Points - 2
					for k,v in ipairs(Points) do
						if v:GetIsSpawn() then continue end
						local Capped = CapStatus(v)
						if Capped == 1 then TeamACaps = TeamACaps + 1 elseif Capped == 2 then TeamBCaps = TeamBCaps + 1 end
					end

					if TotalPoints > 2 then
						local MinCap = math.floor(TotalPoints / 2)
						local TicketDrain = 0

						if TeamACaps > MinCap then TicketDrain = (TeamACaps - MinCap) elseif TeamBCaps > MinCap then TicketDrain = -(TeamBCaps - MinCap) end

						if TeamACaps == TotalPoints then -- Pity drain B
							TicketDrain = 5
						elseif TeamBCaps == TotalPoints then -- Pity drain A
							TicketDrain = -5
						end

						-- TicketDrain > 0 then subtract from team 2s count, otherwise TicketDrain < 0 then subtract from team 1s count
						if TicketDrain > 0 then
							DoTicketChange(2,-TicketDrain,false)
						elseif TicketDrain < 0 then
							DoTicketChange(1,TicketDrain,false)
						end
					elseif TotalPoints > 1 then
						if TeamACaps == TotalPoints then -- Pity drain B
							DoTicketChange(2,-5,false)
						elseif TeamBCaps == TotalPoints then -- Pity drain A
							DoTicketChange(1,-5,false)
						else
							DoTicketChange(2,-TeamACaps,false)
							DoTicketChange(1,-TeamBCaps,false)
						end
					else
						if TeamACaps == TotalPoints then -- Pity drain B
							DoTicketChange(2,-5,false)
						elseif TeamBCaps == TotalPoints then -- Pity drain A
							DoTicketChange(1,-5,false)
						end
					end

					CheckWin()
				end

				NextTicketThink = ST() + 5
			end

			if ST() > NextLongThink then
				Payday() -- gives all players requisition if it is their time to

				for _,v in ipairs(player.GetAll()) do
					if not IsValid(v) then continue end
					v:SetPlayerColor(AAS.TeamData[v:Team()].Color:ToVector())
				end

				local Team1 = team.NumPlayers(1)
				local Team2 = team.NumPlayers(2)
				if AutoBalance then
					AutoBalance = false
					BalanceTeams()
				elseif math.abs(Team1 - Team2) > 1 then
					AutoBalanceTick = AutoBalanceTick + 1
					if AutoBalanceTick >= 6 then
						AutoBalance = true
						AutoBalanceTick = 0
						aasMsg({Colors.BasicCol,"Autobalancing teams in 5s..."})
					end
				else AutoBalanceTick = 0 end

				NextLongThink = ST() + 5
				AAS.Funcs.CalcRequisition()
			end
		end)

		-- Places the player on one of their team spawnpoints
		hook.Add("PlayerSelectSpawn","OverrideSpawn",function(ply)
			local Team = ply:Team()
			if (Team ~= 1) and (Team ~= 2) then
				local numA,numB = team.NumPlayers(1),team.NumPlayers(2)
				ply:SetTeam((numA == numB) and math.random(1,2) or ((numA > numB) and 2 or 1))
				ply.FirstSpawn = true -- Stops ticket loss from spawning
				ply:KillSilent()
				timer.Simple(1,function() ply:Spawn() end)
			else
				if not AAS.SpawnPoints then print("No spawnpoints!") return end

				if not ply.FirstSpawn then -- Deduct 1 ticket from the team for respawning
					DoTicketChange(Team,-1,true)
				else ply.FirstSpawn = nil end

				local List = AAS.SpawnPoints[Team]

				if GetGlobalBool("EditMode",false) then aasMsg({Colors.GoodCol,"AAS: Server is in edit mode, vanilla spawns are used."},ply) return end
				return List[math.random(#List)]
			end
		end)

		-- Handles the player dying, checking if the attacker was a teammate and punishing them with negative karma
		hook.Add("PlayerDeath","KillHandle",function(victim,inflictor,attacker)
			HandleKill(victim,inflictor,attacker)
		end)

		-- Prevents the player from spawning if they aren't allowed
		hook.Add("PlayerDeathThink","SpawnOverride",function(ply)
			if CurTime() < ply:GetNW2Float("NextSpawn",CurTime()) then return false end

			return -- returning true still just blocks spawning, fucking retarded
		end)

		-- Prevents using toolguns outside of the player's spawn, EditMode bypasses this
		hook.Add("CanTool","AAS_SafezoneTool",function(ply,trace) -- tool,button also available, but not needed
			if GetGlobalBool("EditMode",false) then return true end

			if not (PlyInSafezone(ply,ply:GetPos()) and InSafezone(trace.HitPos)) then aasMsg({Colors.BadCol,"You can't use the toolgun outside of your safezone!"},ply) return false end

			return true
		end)

		-- Prevents using physgun at full range outside of the player's spawnzone, otherwise allow full usage
		local PhysDist = 256^2
		hook.Add("PhysgunPickup","AAS_PhysgunLimit",function(ply,ent)
			if PlyInSafezone(ply,ply:GetPos()) and InSafezone(ent:GetPos()) then return true end

			if ply:GetPos():DistToSqr(ent:GetPos()) < PhysDist then return true end

			if GetGlobalBool("EditMode",false) == true then return true else return false end
		end)

		-- Prevents anyone not an admin from editing gamemode entities, and only allowable while EditMode is on
		hook.Add("CanEditVariable","DisableEditing",function(ent,ply)
			-- Only allow superadmins to make stuff for the gamemode
			local IsAdmin = ply:IsSuperAdmin()
			local CanEdit = GetGlobalBool("EditMode",false)

			if ent.AdminOnly and ent.AdminOnly == true then return IsAdmin and CanEdit end

			return true
		end)

		-- Prevents the entity driving mechanic in gmod
		hook.Add("CanDrive","StopDriving",function() return GetGlobalBool("EditMode",false) end)

		-- Disables key entities if the player is over requisition
		local LegalFilter = {acf_gun = true,acf_engine = true,acf_rack = true}
		hook.Add("ACF_IsLegal","AAS_ACFLegalCheck",function(ent)
			if not AAS.CurrentProperties then return true end
			--return IsLegal,"reason","description",OverrideTime
			if not (LegalFilter[ent:GetClass()] or false) then return true end

			local Owner = ent:CPPIGetOwner()
			local Req = Owner:GetNW2Int("UsedRequisition")

			if Req > AAS.CurrentProperties["MaxRequisition"] then return false,"Exceeded requisition","You have exceeded your maximum requisition amount!" end

			return true
		end)

		-- Prevents ACF damage inside a safezone
		hook.Add("ACF_PreDamageEntity","AAS_ACFDamageCheck",function(Entity,DmgResult,DmgInfo)
			if InSafezone(Entity:GetPos()) then
				if DmgInfo:GetAttacker() and DmgInfo:GetAttacker():IsPlayer() then aasMsg({Colors.ErrorCol,"You can't hurt things in a safezone!"},DmgInfo:GetAttacker()) end
				return false
			end
		end)

		-- Prevents shooting inside a safezone
		hook.Add("ACF_FireShell","AAS_ACFSafezoneFireCheck",function(Gun)
			if InSafezone(Gun:GetPos()) then
				if Gun.Owner and Gun.Owner:IsPlayer() then aasMsg({Colors.ErrorCol,"You can't shoot in a safezone!"},Gun.Owner) end
				return false
			end
		end)

		-- Prevents damage inside a safezone
		hook.Add("EntityTakeDamage","AAS_SafezoneDamageCheck",function(ent,dmg)
			if InSafezone(ent:GetPos()) then return true end
		end)

		-- Stops the player from changing teams by console
		hook.Add("PlayerCanJoinTeam","StopChange",function(ply) return false end)

		-- Sets the player's model and color whenever they spawn
		hook.Add("PlayerSpawn","PlayerSpawn",function(ply)
			hook.Call("PlayerSetModel", GAMEMODE, ply)

			local t = ply:Team()
			if (t == 1) or (t == 2) then
				ply:SetPlayerColor(AAS.TeamData[t].Color:ToVector())
			end
		end)

		-- Prevents spawning other vehicles on the server (cars, airboats)
		-- If for whatever reason the server has SCars or something like that, they'll need to add whatever (I don't know why you'd add them anyway, the gamemode is about using your own stuff)
		local BannedVehicles = {prop_vehicle_airboat = true,prop_vehicle_jeep = true,prop_vehicle_jeep_old = true}
		hook.Add("PlayerSpawnVehicle","AAS_VehicleBlock",function(ply,_,vicname,victable)
			if BannedVehicles[victable.Class] or false then
				aasMsg({Colors.ErrorCol,"You aren't allowed to spawn '" .. victable.Name  .. "'!"},ply)
				return false
			end
			if not PlyInSafezone(ply,ply:GetPos()) then aasMsg({Colors.ErrorCol,"You can't spawn props outside of the safezone!"},ply) return false end
			return true
		end)

		local SENTBlockList = { -- [1] = wildcard
			"edit*",
			"item*",
			"combine_mine",
			"npc_grenade_frag",
			"sent_deployableballoons",
			"weapon_striderbuster",
			"grenade_helicopter",
			"prop_thumper",
			"sent_ball"
		}

		-- Prevents the player from spawning special entities they shouldn't have
		hook.Add("PlayerSpawnSENT","AAS_BlockSENT",function(ply,class)
			if GetGlobalBool("EditMode",false) then return true end

			for _,v in ipairs(SENTBlockList) do
				if string.find(class,v) then
					aasMsg({Colors.ErrorCol,"You can't spawn ",class,"!"},ply)
					return false
				end
			end

			if not PlyInSafezone(ply,ply:GetPos()) then aasMsg({Colors.ErrorCol,"You can't spawn stuff outside of the safezone!"},ply) return false end
		end)

		local SpecialSENTBlockList = {
			gmod_wire_field_device = true,
			gmod_wire_turret = true,
			gmod_wire_igniter = true,
			gmod_wire_nailer = true,
			gmod_wire_explosive = true,
			gmod_wire_simple_explosive = true,
			gmod_wire_detonator = true,
			gmod_wire_teleporter = true,
			gmod_wire_dupeport = true
		}
		-- Prevents the player from spawning other special entities they shouldn't have
		hook.Add("OnEntityCreated","AAS_BlockSpecialSENT",function(ent)
			if SpecialSENTBlockList[ent:GetClass()] then aasMsg({Colors.ErrorCol,"Someone is trying to spawn '",ent:GetClass(),"'!"}) timer.Simple(0,function() ent:Remove() end) end
		end)

		-- Prevents the player from spawning weapons (SpawnSWEP spawns in world with toolgun, GiveSWEP is spawning directly in their hands)
		hook.Add("PlayerSpawnSWEP","AAS_BlockSWEP",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol,"You can't spawn weapons!"},ply) return false end end) -- This is for SPAWNING IN THE WORLD
		hook.Add("PlayerGiveSWEP","AAS_BlockSWEP",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol,"You can't spawn weapons!"},ply) return false end end) -- This is for GIVING THE PLAYER WEAPONS DIRECTLY

		-- Prevents the player from spawning NPCs, effects, and ragdolls
		hook.Add("PlayerSpawnNPC","AAS_BlockNPC",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol,"You can't spawn NPCs!"},ply) return false end end)
		hook.Add("PlayerSpawnEffect","AAS_BlockFX",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol,"You can't spawn effects!"},ply) return false end end)
		hook.Add("PlayerSpawnRagdoll","AAS_BlockRagdoll",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol,"You can't spawn ragdolls!"},ply) return false end end)

		-- Prevents the player from spawning props outside their safezone
		hook.Add("PlayerSpawnProp","AAS_SafezonePropSpawn",function(ply)
			if GetGlobalBool("EditMode",false) then return end
			if not PlyInSafezone(ply,ply:GetPos()) then aasMsg({Colors.ErrorCol,"You can't spawn props outside of the safezone!"},ply) return false end
		end)

		-- Prevents the player from spawning props outside the safezone (this is post-spawn, and will delete if it still managed to get spawned)
		hook.Add("PlayerSpawnedProp","AAS_SafezonePostPropSpawn",function(ply,_,ent)
			if GetGlobalBool("EditMode",false) then return end
			if not InSafezone(ent:GetPos()) then aasMsg({Colors.ErrorCol,"You can't spawn props outside of the safezone!"},ply) ent:Remove() end
		end)
	end

	do	-- Net handling
		-- Sends the gamemode info to the client
		net.Receive("AAS.PlayerInit",function(_,ply)
			if not AAS.RAASLine then
				print("No RAASLine defined to send to " .. tostring(ply) .. "!")

				if file.Exists("aas/maps/" .. string.lower(game.GetMap()) .. ".txt","DATA") then AAS.Funcs.setupMap() end

				return
			end
			for k,v in ipairs(AAS.RAASLine) do
				if not IsValid(v) then continue end
				v:SetForceUpdate(not v:GetForceUpdate())
			end
			AAS.Funcs.sendRAAS(ply)

			ply.NextPay = ST()

			AAS.Funcs.updateTeamData(ply)
		end)

		-- Handles when a player wishes to change teams legitimately, and will block them if they aren't allowed (team misbalance, changing too often)
		net.Receive("AAS.RequestTeamSwap",function(_,ply)
			if ply.NextTeamSwitch and (ply.NextTeamSwitch >= ST()) then
				aasMsg({Colors.ErrorCol, "You can't switch teams for another " .. math.Round(ply.NextTeamSwitch - ST(), 1) .. " seconds!"}, ply)
				return
			end
			local CurTeam = ply:Team()
			local OppTeam = (CurTeam == 1) and 2 or 1

			if team.NumPlayers(CurTeam) <= team.NumPlayers(OppTeam) then
				aasMsg({AAS.TeamData[OppTeam].Color,AAS.TeamData[OppTeam].Name,Colors.BadCol," has too many players for you to join!"},ply)
				return
			end

			-- Reset the player's karma if it is over 0 so they have to contribute to get where they were at, otherwise if its low
			if ply:GetNW2Int("Karma", 0) > 0 then AAS.Funcs.SetKarma(Ply, 0) end
			ply:SetNW2Int("Requisition", 0)
			ply.NextPay	= ST()

			ply.FirstSpawn = true
			ply:SetTeam(OppTeam)

			aasMsg({Colors.BasicCol,ply:Nick() .. " switched to ",AAS.TeamData[ply:Team()].Color, AAS.TeamData[ply:Team()].Name, Colors.BasicCol, "."})

			ply:Spawn()
			ply.NextTeamSwitch = ST() + 60
		end)

		-- Handles any updates to the server settings, with a myriad of checks to block any unwanted changes
		net.Receive("AAS.UpdateServerSettings",function(_,ply)
			local Settings = net.ReadTable()
			if ply == nil then print("how?") return end
			if not ply:IsSuperAdmin() then print(ply:Nick() .. " attempted to update server settings.") return end
			if not GetGlobalBool("EditMode",false) then print(ply:Nick() .. " attempted to update server settings.") return end

			print("BEFORE")
			PrintTable(AAS.CurrentProperties)
			AAS.CurrentProperties = Settings
			print("AFTER")
			PrintTable(AAS.CurrentProperties)

			AAS.Funcs.SetEditMode(false)
			AAS.Funcs.saveMap()
			AAS.Funcs.setupMap()
		end)
	end

	do	-- ConCommands
		concommand.Add("aas_editmode",function(ply,cmd,arg)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return end

			local Arg = tobool(arg[1]) or false
			AAS.Funcs.SetEditMode(Arg)
			if Arg == true then
				AAS.Funcs.deepReset()
				AAS.Funcs.setupMap() -- Completely resets the map, most importantly loads points if its RAAS
			end
		end)

		concommand.Add("aas_save",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return else AAS.Funcs.saveMap() end
		end)

		concommand.Add("aas_load",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return else AAS.Funcs.deepReset() AAS.Funcs.setupMap() end
		end)

		concommand.Add("aas_opensettings",function(ply)
			if ply == NULL then print("You can't run this from rcon!") return end
			if not ply:IsSuperAdmin() then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return end
			if GetGlobalBool("EditMode",false) == false then ply:PrintMessage(HUD_PRINTTALK,"The server is not in edit mode!") return end

			AAS.Funcs.updateTeamData(ply)

			timer.Simple(0,function()
				net.Start("AAS.OpenSettings")
				net.WriteTable(AAS.CurrentProperties)
				net.Send(ply)
			end)

		end)
	end
end