-- Classic Baikonur
--[[
	Requires Spawn A and Spawn B to be placed, and then a number of points can be randomly scattered
	All of the points will be active for capturing


]]

local GMT = {}
AAS.Funcs.DefineGamemode("classic", GMT)
GMT.Name	= "Classic"
GMT.Desc	= "Classic Baikonur experience, using team-wide weight limits"

AAS.SettingsFuncs.Number(GMT, "Starting weight", 150, 5, 300, "The initial weight limit, team-wide", 20)
AAS.SettingsFuncs.Number(GMT, "Weight bonus per point", 50, 5, 100, "Bonus weight per captured point", 21)
AAS.SettingsFuncs.Remove(GMT, "Max Requisition")
AAS.SettingsFuncs.Remove(GMT, "Max Rate")
AAS.SettingsFuncs.Flag(GMT, "Disable Requisition")

GMT.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate
	AAS.Funcs.UpdateState()
end

GMT.Load	= function(MapData) -- Assemble the map here, like placing points/spawns

end

GMT.Save	= function(MapData) -- Return false to abort saving for any reason
	-- Nothing to do here?
end

GMT.TicketThink	= function() -- Called when the server is doing ticket changes

end

GMT.ShortThink	= function() -- Called about every half second, keep it light

end

GMT.LongThink	= function() -- Called every 5 seconds

end