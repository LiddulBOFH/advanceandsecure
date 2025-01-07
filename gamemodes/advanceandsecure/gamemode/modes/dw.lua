--	Diesel wars
--[[
	Team deathmatch based gamemode, only ticket loss is from dying

	Resource nodes are around the map that, to be determined how, can spawn a resource package which must be transported back to the team base
	When that happens, the team that receives it, will receive a team-wide payout

	Package should be light enough that a gravity gun can carry it, but not enough to be player carried. Physics gun should be unable to pick it up
	Should also have a maximum lifetime to prevent hoarding

	1 minute before a new package can be spawned, and perhaps allow points in the package to increase over time, to encourage defense?
]]

local GMT = {}
AAS.Funcs.DefineGamemode("dw", GMT)
GMT.Name	= "Diesel wars"
GMT.Desc	= "Resource-based team deathmatch"

GMT.Init	= function(MapData)	-- Setup whatever settings for the map to run here. Should be a clean slate

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