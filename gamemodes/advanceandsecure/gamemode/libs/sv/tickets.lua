MsgN("+ Tickets loaded")

AAS.Funcs.FlipTeams	= function()
	aasMsg({Colors.BasicCol,"Switching the teams!"})

	for _,v in player.Iterator() do
		v:SetTeam((v:Team() == 1) and 2 or 1)
	end
end

AAS.Funcs.ScrambleTeams	= function()
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

AAS.Funcs.UpdateTickets		= function()
	net.Start("AAS.UpdateTickets")
		net.WriteUInt(AAS.State.Team["BLUFOR"].Tickets, 11)
		net.WriteUInt(AAS.State.Team["OPFOR"].Tickets, 11)
	net.Broadcast()
end

AAS.Funcs.DoTicketChange	= function(Team,Amount,Check)
	if GetGlobalBool("EditMode",false) == true then return end

	local Old = AAS.Funcs.GetTeamInfo(Team).Tickets

	AAS.State.Team[Team == 1 and "BLUFOR" or "OPFOR"].Tickets = math.max(Old + Amount, 0)

	AAS.Funcs.UpdateTickets()

	if Check then AAS.GM.CheckWin() end
end

AAS.Funcs.SetTeamScore	= function(Score)
	AAS.Funcs.FlushXPList()

	AAS.RoundCounter = AAS.RoundCounter + (Score ~= 0 and 1 or 0)
	if Score > 0 then team.AddScore(1,1) elseif Score < 0 then team.AddScore(2,1) end
end