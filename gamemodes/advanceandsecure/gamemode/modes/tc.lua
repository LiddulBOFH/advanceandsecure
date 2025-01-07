-- Territory Control
--[[
	Requires Spawn A and Spawn B to be placed, and then the grid should be configured

	TODO: Enable grid view for editing
	TODO: Figure out hex calculations, to be true to squad's TC

	Teams must capture grids and maintain connection in order to have effect from them
	When over 55% of the zones are captured, start bleedout
	55-59% 1 ticket/min
	60-65% 2 t/min
	66-69% 3 t/min
	70-74% 4 t/min
	75-79% 5 t/min
	80-84% 6 t/min
	85-89% 30 t/min
	90-100% 120 t/min

	Grid setting should include:
	- Enabled zones
]]

local GMT = {}
AAS.Funcs.DefineGamemode("tc", GMT)
GMT.Name	= "Territory Control"
GMT.Desc	= "Hex-based zone capturing across the map"

GMT.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate

end

GMT.Load	= function(MapData) -- Assemble the map here, like placing points/spawns
	-- Load grid settings
end

GMT.Save	= function(MapData) -- Return false to abort saving for any reason
	-- Save grid settings
end

GMT.TicketThink	= function() -- Called when the server is doing ticket changes

end

GMT.ShortThink	= function() -- Called about every half second, keep it light

end

GMT.LongThink	= function() -- Called every 5 seconds

end