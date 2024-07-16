MsgN("+ Util loaded")

function GM:CreateTeams()
	team.SetUp(1,"A",AAS.TeamData[1]["Color"],true)
	team.SetUp(2,"B",AAS.TeamData[2]["Color"],true)

	-- Won't actually be used as intended
	team.SetSpawnPoint("A","aas_spawnpoint")
	team.SetSpawnPoint("B","aas_spawnpoint")
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
	if not Lookup then if CLIENT then net.Start("AAS.PlayerInit") net.SendToServer() end return false end
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
	if not Line or not Lookup then if CLIENT then net.Start("AAS.PlayerInit") net.SendToServer() end return false end

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
	if not AAS.PointAlias then if CLIENT then net.Start("AAS.PlayerInit") net.SendToServer() end return false end
	local SpawnA = AAS.PointAlias["SpawnA"]:GetPos()
	local SpawnB = AAS.PointAlias["SpawnB"]:GetPos()

	if Pos:WithinAABox(SpawnA + AAS.SpawnBoundA,SpawnA + AAS.SpawnBoundB) then return true
	elseif Pos:WithinAABox(SpawnB + AAS.SpawnBoundA,SpawnB + AAS.SpawnBoundB) then return true end

	return false
end

function PlyInSafezone(Ply,Pos)
	if not IsValid(Ply) then return false end
	if not AAS.PointAlias then if CLIENT then net.Start("AAS.PlayerInit") net.SendToServer() end return false end
	local Team = Ply:Team()
	local Spawn = AAS.PointAlias[Team == 1 and "SpawnA" or "SpawnB"]
	local SpawnPos = Vector()
	if IsValid(Spawn) then SpawnPos = Spawn:GetPos() else return false end

	local OBMin,OBMax = Ply:OBBMins(),Ply:OBBMaxs()
	if Pos:WithinAABox(SpawnPos + AAS.SpawnBoundA - OBMin,SpawnPos + AAS.SpawnBoundB - OBMax) then return true else return false end
end

function PlyInEnemySafezone(Ply,Pos)
	if not IsValid(Ply) then return false end
	if not AAS.PointAlias then if CLIENT then net.Start("AAS.PlayerInit") net.SendToServer() end return false end
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

hook.Add("ACF_PreBeginScanning", "ScanHalt", function() return false, "Disabled by gamemode." end)