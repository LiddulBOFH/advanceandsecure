include("shared.lua")
local LP = LocalPlayer()

AAS.ServerRAAS		= nil
AAS.RAASLine		= nil
AAS.RAASLookup		= nil
AAS.RAASFinished	= false
AAS.RAASQueued		= false

-- Default values for point names, to be overridden when RAAS info is received
AAS.LocalAlias		= {["SpawnA"] = "SpawnA",["SpawnB"] = "SpawnB"}

local PointBaseColor = Color(65,65,65)

local SW,SH = ScrW(),ScrH()
local SM = {x = SW / 2, y = SH / 2}
local UU = ((SW > SH) and SH or SW) / 12

local HUDHide = {["CHudHealth"] = true,["CHUDQuickInfo"] = true,["CHudBattery"] = true}

local DupeCost = {Draw = false}

local function setupRAASLocal()
	if not AAS.ServerRAAS then return end
	AAS.RAASLine = table.Copy(AAS.ServerRAAS)

	if VotePanel then VotePanel:Remove() end

	if LP:Team() == 2 then
		AAS.RAASLine = table.Reverse(AAS.RAASLine)
	end

	for k,v in ipairs(AAS.RAASLine) do
		AAS.RAASLookup[v] = k
		if not IsValid(v) then
			if not AAS.RAASQueued then
				net.Start("AAS.PlayerInit")
				net.SendToServer()
			end

			return
		end
	end

	AAS.RAASFinished = true
end

local function mixColor(ColorA,ColorB,Mix)
	local CA = ColorA:ToVector()
	local CB = ColorB:ToVector()
	return (CB * (1 - Mix) + CA * Mix):ToColor()
end

function GM:NotifyShouldTransmit(ent,should)
	if ent:GetClass() == "aas_point" then ent:SetPredictable(true) end
end

-- Render mess and things

-- This is for fixing sync issues regarding teams and setting up the RAASLine for the player's perspective
local StoredTeam = 0

local function CapColor(Cap)
	if Cap > 0 then return mixColor(AAS.TeamData[1].Color,PointBaseColor,Cap / 100)
	elseif Cap < 0 then return mixColor(AAS.TeamData[2].Color,PointBaseColor,-Cap / 100)
	else return PointBaseColor end
end

local ATeamHalf = {}
ATeamHalf[1] = {x = SM.x, y = 0}
ATeamHalf[2] = {x = SM.x, y = UU * 0.5}
ATeamHalf[3] = {x = SM.x - (UU * 1), y = UU * 0.5}
ATeamHalf[4] = {x = SM.x - (UU * 1.5), y = 0}

local BTeamHalf = {}
BTeamHalf[1] = {x = SM.x, y = 0}
BTeamHalf[2] = {x = SM.x + (UU * 1.5), y = 0}
BTeamHalf[3] = {x = SM.x + (UU * 1), y = UU * 0.5}
BTeamHalf[4] = {x = SM.x, y = UU * 0.5}

local function PointChange(Point,OldStatus,NewStatus)
	if PointChangeBase then PointChangeBase:Remove() end

	PointChangeBase = vgui.Create("Panel")
	PointChangeBase:SetSize(UU * 8,UU * 2)
	PointChangeBase:CenterHorizontal(0.5)
	PointChangeBase:CenterVertical(0.25)
	PointChangeBase:AlphaTo(0,1,4,function(_,panel) panel:Remove() end)
	PointChangeBase.Paint = function(self,w,h)
		if not AAS.TeamData then net.Start("AAS.PlayerInit") net.SendToServer() PointChangeBase:Remove() end -- somehow we lost vital data??
		local CappingTeam = CapStatus(Point)
		local CurrentTeam = LP:Team()
		draw.NoTexture()
		local Col = PointBaseColor
		if AAS.TeamData[CappingTeam] then Col = AAS.TeamData[CappingTeam].Color end
		local CapText = ""
		local CapCol = Color(255,255,255)

		local PolyCol = Color(65,65,65)
		if (NewStatus == 0) and (OldStatus ~= CurrentTeam) then
			CapCol = Colors.GoodCol
			CapText = "Neutralized"
		elseif NewStatus ~= CurrentTeam and (OldStatus == CurrentTeam) then
			CapCol = Colors.BadCol
			CapText = "Lost"
		else
			PolyCol = Col
			CapCol = (NewStatus == CurrentTeam and Colors.GoodCol or Colors.BadCol)
			CapText = "Captured by " .. (AAS.TeamData[CappingTeam].Name or "")
		end

		local CX,CY = w / 2,h / 2

		local LowPoly = {
			{x = CX,y = CY + UU * 0.6},
			{x = CX - UU * 0.6,y = CY},
			{x = CX - UU * 0.35,y = CY},
			{x = CX,y = CY + UU * 0.35},
			{x = CX + UU * 0.35,y = CY},
			{x = CX + UU * 0.6,y = CY}
		}
		local HighPoly = {
			{x = CX,y = CY - UU * 0.6},
			{x = CX + UU * 0.6,y = CY},
			{x = CX + UU * 0.35,y = CY},
			{x = CX,y = CY - UU * 0.35},
			{x = CX - UU * 0.35,y = CY},
			{x = CX - UU * 0.6,y = CY}
		}
		surface.SetDrawColor(PolyCol)
		surface.DrawPoly(LowPoly)
		surface.DrawPoly(HighPoly)

		surface.SetDrawColor(Col)

		local PointName = AAS.LocalAlias[Point:GetPointName()] or Point:GetPointName()

		draw.SimpleTextOutlined(PointName,"BasicFontLarge",CX - UU * 0.75,CY,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER,1,color_black)
		draw.SimpleTextOutlined(CapText,"BasicFontLarge",CX + UU * 0.75,CY,CapCol,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,color_black)
	end
end

local SVProperties = {}

local function SettingsMenu()
	if GetGlobalBool("EditMode",false) == false then LP:PrintMessage(HUD_PRINTTALK,"The server is not in edit mode!") return end

	local Settings = table.Copy(SVProperties)
	SettingsBase = vgui.Create("DFrame")
	SettingsBase:SetSize(220,420)
	SettingsBase:SetTitle("Game Settings")
	SettingsBase:Center()
	SettingsBase:MakePopup()
	SettingsBase:SetDraggable(false)

	local InfoLabel = vgui.Create("DLabel",SettingsBase)
	InfoLabel:SetText("Info: Hover over each item for more info")
	InfoLabel:Dock(TOP)
	InfoLabel:DockMargin(0,4,0,0)

	local SetIsLinear = vgui.Create("DCheckBoxLabel",SettingsBase)
	SetIsLinear:SetText("Non-linear points?")
	SetIsLinear:SetTooltip("This determines if the points are to be connected for capture and revealing purposes")
	SetIsLinear:Dock(TOP)
	SetIsLinear:SetValue(Settings.NonLinear)
	SetIsLinear.OnChange = function(self,b)
		Settings.NonLinear = b
	end
	SetIsLinear:DockMargin(0,4,0,0)

	local TicketLabel = vgui.Create("DLabel",SettingsBase)
	TicketLabel:SetText("Starting Tickets")
	TicketLabel:Dock(TOP)
	TicketLabel:DockMargin(0,4,0,0)

	local StartTix = vgui.Create("DNumberWang",SettingsBase)
	StartTix:SetMinMax(50,1000)
	StartTix:SetValue(Settings.StartTickets)
	StartTix:SetDecimals(0)
	StartTix:SetInterval(50)
	StartTix:SetTooltip("The number of tickets each team starts with")
	StartTix:Dock(TOP)
	StartTix.OnValueChanged = function(self,val)
		Settings.StartTickets = val
	end


	local MaxReqLabel = vgui.Create("DLabel",SettingsBase)
	MaxReqLabel:SetText("Maximum Requisition")
	MaxReqLabel:Dock(TOP)
	MaxReqLabel:DockMargin(0,4,0,0)

	local MaxReq = vgui.Create("DNumberWang",SettingsBase)
	MaxReq:SetMinMax(100,500)
	MaxReq:SetValue(Settings.MaxRequisition)
	MaxReq:SetDecimals(0)
	MaxReq:SetInterval(50)
	MaxReq:SetTooltip("The total number of requisition points a player can have")
	MaxReq:Dock(TOP)
	MaxReq.OnValueChanged = function(self,val)
		Settings.MaxRequisition = val
	end

	local ReqGainLabel = vgui.Create("DLabel",SettingsBase)
	ReqGainLabel:SetText("Requisition Gain")
	ReqGainLabel:SetTooltip("Every player will be able to gain at most this number of points, starting at half and gets adjusted based on their karma amount")
	ReqGainLabel:Dock(TOP)
	ReqGainLabel:DockMargin(0,4,0,0)

	local ReqGain = vgui.Create("DNumberWang",SettingsBase)
	ReqGain:SetMinMax(1,100)
	ReqGain:SetValue(Settings.RequisitionGain)
	ReqGain:SetDecimals(0)
	ReqGain:SetInterval(10)
	ReqGain:SetTooltip("The total number of requisition points players can get per 'payday'")
	ReqGain:Dock(TOP)
	ReqGain.OnValueChanged = function(self,val)
		Settings.RequisitionGain = val
	end

	local TeamAliasLabel = vgui.Create("DLabel",SettingsBase)
	TeamAliasLabel:SetText("Team Alias")
	TeamAliasLabel:Dock(TOP)
	TeamAliasLabel:DockMargin(0,4,0,0)

	local UseAlias = vgui.Create("DCheckBoxLabel",SettingsBase)
	UseAlias:SetText("Use alias?")
	UseAlias:SetTooltip("Whether or not to use special alias names for each team")
	UseAlias:Dock(TOP)
	UseAlias:SetValue(Settings.ChangedAlias)
	UseAlias:DockMargin(0,4,0,0)

	local AliasA = vgui.Create("DTextEntry",SettingsBase)
	AliasA:SetText(Settings.Alias[1].Name)
	AliasA:Dock(TOP)
	AliasA:SetTooltip("The alias for team A")
	AliasA:SetUpdateOnType(true)
	AliasA.OnValueChange = function(self,s)
		Settings.Alias[1].Name = s
	end
	AliasA.OnEnter = function(self,s)
		if s == "" then
			AliasA:SetText("BLUFOR")
			Settings.Alias[1].Name = "BLUFOR"
		end
	end
	AliasA:SetEnabled(UseAlias:GetChecked())
	AliasA:DockMargin(0,4,0,0)

	local AliasB = vgui.Create("DTextEntry",SettingsBase)
	AliasB:SetText(Settings.Alias[2].Name)
	AliasB:Dock(TOP)
	AliasB:SetTooltip("The alias for team B")
	AliasB:SetUpdateOnType(true)
	AliasB.OnValueChange = function(self,s)
		Settings.Alias[2].Name = s
	end
	AliasB.OnEnter = function(self,s)
		if s == "" then
			AliasB:SetText("OPFOR")
			Settings.Alias[2].Name = "OPFOR"
		end
	end
	AliasB:SetEnabled(UseAlias:GetChecked())
	AliasB:DockMargin(0,4,0,0)

	local FinishButton = vgui.Create("DButton",SettingsBase)
	FinishButton:SetSize(1,24)
	FinishButton:SetText("Apply")
	FinishButton:Dock(BOTTOM)

	local SubPanel = vgui.Create("Panel",SettingsBase)
	SubPanel:SetSize(1,72)
	SubPanel:Dock(BOTTOM)
	SubPanel:DockMargin(0,0,0,4)
	SubPanel.Paint = function(self,w,h)
		surface.SetDrawColor(127,127,127)
		surface.DrawRect(0,0,w,h)
	end

	local SubPanelB = vgui.Create("Panel",SettingsBase)
	SubPanelB:SetSize(1,18)
	SubPanelB:Dock(BOTTOM)

	local ColBlockA = vgui.Create("Panel",SubPanelB)
	ColBlockA:SetSize(85,1)
	ColBlockA:Dock(LEFT)
	ColBlockA:SetTooltip("The color for team A")
	ColBlockA.Paint = function(self,w,h)
		surface.SetDrawColor(Settings.Alias[1].Color)
		surface.DrawRect(0,0,w,h)
	end

	local ColBlockB = vgui.Create("Panel",SubPanelB)
	ColBlockB:SetSize(85,1)
	ColBlockB:Dock(RIGHT)
	ColBlockB:SetTooltip("The color for team B")
	ColBlockB.Paint = function(self,w,h)
		surface.SetDrawColor(Settings.Alias[2].Color)
		surface.DrawRect(0,0,w,h)
	end

	local function setACol(col)
		Settings.Alias[1].Color = col
	end

	local TeamAColPicker = vgui.Create("DRGBPicker",SubPanel)
	TeamAColPicker:SetSize(14,1)
	TeamAColPicker:Dock(LEFT)
	TeamAColPicker:SetEnabled(UseAlias:GetChecked())
	TeamAColPicker:SetRGB(Settings.Alias[1].Color)

	local TeamACol = vgui.Create("DColorCube",SubPanel)
	TeamACol:SetSize(72,72)
	TeamACol:Dock(LEFT)
	TeamACol:SetEnabled(UseAlias:GetChecked())
	TeamACol:SetColor(Settings.Alias[1].Color)

	TeamAColPicker.OnChange = function(self,col)
		local h,_,_ = ColorToHSV(col)
		local _,s,v = ColorToHSV(TeamACol:GetRGB())
		col = HSVToColor(h,s,v)
		TeamACol:SetColor(col)
		setACol(col)
	end

	TeamACol.OnUserChanged = function(self,col)
		setACol(col)
	end

	local function setBCol(col)
		Settings.Alias[2].Color = col
	end

	local TeamBColPicker = vgui.Create("DRGBPicker",SubPanel)
	TeamBColPicker:SetSize(14,1)
	TeamBColPicker:Dock(RIGHT)
	TeamBColPicker:SetEnabled(UseAlias:GetChecked())
	TeamBColPicker:SetRGB(Settings.Alias[2].Color)

	local TeamBCol = vgui.Create("DColorCube",SubPanel)
	TeamBCol:SetSize(72,72)
	TeamBCol:Dock(RIGHT)
	TeamBCol:SetEnabled(UseAlias:GetChecked())
	TeamBCol:SetColor(Settings.Alias[2].Color)

	TeamBColPicker.OnChange = function(self,col)
		local h,_,_ = ColorToHSV(col)
		local _,s,v = ColorToHSV(TeamBCol:GetRGB())
		col = HSVToColor(h,s,v)
		TeamBCol:SetColor(col)
		setBCol(col)
	end

	TeamBCol.OnUserChanged = function(self,col)
		setBCol(col)
	end

	UseAlias.OnChange = function(self,b)
		Settings.ChangedAlias = b
		AliasA:SetEnabled(b)
		AliasB:SetEnabled(b)

		TeamAColPicker:SetEnabled(b)
		TeamACol:SetEnabled(b)

		TeamBColPicker:SetEnabled(b)
		TeamBCol:SetEnabled(b)
	end

	FinishButton.DoClick = function()
		--PrintTable(Settings)
		net.Start("AAS.UpdateServerSettings")
			net.WriteTable(Settings)
		net.SendToServer()

		SettingsBase:Remove()
	end
end
if SettingsBase then SettingsBase:Remove() end

net.Receive("AAS.OpenSettings",function()
	SVProperties = net.ReadTable()
	SettingsMenu()
end)

do  -- Stuff to organize

	do	-- Net
		-- Handles any changes in point capture status
		net.Receive("AAS.UpdatePointState",function()
			PointChange(net.ReadEntity(),net.ReadInt(3),net.ReadInt(3))
		end)

		-- Sets up the line of points for the player, with it arranged for their team
		net.Receive("AAS.RAASLine",function()
			AAS.ServerRAAS = net.ReadTable()
			AAS.PointAlias = net.ReadTable()
			AAS.RAASLookup = {}
			AAS.RAASQueued = false

			AAS.RAASFinished = false

			AAS.NonLinear = GetGlobalBool("IsNonLinear",false)
			AAS.MaxRequisition = GetGlobalInt("MaxRequisition",AAS.DefaultProperties.MaxRequisition)

			setupRAASLocal()
		end)

		-- Sets up the team aliases as well as colors for the client, also sets the player color
		net.Receive("AAS.UpdateTeamData",function()
			AAS.TeamData = net.ReadTable()

			if LP:GetPlayerColor() ~= AAS.TeamData[LP:Team()].Color then
				LP:SetPlayerColor(AAS.TeamData[LP:Team()].Color:ToVector())
			end

			team.SetColor(1,AAS.TeamData[1].Color)
			team.SetColor(2,AAS.TeamData[2].Color)

			AAS.LocalAlias["SpawnA"] = AAS.TeamData[1].Name .. " Spawn"
			AAS.LocalAlias["SpawnB"] = AAS.TeamData[2].Name .. " Spawn"
		end)

		-- Sent whenever the player spawns a dupe, provides information about the cost of everything in the dupe
		net.Receive("AAS.CostPanel",function()
			local DupeCenter = net.ReadVector()
			local CostBreakdown = net.ReadTable()
			local Cost = net.ReadUInt(16)
			local Highest = net.ReadUInt(12)

			DupeCost.DupeCenter = DupeCenter
			DupeCost.HighCenter = Vector(DupeCenter.x,DupeCenter.y,Highest)
			DupeCost.CostBreakdown = CostBreakdown
			DupeCost.BreakdownCount = table.Count(CostBreakdown)
			DupeCost.Cost = Cost
			DupeCost.Time = SysTime() + math.min(table.Count(CostBreakdown) * 4,15)
			DupeCost.Draw = true
		end)
	end

	do	-- Hooks
		-- Requests information about the running game, like the points and how they are connected

		local function requestInfo()
			if AAS.RAASQueued then return end

			timer.Simple(5,function() AAS.RAASQueued = false end)
			AAS.RAASQueued = true

			net.Start("AAS.PlayerInit")
			net.SendToServer()
		end

		hook.Add("InitPostEntity","PlyInit",function()
			requestInfo()
		end)

		requestInfo()

		-- A slow tick that just checks if for some reason the client lost the info, which has happened for reasons unknown as of writing
		local ClientThinkDelay = 0
		hook.Add("Think","PlyThink",function()
			if SysTime() <= ClientThinkDelay then return end
			if not IsValid(LP) then LP = LocalPlayer() return end
			local Team = LP:Team()

			if not AAS.TeamData then
				requestInfo()
			end

			if Team ~= StoredTeam then
				AAS.RAASFinished = false
				setupRAASLocal()
				if not GetGlobalBool("EditMode",false) then LP:SetPlayerColor(AAS.TeamData[Team].Color:ToVector()) end
				StoredTeam = Team
			end

			ClientThinkDelay = SysTime() + 1
		end)

		-- Blanks out the screen when the player is dead, or fades it with red when below 25% health
		-- While dead the player can see a time until they can respawn, a hint for the gamemode, and a warning if their karma is too low (extends respawn time)
		hook.Add("PostDrawHUD","PostGameHUD",function()
			draw.NoTexture()
			if not IsValid(LP) then LP = LocalPlayer() return end
			local Health = LP:Health()
			if Health < 25 then
				surface.SetDrawColor(255 * (Health / 25),0,0,255 * (1 - (Health / 25)))
				surface.DrawRect(0,0,SW,SH)

				if not LP:Alive() then
					local DeathTime = math.Round(LP:GetNW2Float("NextSpawn",CurTime()) - CurTime(),1)

					draw.SimpleText("YOU HAVE DIED","BasicFontExtraLarge",SW / 2, (SH / 2) - UU * 0.5,Colors.BadCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

					if DeathTime > 0 then
						draw.SimpleText(DeathTime .. "s","BasicFontLarge",SW / 2, SH / 2,Colors.BadCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
					else
						draw.SimpleText("Press space or click to spawn!","BasicFontLarge",SW / 2, SH / 2,Colors.GoodCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
					end

					if LP:GetNW2Int("karma",0) < -10 then
						draw.SimpleText("Your extended respawn time is due to your karma (" .. LP:GetNW2Int("karma",0) .. ")",
						"BasicFontLarge",SW / 2, (SH / 2) + UU * 0.5,Colors.BadCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
					end

					draw.DrawText(AAS.Funcs.getHint(),"BasicFontLarge",SW / 2, SH * 0.75,Colors.BasicCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

					return
				end
			end
		end)

		-- Just hides HUD elements
		hook.Add("HUDShouldDraw","HideHUD",function(label)
			if HUDHide[label] then return false end
		end)

		-- Draws all of the points the player can see, info about the game (tickets, requisition), any friendlies on the map, and the dupe cost of a recently spawned dupe
		local FriendlyScale = 10
		local PointScale = 20
		hook.Add("HUDPaint","GameHUD",function()
			draw.NoTexture()
			if not IsValid(LP) then LP = LocalPlayer() return end
			if not LP:Alive() then return end

			local Team = LP:Team()

			local TeamCol = team.GetColor(Team)
			local FinCol = Color(TeamCol.r,TeamCol.g,TeamCol.b,200)
			draw.NoTexture()
			surface.SetDrawColor(FinCol)

			local friendlies = team.GetPlayers(Team)

			for k,v in ipairs(friendlies) do
				if v == LP then continue end
				local Poly = {}
				local Pos2 = v:GetShootPos():ToScreen()
				for I = 1,3 do
					local Ang = math.rad((120 * I) + 30)
					Poly[I] = {x = Pos2.x + (math.cos(Ang) * FriendlyScale), y = Pos2.y + (math.sin(Ang) * FriendlyScale)}
				end

				surface.DrawPoly(Poly)

				draw.SimpleTextOutlined(v:Nick(),"BasicFont",Pos2.x,Pos2.y - UU * 0.25,TeamCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
			end

			local TicketTotal = AAS.TeamData[1].Tickets + AAS.TeamData[2].Tickets
			local TicketRatio = math.Clamp(AAS.TeamData[1].Tickets / TicketTotal,0,2)

			draw.RoundedBoxEx(16,20,20,256 * TicketRatio,72,AAS.TeamData[1].Color,true,false,true,false)
			draw.RoundedBoxEx(16,20 + (256 * TicketRatio),20,128 + (128 - (256 * TicketRatio)),72,AAS.TeamData[2].Color,false,true,false,true)
			draw.RoundedBox(8,20 + 8,20 + 8,256 - 16,72 - 16,Color(65,65,65,240))

			surface.SetDrawColor(color_black)
			surface.DrawRect(20 + 128,20,2,72)

			draw.SimpleTextOutlined(AAS.TeamData[1].Name,"BasicFont14",24 + 64,40,AAS.TeamData[1].Color,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
			draw.SimpleTextOutlined(AAS.TeamData[2].Name,"BasicFont14",16 + 128 + 64,40,AAS.TeamData[2].Color,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)

			draw.SimpleTextOutlined(AAS.TeamData[1].Tickets,"BasicFontLarge",24 + 64,64,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
			draw.SimpleTextOutlined(AAS.TeamData[2].Tickets,"BasicFontLarge",16 + 128 + 64,64,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)

			draw.RoundedBox(16,20,92 + 8,256,96,TeamCol)
			draw.RoundedBox(8,28,92 + 16,256 - 16,96 - 16,Color(65,65,65,240))

			local MaxReq = (AAS.MaxRequisition or 0)
			local CurReq = LP:GetNW2Int("Requisition",0)
			local UsedReq = LP:GetNW2Int("UsedRequisition",0)
			draw.SimpleTextOutlined("Requisition","BasicFontLarge",148,92 + 20,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,color_black)
			draw.SimpleTextOutlined("Used: " .. UsedReq,"BasicFontLarge",40,92 + 40,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)
			draw.SimpleTextOutlined("Cur: " .. CurReq .. "/" .. MaxReq,"BasicFontLarge",256,92 + 40,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_TOP,1,color_black)

			surface.SetDrawColor(color_black)
			surface.DrawRect(28,92 + 72,256 - 16,12)
			surface.SetDrawColor(0,255,0)
			surface.DrawRect(30,94 + 72,(256 - 20) * (CurReq / MaxReq),8)
			surface.SetDrawColor(255,0,0)
			surface.DrawRect(30,98 + 72,(256 - 20) * (UsedReq / MaxReq),4)

			if DupeCost.Draw == true then
				local DupePos = (DupeCost.HighCenter + Vector(0,0,32)):ToScreen()
				local DupeRPos = DupeCost.HighCenter:ToScreen()

				surface.SetDrawColor(100,100,100)
				surface.DrawLine(DupePos.x,DupePos.y,DupeRPos.x,DupeRPos.y)

				surface.DrawRect(DupePos.x,DupePos.y,128,20)
				draw.SimpleTextOutlined("COST: ","BasicFontLarge",DupePos.x + 4,DupePos.y + 10,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,color_black)
				draw.SimpleTextOutlined(tostring(DupeCost.Cost),"BasicFontLarge",DupePos.x + 124,DupePos.y + 10,Color(255,0,0),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER,1,color_black)

				surface.DrawRect(DupePos.x,DupePos.y - DupeCost.BreakdownCount * 16,4,DupeCost.BreakdownCount * 16)

				local int = 0
				for k,v in pairs(DupeCost.CostBreakdown) do
					int = int + 1
					draw.SimpleTextOutlined(k .. ": " .. math.Round(v,2),"BasicFont14",DupePos.x + 8,DupePos.y - (16 * int) + 6,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,color_black)
				end

				if SysTime() >= DupeCost.Time then DupeCost = {Draw = false} end
			end

			local Points = ents.FindByClass("aas_point")
			local CanIgnoreDraw = GetGlobalBool("EditMode",false)

			draw.NoTexture()
			surface.SetDrawColor(Color(255,255,255))
			local PlyPos = EyePos()

			for k,v in ipairs(Points) do
				if CanIgnoreDraw or checkConnection(v,AAS.RAASLine,AAS.RAASLookup,Team) then
					local Pos = v:GetPos()
					local Dist = PlyPos:DistToSqr(Pos)
					local Dist2 = math.max(Dist - 20000,0)
					local Pos2 = (Pos + Vector(0,0,256 + 32 + math.min(1200,Dist2 / 60000))):ToScreen()

					local PointName = AAS.LocalAlias[v:GetPointName()] or v:GetPointName()

					local Poly = {}

					for I = 1,6 do
						local Ang = math.rad(60 * I)
						Poly[I] = {x = Pos2.x + (math.cos(Ang) * PointScale), y = Pos2.y + (math.sin(Ang) * PointScale)}
					end

					local PointCol = CapColor(v:GetCapture())
					surface.SetDrawColor(PointCol)
					surface.DrawPoly(Poly)

					draw.SimpleTextOutlined(PointName,"BasicFont",Pos2.x,Pos2.y,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)

					if Dist < AAS.CapInfoRange then
						local Pos3 = Vector(Pos.x,Pos.y,EyePos().z):ToScreen()

						local CapAmount = v:GetCapture()
						local ReqCap = Team == 1 and 100 or -100

						local IsSpawn = v:GetIsSpawn()

						if not IsSpawn then
							if (CapAmount ~= ReqCap) and (Dist <= AAS.CapRange) then draw.SimpleTextOutlined("CAPTURING: " .. math.abs(CapAmount),"BasicFontLarge",Pos3.x,Pos3.y,CapColor(CapAmount),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black) end

							if CapStatus(v) == Team then
								draw.SimpleTextOutlined("USE: Ammo","BasicFontLarge",Pos3.x,Pos3.y + 24,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
							end
						elseif CapAmount == ReqCap then
							draw.SimpleTextOutlined("USE: Free Ammo","BasicFontLarge",Pos3.x,Pos3.y,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
							draw.SimpleTextOutlined("USE: Open Loadout","BasicFontLarge",Pos3.x,Pos3.y + 24,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
						end
					end
				end
			end
		end)

		-- Draws a line between each point that the player knows about
		-- Also draws an outlined box around the player's team spawn, and an opaque box around the enemy spawn
		-- When if EditMode, will draw boxes around all spawnpoints
		local ColorWheel = 0
		hook.Add("PostDrawOpaqueRenderables","EditMode3D",function(depth,skybox,skybox3D)
			if AAS.RAASFinished then
				if not IsValid(AAS.RAASLine[1]) then AAS.RAASFinished = false return end
				local CanIgnoreDraw = GetGlobalBool("EditMode")

				render.SetColorMaterial()

				local Team = LP:Team()
				local OpTeam = (Team == 1 and 2 or 1)

				local Spawn = AAS.PointAlias[Team == 1 and "SpawnA" or "SpawnB"]
				local OpSpawn = AAS.PointAlias[Team == 1 and "SpawnB" or "SpawnA"]

				if (LP:GetPos():Distance(Spawn:GetPos()) < 2500) and not skybox3D then
					render.DrawWireframeBox(Spawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,Colors.White,false)
					local R,G,B = AAS.TeamData[Team].Color:Unpack()
					local BoxCol = Color(R,G,B,32)
					render.DrawBox(Spawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,BoxCol)
					render.DrawBox(Spawn:GetPos(),Angle(),AAS.SpawnBoundA * Vector(-1,1,1),AAS.SpawnBoundB * Vector(-1,1,1),BoxCol)
				end

				if (LP:GetPos():Distance(OpSpawn:GetPos()) < 5000) and not skybox3D then
					local R,G,B = AAS.TeamData[OpTeam].Color:Unpack()
					local BoxCol = Color(R,G,B,255)
					render.OverrideDepthEnable(true,true)
					render.DrawBox(OpSpawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,BoxCol)
					render.OverrideDepthEnable(false,false)
				end

				for I = 2,#AAS.RAASLine do
					local PointA,PointB = AAS.RAASLine[I-1],AAS.RAASLine[I]
					if not (PointA:IsValid() and PointB:IsValid()) then continue end

					if (isConnectedTo(PointA,PointB,AAS.RAASLookup,Team) or CanIgnoreDraw) and not AAS.NonLinear and not skybox3D then
						local Col = mixColor(CapColor(PointA.InterpCapture),CapColor(PointB.InterpCapture),0.5)
						render.DrawLine(PointA:GetPos() + Vector(0,0,256),PointB:GetPos() + Vector(0,0,256),Col,false)

						render.OverrideDepthEnable(true,true)
						render.DrawBeam(PointA:GetPos() + Vector(0,0,256),PointB:GetPos() + Vector(0,0,256),5,1,1,Col)
						render.OverrideDepthEnable(false,false)
					end
				end
			end

			if GetGlobalBool("EditMode",false) and not skybox3D then
				local Spawns = ents.FindByClass("aas_spawnpoint")
				render.SetColorMaterial()

				render.OverrideDepthEnable(true,true)
				for k,v in ipairs(Spawns) do
					local Pos = v:GetPos()
					local SpawnColor = HSVToColor(ColorWheel + 15 * k,1,0.5)

					render.DrawBox(Pos + Vector(0,0,36),v:GetAngles(),Vector(16,-16,-36),Vector(-16,16,36),SpawnColor)
					render.DrawLine(Pos + Vector(0,0,36),Pos + Vector(0,0,36) + v:GetForward() * 32,color_white,false)
				end
				render.OverrideDepthEnable(false,false)
			end

			ColorWheel = ColorWheel + (FrameTime() * 10)
			if ColorWheel >= 360 then ColorWheel = ColorWheel - 360 end
		end)
	end
end