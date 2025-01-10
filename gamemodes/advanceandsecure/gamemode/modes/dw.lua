--	Diesel wars
--[[
	Team deathmatch based gamemode, only ticket loss is from dying

	Resource nodes are around the map that, to be determined how, can spawn a resource package which must be transported back to the team base
	When that happens, the team that receives it, will receive a team-wide payout

	Package should be light enough that a gravity gun can carry it, but not enough to be player carried. Physics gun should be unable to pick it up
	Should also have a maximum lifetime to prevent hoarding

	High limit on requisition per player, but low regular income, so its a good idea to go out and grab these resource packages
]]

local GMT = {}
AAS.Funcs.DefineGamemode("dw", GMT)
GMT.Name	= "Diesel wars"
GMT.Desc	= "Resource-based team deathmatch"

-- Override the default settings for these, to allow much higher limits
AAS.SettingsFuncs.Number(GMT, "Max Requisition", 500, 50, 1000, "Maximum amount of accruable requisition", -10)
AAS.SettingsFuncs.Number(GMT, "Max Rate", 25, 5, 50, "Rate of requisition per pay cycle", -9)

GMT.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate
	AAS.Funcs.UpdateState()
end

GMT.Load	= function(MapData) -- Assemble the map here, like placing points/spawns
	-- Load resource nodes + settings
end

GMT.Save	= function(MapData) -- Return false to abort saving for any reason
	-- Save resource nodes + settings
end

GMT.TicketThink	= function() -- Called when the server is doing ticket changes

end

GMT.ShortThink	= function() -- Called about every half second, keep it light

end

GMT.LongThink	= function() -- Called every 5 seconds

end

-- We don't use karma for this gamemode, so replace the Payday function
GMT.Payday		= function(ply)
	local MaxGain = AAS.Funcs.GetSetting("Max Rate", 25)
	local Time = SysTime()

	if ply == nil then
		for k,v in player.Iterator() do
			if v.NextPay and (v.NextPay > Time) then continue end
			AAS.Funcs.ChargeRequisition(v,-MaxGain)

			v.NextPay = Time + 60
		end
	else
		if ply.NextPay and (ply.NextPay > Time) then return end
		AAS.Funcs.ChargeRequisition(ply,-MaxGain)

		ply.NextPay = Time + 60
	end
end