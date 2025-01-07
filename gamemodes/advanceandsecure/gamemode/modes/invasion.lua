-- Invasion
--[[
	Essentially RAAS but defender starts with all of the points captured
	As points are captured, they become locked and can not be recaptured

	Defenders start with a high ticket count which is not replenishable
	Attackers start with a low ticket count which replenishes with each point captured

	Tickets are only deducted on player death
	Potentially free loadouts, and *only* provide a certain amount of requisition?
	Defenders get a sizeable amount to start with, but thats it. No more afterwards
	Attackers start with a small amount, and get extra with points captured?
]]

local GMT = {}
AAS.Funcs.DefineGamemode("invasion", GMT)
GMT.Name	= "Invasion"
GMT.Desc	= "Attackers versus defenders"

GMT.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate
	AAS.Funcs.UpdateState()
end

GMT.Load	= function(MapData) -- Assemble the map here, like placing points/spawns

end

GMT.Save	= function(MapData) -- Return false to abort saving for any reason

	return true
end

GMT.TicketThink	= function() -- Called when the server is doing ticket changes
	local TeamACaps = 0
	local TeamBCaps = 0
	local Points = ents.FindByClass("aas_point")
	local TotalPoints = #Points - 2 -- There are always atleast 2 points due to team spawns technically being points

	if TotalPoints == 0 then AAS.Funcs.Stop() MsgN("[AAS] Halting game due to no capturable points being available.") end

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