-- Random Advance and Secure
--[[
	Requires Spawn A and Spawn B to be placed, and then a bunch of points can be randomly scattered
	This will attempt to connect Spawn A to Spawn B with randomly selected point
]]

local GMT = {}
AAS.Funcs.DefineGamemode("raas", GMT)
GMT.Name	= "Random Advance and Secure"
GMT.Desc	= "Randomized linear point capturing"

GMT.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate
	AAS.Funcs.UpdateState()
end

GMT.Load	= function(MapData) -- Assemble the map here, like placing points/spawns
	MsgN("========================== RAAS Start Generation")
	local SpawnA, SpawnB
	local AllPoints, PointList, InvPointList = {}, {}, {}

	local NumPoints = 0
	for point,alias in pairs(AAS.State.AliasLookup) do
		if point:GetIsSpawn() then
			if point:GetTeamSpawn() == 1 then SpawnA = point else SpawnB = point end
		else
			table.insert(AllPoints, point)
			NumPoints = NumPoints + 1
		end
	end

	PointList = table.Copy(AllPoints)
	InvPointList = table.Copy(AllPoints)

	local UsedList = {}
	for _, point in ipairs(AllPoints) do
		UsedList[point] = false
	end

	-- Sort the points closest to each spawn, can't simply invert the list because spawns are not always symmetrical on the map
	local SpawnAPos = SpawnA:GetPos()
	local SpawnBPos = SpawnB:GetPos()

	local Line = {}
	if NumPoints == 1 then -- Why even use RAAS; single point to capture
		Line = {SpawnA, PointList[1], SpawnB}
	else
		if NumPoints <= 3 then -- One point to randomly pick from; single point to capture
			Line = {SpawnA, PointList[math.random(#PointList)], SpawnB}
		else
			-- Sort the points by distance to each spawn
			table.sort(PointList, function(A, B)
				return A:GetPos():DistToSqr(SpawnAPos) < B:GetPos():DistToSqr(SpawnAPos)
			end)

			table.sort(InvPointList, function(A, B)
				return A:GetPos():DistToSqr(SpawnBPos) < B:GetPos():DistToSqr(SpawnBPos)
			end)

			if NumPoints <= 6 then -- Pick closest point to each spawn, then 1 random; 3 capturable points

				UsedList[PointList[1]] = true
				UsedList[InvPointList[1]] = true

				local RandList	= {}
				for point, used in pairs(UsedList) do
					if used == false then table.insert(RandList, point) end
				end

				local MidPoint = RandList[math.random(#RandList)]

				Line = {SpawnA, PointList[1], MidPoint, InvPointList[1], SpawnB} -- insert points between spawns
			else	-- 3 capturable points

				-- Pick midline point using center of the map as base and line made from perpendicular direction between spawns
				-- Divide both sides into two separate pools of points and sort by distance to center line between spawn and center, as well as weighted distance away from enemy spawn?

				local SpawnDir	= ((SpawnBPos - SpawnAPos) * Vector(1, 1, 0)):GetNormalized()
				local DirRight	= SpawnDir:Cross(vector_up)

				table.sort(AllPoints, function(A, B)
					local CompA = util.DistanceToLine(DirRight * -16384, DirRight * 16384, A:GetPos() * Vector(1, 1, 0))
					local CompB = util.DistanceToLine(DirRight * -16384, DirRight * 16384, B:GetPos() * Vector(1, 1, 0))

					return CompA < CompB
				end)

				local MidPoint	= AllPoints[math.Clamp(math.random(math.ceil(NumPoints / 5)), 1, 6)]

				UsedList[MidPoint]	= true

				for i = 1, math.max(math.ceil(NumPoints / 4), 1) do
					local point = AllPoints[i]
					UsedList[point] = true
				end

				SideA, SideB	= {}, {}

				for point, used in pairs(UsedList) do
					if used then continue end

					if SpawnDir:Dot((point:GetPos() * Vector(1, 1, 0)) - vector_origin) >= 0 then
						table.insert(SideB, point)
					else
						table.insert(SideA, point)
					end
				end

				local SpawnAMidpoint	= (SpawnAPos / 1.5) * Vector(1, 1, 0)
				local SpawnADir			= (SpawnAPos * Vector(1, 1, 0)):GetNormalized()
				local SpawnADirRight	= SpawnADir:Cross(vector_up)
				local LPA1, LPA2		= SpawnAMidpoint + SpawnADirRight * -16384, SpawnAMidpoint + SpawnADirRight * 16384
				table.sort(SideA, function(A, B)
					local AP, BP = A:GetPos(), B:GetPos()

					local ScoreA	= (-util.DistanceToLine(LPA1, LPA2, AP * Vector(1, 1, 0)) * 3) + AP:DistToSqr(MidPoint:GetPos()) + (AP:DistToSqr(SpawnAPos) / 4)
					local ScoreB	= (-util.DistanceToLine(LPA1, LPA2, BP * Vector(1, 1, 0)) * 3) + BP:DistToSqr(MidPoint:GetPos()) + (BP:DistToSqr(SpawnAPos) / 4)

					return ScoreA > ScoreB
				end)

				local SpawnBMidpoint	= (SpawnBPos / 1.5) * Vector(1, 1, 0)
				local SpawnBDir			= (SpawnBPos * Vector(1, 1, 0)):GetNormalized()
				local SpawnBDirRight	= SpawnBDir:Cross(vector_up)
				local LPB1, LPB2		= SpawnBMidpoint + SpawnBDirRight * -16384, SpawnBMidpoint + SpawnBDirRight * 16384
				table.sort(SideB, function(A, B)
					local AP, BP = A:GetPos(), B:GetPos()

					local ScoreA	= (-util.DistanceToLine(LPB1, LPB2, AP * Vector(1, 1, 0)) * 3) + AP:DistToSqr(MidPoint:GetPos()) + (AP:DistToSqr(SpawnBPos) / 4)
					local ScoreB	= (-util.DistanceToLine(LPB1, LPB2, BP * Vector(1, 1, 0)) * 3) + BP:DistToSqr(MidPoint:GetPos()) + (BP:DistToSqr(SpawnBPos) / 4)

					return ScoreA > ScoreB
				end)

				local PointA = SideA[math.random( math.max( math.ceil(#SideA / 2), 1) )]
				local PointB = SideB[math.random( math.max( math.ceil(#SideB / 2), 1) )]

				Line = {SpawnA, PointA, MidPoint, PointB, SpawnB}
				PrintTable(Line)
			end
		end
	end

	-- Put together everything for networking and whatnot
	AAS.State.Data["Line"] = {}

	for _, v in ipairs(Line) do
		table.insert(AAS.State.Data["Line"], v:GetPointName())
	end

	AAS.State.LineLookup = {}
	for k,v in ipairs(AAS.State.Data["Line"]) do
		AAS.State.LineLookup[AAS.State.Alias[v] ] = k
	end

	if GetGlobalBool("EditMode", false) == false then
		local SavedPoints = {}
		for _, point in ipairs(Line) do
			SavedPoints[point] = true
		end

		for _, point in ipairs(AllPoints) do
			if not SavedPoints[point] then point:Remove() end
		end
	end
end

GMT.Save	= function(MapData) -- Return false to abort saving for any reason

	return true
end

GMT.TicketThink	= function() -- Called when the server is doing ticket changes
	local TeamACaps = 0
	local TeamBCaps = 0
	local Points = ents.FindByClass("aas_point")
	local TotalPoints = #Points - 2 -- There are always atleast 2 points due to team spawns technically being points

	if TotalPoints == 0 then AAS.Funcs.Stop() aasMsg({Colors.ErrorCol,"[AAS] Halting game due to no capturable points being available."}) end

	for _, v in ipairs(Points) do
		if v:GetIsSpawn() then continue end

		local Capped = CapStatus(v)

		if Capped == 1 then TeamACaps = TeamACaps + 1 elseif Capped == 2 then TeamBCaps = TeamBCaps + 1 end
	end

	if TotalPoints == 1 then -- Singular point, so no need to check amount of captured points
		if TeamACaps > 0 then
			AAS.Funcs.DoTicketChange(2, -5, false)
		elseif TeamBCaps > 0 then
			AAS.Funcs.DoTicketChange(1, -5, false)
		end
	else
		if TotalPoints % 2 == 0 then -- Even number of points
			local MinCap	= math.floor(TotalPoints / 2)
			local Rate = 0

			if TeamACaps > MinCap then
				if TeamACaps == TotalPoints then
					Rate = 10
				else
					Rate = TeamACaps - MinCap
				end

				AAS.Funcs.DoTicketChange(2, -Rate, false)
			elseif TeamBCaps > MinCap then
				if TeamBCaps == TotalPoints then
					Rate = 10
				else
					Rate = TeamBCaps - MinCap
				end

				AAS.Funcs.DoTicketChange(1, -Rate, false)
			end
		else -- Odd number of points, middle point does not count for bleedout
			local MinCap	= math.floor(TotalPoints / 2)
			local Rate = 0

			if TeamACaps > MinCap then
				if TeamACaps == TotalPoints then
					Rate = 10
				else
					Rate = TeamACaps - MinCap
				end

				AAS.Funcs.DoTicketChange(2, -Rate, false)
			elseif TeamBCaps > MinCap then
				if TeamBCaps == TotalPoints then
					Rate = 10
				else
					Rate = TeamBCaps - MinCap
				end

				AAS.Funcs.DoTicketChange(1, -Rate, false)
			end
		end
	end

	AAS.GM.CheckWin()
end

GMT.ShortThink	= function() -- Called about every half second, keep it light

end

GMT.LongThink	= function() -- Called every 5 seconds

end