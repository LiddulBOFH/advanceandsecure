AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("entities/aas_spawnpoint.lua")
include("shared.lua")

local ST = SysTime

-- Serverside
util.AddNetworkString("aas_msg")
util.AddNetworkString("aas_raasline")
util.AddNetworkString("aas_send_updateproperties")
util.AddNetworkString("aas_pointstatechange")
util.AddNetworkString("aas_UpdateTeamData")
util.AddNetworkString("aas_opensettings")
util.AddNetworkString("aas_openloadout")
util.AddNetworkString("aas_openvotes")

util.AddNetworkString("aas_requestcostscript")

util.AddNetworkString("aas_requestdupes")
util.AddNetworkString("aas_choosedupe")

-- Clientside
util.AddNetworkString("aas_requestteam")
util.AddNetworkString("aas_playerinit")
util.AddNetworkString("aas_edit_updateproperties")
util.AddNetworkString("aas_UpdateServerSettings")
util.AddNetworkString("aas_receiveplayerloadout")
util.AddNetworkString("aas_receivevote")

util.AddNetworkString("aas_createE2")
util.AddNetworkString("aas_notifycost")

util.AddNetworkString("aas_dupelist")
util.AddNetworkString("aas_receivedupe")
util.AddNetworkString("aas_ReceiveFile")

AAS.RAASFinished = false
AAS.RoundCounter = 1
AAS.TeamWins = {0,0}
AAS.Halt = false
AAS.Voting = false
AAS.RTV = false
AAS.RAASLookup = {}
AAS.Funcs = {}

-- Only filled during voting
local PreMapList = {}

local PointValues = {"PointName","IsSpawn","TeamSpawn"}

function aasMsg(msg,ply)
	net.Start("aas_msg")
		net.WriteTable(msg)
	if ply == nil then net.Broadcast() else net.Send(ply) end
end

function aas_PointStateChange(point,oldstatus,newstatus)
	net.Start("aas_pointstatechange")
		net.WriteEntity(point)
		net.WriteInt(oldstatus,3)
		net.WriteInt(newstatus,3)
	net.Broadcast()
end

local function aas_UpdateTeamData(ply)
	net.Start("aas_UpdateTeamData")
		net.WriteTable(AAS.TeamData)
	if ply == nil then net.Broadcast() else net.Send(ply) end
end

function aas_SetEditMode(bool)
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

local function sendRAAS(ply) -- pass nil to broadcast
	if not AAS.RAASFinished then return end
	net.Start("aas_raasline")
		net.WriteTable(AAS.RAASLine)
		net.WriteTable(AAS.PointAlias)
	if ply == nil then net.Broadcast() MsgN("AAS: Broadcasting points!") else net.Send(ply) MsgN("AAS: Sending points to " .. ply:Nick()) end
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
	--PrintTable(Line1)

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
			sendRAAS()
			aas_UpdateTeamData()

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

local function haltMap()
	aas_SetEditMode(true)
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
		Data = util.JSONToTable(file.Read("aas/maps/" .. Map .. ".txt","DATA"))

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

		loadMap(Data)
	else
		MsgN("No Data, setting to edit mode...")
		AAS.CurrentProperties = table.Copy(AAS.DefaultProperties)
		aas_SetEditMode(true)
	end
end

AAS.Funcs.setupMap = setupMap

-- Initialize

function GM:Initialize()
	GAMEMODE.ACFLoaded = false
	GAMEMODE.EditMode = GAMEMODE.EditMode or false
	if ACF then
		GAMEMODE.ACFLoaded = true
	else print("ACF is not loaded, what are you even playing this for?") end

	if not CPPI then error("No CPPI-compliant prop protection loaded, this is required!") end

	MsgN("--== ACF Advance and Secure v0.5 ==--")

	if not file.Exists("aas","DATA") then
		MsgN("Missing base directory 'aas', making...")
		file.CreateDir("aas/maps")
	end

	aas_SetEditMode(GAMEMODE.EditMode)
end

function GM:InitPostEntity()
	setupMap()
end

local maleDeath = {
	[1] = "vo/npc/male01/pain09.wav",
	[2] = "vo/npc/male01/pain08.wav",
	[3] = "vo/npc/male01/pain07.wav",
	[4] = "vo/npc/male01/no02.wav",
	[5] = "vo/npc/male01/hacks01.wav",
	[6] = "vo/npc/male01/vanswer14.wav",
	[7] = "vo/npc/male01/vanswer13.wav",
	[8] = "vo/npc/male01/startle02.wav",
	[9] = "vo/npc/male01/answer36.wav",
	[10] = "vo/npc/male01/answer04.wav"
}
local femaleDeath = {
	[1] = "vo/npc/female01/hacks02.wav",
	[2] = "vo/npc/female01/hacks01.wav",
	[3] = "vo/npc/female01/ow01.wav",
	[4] = "vo/npc/female01/ow02.wav",
	[5] = "vo/npc/female01/pain09.wav",
	[6] = "vo/npc/female01/pain08.wav",
	[7] = "vo/npc/female01/pain05.wav",
	[8] = "vo/npc/female01/startle01.wav",
	[9] = "vo/npc/female01/startle02.wav",
	[10] = "vo/npc/female01/vanswer14.wav",
	[11] = "vo/npc/female01/vanswer13.wav",
	[12] = "vo/npc/female01/no01.wav",
}

function GM:PlayerDeathSound(ply)
	local mdl = ply:GetModel()
	local IsMale = not string.find(mdl,"female")
	ply:EmitSound(IsMale and maleDeath[math.random(#maleDeath)] or femaleDeath[math.random(#femaleDeath)],SNDLVL_NORM,100)

	return true
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

		AdjustKarma(attacker,-25)
		aasMsg({Colors.BadCol,"You just teamkilled " .. victim:Nick() .. "!"},attacker)

		if victim:IsPlayer() then victim:SetNW2Float("NextSpawn",CurTime() + 1) end -- pity respawn timer for the player that got teamkilled
	end
end

local NextReqCheck = ST()

AAS.PlyReq = {}
AAS.RequisitionCosts = {}

AAS.RequisitionCosts.CalcSingleFilter = {
	gmod_wire_expression2 = 2.5,
	starfall_processor = 2.5,
	acf_piledriver = 5,
	acf_rack = 10,
	acf_engine = 1,
	prop_physics = 1,
	acf_armor = 1,
	acf_gun = 1,
	acf_ammo = 1,
	acf_radar = 10,
	gmod_wire_gate = 1,
	primitive_shape = 1
}

local FilterList = {}
for k,v in pairs(AAS.RequisitionCosts.CalcSingleFilter) do
	table.insert(FilterList,k)
end

AAS.RequisitionCosts.ACFGunCost = { -- anything not on here costs 1
	SB = 1, -- old smoothbores, leaving
	C = 0.9,
	SC = 0.7,
	AC = 1.2,
	LAC = 1.1,
	HW = 0.75,
	MO = 0.75,
	RAC = 2,
	SA = 1,
	AL = 1.1,
	GL = 0.75,
	MG = 0.1,
	SL = 0.02,
	FGL = 0.125
}

AAS.RequisitionCosts.ACFAmmoModifier = { -- Anything not in here is 0.2
	AP = 0.3,
	APCR = 0.4,
	APDS = 0.55,
	APFSDS = 0.7,
	APHE = 0.3,
	HE = 0.25,
	HEAT = 0.35,
	HEATFS = 0.45,
	FL = 0.25,
	HP = 0.1,
	SM = 0.1,
	GLATGM = 1.5,
	FLR = 0.05,
}

AAS.RequisitionCosts.ACFMissileModifier = { -- Default 5
	ATGM = 6,
	AAM = 5,
	ARM = 2.5,
	ARTY = 5,
	BOMB = 5, -- Dumb bomb
	FFAR = 2,
	GBOMB = 5, -- Glide bomb
	GBU = 7.5, -- Guided bomb
	SAM = 2.5,
	UAR = 4,
}

AAS.RequisitionCosts.SpecialModelFilter = { -- any missile rack not in here costs 10 points
	["models/failz/b8.mdl"] = 20,
	["models/failz/lau_61.mdl"] = 15,
	["models/failz/ub_16.mdl"] = 15,
	["models/failz/ub_32.mdl"] = 20,
	["models/ghosteh/lau10.mdl"] = 15,

	["models/missiles/rk3uar.mdl"] = 15,

	["models/spg9/spg9.mdl"] = 7.5,

	["models/kali/weapons/kornet/parts/9m133 kornet tube.mdl"] = 15,
	["models/missiles/9m120_rk1.mdl"] = 15,
	["models/missiles/at3rs.mdl"] = 10,
	["models/missiles/at3rk.mdl"] = 10,

	-- BIG rack, can hold lots of boom
	["models/missiles/6pod_rk.mdl"] = 25,

	-- YUGE fuckin tube, launches a 380mm rocket
	["models/launcher/rw61.mdl"] = 35,

	["models/missiles/agm_114_2xrk.mdl"] = 15,
	["models/missiles/agm_114_4xrk.mdl"] = 20,

	["models/missiles/launcher7_40mm.mdl"] = 12,
	["models/missiles/launcher7_70mm.mdl"] = 16,

	["models/missiles/bgm_71e_round.mdl"] = 15,
	["models/missiles/bgm_71e_2xrk.mdl"] = 17.5,
	["models/missiles/bgm_71e_4xrk.mdl"] = 20,

	["models/missiles/fim_92_1xrk.mdl"] = 7.5,
	["models/missiles/fim_92_2xrk.mdl"] = 10,
	["models/missiles/fim_92_4xrk.mdl"] = 15,

	["models/missiles/9m31_rk1.mdl"] = 10,
	["models/missiles/9m31_rk2.mdl"] = 15,
	["models/missiles/9m31_rk4.mdl"] = 20,

	["models/missiles/bomb_3xrk.mdl"] = 20,

	["models/missiles/rkx1_sml.mdl"] = 10,
	["models/missiles/rkx1.mdl"] = 10,
	["models/missiles/rack_double.mdl"] = 15,
	["models/missiles/rack_quad.mdl"] = 20
}

local DupeList = nil
local function BuildDupeList()
	local Dupes,_ = file.Find(engine.ActiveGamemode() .. "/distributables/advdupe2/*.txt","LUA")

	DupeList = {}

	for k,v in pairs(Dupes) do
		local FileSize = file.Size(engine.ActiveGamemode() .. "/distributables/advdupe2/" .. v,"LUA")
		DupeList[string.StripExtension(v)] = {txt = v,size = FileSize,strsize = math.Round(FileSize / 1024,2) .. "kB"}
	end
end
BuildDupeList()

local FileQueue = {}
local function SendChunk(ply)
	if not FileQueue[ply] then print("No file queued for player") return end
	local PlyFile = FileQueue[ply]

	PlyFile.OpenFile = file.Open(engine.ActiveGamemode() .. "/distributables/advdupe2/" .. PlyFile.file .. ".txt","rb","LUA")

	local ReadData = PlyFile.OpenFile:Read(PlyFile.OpenFile:Size())
	local _,dupe,_,_ = AdvDupe2.Decode(ReadData)

	net.Start("aas_receivedupe")
		net.WriteString(PlyFile.file)
	net.Send(ply)

	net.Start("AdvDupe2_SetDupeInfo")
		net.WriteString(PlyFile.file)
		net.WriteString(ply:Nick())
		net.WriteString(os.date("%d %B %Y"))
		net.WriteString(os.date("%I:%M %p"))
		net.WriteString("")
		net.WriteString("Public dupe saved from AAS Gamemode.")
		net.WriteString(table.Count(dupe.Entities))
		net.WriteString(#dupe.Constraints)
	net.Send(ply)

	dupe.Description = "Public dupe saved from AAS Gamemode."

	AdvDupe2.Encode(dupe,AdvDupe2.GenerateDupeStamp(ply),function(data)
		if not IsValid(ply) then return end
		ply.AdvDupe2.Downloading = true

		net.Start("aas_ReceiveFile")
			net.WriteStream(data, function()
				ply.AdvDupe2.Downloading = false
			end)
		net.Send(ply)
	end)
end

-- This adjusts how much requisition the player gets per interval
function AdjustKarma(Ply,Amount)
	if not Ply:IsPlayer() then return end
	local OldKarma = Ply:GetNW2Int("Karma",0)
	Ply:SetNW2Int("Karma",math.Clamp(OldKarma + Amount,-100,100))
end

-- Anything can be passed to Change
-- If it is POSITIVE it is a charge
-- If it is NEGATIVE it is a gain
-- Reason is optional, it'll change the message to display it
function ChargeRequisition(Ply,Change,Reason)
	local Current = Ply:GetNW2Int("Requisition",0)
	Change = math.Round(Change)
	if Change > 0 then -- Deduct
		if Change > Current then return false, "Overdrawn" end
		Ply:SetNW2Int("Requisition",Current - Change)
	else
		Ply:SetNW2Int("Requisition",math.min(Current + math.abs(Change),AAS.CurrentProperties["MaxRequisition"]))
	end
	local Diff = Ply:GetNW2Int("Requisition",0) - Current

	if Diff == 0 then
		return true
	end

	local msg = {Colors.BasicCol}
	if Diff > 0 then
		table.Add(msg,{"You received ",Colors.GoodCol,tostring(math.abs(Diff))})
	elseif Diff < 0 then
		table.Add(msg,{"You were charged ",Colors.BadCol,tostring(math.abs(Diff))})
	end
	table.insert(msg,Colors.BasicCol)
	if Reason then table.insert(msg," points for: " .. Reason .. ". Current amount: ") else table.insert(msg," points. Current amount: ") end
	table.Add(msg,{Colors.GoodCol,tostring(Ply:GetNW2Int("Requisition",0)),Colors.BasicCol,"."})

	aasMsg(msg,Ply)

	return true
end

local function Payday(ply) -- gives targetted player (or all players if nil is given) a regular income of requisition
	if not AAS.CurrentProperties then return end
	local MaxGain = AAS.CurrentProperties["RequisitionGain"]
	local Time = ST()

	if ply == nil then
		for k,v in ipairs(player.GetAll()) do
			if v.NextPay and (v.NextPay > Time) then continue end
			local Gain = math.Round(math.Clamp((MaxGain / 2) + ((v:GetNW2Int("Karma",0) / 100) * (MaxGain / 2)),0,MaxGain))
			ChargeRequisition(v,-Gain)

			v.NextPay = Time + 60
		end
	else
		if ply.NextPay and (ply.NextPay > Time) then return end
		local Gain = math.Round(math.Clamp((MaxGain / 2) + ((ply:GetNW2Int("Karma",0) / 100) * (MaxGain / 2)),0,MaxGain))
		ChargeRequisition(ply,-Gain)

		ply.NextPay = Time + 60
	end
end

local function CalcCost(E)
	local Class = E:GetClass()
	if not AAS.RequisitionCosts.CalcSingleFilter[Class] then return 0 end
	local Cost = AAS.RequisitionCosts.CalcSingleFilter[Class] or 1

	if Class == "acf_gun" then
		Cost = (AAS.RequisitionCosts.ACFGunCost[E.Class] or 1) * E.Caliber
	elseif Class == "acf_armor" or Class == "prop_physics" or Class == "primitive_shape" or Class == "gmod_wire_gate" then
		local phys = E:GetPhysicsObject()
		if IsValid(phys) then Cost = 0.1 + math.max(0.01,phys:GetMass() / 500) else Cost = 1 end
	elseif Class == "acf_engine" then
		Cost = math.max(5,E.PeakTorque / 100)
	elseif Class == "acf_rack" then
		if AAS.RequisitionCosts.SpecialModelFilter[E:GetModel()] then Cost = AAS.RequisitionCosts.SpecialModelFilter[E:GetModel()] else Cost = 10 end
	elseif Class == "acf_radar" then
		Cost = math.max(10,0)
	elseif Class == "acf_ammo" then
		if E.AmmoType == "Refill" then
			Cost = E.Capacity * 0.05
		elseif E.IsMissileAmmo then -- Only present on crates that actually hold ACF-3 Missiles ammo, courtesy of a hook intercept in ACF-3 Missiles
			Cost = E.Capacity * (AAS.RequisitionCosts.ACFAmmoModifier[E.AmmoType] or 0.2) * (AAS.RequisitionCosts.ACFMissileModifier[E.Class] or 10) * math.max(1,(E.Caliber / 100) ^ 1.5)
		else
			Cost = E.Capacity * (AAS.RequisitionCosts.ACFAmmoModifier[E.AmmoType] or 0.2) * ((E.Caliber / 100) ^ 2) * (AAS.RequisitionCosts.ACFGunCost[E.Class] or 1)
		end
	end

	return Cost
end

function CalcRequisition()
	if ST() < NextReqCheck then return end
	local Ents = {}
	local EntLookup = {}
	local PlyEnts = {}

	local PreFilterEnts = {}
	for _,class in ipairs(FilterList) do
		local TempEnts = ents.FindByClass(class)
		table.Add(PreFilterEnts,TempEnts)
	end

	local World = game.GetWorld()
	for _,ent in ipairs(PreFilterEnts) do
		if ent:IsPlayerHolding() then continue end
		if (ent:GetCreationTime() + 10.1) > CurTime() then continue end
		local Owner = ent:CPPIGetOwner()
		if Owner == nil then continue end
		if (Owner ~= World) or false then
			table.insert(Ents,ent)
			EntLookup[ent] = Owner
			if not PlyEnts[Owner] then PlyEnts[Owner] = {} end
			table.insert(PlyEnts[Owner],ent)
		end
	end

	AAS.PlyReq = {}

	for _,ent in ipairs(Ents) do
		local Class = ent:GetClass()
		if not AAS.RequisitionCosts.CalcSingleFilter[Class] then continue end

		local Owner = ent:CPPIGetOwner()
		local Cost = CalcCost(ent)

		AAS.PlyReq[Owner] = (AAS.PlyReq[Owner] or 0) + Cost
	end

	for k,v in ipairs(player.GetAll()) do
		AAS.PlyReq[v] = math.ceil(AAS.PlyReq[v] or 0)
		v:SetNW2Int("UsedRequisition",AAS.PlyReq[v] or 0)
	end

	NextReqCheck = ST() + 1
end

function CalcSingleRequisition(Ents)
	local TotalCost = 0
	local CostBreakdown = {}
	local DupeCenter = nil
	local Highest = 0
	local EntCount = 0

	for _,ent in pairs(Ents) do
		local Class = ent:GetClass()
		if not AAS.RequisitionCosts.CalcSingleFilter[Class] then continue end
		local Cost = CalcCost(ent)

		if not CostBreakdown[ent:GetClass()] then CostBreakdown[ent:GetClass()] = 0 end

		CostBreakdown[ent:GetClass()] = CostBreakdown[ent:GetClass()] + Cost

		if not DupeCenter then
			DupeCenter = ent:GetPos()
			Highest = DupeCenter.z
		else
			DupeCenter = DupeCenter + ent:GetPos()
			if ent:GetPos().z > Highest then Highest = ent:GetPos().z end
		end

		EntCount = EntCount + 1

		TotalCost = TotalCost + Cost
	end

	TotalCost = math.ceil(TotalCost)
	DupeCenter = DupeCenter / EntCount

	return TotalCost,CostBreakdown,DupeCenter,Highest
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

local function FlipTeams()
	aasMsg({Colors.BasicCol,"Switching the teams!"})
	local PlyList = player.GetAll()

	for k,v in ipairs(PlyList) do
		v:SetTeam((v:Team() == 1) and 2 or 1)
	end
end

local function ScrambleTeams()
	aasMsg({Colors.BasicCol,"Scrambling the teams!"})

	local PlyList = player.GetAll()

	local Flip = math.random(0,1) == 1

	while not table.IsEmpty(PlyList) do
		local ind = math.random(1,#PlyList)
		local Ply = PlyList[ind]

		Ply:SetTeam(Flip and 1 or 2)
		Flip = not Flip

		table.remove(PlyList,ind)
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
			AdjustKarma(ply,-10) -- steeply punish the player for being in the enemy safezone
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

function SetTeamScore(Score)
	AAS.RoundCounter = AAS.RoundCounter + (Score ~= 0 and 1 or 0)
	if Score == 1 then AAS.TeamWins[1] = AAS.TeamWins[1] + 1 elseif Score == -1 then AAS.TeamWins[2] = AAS.TeamWins[2] + 1 end
end

local CurrentVoteList = {}
local VoteData = {}

local function FinishVote(Choice)
	if Choice <= 3 then
		if #CurrentVoteList == 0 then FinishVote(5) return end -- Just more insurance, if somehow we managed to get this vote here, we'll safely restart the map
		RunConsoleCommand("changelevel",CurrentVoteList[math.min(Choice,#CurrentVoteList)])
	elseif Choice == 4 then
		aasMsg({Colors.BasicCol,"Refreshing the vote, old choices are no longer available!"})
		OpenVotes()
	elseif Choice == 5 then
		ScrambleTeams()
		deepReset()
		setupMap()
	end
end

local function CountVotes()
	AAS.Voting = false
	SetGlobalBool("AAS.Voting",AAS.Voting)

	print("Counting votes!")
	local Count = {}

	if table.Count(VoteData) == 0 then
		if #CurrentVoteList == 0 then
			FinishVote(5) -- just refresh the map, dunno how we got here
		else
			FinishVote(math.random(1,3))
			return
		end
	end

	for k,v in pairs(VoteData) do
		Count[v] = (Count[v] or 0) + 1
	end

	local Highest = Count[table.GetWinningKey(Count)]
	local Ties = table.KeysFromValue(Count, Highest)

	FinishVote(Ties[math.random(1,#Ties)])
end

local function UpdateVotes()
	local Counts = {}
	for k,v in pairs(VoteData) do
		Counts[tostring(v)] = (Counts[tostring(v)] or 0) + 1
	end

	for i = 1,5,1 do
		SetGlobalInt("vote_" .. i,0)
	end

	for k,v in pairs(Counts) do
		SetGlobalInt("vote_" .. k,v or 0)
	end
end

local Maps = {}
function OpenVotes()
	if table.IsEmpty(PreMapList) then
		PreMapList = file.Find("aas/maps/*.txt","DATA")

		for k,v in ipairs(PreMapList) do
			local str = string.StripExtension(v)
			if str == game.GetMap() then continue end
			Maps[k] = str
		end

		if #Maps == 0 then FinishVote(5) return end
	end

	local Choices = {}

	print(math.min(#Maps,3))
	for i = 1,math.min(#Maps,3),1 do
		local Pick = math.random(1,#Maps)
		Choices[i] = Maps[Pick]
		table.remove(Maps,Pick)
	end

	AAS.Voting = true
	SetGlobalBool("AAS.Voting",AAS.Voting)

	AAS.RTV = (#Maps > 0)
	print(AAS.RTV)

	local CheckTime = 30

	CurrentVoteList = table.Copy(Choices)

	print("================= MAPS")
	PrintTable(Maps)
	print("================= CHOICES")
	PrintTable(Choices)

	net.Start("aas_openvotes")
		net.WriteFloat(ST() + CheckTime)
		net.WriteBool(AAS.RTV)
		net.WriteTable(Choices)
	net.Broadcast()

	VoteData = {}

	UpdateVotes()

	timer.Simple(CheckTime,CountVotes)
end

function CheckWin()
	local TixA = AAS.TeamData[1].Tickets
	local TixB = AAS.TeamData[2].Tickets
	local Reset = false

	if (TixA == 0) and (TixB == 0) then -- tie, somehow
		Reset = true

		aasMsg({Colors.BasicCol,"It's a tie!"})
	elseif TixA == 0 then -- team A loses
		Reset = true

		SetTeamScore(-1)

		if AAS.TeamWins[2] >= 2 then aasMsg({AAS.TeamData[2].Color,AAS.TeamData[2].Name,Colors.BasicCol," wins the round!"}) else aasMsg({AAS.TeamData[2].Color,AAS.TeamData[2].Name,Colors.BasicCol," wins the match!"}) end
	elseif TixB == 0 then -- team B loses
		Reset = true

		SetTeamScore(1)

		if AAS.TeamWins[1] >= 2 then aasMsg({AAS.TeamData[1].Color,AAS.TeamData[1].Name,Colors.BasicCol," wins the round!"}) else aasMsg({AAS.TeamData[1].Color,AAS.TeamData[1].Name,Colors.BasicCol," wins the match!"}) end
	end

	if Reset then
		if (AAS.TeamWins[1] >= 2) or (AAS.TeamWins[2] >= 2) then -- greater than just incase it somehow skips??
			-- Do voting here
			AAS.Halt = true -- Halts any other game functions as they are not needed anymore

			local players = player.GetAll()
			local SpawnA,SpawnB = AAS.PointAlias["SpawnA"], AAS.PointAlias["SpawnB"]
			local Dir = (SpawnB:GetPos() - SpawnA:GetPos()):GetNormalized()
			for _,v in ipairs(players) do
				local pTeam = v:Team()
				local Base = (pTeam == 1) and SpawnA or SpawnB
				v:Spectate(OBS_MODE_ROAMING)
				v:SetPos(Base:GetPos() + Vector(0,0,2048))
				v:SetEyeAngles((Dir * (pTeam == 1 and 1 or -1)):Angle())
				v:Lock()
				v:StripWeapons()
			end

			OpenVotes()
		else
			if AAS.RoundCounter == 2 then FlipTeams() elseif AAS.RoundCounter > 2 then ScrambleTeams() end

			for k,v in ipairs(player.GetAll()) do
				v.FirstSpawn = true

				v:SetFrags(0)
				v:SetDeaths(0)
				v:StripWeapons()
				v:StripAmmo()
				v:Spawn()
			end

			setupMap()
		end
	end
end

function DoTicketChange(Team,Amount,Check)
	if GetGlobalBool("EditMode",false) == true then return end
	local Old = AAS.TeamData[Team].Tickets
	AAS.TeamData[Team].Tickets = math.max(Old + Amount,0)

	aas_UpdateTeamData()
	if Check then CheckWin() end
end

-- Lodsa commands

do	-- Organizing stuff :)
	do	-- Hooks, arr

		-- Ugly mess, handles everything from payday to checking wins if point updates didn't catch it
		local NextLongThink = ST()
		local ShortThink = ST()
		local NextTicketThink = ST()
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
				CalcRequisition()
			end
		end)

		-- Replaces the player's default gmod loadout with whatever they want, if they can afford it, otherwise load the server default loadout
		hook.Add("PlayerLoadout","OverrideLoadout",function(ply)
			ply:ApplyLoadout()

			--ply:SetModel(ModelList[math.random(1,#ModelList)] or "models/Humans/Group03/male_02.mdl")
			ply:SetPlayerColor(AAS.TeamData[ply:Team()].Color:ToVector())

			if GetGlobalBool("EditMode",false) == true then -- give basic tooling to aid in map creation
				ply:Give("weapon_physgun")
				ply:Give("gmod_tool")
			end

			if ply:GetNW2Int("KnownRound",0) ~= AAS.RoundCounter then
				local msg = {Colors.BasicCol,"We're on round " .. AAS.RoundCounter .. "! "}

				local TeamAWins = AAS.TeamWins[1]
				local TeamBWins = AAS.TeamWins[2]

				if TeamAWins > 0 and TeamBWins == 0 then
					table.Add(msg,{AAS.TeamData[1].Color,AAS.TeamData[1].Name,Colors.BasicCol," just needs to win again!"})
				elseif TeamBWins > 0 and TeamAWins == 0 then
					table.Add(msg,{AAS.TeamData[2].Color,AAS.TeamData[2].Name,Colors.BasicCol," just needs to win again!"})
				elseif TeamAWins > 0 and TeamBWins > 0 then
					table.Add(msg,{"This should be a tie-breaker!"})
				end

				aasMsg(msg,ply)

				ply:SetNW2Int("KnownRound",AAS.RoundCounter)
			end

			return true
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
			if GetGlobalBool("EditMode",false) == true then return else return false end
			if PlyInSafezone(ply,ply:GetPos()) and InSafezone(ent:GetPos()) then return true end

			if ply:GetPos():DistToSqr(ent:GetPos()) < PhysDist then return true end
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

		-- This captures when a player spawns a dupe with Advanced Duplicator 2
		-- This will check the cost of the vehicle and notify the player of that cost, and have a 10 second timer before that cost is deducted from the player
		-- The player can remove it within those 10 seconds so the cost isn't deducted
		-- There are two random entities picked from the dupe that get checked for existing before cost is applied
		hook.Add("AdvDupe_FinishPasting","CheckDupe",function(Dupe) -- force the requisition calculator to run when a dupe is done pasting
			local DupeEnts = Dupe[1].CreatedEntities
			local Ply = Dupe[1].Player
			local Cost,Breakdown,DupeCenter,Highest = CalcSingleRequisition(DupeEnts)

			net.Start("aas_notifycost")
				net.WriteVector(DupeCenter)
				net.WriteTable(Breakdown)
				net.WriteUInt(Cost,16)
				net.WriteUInt(Highest,12)
			net.Send(Ply)

			CalcRequisition()
			if Cost > (AAS.CurrentProperties["MaxRequisition"] - Ply:GetNW2Int("UsedRequisition")) then
				aasMsg({Colors.ErrorCol,"Not enough total requisiton to spawn!"},Ply)
				if not GetGlobalBool("EditMode",false) then error("Not enough requisition!") end -- Doing this will instantly remove the pasted duplication
			else
				local CheckEnt = table.Random(DupeEnts)
				while not IsValid(CheckEnt) do
					CheckEnt = table.Random(DupeEnts)
				end
				local SecondCheckEnt = table.Random(DupeEnts)
				while (not IsValid(SecondCheckEnt)) and (SecondCheckEnt ~= CheckEnt) do
					SecondCheckEnt = table.Random(DupeEnts)
				end

				if GetGlobalBool("EditMode",false) == false then
					aasMsg({Colors.BasicCol,"After 10 seconds this will cost you ",Color(255,127,127),tostring(Cost),Colors.BasicCol," of your ",Colors.GoodCol,tostring(Ply:GetNW2Int("Requisition",0)),Colors.BasicCol," requisition."},Ply)

					timer.Simple(10,function()
						if not (IsValid(CheckEnt) or IsValid(SecondCheckEnt)) then return end

						print("Charging " .. Ply:Nick() .. " for " .. Cost)

						local CanAfford = ChargeRequisition(Dupe[1].Player,Cost,"Cost of dupe")

						if not CanAfford then
							aasMsg({Colors.ErrorCol,"You can't afford this dupe!"},Ply)
							for k,v in pairs(Dupe[1].CreatedEntities) do
								v:Remove()
							end
						end
					end)
				end
			end
		end)
	end

	do	-- Net handling
		-- Sends the gamemode info to the client
		net.Receive("aas_playerinit",function(_,ply)
			if not AAS.RAASLine then print("No RAASLine defined to send to " .. tostring(ply) .. "!") return end
			for k,v in ipairs(AAS.RAASLine) do
				if not IsValid(v) then continue end
				v:SetForceUpdate(not v:GetForceUpdate())
			end
			sendRAAS(ply)

			ply.NextPay = ST()

			aas_UpdateTeamData(ply)
		end)

		-- Handles when a player wishes to change teams legitimately, and will block them if they aren't allowed (team misbalance, changing too often)
		net.Receive("aas_requestteam",function(_,ply)
			if ply.NextTeamSwitch and (ply.NextTeamSwitch >= ST()) then
				aasMsg({Colors.ErrorCol,"You can't switch teams for another " .. math.Round(ply.NextTeamSwitch - ST(),1) .. " seconds!"},ply)
				return
			end
			local CurTeam = ply:Team()
			local OppTeam = (CurTeam == 1) and 2 or 1

			if team.NumPlayers(CurTeam) <= team.NumPlayers(OppTeam) then
				aasMsg({AAS.TeamData[OppTeam].Color,AAS.TeamData[OppTeam].Name,Colors.BadCol," has too many players for you to join!"},ply)
				return
			end

			ply.FirstSpawn = true
			ply:SetTeam(OppTeam)

			aasMsg({Colors.BasicCol,ply:Nick() .. " switched to ",AAS.TeamData[ply:Team()].Color, AAS.TeamData[ply:Team()].Name,Colors.BasicCol,"."})

			ply:Spawn()
			ply.NextTeamSwitch = ST() + 30
		end)

		-- Handles any updates to the server settings, with a myriad of checks to block any unwanted changes
		net.Receive("aas_UpdateServerSettings",function(_,ply)
			local Settings = net.ReadTable()
			if ply == nil then print("how?") return end
			if not ply:IsSuperAdmin() then print(ply:Nick() .. " attempted to update server settings.") return end
			if not GetGlobalBool("EditMode",false) then print(ply:Nick() .. " attempted to update server settings.") return end

			print("BEFORE")
			PrintTable(AAS.CurrentProperties)
			AAS.CurrentProperties = Settings
			print("AFTER")
			PrintTable(AAS.CurrentProperties)

			aas_SetEditMode(false)
			saveMap()
			setupMap()
		end)

		-- Sends the client the generic cost calculator, which is then further updated using the current cost metrics
		net.Receive("aas_requestcostscript",function(_,ply)
			local Script = file.Read(engine.ActiveGamemode() .. "/distributables/expression2/aas_costcalc.txt","LUA")

			net.Start("aas_createE2")
				net.WriteString(Script)
				net.WriteTable(AAS.RequisitionCosts)
			net.Send(ply)
		end)

		-- Sends the client all of the dupes on the server
		net.Receive("aas_requestdupes",function(_,ply)
			if not DupeList then BuildDupeList() end

			net.Start("aas_dupelist")
				net.WriteTable(DupeList)
			net.Send(ply)
		end)

		-- Sends dupe info to the client when they want to download it
		net.Receive("aas_choosedupe",function(_,ply)
			local ChosenDupe = net.ReadString()
			if not DupeList[ChosenDupe] then aasMsg({Colors.ErrorCol,"Invalid dupe! Try again!"},ply) return end

			aasMsg({Colors.BasicCol,"Attempting to download " .. ChosenDupe .. "..."},ply)
			FileQueue[ply] = {file = ChosenDupe,state = "pending",step = 0,size = DupeList[ChosenDupe].size}

			SendChunk(ply)
		end)

		-- Receives vote info and updates clients about that, otherwise will send a rude message to anyone thats trying to circumvent it
		net.Receive("aas_receivevote",function(_,ply)
			if not AAS.Voting then aasMsg({Colors.ErrorCol,"Bugger off"},ply) return end
			local Choice = net.ReadUInt(3)

			VoteData[ply] = Choice

			UpdateVotes()
		end)
	end

	do	-- ConCommands
		concommand.Add("aas_editmode",function(ply,cmd,arg)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return end

			local Arg = tobool(arg[1]) or false
			aas_SetEditMode(Arg)
			if Arg == true then
				deepReset()
				setupMap() -- Completely resets the map, most importantly loads points if its RAAS
			end
		end)

		concommand.Add("aas_save",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return else saveMap() end
		end)

		concommand.Add("aas_load",function(ply)
			if not ((ply == NULL) or (ply:IsSuperAdmin())) then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return else deepReset() setupMap() end
		end)

		concommand.Add("aas_opensettings",function(ply)
			if ply == NULL then print("You can't run this from rcon!") return end
			if not ply:IsSuperAdmin() then aasMsg({Colors.ErrorCol,"You aren't allowed to run that command!"},ply) return end
			if GetGlobalBool("EditMode",false) == false then ply:PrintMessage(HUD_PRINTTALK,"The server is not in edit mode!") return end

			aas_UpdateTeamData(ply)

			timer.Simple(0,function()
				net.Start("aas_opensettings")
				net.WriteTable(AAS.CurrentProperties)
				net.Send(ply)
			end)

		end)
	end
end