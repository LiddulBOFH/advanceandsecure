MsgN("+ Modes system loaded")

-- Generalized gamemode definition functions, also define default settings/functions here
--[[
	1. Define mode ("aas", "raas", "tc", etc)
	2. Set variables, whatever they may be
	3. General hooks (ACF_IsLegal)
	4. Default settings (create new settings panel that can build from this list) and ranges

	Every mode will build from "default", as seen in gamemode/modes
	Anything defined there overrides "default", and "default" *will not work on its own*, it is purely to provide default settings/hooks/etc
]]

--[[

	ENTRYPOINT:
	Initial load of gamemode, sets the GAMEMODE.FirstLoad flag

	From here, server should check if "aas_gamemode <mode>" exists
	If not, default to "aas"

	It should then check if there is data stored for this mode, and attempt to load it
	If it doesn't exist, load the default settings for the mode and set EditMode to true

	*** If EditMode is true, it should stop here

	If all loads correctly, then the game should start

]]

-- Default table with current mode information, to be partially overwritten by the selected gamemode
AAS.Modes			= {} -- Stores all of the available modes that can run
AAS.GM				= {} -- The currently loaded gamemode
AAS.SettingsFuncs	= {} -- Functions required for setting Settings for the active gamemode are stored here
AAS.Settings		= {} -- Any active settings for the current gamemode are stored here
AAS.ActiveHooks		= {} -- Any actively running hooks are stored here, should be removed
AAS.State			= {} -- Current state of the running game, for ease of access/networking
AAS.FirstLoad		= false	-- Simple trip flag that will cause the game to do first time setup for a map
AAS.SuppressReload	= false -- Suppresses the gamemode reload when EditMode is toggled

local ST			= SysTime

AAS.ModeCV = CreateConVar("aas_gamemode", "none", FCVAR_ARCHIVE + FCVAR_UNREGISTERED, "Gamemode for AAS")
cvars.AddChangeCallback("aas_gamemode", function(_, _, new)
	if AAS.FirstLoad then AAS.FirstLoad = false return end

	AAS.Funcs.LoadGamemode(new)
end)

AAS.Funcs.DefineGamemode = function(ID, Data)
	MsgN("[AAS] Defined gamemode: " .. ID)

	Data.Settings	= {}
	Data.Hooks		= {}
	Data.Flags		= {}

	AAS.Modes[ID]	= Data
end


do	-- Settings control
	-- An adjustable number setting
	AAS.SettingsFuncs.Number	= function(GMT, Name, Default, Min, Max, Desc, Order)
		GMT.Settings[Name] = {type = "number", name = Name, default = Default, value = Default, min = Min, max = Max, desc = Desc or "", order = Order or 0}
	end

	-- A toggle setting
	AAS.SettingsFuncs.Bool	= function(GMT, Name, Default, Desc, Order)
		GMT.Settings[Name] = {type = "bool", name = Name, default = Default, value = Default, desc = Desc or "", order = Order or 0}
	end

	-- A free input setting for text
	AAS.SettingsFuncs.String	= function(GMT, Name, Default, Desc, Order)
		GMT.Settings[Name] = {type = "string", name = Name, default = Default, value = Default, desc = Desc or "", order = Order or 0}
	end

	-- An adjustable color setting, primarily for team colors
	-- Internally this is a vector due to colors not saving correctly
	AAS.SettingsFuncs.Color		= function(GMT, Name, Default, Desc, Order)
		GMT.Settings[Name] = {type = "color", name = Name, default = Default, value = Default, desc = Desc or "", order = Order or 0}
	end

	-- Sets a flag for the gamemode
	AAS.SettingsFuncs.Flag	= function(GMT, Name)
		GMT.Flags[Name]	= true
	end

	-- A way to override default settings
	AAS.SettingsFuncs.Remove	= function(GMT, Name) -- Marks a setting for removal, when it is merged
		GMT.Settings[Name] = false
	end
end

AAS.Funcs.InitTeams		= function()
	AAS.State.Team["BLUFOR"] = {
		Name	= AAS.GM.Settings["BLUFOR Name"].value,
		Color	= AAS.GM.Settings["BLUFOR Color"].value,
		Tickets	= AAS.GM.Settings["Tickets"].value
	}
	AAS.State.Team["OPFOR"] = {
		Name	= AAS.GM.Settings["OPFOR Name"].value,
		Color	= AAS.GM.Settings["OPFOR Color"].value,
		Tickets	= AAS.GM.Settings["Tickets"].value
	}

	team.SetColor(1, AAS.State.Team["BLUFOR"].Color:ToColor())
	team.SetColor(2, AAS.State.Team["OPFOR"].Color:ToColor())
end

AAS.Funcs.ApplySettings	= function(MapData)
	local Settings = MapData.Settings

	for k,v in pairs(AAS.GM.Settings) do
		if Settings[k] then
			local Setting = AAS.GM.Settings[k]

			if Setting.type == "number" then
				AAS.GM.Settings[k].value = math.Clamp(math.floor(Settings[k]), Setting.min, Setting.max)
			elseif Setting.type == "color" then
				AAS.GM.Settings[k].value = Vector(math.Clamp(math.ceil(Settings[k].x), 0, 255), math.Clamp(math.ceil(Settings[k].y), 0, 255), math.Clamp(math.ceil(Settings[k].z), 0, 255))
			else
				AAS.GM.Settings[k].value = Settings[k]
			end
		end
	end

	AAS.Funcs.InitTeams()
end

do	-- Hook control
	-- Adds a hook that should be loaded with the mode
	AAS.Funcs.AddHook	= function(GMT, Hook, Func)
		GMT.Hooks[Hook] = Func
	end

	-- Actually starts running a hook, don't use this
	AAS.Funcs.StartHook	= function(Hook, Func)
		MsgN("== Starting hook: AAS." .. Hook)

		hook.Remove(Hook, "AAS." .. Hook) -- Just in case
		AAS.ActiveHooks[Hook] = {event = Hook, identifier = "AAS." .. Hook}
		hook.Add(Hook, "AAS." .. Hook, Func)
	end

	-- Removes a hook from the tracking list, as well as stops it
	AAS.Funcs.RemoveHook = function(HookData)
		if AAS.ActiveHooks[HookData.event] then AAS.ActiveHooks[HookData.event] = nil end
		hook.Remove(HookData.event, HookData.identifier)
	end

	-- Clear any active hooks
	AAS.Funcs.ClearHooks	= function()
		for _,v in pairs(AAS.ActiveHooks) do
			AAS.Funcs.RemoveHook(v)
		end
	end
end

-- Goes over the requested mode and loads everything, overwriting default values
AAS.Funcs.LoadGamemode	= function(ID)
	-- Remove any hooks currently active
	AAS.Funcs.ClearHooks()

	AAS.GM	= {}
	table.Merge(AAS.GM, AAS.DefaultMode)

	-- If for some reason an invalid mode was checked for
	if not AAS.Modes[ID] then
		ID				= "aas"
		AAS.FirstLoad	= true
		AAS.ModeCV:SetString("aas")
	end

	-- Merge everything from the selected gamemode
	table.Merge(AAS.GM, AAS.Modes[ID], false)

	-- Purge any settings that were marked for removal
	for k,v in pairs(AAS.GM.Settings) do
		if type(v) == TYPE_BOOL then table.remove(k) continue end
	end

	AAS.Funcs.Reset(true)

	local Map	= string.lower(game.GetMap())
	if not file.Exists("aas/maps/" .. Map, "DATA") then
		MsgN("Nothing found at all for this map! Defaulting to edit mode.")
		file.CreateDir("aas/maps/" .. Map)

		AAS.FirstLoad = true
		AAS.ModeCV:SetString("aas")

		AAS.Funcs.LoadNoPlay()

		return
	end

	local MapData = ""
	local MapFile = "aas/maps/" .. Map .. "/" .. ID .. ".txt"
	if file.Exists(MapFile,"DATA") then
		MapData = util.JSONToTable(file.Read(MapFile,"DATA"))

		if MapData == "" then
			MsgN("[AAS] Missing map data for this gamemode!")

			AAS.Funcs.LoadNoPlay()

			return
		end

		AAS.Funcs.Init(MapData)
	else
		AAS.Funcs.LoadNoPlay()
	end
end

-- Reset the currently loaded mode, just an easy accessor function without having to lookup the current mode
AAS.Funcs.ReloadGamemode = function()
	AAS.Funcs.LoadGamemode(AAS.ModeCV:GetString())
end

-- Deep reset followed by reload of the current gamemode
AAS.Funcs.FullReload	= function()
	AAS.Funcs.DeepReset()
	AAS.Funcs.ReloadGamemode()
end

AAS.Funcs.LoadNoPlay	= function()
	AAS.Funcs.InitTeams()

	AAS.SuppressReload	= true
	AAS.Funcs.SetEditMode(true)

	AAS.Funcs.UpdateState()
end

-- Update players (or, if ply is passed, one player) of the current state of the game
AAS.Funcs.UpdateState = function(ply)
	local State = AAS.State

	if not AAS.GM.Update then return end

	AAS.GM.Update(State.Data)

	net.Start("AAS.UpdateState")
		net.WriteTable({mode = State.Mode, name = AAS.GM.Name, desc = AAS.GM.Desc})
		net.WriteBool(State.Active)
		net.WriteTable(State.Data)
		net.WriteString(util.TableToJSON(State.Team))
		net.WriteString(util.TableToJSON(AAS.GM.Settings))
		net.WriteString(util.TableToJSON(AAS.GM.Flags))
		net.WriteTable(AAS.State.Alias or {})
	if IsValid(ply) then print("UPDATESTATE: Updating ", ply) net.Send(ply) else print("UPDATESTATE: Broadcasting state") net.Broadcast() end
end

-- Pass the deserialized map data as a table for the current gamemode
AAS.Funcs.Init 	= function(MapData)
	MsgN("[AAS] Initializing gamemode: " .. AAS.ModeCV:GetString())

	AAS.Funcs.LoadMap(MapData)	-- Assemble the standard components of the map

	AAS.Funcs.ApplySettings(MapData)	-- Apply settings that were saved

	AAS.GM.Init(MapData)	-- Initialize the gamemode specific function

	AAS.Funcs.Start()
end

local function EnemySZCountdown(ply)
	if ply.DeathCountdown == nil then return end -- something else, like a round restart, set this to nil
	if PlyInEnemySafezone(ply,ply:GetPos()) then
		aasMsg({Colors.ErrorCol, "You have " .. ply.DeathCountdown .. " seconds to leave the enemy safezone."}, ply)
		ply.DeathCountdown = ply.DeathCountdown - 1

		if ply.DeathCountdown >= 0 then
			AAS.Funcs.AdjustKarma(ply, -10) -- steeply punish the player for being in the enemy safezone
			timer.Simple(1,function() EnemySZCountdown(ply) end)
		else
			ply.DeathCountdown = nil
			ply:Kill()
		end
	else
		aasMsg({Colors.BasicCol, "You have ", Colors.GoodCol, "left", Colors.BasicCol, " the ", Colors.BadCol, "enemy", Colors.BasicCol, " safezone."}, ply)
		ply.DeathCountdown = nil
	end
end

local function SafezoneCheck()
	for _, ply in player.Iterator() do
		local state = PlyInSafezone(ply, ply:GetPos())
		if ply:GetNW2Bool("InSafezone") ~= state then
			if state then
				aasMsg({Colors.BasicCol, "You have ", Colors.GoodCol, "entered", Colors.BasicCol, " the safezone."}, ply)
			else
				aasMsg({Colors.BasicCol, "You have ", Colors.BadCol, "left", Colors.BasicCol, " the safezone."}, ply)
			end

			ply:SetNW2Bool("InSafezone",state) -- this doesn't affect anything right now except for what the client sees, InSafezone is checked for every damage interaction again
		end

		if PlyInEnemySafezone(ply, ply:GetPos()) and (GetGlobalBool("EditMode", false) == false) and (not ply.DeathCountdown and ply:Alive()) then
			aasMsg({Colors.BasicCol, "You have ", Colors.BadCol, "entered", Colors.BasicCol, " the ", Colors.BadCol, "enemy", Colors.BasicCol, " safezone."}, ply)
			ply.DeathCountdown = 5

			EnemySZCountdown(ply)
		end
	end
end

local function BalanceTeams()
	local TeamDiff = team.NumPlayers(1) - team.NumPlayers(2)
	local LargerTeam = (TeamDiff > 0) and 1 or 2
	local SmallerTeam = (TeamDiff > 0) and 2 or 1

	if math.abs(TeamDiff) <= 1 then return end

	local Team = team.GetPlayers(LargerTeam)

	local I = 0
	local NumToBalance = math.ceil(math.abs(TeamDiff / 2))
	local Moving = {}
	while I < NumToBalance do
		local PlyIn = math.random(#Team)
		local Ply = Team[PlyIn]
		Moving[#Moving + 1] = Ply
		table.remove(Team,PlyIn)

		I = I + 1
	end

	local SmallerTeamInfo = AAS.Funcs.GetTeamInfo(SmallerTeam)
	for _,ply in ipairs(Moving) do
		ply:SetTeam(SmallerTeam)
		ply:StripWeapons()
		ply:StripAmmo()
		ply:Spawn()
		aasMsg({Colors.BasicCol,"Moving " .. ply:Nick() .. " to ", SmallerTeamInfo.Color, SmallerTeamInfo.Name, Colors.BasicCol,"!"})
	end
end

local AutoBalance		= false
local AutoBalanceTick	= 5
local NextShortTick		= 0
local NextLongTick		= 0
local NextTicketCheck	= 0
local function MainTick()
	if not AAS.State.Active then AAS.Funcs.Stop() return end
	local pass, msg

	local T = ST()

	if T >= NextShortTick then
		NextShortTick = T + 0.5

		pass, msg = pcall(SafezoneCheck)
		if not pass then MsgN("Error in SafeZone check", msg) end

		pass, msg = pcall(AAS.GM.ShortThink)
		if not pass then MsgN("Error in ShortThink", msg) end
	end

	if T >= NextLongTick then
		NextLongTick = T + 5

		pass, msg = pcall(AAS.GM.LongThink)
		if not pass then MsgN("Error in LongThink", msg) end
	end

	if T >= NextTicketCheck then
		NextTicketCheck = T + 5

		local Team1 = team.NumPlayers(1)
		local Team2 = team.NumPlayers(2)
		if AutoBalance then
			AutoBalance = false
			BalanceTeams()
		elseif math.abs(Team1 - Team2) > 1 then
			AutoBalanceTick = AutoBalanceTick + 1
			if AutoBalanceTick >= 6 then
				AutoBalance = true
				AutoBalanceTick = 0
				aasMsg({Colors.BasicCol,"Autobalancing teams in 5s..."})
			end
		else AutoBalanceTick = 0 end

		AAS.GM.Payday()
		AAS.Funcs.CalcRequisition()

		pass, msg = pcall(AAS.GM.TicketThink)
		if not pass then MsgN("Error in TicketThink", msg) end
	end
end

AAS.Funcs.Start	= function()
	if GetGlobalBool("EditMode",false) == false then
		for k,v in pairs(AAS.GM.Hooks) do
			AAS.Funcs.StartHook(k, v)
		end

		AAS.State.Active = true
		hook.Add("Think", "AAS.MainTick", MainTick)
	end

	AAS.Funcs.UpdateState()
end

AAS.Funcs.Stop = function()
	MsgN("[AAS] Stopping main tick")
	hook.Remove("Think", "AAS.MainTick")

	AAS.Funcs.ClearHooks()

	AAS.State.Active = false
	AAS.Funcs.UpdateState()
end

MsgN("[AAS] Loading modes...")
local Modes = file.Find(engine.ActiveGamemode() .. "/gamemode/modes/*.lua", "LUA")

for _, mode in pairs(Modes) do
	MsgN("[AAS] Adding: " .. mode)
	include(engine.ActiveGamemode() .. "/gamemode/modes/" .. mode)
end
MsgN("[AAS] Finished adding modes!")