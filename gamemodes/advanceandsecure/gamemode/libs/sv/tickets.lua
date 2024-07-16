MsgN("+ Tickets loaded")

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

function DoTicketChange(Team,Amount,Check)
	if GetGlobalBool("EditMode",false) == true then return end
	local Old = AAS.TeamData[Team].Tickets
	AAS.TeamData[Team].Tickets = math.max(Old + Amount,0)

	AAS.Funcs.updateTeamData()
	if Check then CheckWin() end
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

			AAS.Funcs.openVotes()
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

			AAS.Funcs.setupMap()
		end
	end
end

function SetTeamScore(Score)
	AAS.RoundCounter = AAS.RoundCounter + (Score ~= 0 and 1 or 0)
	if Score == 1 then AAS.TeamWins[1] = AAS.TeamWins[1] + 1 elseif Score == -1 then AAS.TeamWins[2] = AAS.TeamWins[2] + 1 end
end