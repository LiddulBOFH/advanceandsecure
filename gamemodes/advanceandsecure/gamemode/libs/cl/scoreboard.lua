MsgN("+ Scoreboard loaded")

local PlyColor = Color(0,127,0)

local function localizeToPanel(Vec3,Panel)
	return {x = ((Vec3.x / 16384) * (Panel:GetWide() / 2)) + (Panel:GetWide() / 2), y = ((-Vec3.y / 16384) * (Panel:GetTall() / 2)) + (Panel:GetTall() / 2)}
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