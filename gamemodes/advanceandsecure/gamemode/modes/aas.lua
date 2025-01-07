-- Linear Advance and Secure
--[[
	Requires a manually set line from Spawn A to Spawn B

	Thats it. Enjoy.
]]

local GMT = {}
AAS.Funcs.DefineGamemode("aas", GMT)
GMT.Name	= "Advance and Secure"
GMT.Desc	= "Linear point capturing"

GMT.Init	= function(MapData)	-- Setup whatever is required for this gamemode to run. This is AFTER settings have been applied
	AAS.Funcs.UpdateState()
end

GMT.Load	= function(MapData) -- Assemble the map here, like placing points/spawns
	AAS.State.Data["Line"] = MapData.Data.Line
	AAS.State.LineLookup	= {}
	for k,v in ipairs(AAS.State.Data["Line"]) do
		AAS.State.LineLookup[AAS.State.Alias[v]] = k
	end
end

GMT.Save	= function(MapData) -- Return false to abort saving for any reason
	-- Save the links between points
	if AAS.Funcs.GetSetting("Non-linear", false) == false then
		if not AAS.State.Data["Line"] then ErrorNoHalt("No line defined") return false end
		MapData.Data.Line	= AAS.State.Data["Line"]

		return true
	end

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