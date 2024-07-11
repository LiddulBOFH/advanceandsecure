AddCSLuaFile()
DeriveGamemode("sandbox")

GM.Name = "Advance and Secure"
GM.Author = "LiddulBOFH"
GM.Email = "No"
GM.Website = "Also no"

AAS = {}

-- Default alias, if not set
AAS.TeamData = {
	[1] = {
		Name    = "BLUFOR",
		Color   = Color(3, 94, 252),
		Tickets = 300,
		Seats   = {}
	},
	[2] = {
		Name    = "OPFOR",
		Color   = Color(255, 87, 87),
		Tickets = 300,
		Seats   = {}
	}
}

AAS.DefaultProperties = {
	MaxRequisition = 500,
	RequisitionGain = 50,
	NonLinear = false,
	ChangedAlias = false,
	Alias = {[1] = {Name = "BLUFOR",Color = Color(3, 94, 252)},[2] = {Name = "OPFOR",Color = Color(255, 87, 87)}},
	StartTickets = 500,
}

AAS.RAASFinished = false
AAS.NonLinear = false
AAS.SpawnBoundA = Vector(-1024,-1024,-256)
AAS.SpawnBoundB = Vector(1024,1024,512 + 256)
AAS.PointAlias = nil

AAS.CapRange = 256 ^ 2
AAS.CapInfoRange = 512 ^ 2

-- Dandy collection of commonly used colors
Colors = {
	ErrorCol = Color(255,0,0),
	BasicCol = Color(200,200,200),
	GoodCol = Color(65,255,65),
	BadCol = Color(255,65,65),
	White = Color(255,255,255),
	Black = Color(0,0,0)
}

include("libs/loadouts.lua")
include("libs/seatsystem.lua")

function GM:CreateTeams()
	team.SetUp(1,"A",AAS.TeamData[1]["Color"],true)
	team.SetUp(2,"B",AAS.TeamData[2]["Color"],true)

	-- Won't actually be used as intended
	team.SetSpawnPoint("A","aas_spawnpoint")
	team.SetSpawnPoint("B","aas_spawnpoint")
end

function CapStatus(Point)
	if not IsValid(Point) then return 0 end
	if not Point:GetCapture() then return 0 end
	local Cap = Point:GetCapture()
	if Cap < 25 and Cap > -25 then return 0
	elseif Cap >= 25 then return 1
	elseif Cap <= -25 then return 2 end
end

function checkVisible(Point,Team)
	if Point:GetIsSpawn() == true then return true end
	if Team == CapStatus(Point) then return true end
	return false
end

function isConnectedTo(PointA,PointB,Lookup,Team)
	if not Lookup then if CLIENT then net.Start("aas_playerinit") net.SendToServer() end return false end
	local IndexA = Lookup[PointA]
	local IndexB = Lookup[PointB]

	if not (((IndexA + 1) == IndexB) or ((IndexA - 1) == IndexB)) then
		return false
	else
		return (CapStatus(PointA) == Team) or (CapStatus(PointB) == Team)
	end
end

function checkConnection(Point,Line,Lookup,Team)
	if AAS.NonLinear then return true end
	if not Line or not Lookup then if CLIENT then net.Start("aas_playerinit") net.SendToServer() end return false end

	if checkVisible(Point,Team) then return true end

	if not Lookup[Point] then return false end
	local PointIndex = Lookup[Point]

	if (PointIndex + 1) <= #Line then
		local PointB = Line[PointIndex + 1]
		if isConnectedTo(Point,PointB,Lookup,Team) then return true end
	end

	if (PointIndex - 1) >= 1 then
		local PointB = Line[PointIndex - 1]
		if isConnectedTo(Point,PointB,Lookup,Team) then return true end
	end

	return false
end

function ClampVector(V1,V2,V3)
	return Vector(math.Clamp(V1.x,V2.x,V3.x),math.Clamp(V1.y,V2.y,V3.y),math.Clamp(V1.z,V2.z,V3.z))
end

function InSafezone(Pos)
	if not Pos then return true end -- Somehow Pos is nil, so we'll default to true?
	if not AAS.PointAlias then if CLIENT then net.Start("aas_playerinit") net.SendToServer() end return false end
	local SpawnA = AAS.PointAlias["SpawnA"]:GetPos()
	local SpawnB = AAS.PointAlias["SpawnB"]:GetPos()

	if Pos:WithinAABox(SpawnA + AAS.SpawnBoundA,SpawnA + AAS.SpawnBoundB) then return true
	elseif Pos:WithinAABox(SpawnB + AAS.SpawnBoundA,SpawnB + AAS.SpawnBoundB) then return true end

	return false
end

function PlyInSafezone(Ply,Pos)
	if not IsValid(Ply) then return false end
	if not AAS.PointAlias then if CLIENT then net.Start("aas_playerinit") net.SendToServer() end return false end
	local Team = Ply:Team()
	local Spawn = AAS.PointAlias[Team == 1 and "SpawnA" or "SpawnB"]
	local SpawnPos = Vector()
	if IsValid(Spawn) then SpawnPos = Spawn:GetPos() else return false end

	local OBMin,OBMax = Ply:OBBMins(),Ply:OBBMaxs()
	if Pos:WithinAABox(SpawnPos + AAS.SpawnBoundA - OBMin,SpawnPos + AAS.SpawnBoundB - OBMax) then return true else return false end
end

function PlyInEnemySafezone(Ply,Pos)
	if not IsValid(Ply) then return false end
	if not AAS.PointAlias then if CLIENT then net.Start("aas_playerinit") net.SendToServer() end return false end
	local Team = Ply:Team()
	local SpawnPos = Vector()
	local Spawn = AAS.PointAlias[Team == 2 and "SpawnA" or "SpawnB"]
	if IsValid(Spawn) then SpawnPos = Spawn:GetPos() else return false end

	if Pos:WithinAABox(SpawnPos + AAS.SpawnBoundA,SpawnPos + AAS.SpawnBoundB) then return true else return false end
end

hook.Add("PlayerTick","AAS_PlayerTick",function(ply,cmove)
	if GetGlobalBool("EditMode",false) == true then return end
	if ply:InVehicle() then return end
	if not IsValid(ply) then return end
	if ply:GetMoveType() ~= MOVETYPE_NOCLIP then return end

	if not PlyInSafezone(ply,cmove:GetOrigin() + (cmove:GetVelocity() * FrameTime())) then
		if not AAS.PointAlias then return end
		local Team = ply:Team()
		local Spawn = AAS.PointAlias[Team == 1 and "SpawnA" or "SpawnB"]
		local SpawnPos = Vector()
		if IsValid(Spawn) then
			SpawnPos = Spawn:GetPos()
		else return end

		local OBMin,OBMax = ply:OBBMins(),ply:OBBMaxs()
		cmove:SetOrigin(ClampVector(ply:GetPos() - (cmove:GetVelocity() * FrameTime()),SpawnPos + AAS.SpawnBoundA - OBMin,SpawnPos + AAS.SpawnBoundB - OBMax)) -- we keep the fly in the box
	end

	cmove:SetVelocity(Vector()) -- this doesn't affect noclip, but will stop the player's velocity when they leave noclip; that stops people from slingshotting out of the safezone
end)

hook.Add("PlayerNoClip","AAS_Noclip",function(ply,state)
	if state == false then return true end
	if GetGlobalBool("EditMode",false) == true then return true end

	if PlyInSafezone(ply,ply:GetPos()) then return true else return false end
end)
