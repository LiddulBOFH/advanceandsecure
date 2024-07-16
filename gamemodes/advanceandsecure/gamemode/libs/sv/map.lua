MsgN("+ Map system loaded")

local ST = SysTime

AAS.RAASLookup = {}
AAS.RAASFinished = false

local PointValues = {"PointName","IsSpawn","TeamSpawn"}

local function aas_SetEditMode(bool)
	SetGlobalBool("EditMode",bool)

	aasMsg({Colors.BasicCol,"Game Editmode has been set to ",tostring(GetGlobalBool("EditMode",false)),"."})

	for k,v in ipairs(ents.FindByClass("aas_spawnpoint")) do
		v:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
	end

	for k,v in ipairs(ents.FindByClass("aas_prop")) do
		v:SetEditable(bool)
	end
end
AAS.Funcs.SetEditMode = aas_SetEditMode

local function sendRAAS(ply) -- pass nil to broadcast
	if not AAS.RAASFinished then return end

	net.Start("aas_raasline")
		net.WriteTable(AAS.RAASLine)
		net.WriteTable(AAS.PointAlias)
	if ply == nil then
		net.Broadcast()
		MsgN("AAS: Broadcasting points!")
	else
		net.Send(ply)
		MsgN("AAS: Sending points to " .. ply:Nick())
	end
end
AAS.Funcs.sendRAAS = sendRAAS

local function aas_UpdateTeamData(ply)
	net.Start("aas_UpdateTeamData")
		net.WriteTable(AAS.TeamData)
	if ply == nil then net.Broadcast() else net.Send(ply) end
end
AAS.Funcs.updateTeamData = aas_UpdateTeamData

local function haltMap()
	AAS.Funcs.SetEditMode(true)
end

local function deepReset() -- Used incase the vote at match end results in a reset of the current map
	AAS.RoundCounter = 1
	AAS.TeamWins = {0,0}
	AAS.Halt = false
	AAS.Voting = false
	AAS.RTV = false
	PreMapList = {}

	SetGlobalBool("AAS.Voting",AAS.Voting)

	local players = player.GetAll()
	for _,v in ipairs(players) do
		v:UnSpectate(OBS_MODE_NONE)
	end
end
AAS.Funcs.deepReset = deepReset

local function ValidPoints(Pos,Target,UsedList,CurList) -- Returns top 3 choices, sorted by distance
	local Points = ents.FindByClass("aas_point")
	local FilteredPoints = {}

	for k,v in ipairs(Points) do
		if not UsedList[v] then FilteredPoints[#FilteredPoints + 1] = v end
	end

	local ConeFiltered = {}

	local PosToTarget = (Target:GetPos() - Pos):GetNormalized()
	for k,v in ipairs(FilteredPoints) do
		local PointToTarget = (v:GetPos() - Pos):GetNormalized()

		if PosToTarget:Dot(PointToTarget) >= (1 - ((200 / #UsedList) / 300)) then
			ConeFiltered[#ConeFiltered + 1] = v
		end
	end

	ConeFiltered[#ConeFiltered + 1] = Target

	if #ConeFiltered == 1 then return {Target} end

	table.sort(ConeFiltered,function(a,b) return a:GetPos():DistToSqr(Pos) < b:GetPos():DistToSqr(Pos) end)

	local ReturnPoints = {}
	local ReturnInt = 0
	while #ReturnPoints < math.min(3,#ConeFiltered) do
		ReturnInt = ReturnInt + 1
		local Point = ConeFiltered[ReturnInt]
		if Point == Target then return {Target}
		else ReturnPoints[#ReturnPoints + 1] = Point end

		if ReturnInt > ((#ConeFiltered) / 2) then return {Target} end
	end

	PrintTable(ReturnPoints)

	return ReturnPoints
end

local function RAASConnect()
	if not AAS.PointAlias then print("Missing PointAlias") return end
	local SpawnA = AAS.PointAlias["SpawnA"]
	local SpawnB = AAS.PointAlias["SpawnB"]
	if not (SpawnA and SpawnB) then print("Missing a spawn!") end

	print("Starting...")

	local Line1,Line2 = {SpawnA},{SpawnB}

	local Start1,Start2 = SpawnA:GetPos(),SpawnB:GetPos()

	local Connected = false

	local SafeInt = 0

	local AllPoints = ents.FindByClass("aas_point")
	local NumPoints = #AllPoints

	while Connected == false do
		if SafeInt >= 50 then print("System went for too long, stopping to save resources! " .. SafeInt)  break end

		local UsedList = {}
		for k,v in pairs(Line1) do
			UsedList[v] = true
		end
		for k,v in pairs(Line2) do
			UsedList[v] = true
		end

		local AList = ValidPoints(Start1,Line2[#Line2],UsedList,AList)
		Line1[#Line1 + 1] = AList[math.floor(math.sqrt(math.random(1,(#AList) ^ 2)))]

		if Line1[#Line1] == Line2[#Line2] then Connected = true break end

		local BList = ValidPoints(Start2,Line1[#Line1],UsedList,BList)
		Line2[#Line2 + 1] = BList[math.floor(math.sqrt(math.random(1,(#BList) ^ 2)))]

		Start1 = Line1[#Line1]:GetPos()
		Start2 = Line2[#Line2]:GetPos()

		SafeInt = SafeInt + 1

		if SafeInt >= (NumPoints / 4) then Connected = true print("ding ding ding") break end
		if Line1[#Line1] == Line2[#Line2] then Connected = true break end
	end

	table.remove(Line2)
	Line2 = table.Reverse(Line2)
	table.Add(Line1,Line2)

	if ((#Line1 <= math.floor(#AllPoints * (2 / 6))) or (#Line1 >= math.ceil(#AllPoints * (5 / 6)))) and (#AllPoints > 3) then
		print("Not within limits, restarting...")
		RAASConnect()
	else
		AAS.RAASLine = Line1
		AAS.RAASLookup = {}

		PrintTable(Line1)

		for k,v in ipairs(AAS.RAASLine) do
			AAS.RAASLookup[v] = k
			v:SetCapture(0)
		end

		AAS.RAASFinished = true
	end
end

local function aliasPoints()
	local Points = ents.FindByClass("aas_point")
	if #Points == 0 then return end

	MsgN("AAS: Aliasing points!")

	AAS.PointAlias = {}
	for k,v in ipairs(Points) do
		local Name = v:GetPointName()
		if AAS.PointAlias[Name] then print("Duplicate point found, deleted: " .. Name) v:Remove() else AAS.PointAlias[Name] = v end
	end

	local SpawnA = AAS.PointAlias["SpawnA"]
	local SpawnB = AAS.PointAlias["SpawnB"]
	local SAPos = SpawnA:GetPos()
	local SBPos = SpawnB:GetPos()

	if not (SpawnA and SpawnB) then error("How did it get this far? Setup some nodes!") end

	AAS.SpawnPoints = {[1] = {}, [2] = {}}

	for k,v in ipairs(ents.FindByClass("aas_spawnpoint")) do
		local pos = v:GetPos()
		local D1 = pos:DistToSqr(SAPos)
		local D2 = pos:DistToSqr(SBPos)

		if D1 <= D2 then table.insert(AAS.SpawnPoints[1],v) else table.insert(AAS.SpawnPoints[2],v) end
	end

	if AAS.ManualLink and not AAS.NonLinear then
		AAS.RAASLine = {}
		AAS.RAASLookup = {}

		for k,v in ipairs(AAS.ManualLink) do
			local P = AAS.PointAlias[v]
			AAS.RAASLine[k] = P
			AAS.RAASLookup[P] = k
			P:SetCapture(0)
		end

		AAS.RAASFinished = true


	elseif AAS.NonLinear then
		print("Non linear setup")
		AAS.RAASLookup = {}
		AAS.RAASLine = Points
		PrintTable(AAS.RAASLine)
		for k,v in ipairs(Points) do
			if not v:GetIsSpawn() then
				v:SetCapture(0)
			end

			AAS.RAASLookup[v] = k
		end
		AAS.RAASFinished = true

	else RAASConnect() end -- Goes ahead with normal random behavior
end

local removeExtra = {"item_ammo_crate"}
local function loadMap(InputData)
	MsgN("AAS: Reloading the map!")

	game.CleanUpMap( false, { "env_fire", "entityflame", "_firesmoke" } )

	for _,itemType in ipairs(removeExtra) do
		local items = ents.FindByClass(itemType)
		for _,item in ipairs(items) do
			item:Remove()
		end
	end

	CalcRequisition()

	for k,v in ipairs(InputData["points"]) do -- TODO: fix broken sync (1/29/2023 note: I forgot what was not getting synced, but everything seems to be working fine, I will leave this until I know for sure)
		local point = ents.Create("aas_point")
		point:SetPos(v.pos)
		point:SetAngles(v.ang)
		point:Spawn()

		point.ExtraData = {PointName = v.PointName,IsSpawn = v.IsSpawn,TeamSpawn = v.TeamSpawn}

		point:SetPointName("")
		point:SetTeamSpawn(1)
		point:SetIsSpawn(false)
	end

	for k,v in ipairs(InputData["spawns"]) do
		local point = ents.Create("aas_spawnpoint")
		point:SetPos(v.pos)
		point:SetAngles(v.ang)
		point:Spawn()
	end

	if InputData["props"] then
		for k,v in ipairs(InputData["props"]) do
			local prop = ents.Create("aas_prop")
			prop:SetPos(v.pos)
			prop:SetAngles(v.ang)
			prop:Spawn()
			prop:SetModel(v.mdl)
		end
	end

	if InputData["manual"] then
		AAS.ManualLink = InputData["manual"]
		--PrintTable(AAS.ManualLink)
	end

	SetGlobalBool("IsNonLinear",InputData["properties"].NonLinear or false)
	AAS.NonLinear = GetGlobalBool("IsNonLinear",false)

	AAS.CurrentProperties = InputData["properties"]
	SetGlobalInt("MaxRequisition",AAS.CurrentProperties.MaxRequisition)

	AAS.TeamData[1].Tickets = AAS.CurrentProperties.StartTickets
	AAS.TeamData[2].Tickets = AAS.CurrentProperties.StartTickets

	if AAS.CurrentProperties.ChangedAlias or false then
		AAS.TeamData[1].Name    = AAS.CurrentProperties.Alias[1].Name
		AAS.TeamData[2].Name    = AAS.CurrentProperties.Alias[2].Name

		local ColA = AAS.CurrentProperties.Alias[1].Color
		local ColB = AAS.CurrentProperties.Alias[2].Color

		AAS.TeamData[1].Color   = Color(ColA.r,ColA.g,ColA.b)
		AAS.TeamData[2].Color   = Color(ColB.r,ColB.g,ColB.b)
	else
		AAS.TeamData[1].Name    = AAS.DefaultProperties.Alias[1].Name
		AAS.TeamData[2].Name    = AAS.DefaultProperties.Alias[2].Name

		AAS.TeamData[1].Color   = AAS.DefaultProperties.Alias[1].Color
		AAS.TeamData[2].Color   = AAS.DefaultProperties.Alias[2].Color
	end

	team.SetColor(1,AAS.TeamData[1].Color)
	team.SetColor(2,AAS.TeamData[2].Color)

	timer.Simple(0.1,function() -- Fixes weird clientside sync issue caused by immediately setting these variables when the entity is made
		for k,v in ipairs(ents.FindByClass("aas_point")) do
			local D = v.ExtraData
			v:SetPointName(D.PointName)
			v:SetTeamSpawn(D.TeamSpawn)
			v:SetIsSpawn(D.IsSpawn)
			v.ExtraData = nil
		end

		aliasPoints()

		for k,v in ipairs(ents.FindByClass("aas_point")) do
			if AAS.RAASFinished and (not GetGlobalBool("EditMode",false)) and not AAS.RAASLookup[v] then
				v:Remove()
			end
		end

		timer.Simple(0.5,function()
			AAS.Funcs.sendRAAS()
			AAS.Funcs.updateTeamData()

			--NavGen:Init()

			if GetGlobalBool("EditMode",false) == false then
				for k,v in ipairs(player.GetAll()) do
					v.FirstSpawn = true
					v:StripWeapons()
					v:StripAmmo()
					v:Spawn()
				end
			end
		end)
	end)

	if GetGlobalBool("EditMode",false) then
		aasMsg({Colors.ErrorCol,"The game has been loaded with EditMode enabled!"})
	end
end
AAS.Funcs.loadMap = loadMap

local function setupMap()
	local Map = string.lower(game.GetMap())
	MsgN("AAS: Attempting to load " .. Map .. "...")

	--game.CleanUpMap( false, { "env_fire", "entityflame", "_firesmoke" } )

	AAS.RAASFinished = false
	SetGlobalBool("AAS.Voting",false)

	for k,v in ipairs(player.GetAll()) do
		if AAS.RoundCounter == 1 then v:SetNW2Int("KnownRound",0) end
		v:SetNW2Int("Karma",0)
		v:SetNW2Int("Requisition",0)
		v:SetNW2Int("UsedRequisition",0)
		v:SetNW2Bool("InSafezone",true)
		v:UnLock()
		v.DeathCountdown = nil
		v.PlayerLoadout = nil

		v.NextPay = ST()
	end

	if file.Exists("aas/maps/" .. Map .. ".txt","DATA") then
		local Data = util.JSONToTable(file.Read("aas/maps/" .. Map .. ".txt","DATA"))

		if Data == "" then MsgN("AAS: Missing data!") return end

		if not Data.properties.Alias[1].Name then
			print("Missing name for Team A")
			Data.properties.Alias[1].Name = "BLUFOR"
		end

		if not Data.properties.Alias[2].Name then
			print("Missing name for Team B")
			Data.properties.Alias[2].Name = "OPFOR"
		end

		if table.IsEmpty(Data.points) then
			MsgN("Missing points! Setting to edit mode...")
			haltMap()
			return
		elseif table.IsEmpty(Data.spawns) then
			MsgN("Missing spawns! Setting to edit mode...")
			haltMap()
			return
		end

		AAS.Funcs.loadMap(Data)
	else
		MsgN("No Data, setting to edit mode...")
		AAS.CurrentProperties = table.Copy(AAS.DefaultProperties)
		AAS.Funcs.SetEditMode(true)
	end
end
AAS.Funcs.setupMap = setupMap

local function saveMap()
	local Map = string.lower(game.GetMap())
	local Data = {}

	Data["spawns"] = {}
	Data["points"] = {}
	Data["props"] = {}
	if not AAS.CurrentProperties then AAS.CurrentProperties = table.Copy(AAS.DefaultProperties) end
	Data["properties"] = table.Copy(AAS.CurrentProperties)

	local Spawns = ents.FindByClass("aas_spawnpoint")
	local Points = ents.FindByClass("aas_point")

	local Props = ents.FindByClass("aas_prop")

	for k,v in ipairs(Spawns) do
		local Pos = v:GetPos()
		local Ang = v:GetAngles()
		Data["spawns"][#Data["spawns"] + 1] = {
			pos = Vector(math.Round(Pos.x),math.Round(Pos.y),math.Round(Pos.z)),
			ang = Angle(0,math.Round(Ang.y),0)
		}
	end

	for k,v in ipairs(Points) do
		local Pos = v:GetPos()
		local Ang = v:GetAngles()
		local NWVars = v:GetNetworkVars()
		local Index = #Data["points"]
		Data["points"][Index + 1] = {
			pos = Vector(math.Round(Pos.x),math.Round(Pos.y),math.Round(Pos.z)),
			ang = Angle(0,math.Round(Ang.y),0)
		}
		for k2,v2 in ipairs(PointValues) do
			Data["points"][Index + 1][v2] = NWVars[v2]
		end
	end

	if #Props then
		for k,v in ipairs(Props) do
			local Pos = v:GetPos()
			local Ang = v:GetAngles()
			local Mdl = v:GetModel()

			Data["props"][#Data["props"] + 1] = {
				pos = Pos,
				ang = Ang,
				mdl = Mdl
			}
		end
	end

	if AAS.ManualLink then
		print("We got a manual link!")
		Data["manual"] = AAS.ManualLink
	end

	MsgN("Saving to " .. Map .. "...")
	PrintTable(Data)
	local File = util.TableToJSON(Data)
	file.Write("aas/maps/" .. Map .. ".txt",File)
end
AAS.Funcs.saveMap = saveMap

function GM:InitPostEntity()
	AAS.Funcs.setupMap()
end