-- The default for everything else to be based off of. This should NEVER load on it's own normally, as it is non functional

local DefaultMode		= {}
DefaultMode.Name		= "Base"
DefaultMode.Desc		= "Not defined"
DefaultMode.Settings	= {}
DefaultMode.Hooks		= {}
DefaultMode.Flags		= {}

AAS.SettingsFuncs.String(DefaultMode, "BLUFOR Name", "BLUFOR", "Name of the BLUFOR team", -20)
AAS.SettingsFuncs.Color(DefaultMode, "BLUFOR Color", Vector(0,127,255), "Color of the BLUFOR team", -19)
AAS.SettingsFuncs.String(DefaultMode, "OPFOR Name", "OPFOR", "Name of the OPFOR team", -18)
AAS.SettingsFuncs.Color(DefaultMode, "OPFOR Color", Vector(255,87,87), "Color of the OPFOR team", -17)
AAS.SettingsFuncs.Number(DefaultMode, "Max Requisition", 500, 50, 750, "Maximum amount of accruable requisition", -10)
AAS.SettingsFuncs.Number(DefaultMode, "Max Rate", 50, 5, 200, "Maximum rate (at max karma) of requisition per pay cycle", -9)
AAS.SettingsFuncs.Number(DefaultMode, "Tickets", 300, 50, 1000, "Maximum number of tickets per team", -8)
AAS.SettingsFuncs.Bool(DefaultMode, "Death ticket loss", true, "Whether or not dying causes the team to lose a ticket", -7)
AAS.SettingsFuncs.Bool(DefaultMode, "Non-linear", false, "Enable/disable point linking", -6)

DefaultMode.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate
	ErrorNoHalt("Somehow the game was loaded without a valid gamemode!") -- Remove when using in a new mode!
	AAS.SuppressReload = true
	AAS.Funcs.SetEditMode(true)
end

DefaultMode.Load	= function(MapData) -- Assemble the map here, like placing points/spawns

end

DefaultMode.Save	= function() -- Return false to abort saving for any reason
	return false
end

DefaultMode.TicketThink	= function() -- Called when the server is doing ticket changes

end

DefaultMode.ShortThink	= function() -- Called about every half second, keep it light

end

DefaultMode.LongThink	= function() -- Called every 5 seconds

end

DefaultMode.Update		= function() -- Called whenever a state update is called

end

DefaultMode.CheckWin	= function() -- Called when checking to see if the round should finish
	local TeamA = AAS.Funcs.GetTeamInfo(1)
	local TeamB = AAS.Funcs.GetTeamInfo(2)
	local TixA = TeamA.Tickets
	local TixB = TeamB.Tickets
	local Reset = false

	if (TixA == 0) and (TixB == 0) then -- tie, somehow
		Reset = true

		aasMsg({Colors.BasicCol,"It's a tie!"})
	elseif TixA == 0 then -- team A loses
		Reset = true

		AAS.Funcs.SetTeamScore(-1)

		local TC	= TeamB.Color
		local Col	= Color(TC.x, TC.y, TC.z)

		if team.GetScore(2) >= 2 then
			aasMsg({Col,TeamB.Name,Colors.BasicCol," wins the game!"})
		else
			aasMsg({Col,TeamB.Name,Colors.BasicCol," wins the round!"})
		end

		AAS.Funcs.AddTeamXP(2, 100)
	elseif TixB == 0 then -- team B loses
		Reset = true

		AAS.Funcs.SetTeamScore(1)

		local TC	= TeamA.Color
		local Col	= Color(TC.x, TC.y, TC.z)

		if team.GetScore(1) >= 2 then
			aasMsg({Col,TeamA.Name,Colors.BasicCol," wins the game!"})
		else
			aasMsg({Col,TeamA.Name,Colors.BasicCol," wins the round!"})
		end

		AAS.Funcs.AddTeamXP(1, 100)
	end

	if Reset then
		if (team.GetScore(1) >= 2) or (team.GetScore(2) >= 2) then -- greater than just incase it somehow skips??
			-- Do voting here
			AAS.Funcs.Stop() -- Halts any other game functions as they are not needed anymore

			local SpawnA,SpawnB = AAS.State.Alias["SpawnA"], AAS.State.Alias["SpawnB"]
			local Dir = (SpawnB:GetPos() - SpawnA:GetPos()):GetNormalized()
			for _,v in player.Iterator() do
				local pTeam = v:Team()
				local Base = (pTeam == 1) and SpawnA or SpawnB
				v:ExitVehicle()
				v:Spectate(OBS_MODE_ROAMING)
				v:SetPos(Base:GetPos() + Vector(0,0,2048))
				v:SetEyeAngles((Dir * (pTeam == 1 and 1 or -1)):Angle())
				v:Lock()
				v:StripWeapons()
			end

			AAS.Funcs.openVotes()
		else
			if AAS.RoundCounter == 2 then AAS.Funcs.FlipTeams() elseif AAS.RoundCounter > 2 then AAS.Funcs.ScrambleTeams() end

			for k,v in player.Iterator() do
				v.FirstSpawn = true

				AAS.Funcs.ResetPlayer(v)
				v:Spawn()
			end

			AAS.Funcs.ReloadGamemode()
		end
	end
end

DefaultMode.Payday		= function(ply)
	local MaxGain = AAS.Funcs.GetSetting("Max Rate", 50)
	local Time = SysTime()

	if ply == nil then
		for k,v in player.Iterator() do
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

do	-- Hookery
	do	-- Teamkill handling
		local function HandleKill(victim, inflictor, attacker)
			if GetGlobalBool("EditMode", false) then victim:SetNW2Float("NextSpawn", CurTime() + 1) return end

			if victim:IsPlayer() then
				if not victim.FirstSpawn then -- normal death, with some adjustment depending on how the player has acted
					victim:SetNW2Float("NextSpawn", CurTime() + math.Clamp( 5 + (-5 * (victim:GetNW2Int("karma",0) / 100)) , 2.5, 10))
				else
					victim:SetNW2Float("NextSpawn", CurTime() + 1) -- First time spawning, so no extensive respawn
				end
			end

			if not ((victim:IsPlayer() or victim:IsNextBot()) and attacker:IsPlayer()) then return end

			if victim == attacker then return end

			if (victim:Team() == attacker:Team()) then
				attacker:SetFrags(attacker:Frags() - 2)

				AAS.Funcs.AdjustKarma(attacker, -25)
				aasMsg({Colors.BadCol,"You just teamkilled " .. victim:Nick() .. "!"}, attacker)

				if victim:IsPlayer() then victim:SetNW2Float("NextSpawn", CurTime() + 1) end -- pity respawn timer for the player that got teamkilled
			end
		end

		-- Handles the player dying, checking if the attacker was a teammate and punishing them with negative karma
		AAS.Funcs.AddHook(DefaultMode, "PlayerDeath", HandleKill)
	end

	do	-- Misc

		local TalkRange = 1024 ^ 2
		AAS.Funcs.AddHook(DefaultMode, "PlayerCanHearPlayersVoice", function(listener, talker)
			if listener:Team() == talker:Team() then -- Allow team to use VC with eachother without issue
				return true, false
			else
				if listener:GetPos():DistToSqr(talker:GetPos()) < TalkRange then -- If the enemy is close, let them hear, otherwise nothing
					return true, true
				else
					return false
				end
			end
		end)

		-- Sets the player's model and color whenever they spawn
		AAS.Funcs.AddHook(DefaultMode, "PlayerSpawn",function(ply)
			hook.Call("PlayerSetModel", GAMEMODE, ply)

			local t = ply:Team()
			if (t == 1) or (t == 2) then
				ply:SetPlayerColor(AAS.Funcs.GetTeamInfo(t).Color)
			end
		end)

		-- Places the player on one of their team spawnpoints
		AAS.Funcs.AddHook(DefaultMode, "PlayerSelectSpawn",function(ply)
			local Team = ply:Team()
			if (Team ~= 1) and (Team ~= 2) then
				local numA,numB = team.NumPlayers(1),team.NumPlayers(2)

				ply:SetTeam((numA == numB) and math.random(1,2) or ((numA > numB) and 2 or 1))

				ply.FirstSpawn = true -- Stops ticket loss from spawning
				ply:KillSilent()

				timer.Simple(1,function() ply:Spawn() end)
			else
				if not AAS.Spawnpoints then print("No spawnpoints!") return end

				if not ply.FirstSpawn then -- Deduct 1 ticket from the team for respawning
					if AAS.Funcs.GetSetting("Death ticket loss", false) == true then AAS.Funcs.DoTicketChange(Team,-1,true) end
				else ply.FirstSpawn = nil end

				local List = AAS.Spawnpoints[Team]

				if GetGlobalBool("EditMode",false) then aasMsg({Colors.GoodCol, "AAS: Server is in edit mode, vanilla spawns are used."}, ply) return end

				return List[math.random(#List)]
			end
		end)

		-- Prevents the player from spawning if they aren't allowed
		AAS.Funcs.AddHook(DefaultMode,"PlayerDeathThink",function(ply)
			if CurTime() < ply:GetNW2Float("NextSpawn",CurTime()) then return false end

			return
		end)
	end

	do	-- ACF prevention
		-- Prevents ACF damage inside a safezone
		AAS.Funcs.AddHook(DefaultMode,"ACF_PreDamageEntity",function(Entity,DmgResult,DmgInfo)
			if InSafezone(Entity:GetPos()) then
				if DmgInfo:GetAttacker() and DmgInfo:GetAttacker():IsPlayer() then aasMsg({Colors.ErrorCol, "You can't hurt things in a safezone!"}, DmgInfo:GetAttacker()) end
				return false
			end
		end)

		-- Prevents shooting inside a safezone
		AAS.Funcs.AddHook(DefaultMode,"ACF_FireShell",function(Gun)
			if InSafezone(Gun:GetPos()) then
				if Gun.Owner and Gun.Owner:IsPlayer() then aasMsg({Colors.ErrorCol, "You can't shoot in a safezone!"}, Gun.Owner) end
				return false
			end
		end)

		-- Disables key entities if the player is over requisition
		local MaxDist	= 2048 ^ 2
		local LegalFilter = {acf_gun = true, acf_engine = true, acf_rack = true}
		AAS.Funcs.AddHook(DefaultMode,"ACF_IsLegal",function(ent)
			--return IsLegal,"reason","description",OverrideTime
			if not (LegalFilter[ent:GetClass()] or false) then return true end

			local Owner = ent:CPPIGetOwner()
			local Req = Owner:GetNW2Int("UsedRequisition")

			if Req > AAS.Funcs.GetSetting("Max Requisition", 500) then return false, "Exceeded requisition", "You have exceeded your maximum requisition amount!", 5 end

			if Owner:GetPos():DistToSqr(ent:GetPos()) > MaxDist then return false, "Too far", "We're not in the future, go man your shit.", 5 end

			return true
		end)
	end

	do	-- Other prevention
		-- Prevents using toolguns outside of the player's spawn, EditMode bypasses this
		AAS.Funcs.AddHook(DefaultMode,"CanTool",function(ply,trace) -- tool,button also available, but not needed
			if GetGlobalBool("EditMode",false) then return true end

			if not (PlyInSafezone(ply,ply:GetPos()) and InSafezone(trace.HitPos)) then aasMsg({Colors.BadCol,"You can't use the toolgun outside of your safezone!"},ply) return false end

			return
		end)

		-- Stops the player from changing teams by console
		AAS.Funcs.AddHook(DefaultMode,"PlayerCanJoinTeam",function(ply) return false end)

		-- Prevents using physgun at full range outside of the player's spawnzone, otherwise allow full usage
		local PhysDist = 256^2
		AAS.Funcs.AddHook(DefaultMode,"PhysgunPickup", function(ply,ent)
			if (ply:GetPos():DistToSqr(ent:GetPos()) > PhysDist) and ((not GetGlobalBool("EditMode",false)) or (PlyInSafezone(ply,ply:GetPos()) and InSafezone(ent:GetPos()))) then return end
		end)

		-- Prevents anyone not an admin from editing gamemode entities, and only allowable while EditMode is on
		AAS.Funcs.AddHook(DefaultMode,"CanEditVariable",function(ent,ply)
			-- Only allow superadmins to make stuff for the gamemode
			local IsAdmin = ply:IsSuperAdmin()
			local CanEdit = GetGlobalBool("EditMode",false)

			if ent.AdminOnly and ent.AdminOnly == true then return IsAdmin and CanEdit end

			return
		end)

		-- Prevents the entity driving mechanic in gmod
		AAS.Funcs.AddHook(DefaultMode,"CanDrive",function() return GetGlobalBool("EditMode",false) end)

		-- Prevents damage inside a safezone
		AAS.Funcs.AddHook(DefaultMode,"EntityTakeDamage",function(ent,dmg)
			if InSafezone(ent:GetPos()) then return true end
		end)

		-- Prevents the player from spawning weapons (SpawnSWEP spawns in world with toolgun, GiveSWEP is spawning directly in their hands)
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnSWEP",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol, "You can't spawn weapons!"}, ply) return false end end) -- This is for SPAWNING IN THE WORLD
		AAS.Funcs.AddHook(DefaultMode,"PlayerGiveSWEP",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol, "You can't spawn weapons!"}, ply) return false end end) -- This is for GIVING THE PLAYER WEAPONS DIRECTLY

		-- Prevents the player from spawning NPCs, effects, and ragdolls
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnNPC",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol, "You can't spawn NPCs!"}, ply) return false end end)
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnEffect",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol, "You can't spawn effects!"}, ply) return false end end)
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnRagdoll",function(ply) if not GetGlobalBool("EditMode",false) then aasMsg({Colors.ErrorCol, "You can't spawn ragdolls!"}, ply) return false end end)

		-- Prevents the player from spawning props outside their safezone
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnProp",function(ply)
			if GetGlobalBool("EditMode",false) then return end
			if not PlyInSafezone(ply,ply:GetPos()) then aasMsg({Colors.ErrorCol, "You can't spawn props outside of the safezone!"}, ply) return false end
		end)

		-- Prevents the player from spawning props outside the safezone (this is post-spawn, and will delete if it still managed to get spawned)
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnedProp",function(ply,_,ent)
			if GetGlobalBool("EditMode",false) then return end
			if not InSafezone(ent:GetPos()) then aasMsg({Colors.ErrorCol, "You can't spawn props outside of the safezone!"}, ply) ent:Remove() end
		end)
	end
	do	-- Entity prevention
		-- Prevents spawning other vehicles on the server (cars, airboats)
		-- If for whatever reason the server has SCars or something like that, they'll need to add whatever (I don't know why you'd add them anyway, the gamemode is about using your own stuff)
		local BannedVehicles = {
			prop_vehicle_airboat = true,
			prop_vehicle_jeep = true,
			prop_vehicle_jeep_old = true
		}
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnVehicle",function(ply,_,vicname,victable)
			if BannedVehicles[victable.Class] or false then
				aasMsg({Colors.ErrorCol,"You aren't allowed to spawn '" .. victable.Name  .. "'!"},ply)
				return false
			end
			if not PlyInSafezone(ply,ply:GetPos()) then aasMsg({Colors.ErrorCol, "You can't spawn stuff outside of the safezone!"}, ply) return false end
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
		AAS.Funcs.AddHook(DefaultMode,"PlayerSpawnSENT",function(ply,class)
			if GetGlobalBool("EditMode", false) then return end

			for _,v in ipairs(SENTBlockList) do
				if string.find(class, v) then
					aasMsg({Colors.ErrorCol, "You can't spawn ", class, "!"}, ply)
					return false
				end
			end

			if not PlyInSafezone(ply, ply:GetPos()) then aasMsg({Colors.ErrorCol, "You can't spawn stuff outside of the safezone!"}, ply) return false end
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
		AAS.Funcs.AddHook(DefaultMode,"OnEntityCreated",function(ent)
			if SpecialSENTBlockList[ent:GetClass()] then aasMsg({Colors.ErrorCol,"Someone is trying to spawn '",ent:GetClass(),"'!"}) timer.Simple(0,function() ent:Remove() end) end
		end)
	end
end

AAS.DefaultMode = DefaultMode