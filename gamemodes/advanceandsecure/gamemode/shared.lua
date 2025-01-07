AddCSLuaFile()
DeriveGamemode("sandbox")

GM.Name = "Advance and Secure"
GM.Author = "LiddulBOFH"
GM.Email = "No"
GM.Website = "Also no"

AAS = {}

MsgN("+ Gamemode: Advance and Secure")

local function includecs_cl(f) -- Meant for clientside only files
	if SERVER then
		AddCSLuaFile(f)
	else
		include(f)
	end
end

-- for why I don't know but the original includeCS is marked as deprecated
local function includecs(f) -- Meant for shared files
	include(f)
	AddCSLuaFile(f)
end

AddCSLuaFile("libs/cl/png.lua")
includecs("libs/core.lua")			-- Basic stuff required for everything else
includecs("libs/seatsystem.lua")	-- Seat entry/locking, to prevent cross team theft, as well as to allow easy entry without wire users
includecs("libs/util.lua")			-- Miscellaneous
includecs("libs/distro.lua")		-- Dupe/script distribution
includecs("libs/vote.lua")			-- Vote system
includecs("libs/settings.lua")		-- Settings
includecs("libs/mapdraw.lua")		-- Map PNG saving/loading
includecs("libs/levels.lua")		-- Silly leveling system

if SERVER then
	include("libs/sv/modes.lua")	-- Gamemode control
	include("libs/sv/map.lua")		-- Map control
	include("libs/sv/costcalc.lua")	-- Cost calculation
	include("libs/sv/tickets.lua")	-- Tickets for team scoring
	include("libs/sv/plyutil.lua")	-- Various player utilities
end

-- Client
includecs_cl("libs/cl/fonts.lua")		-- Fonts used elsewhere
includecs_cl("libs/cl/vgui/panmap.lua")
includecs_cl("libs/cl/hud.lua")			-- Bulk of the client UI
includecs_cl("libs/cl/hints.lua")		-- Hints that are displayed while the player is dead
includecs_cl("libs/cl/scoreboard.lua")	-- The scoreboard
includecs_cl("libs/cl/costdraw.lua")	-- Client rendering for cost calculations
includecs_cl("libs/cl/chat.lua")		-- Custom chat box

includecs("libs/loadouts.lua")		-- System that provides weapons/gadgets to players for a cost (or free)

MsgN("+ Finished loading gamemode!")