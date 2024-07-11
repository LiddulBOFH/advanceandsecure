include("shared.lua")
local LP = LocalPlayer()

AAS.ServerRAAS = nil
AAS.RAASLine = nil
AAS.RAASLookup = nil
AAS.RAASFinished = false

AAS.LocalAlias = {["SpawnA"] = "SpawnA",["SpawnB"] = "SpawnB"}

local PointBaseColor = Color(65,65,65)
local PlyColor = Color(0,127,0)

local SW,SH = ScrW(),ScrH()
local SM = {x = SW / 2, y = SH / 2}
local UU = ((SW > SH) and SH or SW) / 12

local HUDHide = {["CHudHealth"] = true,["CHUDQuickInfo"] = true,["CHudBattery"] = true}

concommand.Remove("votemap") -- Removes common votemap command, particularly important and cheap for me to do for BAdmin

local HintList = {}
--HintList[#HintList + 1] = {time = 5,text = ""}
HintList[#HintList + 1] = {time = 7.5,text = "You gain or lose karma depending on how you play.\nCapturing points gives you GOOD karma (but only if you aren't sitting!).\nTeamkilling or being in the enemy safezone gives you BAD karma."}
HintList[#HintList + 1] = {time = 5,text = "Spawning will give you ammo for free.\nThat involves dying though..."}
HintList[#HintList + 1] = {time = 5,text = "Press E on a captured point to get ammo, for a price!"}
HintList[#HintList + 1] = {time = 5,text = "You will regularly gain Requisition, which is adjusted by karma."}
HintList[#HintList + 1] = {time = 5,text = "You can noclip, but only inside of your own safezone."}
HintList[#HintList + 1] = {time = 7.5,text = "Press E on your home flag to change loadout!\nAmmo is also free from here."}
HintList[#HintList + 1] = {time = 5,text = "That armor might be beneficial to your survival..."}
HintList[#HintList + 1] = {time = 7.5,text = "Capturing points gives your team tickets!\nKilling enemies makes them lose tickets!"}
HintList[#HintList + 1] = {time = 7.5,text = "Points are considered 'captured' at 25%, but capturing more doesn't hurt"}

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
		if not IsValid(v) then net.Start("aas_playerinit") net.SendToServer() return end
		v:SetPredictable(true)
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

local BaseFont = "Arial"

surface.CreateFont("BasicFont", {
	font = BaseFont,
	size = 12,
	weight = 600,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

surface.CreateFont("BasicFont14", {
	font = BaseFont,
	size = 14,
	weight = 600,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

surface.CreateFont("BasicFontLarge", {
	font = BaseFont,
	size = 20,
	weight = 600,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

surface.CreateFont("BasicFontExtraLarge", {
	font = BaseFont,
	size = 64,
	weight = 600,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

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

local HintTime = CurTime()
local HintIndex
local function GetHint()
	if CurTime() <= HintTime then
		return HintList[HintIndex].text
	else
		local pickHintIndex = math.random(1,#HintList)
		if pickHintIndex == HintIndex then
			return ""
		else
			HintIndex = pickHintIndex
			HintTime = CurTime() + HintList[HintIndex].time
			return HintList[HintIndex].text
		end
	end
end

local function localizeToPanel(Vec3,Panel)
	return {x = ((Vec3.x / 16384) * (Panel:GetWide() / 2)) + (Panel:GetWide() / 2), y = ((-Vec3.y / 16384) * (Panel:GetTall() / 2)) + (Panel:GetTall() / 2)}
end

local function PointChange(Point,OldStatus,NewStatus)
	if PointChangeBase then PointChangeBase:Remove() end

	PointChangeBase = vgui.Create("Panel")
	PointChangeBase:SetSize(UU * 8,UU * 2)
	PointChangeBase:CenterHorizontal(0.5)
	PointChangeBase:CenterVertical(0.25)
	PointChangeBase:AlphaTo(0,1,4,function(_,panel) panel:Remove() end)
	PointChangeBase.Paint = function(self,w,h)
		if not AAS.TeamData then net.Start("aas_playerinit") net.SendToServer() PointChangeBase:Remove() end -- somehow we lost vital data??
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
			CapText = "Captured by " .. AAS.TeamData[CappingTeam].Name
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

local function ShowScoreboard()
	local BluTD = AAS.TeamData[1]
	local BluCol = {r = BluTD.Color.r,g = BluTD.Color.g,b = BluTD.Color.b}

	local OpTD = AAS.TeamData[2]
	local OpCol = {r = OpTD.Color.r,g = OpTD.Color.g,b = OpTD.Color.b}

	ScoreboardBase = vgui.Create("Panel")
	ScoreboardBase:SetSize(UU * 18,UU * 8)
	ScoreboardBase:SetPos(0,0)
	ScoreboardBase.Paint = function(self,w,h)
		surface.SetDrawColor(127,127,127,200)
		surface.DrawRect(0,0,w,h)
	end
	ScoreboardBase:Center()

	ScoreboardBase:MakePopup()
	ScoreboardBase:SetKeyboardInputEnabled(false)

	local BLUFORPlyList = vgui.Create("Panel",ScoreboardBase)
	BLUFORPlyList:SetSize(UU * 5,ScoreboardBase:GetTall())
	BLUFORPlyList:Dock(2)
	local TH = UU * 0.3
	BLUFORPlyList.Paint = function(self,w,h)
		surface.SetDrawColor(BluCol.r,BluCol.g,BluCol.b,255)
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(65,65,65)
		surface.DrawRect(8,8,w - 16,h - 16)

		draw.SimpleText(AAS.TeamData[1].Name,"BasicFontLarge",UU * 2.5,TH / 2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

		draw.SimpleText("Name","BasicFont14",UU * 0.15, TH,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
		draw.SimpleText("K : D","BasicFont14",UU * 1.95, TH,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

		if LP:Team() == 1 then
			draw.SimpleText("Requisition","BasicFont14",UU * 2.75, TH,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			draw.SimpleText("Used","BasicFont14",UU * 3.75, TH,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end

		draw.SimpleText("Ping","BasicFont14",UU * 4.9, TH,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
	end
	BLUFORPlyList:DockPadding(0,UU * 0.4,0,0)

	local TeamA = team.GetPlayers(1)
	table.sort(TeamA,function(a,b)
		local ScoreA = a:Frags() - a:Deaths()
		local ScoreB = b:Frags() - b:Deaths()
		return ScoreA > ScoreB
	end)
	for k,v in ipairs(TeamA) do
		local ListedPly = vgui.Create("Panel",BLUFORPlyList)
		ListedPly:SetSize(0,UU * 0.3)
		ListedPly:Dock(4)
		ListedPly:DockMargin(8,2,8,0)
		local N = v:Nick()
		if #N > 17 then N = string.sub(N,1,17) .. "..." end
		ListedPly.Paint = function(self,w,h)
			surface.SetDrawColor(100,100,100,255)
			surface.DrawRect(0,0,w,h)
			local H = self:GetTall() / 2

			draw.SimpleText(N,"BasicFont",UU * 0.35,H,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

			draw.SimpleText(v:Frags(),"BasicFont",UU * 1.9,H,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
			draw.SimpleText(":","BasicFont",UU * 1.95,H,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			draw.SimpleText(v:Deaths(),"BasicFont",UU * 2,H,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

			if LP:Team() == 1 then
				draw.SimpleText(v:GetNW2Int("Requisition",0),"BasicFont14",UU * 2.75,H,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
				draw.SimpleText(v:GetNW2Int("UsedRequisition",0),"BasicFont14",UU * 3.75,H,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(v:Ping(),"BasicFont14",UU * 4.8,H,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
		end

		local PlyPic = vgui.Create("AvatarImage",ListedPly)
		PlyPic:SetPlayer(v,32)
		PlyPic:SetSize(UU * 0.3,UU * 0.3)
		PlyPic:Dock(2)

		if v:SteamID64() ~= nil then
			local PlyPicButton = vgui.Create("DButton",PlyPic)
			PlyPicButton:StretchToParent()
			PlyPicButton:SetText("")
			PlyPicButton.Paint = function(self,w,h) end
			PlyPicButton.DoClick = function()
				gui.OpenURL("http://steamcommunity.com/profiles/" .. v:SteamID64())
			end
		end
	end

	local OPFORPlyList = vgui.Create("Panel",ScoreboardBase)
	OPFORPlyList:SetSize(UU * 5,ScoreboardBase:GetTall())
	OPFORPlyList:Dock(3)
	OPFORPlyList.Paint = function(self,w,h)
		surface.SetDrawColor(OpCol.r,OpCol.g,OpCol.b,255)
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(65,65,65)
		surface.DrawRect(8,8,w - 16,h - 16)

		draw.SimpleText(AAS.TeamData[2].Name,"BasicFontLarge",UU * 2.5,TH / 2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

		draw.SimpleText("Name","BasicFont14",UU * 0.15, TH,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
		draw.SimpleText("K : D","BasicFont14",UU * 1.95, TH,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

		if LP:Team() == 2 then
			draw.SimpleText("Requisition","BasicFont14",UU * 2.75, TH,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			draw.SimpleText("Used","BasicFont14",UU * 3.75, TH,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end

		draw.SimpleText("Ping","BasicFont14",UU * 4.9, TH,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
	end
	OPFORPlyList:DockPadding(0,UU * 0.4,0,0)

	local TeamB = team.GetPlayers(2)
	table.sort(TeamB,function(a,b)
		local ScoreA = a:Frags() - a:Deaths()
		local ScoreB = b:Frags() - b:Deaths()
		return ScoreA > ScoreB
	end)
	for k,v in ipairs(TeamB) do
		local ListedPly = vgui.Create("Panel",OPFORPlyList)
		ListedPly:SetSize(0,UU * 0.3)
		ListedPly:Dock(4)
		ListedPly:DockMargin(8,2,8,0)
		local N = v:Nick()
		if #N > 17 then N = string.sub(N,1,17) .. "..." end
		ListedPly.Paint = function(self,w,h)
			surface.SetDrawColor(100,100,100,255)
			surface.DrawRect(0,0,w,h)
			local H = self:GetTall() / 2

			draw.SimpleText(N,"BasicFont",UU * 0.35,H,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

			draw.SimpleText(v:Frags(),"BasicFont",UU * 1.9,H,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
			draw.SimpleText(":","BasicFont",UU * 1.95,H,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			draw.SimpleText(v:Deaths(),"BasicFont",UU * 2,H,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

			if LP:Team() == 2 then
				draw.SimpleText(v:GetNW2Int("Requisition",0),"BasicFont14",UU * 2.75,H,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
				draw.SimpleText(v:GetNW2Int("UsedRequisition",0),"BasicFont14",UU * 3.75,H,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(v:Ping(),"BasicFont14",UU * 4.8,H,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
		end

		local PlyPic = vgui.Create("AvatarImage",ListedPly)
		PlyPic:SetPlayer(v,32)
		PlyPic:SetSize(UU * 0.3,UU * 0.3)
		PlyPic:Dock(2)

		if v:SteamID64() ~= nil then
			local PlyPicButton = vgui.Create("DButton",PlyPic)
			PlyPicButton:StretchToParent()
			PlyPicButton:SetText("")
			PlyPicButton.Paint = function(self,w,h) end
			PlyPicButton.DoClick = function()
				gui.OpenURL("http://steamcommunity.com/profiles/" .. v:SteamID64())
			end
		end
	end

	local MapBox = vgui.Create("Panel",ScoreboardBase)
	MapBox:SetSize(UU * 7,UU * 7)
	MapBox:SetPos(UU * (9 - 3.5), 0)
	MapBox.Paint = function(self,w,h)
		surface.SetDrawColor(65,65,65,255)
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(8,8,8,255)
		surface.DrawRect(4,4,w - 8,h - 8)

		local PlyTeam = LP:Team()

		if AAS.RAASFinished then
			for k,v in ipairs(AAS.RAASLine) do
				if not checkConnection(v,AAS.RAASLine,AAS.RAASLookup,PlyTeam) then continue end
				local Pos = v:GetPos()
				local LocPos = {x = Pos.x / 16384,y = -Pos.y / 16384}
				local Cap = v:GetCapture()
				local Col = CapColor(Cap)

				local FinalX,FinalY = (LocPos.x * (self:GetWide() / 2)) + (self:GetWide() / 2) + (UU * 0.1),(LocPos.y * (self:GetTall() / 2)) + (self:GetTall() / 2) + (UU * 0.1)

				if k > 1 then
					local P2 = AAS.RAASLine[k - 1]
					if checkConnection(P2,AAS.RAASLine,AAS.RAASLookup,PlyTeam) and not AAS.NonLinear then
						local LineCol = mixColor(CapColor(Cap),CapColor(P2:GetCapture()),0.5)
						local EP = P2:GetPos()
						local LocPos2 = {x = EP.x / 16384,y = -EP.y / 16384}
						local StartX,StartY = (LocPos2.x * (self:GetWide() / 2)) + (self:GetWide() / 2) + (UU * 0.1),(LocPos2.y * (self:GetTall() / 2)) + (self:GetTall() / 2) + (UU * 0.1)
						surface.SetDrawColor(LineCol)
						surface.DrawLine(StartX,StartY,FinalX,FinalY)
					end
				end

				local PointName = AAS.LocalAlias[v:GetPointName()] or v:GetPointName()

				draw.SimpleTextOutlined(PointName,"BasicFontLarge",FinalX,FinalY - (UU * 0.2),Col,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
			end
		end
	end

	if AAS.RAASFinished then
		for k,v in ipairs(AAS.RAASLine) do
			local Pos = v:GetPos()
			local LocPos = {x = Pos.x / 16384,y = -Pos.y / 16384}

			local MapMarker = vgui.Create("DButton",MapBox)
			MapMarker:SetPos((LocPos.x * (MapBox:GetWide() / 2)) + (MapBox:GetWide() / 2),(LocPos.y * (MapBox:GetTall() / 2)) + (MapBox:GetTall() / 2))
			MapMarker:SetSize(UU * 0.2, UU * 0.2)
			MapMarker:SetText("")
			MapMarker.Paint = function(self,w,h)
				local HasCon = checkConnection(v,AAS.RAASLine,AAS.RAASLookup,LP:Team())
				self:SetMouseInputEnabled(HasCon)
				if HasCon then draw.RoundedBox(4,0,0,w,h,CapColor(v:GetCapture())) end
			end
			MapMarker.DoClick = function()
				local PointName = AAS.LocalAlias[v:GetPointName()] or v:GetPointName()
				if CapStatus(v) == LP:Team() then
					RunConsoleCommand("say_team","Defend the " .. PointName .. " point!")
				else
					RunConsoleCommand("say_team","Attack the " .. PointName .. " point!")
				end
			end
		end
	end

	for k,v in ipairs(team.GetPlayers(LP:Team())) do
		local PlyMarker = vgui.Create("DButton",MapBox)
		PlyMarker:SetSize(UU * 0.15, UU * 0.15)
		PlyMarker:SetText("")
		PlyMarker:NoClipping(true)
		PlyMarker.Paint = function(self,w,h)
			local Pos2D = localizeToPanel(v:GetPos(),MapBox)

			self:SetPos(Pos2D.x,Pos2D.y)

			draw.RoundedBox(24,0,0,w,h,PlyColor)
			local Ang = math.rad(-v:EyeAngles().y)
			local AngX,AngY = math.cos(Ang),math.sin(Ang)
			surface.SetDrawColor(color_white)
			surface.DrawLine(UU * 0.075,UU * 0.075,(AngX * UU * 0.075) + UU * 0.075,(AngY * UU * 0.075) + UU * 0.075)

			draw.SimpleText(v:Nick(),"BasicFont",UU * 0.075,UU * -0.1,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
		PlyMarker.DoClick = function()
			if (v:Team() == LP:Team()) and (v ~= LP) then
				RunConsoleCommand("say_team","Hey " .. v:Name() .. ", wait for me!")
			end
		end
	end

	local ButtonBase = vgui.Create("Panel",ScoreboardBase)
	ButtonBase:SetSize(UU,UU * 0.8)
	ButtonBase:DockMargin(UU * 0.1,0,UU * 0.1,UU * 0.1)
	ButtonBase:Dock(BOTTOM)
	ButtonBase.Paint = function(self,w,h)
		surface.SetDrawColor(27,27,27,255)
		surface.DrawRect(0,0,w,h)
	end

	local RequestScript = vgui.Create("DButton",ButtonBase)
	RequestScript:SetSize(UU * 2,UU * 0.8)
	RequestScript:SetText("")
	RequestScript:DockMargin(8,0,0,0)
	RequestScript:Dock(RIGHT)
	RequestScript.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,127,0,127) else surface.SetDrawColor(127,65,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("REQUEST SCRIPTS","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	RequestScript.DoClick = function()
		net.Start("aas_requestcostscript")
		net.SendToServer()
	end

	local RequestDupes = vgui.Create("DButton",ButtonBase)
	RequestDupes:SetSize(UU * 2,UU * 0.8)
	RequestDupes:SetText("")
	RequestDupes:DockMargin(0,0,8,0)
	RequestDupes:Dock(LEFT)
	RequestDupes.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,127,0,127) else surface.SetDrawColor(127,65,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("REQUEST DUPES","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	RequestDupes.DoClick = function()
		if AdvDupe2 then
			net.Start("aas_requestdupes")
			net.SendToServer()
		else
			chat.AddText(Color(255,0,0),"AdvDupe2 is not available!")
		end
	end

	local SwapTeam = vgui.Create("DButton",ButtonBase)
	SwapTeam:SetSize(UU,UU * 0.8)
	SwapTeam:SetText("")
	SwapTeam:DockMargin(0,0,0,0)
	SwapTeam:Dock(FILL)
	SwapTeam.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,127,0,127) else surface.SetDrawColor(127,65,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("SWITCH TEAM","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	SwapTeam.DoClick = function()
		net.Start("aas_requestteam")
		net.SendToServer()
	end
end

function GM:ScoreboardShow()
	ShowScoreboard()
end

function GM:ScoreboardHide()
	if ScoreboardBase then ScoreboardBase:Remove() end
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
		net.Start("aas_UpdateServerSettings")
			net.WriteTable(Settings)
		net.SendToServer()

		SettingsBase:Remove()
	end
end
if SettingsBase then SettingsBase:Remove() end

net.Receive("aas_opensettings",function()
	SVProperties = net.ReadTable()
	SettingsMenu()
end)

local Loadout = {}

local function LoadoutMenu()
	if LoadoutBase then LoadoutBase:Remove() end
	if not PlyInSafezone(LP,LP:GetPos()) then return end -- Somehow they set this off, we're gonna prevent it if we can

	local SelectedTab = "Primary"

	LoadoutBase = vgui.Create("DFrame")
	LoadoutBase:SetSize(800,344)
	LoadoutBase:SetPos(0,0)
	LoadoutBase.Paint = function(self,w,h)
		surface.SetDrawColor(127,127,127,255)
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(75,75,75)
		surface.DrawRect(0,0,w,24)
	end
	LoadoutBase:Center()
	LoadoutBase:MakePopup()
	LoadoutBase:SetDraggable(false)
	LoadoutBase:ShowCloseButton(false)
	LoadoutBase:SetTitle("Player Loadout")

	local LoadoutList

	local PrimaryLoadoutButton = vgui.Create("DButton",LoadoutBase) -- Primary Weapon
	PrimaryLoadoutButton.Slot = "Primary"
	PrimaryLoadoutButton:SetPos(8,32)
	PrimaryLoadoutButton:SetSize(240,56)
	PrimaryLoadoutButton:SetText("")
	PrimaryLoadoutButton.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)
		end

		surface.SetDrawColor(25,25,25,255)
		surface.DrawRect(0,h / 2,w,h / 2)

		draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

		local Text = "EMPTY"
		if Loadout.Primary ~= "" then Text = NewPlyManager.Weapons[Loadout.Primary].Name end
		draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
	end
	PrimaryLoadoutButton.DoClick = function(self)
		SelectedTab = self.Slot
		LoadoutList:Populate()
	end

	local SecondaryLoadoutButton = vgui.Create("DButton",LoadoutBase) -- Sidearm
	SecondaryLoadoutButton.Slot = "Sidearm"
	SecondaryLoadoutButton:SetPos(8,32 + 60)
	SecondaryLoadoutButton:SetSize(240,56)
	SecondaryLoadoutButton:SetText("")
	SecondaryLoadoutButton.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)
		end

		surface.SetDrawColor(25,25,25,255)
		surface.DrawRect(0,h / 2,w,h / 2)

		draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

		local Text = "EMPTY"
		if Loadout.Sidearm ~= "" then Text = NewPlyManager.Weapons[Loadout.Sidearm].Name end
		draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
	end
	SecondaryLoadoutButton.DoClick = function(self)
		SelectedTab = self.Slot
		LoadoutList:Populate()
	end

	local Gad1LoadoutButton = vgui.Create("DButton",LoadoutBase) -- Gadget 1
	Gad1LoadoutButton.Slot = "Gadget 1"
	Gad1LoadoutButton:SetPos(8,32 + 120)
	Gad1LoadoutButton:SetSize(240,56)
	Gad1LoadoutButton:SetText("")
	Gad1LoadoutButton.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)
		end

		surface.SetDrawColor(25,25,25,255)
		surface.DrawRect(0,h / 2,w,h / 2)

		draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

		local Text = "EMPTY"
		if Loadout.Gadget1 ~= "" then Text = NewPlyManager.Gadgets[Loadout.Gadget1].Name end
		draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
	end
	Gad1LoadoutButton.DoClick = function(self)
		SelectedTab = self.Slot
		LoadoutList:Populate()
	end

	local Gad2LoadoutButton = vgui.Create("DButton",LoadoutBase) -- Gadget 2
	Gad2LoadoutButton.Slot = "Gadget 2"
	Gad2LoadoutButton:SetPos(8,32 + 180)
	Gad2LoadoutButton:SetSize(240,56)
	Gad2LoadoutButton:SetText("")
	Gad2LoadoutButton.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)
		end

		surface.SetDrawColor(25,25,25,255)
		surface.DrawRect(0,h / 2,w,h / 2)

		draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

		local Text = "EMPTY"
		if Loadout.Gadget2 ~= "" then Text = NewPlyManager.Gadgets[Loadout.Gadget2].Name end
		draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
	end
	Gad2LoadoutButton.DoClick = function(self)
		SelectedTab = self.Slot
		LoadoutList:Populate()
	end

	LoadoutList = vgui.Create("DListView",LoadoutBase)
	LoadoutList:SetPos(256,32)
	LoadoutList:SetSize(280,400-96)
	LoadoutList:AddColumn("Name",1)
	LoadoutList:SetMultiSelect(false)
	LoadoutList:SetSortable(false)
	LoadoutList.Index = {}
	local C1 = LoadoutList:AddColumn("Type",2)
	C1:SetFixedWidth(60)
	local C2 = LoadoutList:AddColumn("Cost",3)
	C2:SetFixedWidth(28)
	local C3 = LoadoutList:AddColumn("WU",4)
	C3:SetFixedWidth(24)

	local T = vgui.Create("DLabel",LoadoutBase)
	T:SetPos(12,32 + 240)
	T:SetText("Armor Slider (DEFAULT: " .. NewPlyManager.DefaultLoadout.Armor .. ")")
	T:SizeToContents()

	ArmorSlider = vgui.Create("DNumSlider",LoadoutBase)
	ArmorSlider:SetPos(-140,32 + 260)
	ArmorSlider:SetSize(400,25)
	ArmorSlider:SetDecimals(0)
	ArmorSlider:SetMinMax(0,100)
	ArmorSlider:SetValue(Loadout.Armor)
	ArmorSlider.OnValueChanged = function(self,val)
		Loadout.Armor = math.Clamp(math.Round(val),0,100) -- just extra insurance
		ArmorSlider:SetValue(math.Clamp(math.Round(val),0,100))
		InfoPanel:CalcInfo()
	end

	InfoPanel = vgui.Create("DPanel",LoadoutBase)
	InfoPanel:SetPos(256 + 280 + 8,32)
	InfoPanel:SetSize(248,110)

	InfoPanel.Cost = 0
	InfoPanel.Movespeed = 0
	InfoPanel.WU = 0

	InfoPanel.CalcInfo = function()
		local Cost = 0
		local WU = -12.5 -- Starting armor of 25 has no speed penalty, call it conditioning
		local Movespeed = NewPlyManager.BaseMoveSpeed

		if Loadout.Primary ~= "" then
			local Wep = NewPlyManager.Weapons[Loadout.Primary]
			Cost = Cost + Wep.Cost
			WU = WU + Wep.WU
		end

		if Loadout.Sidearm ~= "" then
			local Wep = NewPlyManager.Weapons[Loadout.Sidearm]
			Cost = Cost + Wep.Cost
			WU = WU + Wep.WU
		end

		if Loadout.Gadget1 ~= "" then
			local Gdgt = NewPlyManager.Gadgets[Loadout.Gadget1]
			Cost = Cost + Gdgt.Cost
			WU = WU + Gdgt.WU
		end

		if Loadout.Gadget2 ~= "" then
			local Gdgt = NewPlyManager.Gadgets[Loadout.Gadget2]
			Cost = Cost + Gdgt.Cost
			WU = WU + Gdgt.WU
		end

		local Armor = math.floor(Loadout.Armor)

		WU = math.max(WU + (Armor / 3),0)
		Cost = Cost + math.ceil(math.max(0,Armor - 25) / 2)

		InfoPanel.Cost = Cost
		InfoPanel.WU = math.Round(WU,1)
		InfoPanel.Movespeed = math.Clamp(math.ceil(Movespeed - (WU * 2.5)),NewPlyManager.MinMoveSpeed,Movespeed)

		--print(InfoPanel.Cost,InfoPanel.WU,InfoPanel.Movespeed)
	end
	InfoPanel:CalcInfo()

	local MovespeedDiff = NewPlyManager.BaseMoveSpeed - NewPlyManager.MinMoveSpeed
	InfoPanel.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		draw.SimpleText("COST: " .. self.Cost,"BasicFont14",4,21,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)
		draw.SimpleText("CURRENT: " .. LP:GetNW2Int("Requisition",0),"BasicFont14",w / 2,21,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)
		draw.SimpleText("WEIGHT: " .. self.WU,"BasicFont14",4,57,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)
		draw.SimpleText("MOVESPEED: " .. self.Movespeed,"BasicFont14",4,93,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)

		surface.SetDrawColor(25,25,25,255)
		surface.DrawRect(0,21,w,16)
		surface.DrawRect(0,57,w,16)
		surface.DrawRect(0,93,w,16)

		surface.SetDrawColor(0,255,0,255)
		surface.DrawRect(1,21,(w - 2) * (LP:GetNW2Int("Requisition",0) / AAS.MaxRequisition),14)
		surface.SetDrawColor(255,0,0,255)
		surface.DrawRect(1,28,(w - 2) * (self.Cost / AAS.MaxRequisition),7)

		local Mix = math.max(0,self.Movespeed - NewPlyManager.MinMoveSpeed) / MovespeedDiff
		local Color1 = Vector(255,0,0)
		local Color2 = Vector(0,255,0)
		local ColMix = Lerp(Mix, Color1, Color2)
		surface.SetDrawColor(ColMix.x, ColMix.y, ColMix.z, 255)

		surface.DrawRect(1,94,(w - 2) * Mix,14)
	end

	local ApplyLoadout = vgui.Create("DButton",LoadoutBase) -- Sends the selected loadout to the server, subject to one last legal check (those pesky clients can't be trusted!)
	ApplyLoadout:SetPos(544 + 126, 252)
	ApplyLoadout:SetSize(122,84)
	ApplyLoadout:SetText("")
	ApplyLoadout.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("APPLY","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	ApplyLoadout.DoClick = function(self)
		net.Start("aas_receiveplayerloadout")
			net.WriteTable(Loadout)
		net.SendToServer()

		LoadoutBase:Remove()
	end

	local Cancel = vgui.Create("DButton",LoadoutBase)
	Cancel:SetPos(544,296)
	Cancel:SetSize(122,40)
	Cancel:SetText("")
	Cancel.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,127) else surface.SetDrawColor(127,0,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("CANCEL","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	Cancel.DoClick = function(self)
		LoadoutBase:Remove()
	end

	local Default = vgui.Create("DButton",LoadoutBase)
	Default:SetPos(544,252)
	Default:SetSize(122,40)
	Default:SetText("")
	Default.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,127,0,127) else surface.SetDrawColor(127,65,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("DEFAULT","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	Default.DoClick = function(self)
		Loadout = table.Copy(NewPlyManager.DefaultLoadout)
		ArmorSlider:SetValue(Loadout.Armor)
		LoadoutList:Populate()
	end

	local AltCancel = vgui.Create("DButton",LoadoutBase)
	AltCancel:SetPos(800 - 24,0)
	AltCancel:SetSize(24,24)
	AltCancel:SetText("")
	AltCancel.Paint = function(self,w,h)
		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,255) else surface.SetDrawColor(127,0,0,255) end
		surface.DrawRect(0,0,w,h)
	end
	AltCancel.DoClick = function(self)
		LoadoutBase:Remove()
	end

	LoadoutList.Populate = function(self)
		self:Clear()

		local Select
		local Empty = self:AddLine("Empty","Empty",0,0)
		Empty.ID = ""

		if SelectedTab == "Primary" then
			for k,v in pairs(NewPlyManager.Weapons) do
				if v.Type ~= "Pistol" then
					local Line = self:AddLine(v.Name,v.Type,v.Cost,v.WU)
					Line.ID = k
					if k == Loadout.Primary then Select = Line end
				end
			end
		elseif SelectedTab == "Sidearm" then
			for k,v in pairs(NewPlyManager.Weapons) do
				if v.Type == "Pistol" then
					local Line = self:AddLine(v.Name,v.Type,v.Cost,v.WU)
					Line.ID = k
					if k == Loadout.Sidearm then Select = Line end
				end
			end
		else -- Gadget1/2
			local Block = ""
			if (SelectedTab == "Gadget 2") and Loadout.Gadget1 ~= "" then Block = NewPlyManager.Gadgets[Loadout.Gadget1].Type
			elseif (SelectedTab == "Gadget 1") and Loadout.Gadget2 ~= "" then Block = NewPlyManager.Gadgets[Loadout.Gadget2].Type end

			for k,v in pairs(NewPlyManager.Gadgets) do
				if v.Type == Block then continue end
				local Line = self:AddLine(v.Name,v.Type,v.Cost,v.WU)
				Line.ID = k
				if (k == Loadout.Gadget1) or (k == Loadout.Gadget2) then Select = Line end
			end
		end

		if Select then self:SelectItem(Select) else self:SelectItem(Empty) end

		self:SortByColumns(3,false,4,false,1,false)
		self:SetSortable(false)
	end

	LoadoutList.OnRowSelected = function(self,index,line)
		if SelectedTab == "Primary" then
			Loadout.Primary = line.ID
		elseif SelectedTab == "Sidearm" then
			Loadout.Sidearm = line.ID
		elseif SelectedTab == "Gadget 1" then
			Loadout.Gadget1 = line.ID
		else -- Gadget 2
			Loadout.Gadget2 = line.ID
		end

		InfoPanel:CalcInfo()
	end

	LoadoutList:Populate()

	local DescPanel = vgui.Create("DPanel",LoadoutBase)
	DescPanel:SetPos(544,146)
	DescPanel:SetSize(248,100)

	DescPanel.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)
		surface.SetDrawColor(50,50,50,255)

		draw.SimpleText("The buttons on the left are for selecting slots","BasicFont",4,4,Colors.White)
		draw.SimpleText("Tab selected: " .. SelectedTab,"BasicFont14",4,18,Colors.White)

		surface.DrawRect(0,33,w,2)

		draw.SimpleText("WU means Weight Units, they slow you down","BasicFont",4,36,Colors.White)
		draw.SimpleText("Weapons and armor both have WU","BasicFont",4,52,Colors.White)

		surface.DrawRect(0,65,w,2)

		draw.SimpleText("This loadout will cost you each time you apply","BasicFont",4,68,Colors.White)
		draw.SimpleText("It will cost each time you respawn too","BasicFont",4,84,Colors.White)
	end
end
if LoadoutBase then LoadoutBase:Remove() end

local Choices = {}
local RTV = false
local Time = SysTime() + 0

local function SendVote(choice)
	net.Start("aas_receivevote")
		net.WriteUInt(choice,3)
	net.SendToServer()
end

local function VoteMenu()
	if VotePanel then VotePanel:Remove() end

	VotePanel = vgui.Create("DFrame")
	VotePanel:SetSize(300,300)
	VotePanel:Center()
	VotePanel:SetDraggable(false)
	VotePanel:ShowCloseButton(false)
	VotePanel:MakePopup()
	VotePanel.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75)
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(25,25,25)
		surface.DrawRect(0,0,w,36)

		draw.SimpleText("MAP VOTING","BasicFontLarge",w / 2,10,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		local TimeLeft = math.Clamp(math.Round(Time - SysTime(),1),0,30)

		if TimeLeft < 10 then surface.SetDrawColor(127,0,0) else surface.SetDrawColor(0,127,0) end
		surface.DrawRect(0,h - 12,w * (TimeLeft / 30),12)
		draw.SimpleText("TIME REMAINING: " .. tostring(TimeLeft),"BasicFont",w / 2,h,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM)
	end
	VotePanel:SetTitle("")

	local shift = 0
	local selected = 0
	for k,v in ipairs(Choices) do
		local button = vgui.Create("DButton",VotePanel)
		button:SetSize(250,30)
		button:SetPos(25,60 + shift)
		button.ID = v
		button.Index = k
		button:SetText("")
		button.Paint = function(self,w,h)
			surface.SetDrawColor(25,25,25)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() then
				surface.SetDrawColor(0,65,0)
				surface.DrawRect(4,4,w - 8,h - 8)
			end

			if selected == self.Index then surface.SetDrawColor(0,127,0) else surface.SetDrawColor(100,100,100) end
			surface.DrawRect(0,0,h,h)

			draw.SimpleText(tostring(GetGlobalInt("vote_" .. self.Index,0)),"BasicFontLarge",h / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

			draw.SimpleText(self.ID,"BasicFont14",h + 4,h / 2,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
		end
		button.DoClick = function(self)
			if not GetGlobalBool("AAS.Voting",false) then return end
			selected = self.Index
			SendVote(self.Index)
		end

		shift = shift + 40
	end

	if RTV then -- allow rock the vote
		local button = vgui.Create("DButton",VotePanel)
		button:SetSize(250,30)
		button:SetPos(25,60 + shift)
		button.ID = "Refresh the vote"
		button.Index = 4
		button:SetText("")
		button.Paint = function(self,w,h)
			surface.SetDrawColor(25,25,25)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() then
				surface.SetDrawColor(0,65,0)
				surface.DrawRect(4,4,w - 8,h - 8)
			end

			if selected == self.Index then surface.SetDrawColor(0,127,0) else surface.SetDrawColor(100,100,100) end
			surface.DrawRect(0,0,h,h)

			draw.SimpleText(tostring(GetGlobalInt("vote_" .. self.Index,0)),"BasicFontLarge",h / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

			draw.SimpleText(self.ID,"BasicFont14",h + 4,h / 2,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
		end
		button.DoClick = function(self)
			if not GetGlobalBool("AAS.Voting",false) then return end
			selected = self.Index
			SendVote(self.Index)
		end

		shift = shift + 40
	end

	local button = vgui.Create("DButton",VotePanel)
	button:SetSize(250,30)
	button:SetPos(25,60 + shift)
	button.ID = "Reuse Current Map"
	button.Index = 5
	button:SetText("")
	button.Paint = function(self,w,h)
		surface.SetDrawColor(25,25,25)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() then
			surface.SetDrawColor(0,65,0)
			surface.DrawRect(4,4,w - 8,h - 8)
		end

		if selected == self.Index then surface.SetDrawColor(0,127,0) else surface.SetDrawColor(100,100,100) end
		surface.DrawRect(0,0,h,h)

		draw.SimpleText(tostring(GetGlobalInt("vote_" .. self.Index,0)),"BasicFontLarge",h / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

		draw.SimpleText(self.ID,"BasicFont14",h + 4,h / 2,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
	end
	button.DoClick = function(self)
		if not GetGlobalBool("AAS.Voting",false) then return end
		selected = self.Index
		SendVote(self.Index)
	end
end

concommand.Add("aas_requestcostscript",function()
	net.Start("aas_requestcostscript")
	net.SendToServer()
end)

local Dupes = {}
local function DupeMenu()
	if DupeMenuBase then DupeMenuBase:Remove() end

	DupeMenuBase = vgui.Create("DFrame")
	DupeMenuBase:SetSize(400,500)
	DupeMenuBase:SetPos(0,0)
	DupeMenuBase.Paint = function(self,w,h)
		surface.SetDrawColor(127,127,127,255)
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(75,75,75)
		surface.DrawRect(0,0,w,24)
	end
	DupeMenuBase:Center()
	DupeMenuBase:MakePopup()
	DupeMenuBase:SetDraggable(false)
	DupeMenuBase:ShowCloseButton(false)
	DupeMenuBase:SetTitle("Dupe Menu")

	local CloseDupeMenu = vgui.Create("DButton",DupeMenuBase)
	CloseDupeMenu:SetPos(400 - 24,0)
	CloseDupeMenu:SetSize(24,24)
	CloseDupeMenu:SetText("")
	CloseDupeMenu.Paint = function(self,w,h)
		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,255) else surface.SetDrawColor(127,0,0,255) end
		surface.DrawRect(0,0,w,h)
	end
	CloseDupeMenu.DoClick = function(self)
		DupeMenuBase:Remove()
	end

	local Allow = false
	local Data = {}
	DupeList = vgui.Create("DListView",DupeMenuBase)
	DupeList:SetPos(8,32)
	DupeList:SetSize(400 - 16,380)
	DupeList:AddColumn("Name",1)
	DupeList:SetMultiSelect(false)
	DupeList:SetSortable(false)
	DupeList.Index = {}
	local C = DupeList:AddColumn("Size",2)
	C:SetFixedWidth(96)

	DupeList.Populate = function(self)
		self:Clear()

		for k,v in pairs(Dupes) do
			local Line = self:AddLine(string.StripExtension(v.txt),v.strsize)
			Line.Data = v
		end

		self:SortByColumns(2,false,1,false)
		self:SetSortable(false)
	end
	DupeList:Populate()

	SelectedFileLabel = vgui.Create("DLabel",DupeMenuBase)
	SelectedFileLabel:SetFont("BasicFont14")
	SelectedFileLabel:SetSize(400,20)
	SelectedFileLabel:SetPos(12,416)
	SelectedFileLabel:SetText("SELECTED: NONE")

	DupeList.OnRowSelected = function(self,index,line)
		Allow = true
		Data = line.Data
		SelectedFileLabel:SetText("SELECTED: " .. Data.txt)
	end


	local DownloadButton = vgui.Create("DButton",DupeMenuBase) -- Sends the selected loadout to the server, subject to one last legal check (those pesky clients can't be trusted!)
	DownloadButton:SetPos(200,436)
	DownloadButton:SetSize(200 - 8,58)
	DownloadButton:SetText("")
	DownloadButton.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if Allow then
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)

			draw.SimpleText("DOWNLOAD","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		else
			surface.SetDrawColor(255,0,0,127)
			surface.DrawRect(4, 4, w - 8, h - 8)

			draw.SimpleText("SELECT FIRST","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
	end
	DownloadButton.DoClick = function(self)
		if Allow then
			net.Start("aas_choosedupe")
				net.WriteString(string.StripExtension(Data.txt))
			net.SendToServer()
			DupeMenuBase:Remove()
		end
	end

	local Cancel = vgui.Create("DButton",DupeMenuBase)
	Cancel:SetPos(8,436)
	Cancel:SetSize(200 - 8,58)
	Cancel:SetText("")
	Cancel.Paint = function(self,w,h)
		surface.SetDrawColor(75,75,75,255)
		surface.DrawRect(0,0,w,h)

		if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,127) else surface.SetDrawColor(127,0,0,127) end
		surface.DrawRect(4, 4, w - 8, h - 8)

		draw.SimpleText("CANCEL","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	end
	Cancel.DoClick = function(self)
		DupeMenuBase:Remove()
	end
end
if DupeMenuBase then DupeMenuBase:Remove() end

local function AAS_ReceiveFile(len, ply) -- A little hijacking here and there from AdvDupe2 and we've now got an ez-dupe system for people to get public dupes from the server
	net.ReadStream(nil, function(data)

		if data then
			chat.AddText(Color(255,0,0),"File was not saved!")
			return
		end

		local dupefile = file.Open(AdvDupe2.SavePath .. ".txt", "wb", "DATA")
		if not dupefile then
			chat.AddText(Color(255,0,0),"File was not saved!")
			return
		end

		dupefile:Write(data)
		dupefile:Close()

		chat.AddText(Color(200,200,200),"Dupe saved to >" .. AdvDupe2.SavePath .. "!")
	end)
end

do  -- Stuff to organize

	do	-- Net
		-- Handles any changes in point capture status
		net.Receive("aas_pointstatechange",function()
			PointChange(net.ReadEntity(),net.ReadInt(3),net.ReadInt(3))
		end)

		-- Sets up the line of points for the player, with it arranged for their team
		net.Receive("aas_raasline",function()
			AAS.ServerRAAS = net.ReadTable()
			AAS.PointAlias = net.ReadTable()
			AAS.RAASLookup = {}

			AAS.RAASFinished = false

			AAS.NonLinear = GetGlobalBool("IsNonLinear",false)
			AAS.MaxRequisition = GetGlobalInt("MaxRequisition",AAS.DefaultProperties.MaxRequisition)

			setupRAASLocal()
		end)

		-- Generic message handler
		net.Receive("aas_msg",function()
			local msg = net.ReadTable()
			chat.AddText(unpack(msg))
		end)

		-- Sets up the team aliases as well as colors for the client, also sets the player color
		net.Receive("aas_UpdateTeamData",function()
			AAS.TeamData = net.ReadTable()

			if LP:GetPlayerColor() ~= AAS.TeamData[LP:Team()].Color then
				LP:SetPlayerColor(AAS.TeamData[LP:Team()].Color:ToVector())
			end

			team.SetColor(1,AAS.TeamData[1].Color)
			team.SetColor(2,AAS.TeamData[2].Color)

			AAS.LocalAlias["SpawnA"] = AAS.TeamData[1].Name .. " Spawn"
			AAS.LocalAlias["SpawnB"] = AAS.TeamData[2].Name .. " Spawn"
		end)

		-- Opens the loadout menu, and provides the player's current loadout
		net.Receive("aas_openloadout",function()
			Loadout = net.ReadTable()
			LoadoutMenu()
		end)

		-- Opens the vote menu, with a timer as well as if "rock the vote" can occur
		net.Receive("aas_openvotes",function()
			Time = net.ReadFloat()
			RTV = net.ReadBool()
			Choices = net.ReadTable()
			VoteMenu()
		end)

		-- Handles inserting data into the generic cost calculator E2 script thats sent, populates it with current info about any costs on the server
		net.Receive("aas_createE2",function()
			local E2Code = net.ReadString()
			local CostInfo = net.ReadTable()

			local CostBreakdown = {}

			for k,v in pairs(CostInfo.CalcSingleFilter) do
				local Str = "\"" .. k .. "\""
				if not CostBreakdown.FilterList then
					CostBreakdown.FilterList = Str
				else
					CostBreakdown.FilterList = CostBreakdown.FilterList .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.CalcSingleFilter) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.CalcSingleFilter then
					CostBreakdown.CalcSingleFilter = Str
				else
					CostBreakdown.CalcSingleFilter = CostBreakdown.CalcSingleFilter .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFGunCost) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFGunCost then
					CostBreakdown.ACFGunCost = Str
				else
					CostBreakdown.ACFGunCost = CostBreakdown.ACFGunCost .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFAmmoModifier) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFAmmoModifier then
					CostBreakdown.ACFAmmoModifier = Str
				else
					CostBreakdown.ACFAmmoModifier = CostBreakdown.ACFAmmoModifier .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFMissileModifier) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFMissileModifier then
					CostBreakdown.ACFMissileModifier = Str
				else
					CostBreakdown.ACFMissileModifier = CostBreakdown.ACFMissileModifier .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.SpecialModelFilter) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.SpecialModelFilter then
					CostBreakdown.SpecialModelFilter = Str
				else
					CostBreakdown.SpecialModelFilter = CostBreakdown.SpecialModelFilter .. "," .. Str
				end
			end

			local FinalCode = string.format(E2Code,
				util.DateStamp(),
				CostBreakdown.FilterList,
				CostBreakdown.CalcSingleFilter,
				CostBreakdown.ACFGunCost,
				CostBreakdown.ACFAmmoModifier,
				CostBreakdown.ACFMissileModifier,
				CostBreakdown.SpecialModelFilter)

			if not file.Exists("expression2/AAS","DATA") then file.CreateDir("expression2/AAS") end
			file.Write("expression2/AAS/aas_costcalc.txt",FinalCode)

			chat.AddText(Color(200,200,200),"AAS Cost script has been saved to >expression2/AAS/aas_costcalc.txt!")
		end)

		-- Sent whenever the player spawns a dupe, provides information about the cost of everything in the dupe
		net.Receive("aas_notifycost",function()
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

		-- Provides a list of all of the dupes available on the server for the player to download one at a time
		net.Receive("aas_dupelist",function()
			Dupes = net.ReadTable()
			if ScoreboardBase then ScoreboardBase:Remove() end
			DupeMenu()

			if not file.Exists("advdupe2/aas","DATA") then file.CreateDir("advdupe2/aas") end
		end)

		-- Start of the dupe saving process
		net.Receive("aas_receivedupe",function()
			local FileName = net.ReadString()

			AdvDupe2.SavePath = "advdupe2/aas/" .. FileName
		end)

		-- Actually saving the dupe
		net.Receive("aas_ReceiveFile", AAS_ReceiveFile)
	end

	do	-- Hooks
		-- Requests information about the running game, like the points and how they are connected
		local function requestInfo()
			net.Start("aas_playerinit")
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

					draw.DrawText(GetHint(),"BasicFontLarge",SW / 2, SH * 0.75,Colors.BasicCol,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

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