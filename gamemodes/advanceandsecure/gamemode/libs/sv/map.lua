MsgN("+ Map system loaded")

local ST		= SysTime

AAS.Funcs.SetEditMode = function(bool)
	SetGlobalBool("EditMode",bool)

	aasMsg({Colors.BasicCol,"Game Editmode has been set to ",tostring(GetGlobalBool("EditMode",false)),"."})

	if bool == true then
		for k,v in player.Iterator() do
			if v:IsSuperAdmin() then v:Give("gmod_tool") v:Give("weapon_physgun") end
		end
	end

	if not AAS.SuppressReload then AAS.SuppressReload = false timer.Simple(0,AAS.Funcs.ReloadGamemode) end
end

AAS.Funcs.ResetPlayer	= function(ply)
	ply.FirstSpawn	= true
	ply:SetFrags(0)
	ply:SetDeaths(0)

	ply:SetNW2Int("Karma",0)
	ply:SetNW2Int("Requisition",0)
	ply:SetNW2Int("UsedRequisition",0)

	ply:StripWeapons()
	ply:RemoveAllAmmo()
end

AAS.Funcs.Reset = function(Bypass)
	AAS.State	= {
		Mode	= AAS.ModeCV:GetString(),
		Active	= false,
		Data	= {},
		Team	= {},
	}

	SetGlobalBool("AAS.Voting",false)

	for _, v in player.Iterator() do
		if AAS.RoundCounter == 1 then v:SetNW2Int("KnownRound",0) end

		v:SetNW2Int("Karma",0)
		v:SetNW2Int("Requisition",0)
		v:SetNW2Int("UsedRequisition",0)
		v:SetNW2Bool("InSafezone",true)
		v:UnLock()

		v.DeathCountdown	= nil
		v.PlayerLoadout		= nil

		v.NextTeamSwitch	= ST()
		v.NextPay			= ST() + 1
		v.FirstSpawn		= true
	end

	if not Bypass then AAS.Funcs.UpdateState() end
end

AAS.Funcs.DeepReset = function()
	AAS.RoundCounter = 1
	team.SetScore(1,0)
	team.SetScore(2,0)
	AAS.Halt = false
	AAS.Voting = false
	AAS.RTV = false
	PreMapList = {}

	AAS.Funcs.Reset()

	for _,v in player.Iterator() do
		v:UnSpectate()
	end
end

local PointVariables = {"PointName", "IsSpawn", "TeamSpawn"}
AAS.Funcs.SaveMap	= function()
	local Data	= {}
	Data.Team	= {}
	Data.Spawns	= {}
	Data.Points	= {}
	Data.Props	= {}
	Data.Data	= {}
	Data.Settings	= {}

	for k,v in pairs(AAS.GM.Settings) do
		Data.Settings[k] = v.value
	end

	local Points	= ents.FindByClass("aas_point")
	local Spawns	= ents.FindByClass("aas_spawnpoint")
	local Props		= ents.FindByClass("aas_prop")

	if next(Points) ~= nil then
		for _, point in pairs(Points) do
			local Pos = point:GetPos()
			local Ang = point:GetAngles()
			local NWVars = point:GetNetworkVars()

			local PointData	= {
				pos = Vector(math.Round(Pos.x), math.Round(Pos.y), math.Round(Pos.z)),
				ang = Angle(0, math.Round(Ang.y), 0)
			}

			for _, val in ipairs(PointVariables) do
				PointData[val] = NWVars[val]
			end

			table.insert(Data.Points, PointData)
		end
	else
		aasMsg({Colors.ErrorCol,"[AAS] No points detected! Aborting"})
		return
	end

	if next(Spawns) ~= nil then
		for _, spawn in pairs(Spawns) do
			local Pos = spawn:GetPos()
			local Ang = spawn:GetAngles()

			table.insert(Data.Spawns, {
				pos = Vector(math.Round(Pos.x), math.Round(Pos.y), math.Round(Pos.z)),
				ang = Angle(0, math.Round(Ang.y), 0)
			})
		end
	else
		aasMsg({Colors.ErrorCol,"[AAS] No spawn points detected! Aborting"})
		return
	end

	if next(Props) ~= nil then
		for _, prop in pairs(Props) do
			local PropData = {
				pos = prop:GetPos(),
				ang = prop:GetAngles(),
				mdl = prop:GetModel()
			}

			local col = prop:GetColor()

			PropData.col = Vector(col.r, col.g, col.b)
			PropData.alpha = col.a

			if prop:GetMaterial() ~= "" then
				PropData.mat = prop:GetMaterial()
			end

			table.insert(Data.Props, PropData)
		end
	end

	-- Call the gamemode specific save function, for any extra data that may be required
	if AAS.GM.Save(Data) == false then return end

	local Map	= string.lower(game.GetMap())
	local MapFile	= "aas/maps/" .. Map .. "/" .. AAS.ModeCV:GetString() .. ".txt"
	MsgN("[AAS] Saving to '" .. MapFile .. "'")

	file.Write(MapFile, util.TableToJSON(Data))
end

local removeExtra = {"item_ammo_crate"}
AAS.Funcs.LoadMap	= function(MapData)
	AAS.Funcs.ClearHooks()
	print("[AAS] Loading!")
	game.CleanUpMap( false, { "env_fire", "entityflame", "_firesmoke" } )

	for _,itemType in ipairs(removeExtra) do
		local items = ents.FindByClass(itemType)
		for _,item in ipairs(items) do
			item:Remove()
		end
	end

	AAS.State.Alias = {}
	AAS.State.AliasLookup	= {}
	AAS.Spawnpoints = {[1] = {}, [2] = {}}

	for _, pointdata in pairs(MapData.Points) do
		local point = ents.Create("aas_point")
		point:SetPos(pointdata.pos)
		point:SetAngles(pointdata.ang)
		point:Spawn()

		point:SetPointName(pointdata.PointName)
		point:SetTeamSpawn(pointdata.TeamSpawn)
		point:SetIsSpawn(pointdata.IsSpawn)

		AAS.State.Alias[pointdata.PointName] = point
		AAS.State.AliasLookup[point] = pointdata.PointName
	end

	for _, spawndata in pairs(MapData.Spawns) do
		local spawn = ents.Create("aas_spawnpoint")
		spawn:SetPos(spawndata.pos)
		spawn:SetAngles(spawndata.ang)
		spawn:Spawn()
	end

	if next(MapData.Props) ~= nil then
		for _, propdata in pairs(MapData.Props) do
			local prop = ents.Create("aas_prop")
			prop:SetPos(propdata.pos)
			prop:SetAngles(propdata.ang)
			prop:Spawn()
			prop:SetModel(propdata.mdl)

			prop:SetMaterial(propdata.mat or "")
			local color = Color(propdata.col.x, propdata.col.y, propdata.col.z)
			color.a = propdata.alpha
			prop:SetColor(color)
		end
	end

	timer.Simple(0.5, function()
		local SpawnA, SpawnB

		for _, v in ipairs(ents.FindByClass("aas_point")) do
			if v:GetIsSpawn() then
				if v:GetTeamSpawn() == 1 and not SpawnA then
					print("Located SpawnA")
					SpawnA = v
				elseif v:GetTeamSpawn() == 2 and not SpawnB then
					print("Located SpawnB")
					SpawnB = v
				end
			end

			v:SetCapture(0)

			v:SetForceUpdate(not v:GetForceUpdate())
		end

		if not (IsValid(SpawnA) and IsValid(SpawnB)) then
			ErrorNoHalt("Unable to locate both spawns!")
			return
		end

		for _,v in ipairs(ents.FindByClass("aas_spawnpoint")) do
			local pos	= v:GetPos()
			local D1	= pos:DistToSqr(SpawnA:GetPos())
			local D2	= pos:DistToSqr(SpawnB:GetPos())

			if D1 < D2 then table.insert(AAS.Spawnpoints[1],v) else table.insert(AAS.Spawnpoints[2],v) end
		end

		AAS.Funcs.UpdateState()

		if not GetGlobalBool("EditMode", false) then
			timer.Simple(0.5, function()
				for _, ply in player.Iterator() do
					AAS.Funcs.ResetPlayer(ply)
					ply:Spawn()
				end
			end)
		end
	end)

	if GetGlobalBool("EditMode",false) then
		aasMsg({Colors.ErrorCol,"The game has been loaded with EditMode enabled!"})
	end

	-- Call the gamemode specific load function, incase theres anything extra
	AAS.GM.Load(MapData)
end