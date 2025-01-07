MsgN("+ HUD system loaded")

local PointBaseColor = Color(65,65,65)

local SW,SH = ScrW(),ScrH()
--local SM = {x = SW / 2, y = SH / 2}
local UU = ((SW > SH) and SH or SW) / 12

local RequisitionPanelWidth	= (UU * 0.25) + 4
local Padding	= {x = (UU * 0.25) + RequisitionPanelWidth, y = UU * 0.25}

do
	do	-- Point Change

		local function PointChange(PointName,OldStatus,NewStatus)
			if PointChangeBase then PointChangeBase:Remove() end

			PointChangeBase = vgui.Create("Panel")
			PointChangeBase:SetSize(UU * 8,UU * 2)
			PointChangeBase:CenterHorizontal(0.5)
			PointChangeBase:CenterVertical(0.25)
			PointChangeBase:AlphaTo(0,1,4,function(_,panel) panel:Remove() end)
			PointChangeBase.Paint = function(self,w,h)
				local CurrentTeam = LocalPlayer():Team()
				draw.NoTexture()
				local Col = PointBaseColor

				if NewStatus ~= 0 then
					local TCol	= AAS.Funcs.GetTeamInfo(NewStatus).Color
					Col	= Color(TCol.x, TCol.y, TCol.z)
				end

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
					CapText	= "Captured by " .. AAS.Funcs.GetTeamInfo(NewStatus).Name
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

				--surface.SetDrawColor(Col)

				draw.SimpleTextOutlined(PointName,"BasicFontLarge",CX - UU * 0.75,CY,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER,1,color_black)
				draw.SimpleTextOutlined(CapText,"BasicFontLarge",CX + UU * 0.75,CY,CapCol,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,color_black)
			end
		end

		-- Handles any changes in point capture status
		net.Receive("AAS.UpdatePointState",function() PointChange(net.ReadString(),net.ReadInt(3),net.ReadInt(3)) end)
	end

	do	-- Main UI

		local MinimapScale	= CreateClientConVar("aas_minimap_scale", 1, true, false, "Sets the scale for the minimap, and all attached elements.", 0.1, 2)
		local MinimapPos	= CreateClientConVar("aas_minimap_pos", 0, true, false, "Position of the minimap. 0 - Bottom left, 1 - Bottom right, 2 - Top right, 3 - Top left", 0, 3)
		local NoMat = Material("materials/gui/noicon.png", "")
		local EyeA	= EyeAngles
		local EyeP	= EyePos

		local function GetBearing(EyeYaw)
			return math.Remap(math.NormalizeAngle(-EyeYaw - 90), -180, 180, 0, 360)
		end

		local function TranslateToMinimap(WorldPos)
			local EA, EP = EyeA(), EyeP()

			local LocPos	= WorldToLocal(WorldPos * Vector(1,1,0), Angle(), EP * Vector(1,1,0), Angle(0, EA.y + 180, 0))

			return Vector(LocPos.y, LocPos.x, 0)
		end

		local MapInfo	= ""
		local StoredMapBounds	= {}
		local function GetMinimapBounds()
			local Scale		= MinimapScale:GetFloat()
			local Corner	= MinimapPos:GetInt()
			local ind = Scale .. ";" .. Corner
			if MapInfo == ind then return unpack(StoredMapBounds) end

			-- Defaults to bottom left corner
			local Size	= {w = UU * 3 * Scale, h = UU * 3.55 * Scale}
			local Cutoff = Size.h - Size.w
			local Pos	= Vector(Padding.x, SH - Size.h - Padding.y, 0)

			if Corner == 1 then	-- Bottom right
				Pos = Vector(SW - Size.w - Padding.x, SH - Size.h - Padding.y * 3, 0)
			elseif Corner == 2 then	-- Top right
				Pos = Vector(SW - Size.w - Padding.x, Padding.y, 0)
			elseif Corner == 3 then	-- Top left
				Pos = Vector(Padding.x, Padding.y, 0)
			end

			local ScissorBounds	= {
				{x = Pos.x, y = Pos.y + Cutoff},
				{x = Pos.x + Size.w, y = Pos.y + Size.w + Cutoff}
			}

			StoredMapBounds = {Pos, Size, ScissorBounds, Cutoff}
			MapInfo	= ind

			return unpack(StoredMapBounds)
		end

		local Letter = {"A", "B", "C", "D", "E", "F", "G"}

		local Zerp	= 0
		local skymask	= MASK_SOLID_BRUSHONLY
		local function DoMinimap()
			draw.NoTexture()

			local EP		= EyePos()
			local Scale		= MinimapScale:GetFloat()
			--local Size		= {w = UU * 3 * Scale, h = UU * 3.55 * Scale}
			local Origin, Size, ScissorBounds, Cutoff = GetMinimapBounds()

			local tr		= util.TraceHull({start = EP, endpos = EP + Vector(0, 0, 2048), mask = skymask, collisiongroup = COLLISION_GROUP_NONE, mins = Vector(-36, -36, 0), maxs = Vector(36, 36, 24)})
			Zerp = Lerp(0.2, Zerp, tr.HitSky and 0.5 or (tr.Fraction * 0.5))

			local Zoom		= 4 - (Zerp * 2)
			local ZoomScale	= ((UU * (4 / Zoom)) * 0.7) * (Scale / 2)
			local MapSize	= UU * Zoom

			local matrix = Matrix()
			matrix:SetTranslation(Origin)

			cam.PushModelMatrix(matrix) -- Move everything to where the minimap cluster is being drawn

			surface.SetDrawColor(65, 127, 200, 127)
			surface.DrawRect(0, 0, Size.w, Size.h)

			local ClipState = DisableClipping(true)
			surface.SetDrawColor(65,127,255)
			surface.DrawOutlinedRect(0, 0, Size.w, Size.h, -4)

			if AAS.State.ClientPointLine then
				local NumPoints = #AAS.State.ClientPointLine

				for I = 1, NumPoints do
					local Point = AAS.State.ClientPointLine[I]
					if (not IsValid(Point)) or Point == NULL then continue end

					surface.SetDrawColor(Point:GetCapColor())
					local Pos = (Size.w / 2) + (UU * 0.3 * (I - 1)) - ((NumPoints - 1) * UU * 0.15)
					surface.DrawTexturedRectRotated(Pos, UU * 0.15, UU * 0.18, UU * 0.18, 45)
					draw.SimpleTextOutlined(Letter[I] or "", "BasicFontLarge", Pos, UU * 0.15, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				end
			end

			local Team1 = AAS.Funcs.GetTeamInfo(1)
			local Team2 = AAS.Funcs.GetTeamInfo(2)
			local Team1C	= Team1.Color
			local Team2C	= Team2.Color

			if AAS.State.Team["BLUFOR"] then
				local NumTickets = AAS.Funcs.GetSetting("Tickets", 300)

				surface.SetDrawColor(65,65,65,255)
				surface.DrawRect(UU * 0.05, UU * 0.4, Size.w * 0.45, UU * 0.1)
				surface.DrawRect(Size.w - UU * 0.05, UU * 0.4, -Size.w * 0.45, UU * 0.1)

				surface.SetDrawColor(Color(Team1C.r, Team1C.g, Team1C.b))
				surface.DrawRect(UU * 0.05, UU * 0.4, Size.w * 0.45 * math.min(1,AAS.State.Team["BLUFOR"].Tickets / NumTickets), UU * 0.1)

				surface.SetDrawColor(Color(Team2C.r, Team2C.g, Team2C.b))
				surface.DrawRect(Size.w - UU * 0.05, UU * 0.4, -Size.w * 0.45 * math.min(1,AAS.State.Team["OPFOR"].Tickets / NumTickets), UU * 0.1)

				draw.SimpleTextOutlined(Team1.Name, "BasicFont14", UU * 0.05, UU * 0.4, Team1.Color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
				draw.SimpleTextOutlined(tostring(AAS.State.Team["BLUFOR"].Tickets), "BasicFont14", UU * 0.05 + Size.w * 0.45, UU * 0.4, Team1.Color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)

				draw.SimpleTextOutlined(Team2.Name, "BasicFont14", Size.w - UU * 0.05, UU * 0.4, Team2.Color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
				draw.SimpleTextOutlined(tostring(AAS.State.Team["OPFOR"].Tickets), "BasicFont14", UU * -0.05 + Size.w * 0.55, UU * 0.4, Team2.Color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
			end

			render.SetScissorRect(ScissorBounds[1].x, ScissorBounds[1].y, ScissorBounds[2].x, ScissorBounds[2].y, true)

			local mapmatrix = Matrix()
			local EA		= EyeA()
			mapmatrix:SetTranslation(Origin + Vector(Size.w / 2, (Size.w / 2) + Cutoff, 0))
			mapmatrix:Rotate(Angle(0, EA.yaw - 90, 0))
			mapmatrix:Scale(Vector(Zoom, Zoom, 0))

			cam.PushModelMatrix(mapmatrix, false)

			local MapLocPos = (EP / 16384) * (MapSize / 2)
			local MapFinPos = Vector(math.floor(MapLocPos.x), math.floor(MapLocPos.y), 0)

			surface.SetMaterial(NoMat)
			surface.SetDrawColor(65,65,65,255)
			surface.DrawTexturedRect(-MapFinPos.x - (MapSize / 2), MapFinPos.y - (MapSize / 2), MapSize, MapSize)

			if AAS.ValidMap then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(AAS.MapPNG)

				surface.DrawTexturedRect(-MapFinPos.x - (MapSize / 2), MapFinPos.y - (MapSize / 2), MapSize, MapSize)
			end

			surface.SetDrawColor(255,0,0)
			surface.DrawOutlinedRect(-MapFinPos.x - (MapSize / 2), MapFinPos.y - (MapSize / 2), MapSize, MapSize, -2)

			draw.NoTexture()
			cam.PopModelMatrix()
			local mapmatrix_norot = Matrix()
			mapmatrix_norot:SetTranslation(Origin + Vector(Size.w / 2, (Size.w / 2) + Cutoff, 0))
			mapmatrix_norot:Scale(Vector(Zoom, Zoom, 0))
			cam.PushModelMatrix(mapmatrix_norot)

			do
				surface.SetDrawColor(65, 65, 65, 255)

				local LocPos = (TranslateToMinimap(LocalPlayer():GetPos() + Vector(0, 16384, 0)) / 16384) * (MapSize / 2)

				local Dir	= LocPos:GetNormalized()
				local Mag	= math.min(ZoomScale * 1.5, LocPos:Length())
				local NewPos	= Mag * Dir
				local ClampedPos	= Vector(math.Clamp(NewPos.x, -ZoomScale, ZoomScale), math.Clamp(NewPos.y, -ZoomScale, ZoomScale), 0)
				local FinPos = Vector(math.floor(ClampedPos.x), math.floor(ClampedPos.y), 0)

				draw.SimpleTextOutlined("N", "PixelFont", FinPos.x, FinPos.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
			end

			for k,v in ipairs(team.GetPlayers(LocalPlayer():Team())) do
				if not IsValid(v) then continue end
				local LocPos = (TranslateToMinimap(v:GetPos()) / 16384) * (MapSize / 2)

				local Dir	= LocPos:GetNormalized()
				local Mag	= math.min(ZoomScale * 2, LocPos:Length())
				local NewPos	= Mag * Dir
				local ClampedPos	= Vector(math.Clamp(NewPos.x, -ZoomScale, ZoomScale), math.Clamp(NewPos.y, -ZoomScale, ZoomScale), 0)
				local FinPos = Vector(math.floor(ClampedPos.x), math.floor(ClampedPos.y), 0)

				surface.SetDrawColor(0,0,0,255)
				surface.DrawTexturedRectRotated(FinPos.x, FinPos.y, 4, 4, -EA.yaw)
				surface.SetDrawColor(0,255,0,255)
				surface.DrawTexturedRectRotated(FinPos.x, FinPos.y, 2, 2, -EA.yaw)
			end

			local CT = CurTime() * 30
			if AAS.State.Alias then
				for k,v in pairs(AAS.State.Alias) do
					if (not IsValid(v)) or (v == NULL) then continue end
					local LocPos = (TranslateToMinimap(v:GetPos()) / 16384) * (MapSize / 2)

					local Dir	= LocPos:GetNormalized()
					local Mag	= math.min(ZoomScale * 2, LocPos:Length())
					local NewPos	= Mag * Dir
					local ClampedPos	= Vector(math.Clamp(NewPos.x, -ZoomScale, ZoomScale), math.Clamp(NewPos.y, -ZoomScale, ZoomScale), 0)
					local FinPos = Vector(math.floor(ClampedPos.x), math.floor(ClampedPos.y), 0)

					surface.SetDrawColor(0,0,0,255)
					surface.DrawTexturedRectRotated(FinPos.x, FinPos.y, 4, 6, -EA.yaw + CT)
					surface.DrawTexturedRectRotated(FinPos.x, FinPos.y, 4, 6, -EA.yaw + CT + 90)
					surface.SetDrawColor(v:GetCapColor())
					surface.DrawTexturedRectRotated(FinPos.x, FinPos.y, 3, 3, -EA.yaw + CT)
				end
			end

			cam.PopModelMatrix()

			render.SetScissorRect(0, 0, 0, 0, false)
			DisableClipping(ClipState)
			cam.PopModelMatrix()
		end

		local CheckFlip	= {["0"] = false, ["1"] = true, ["2"] = true, ["3"] = false}
		local function DoRequisition()
			draw.NoTexture()
			local LP = LocalPlayer()
			local Origin, Size = GetMinimapBounds()
			local Flip	= CheckFlip[tostring(MinimapPos:GetInt())] or false
			local MaxReq	= AAS.Funcs.GetSetting("Max Requisition", 500)

			local matrix = Matrix()
			if Flip then
				matrix:SetTranslation(Origin + Vector(Size.w, 0, 0))
			else
				matrix:SetTranslation(Origin + Vector(-RequisitionPanelWidth, 0, 0))
			end

			local ClipState = DisableClipping(true)
			cam.PushModelMatrix(matrix)

			surface.SetDrawColor(65, 127, 200, 127)
			surface.DrawRect(Flip and 4 or 0, 0, RequisitionPanelWidth - 4, Size.h)

			surface.SetDrawColor(65, 127, 255)
			surface.DrawOutlinedRect(Flip and 4 or 0, 0, RequisitionPanelWidth - 4, Size.h, -4)

			local BarWidth = RequisitionPanelWidth - 12
			surface.SetDrawColor(65, 65, 65)
			surface.DrawRect(Flip and 8 or 4, 4, BarWidth, Size.h - 8)

			local ReqPerc	= LP:GetNW2Int("Requisition", 0) / MaxReq
			surface.SetDrawColor(0, 255, 0)
			surface.DrawRect(Flip and 8 or 4, Size.h - 4, BarWidth, (-Size.h + 8) * ReqPerc)

			surface.SetDrawColor(200, 0, 0)
			surface.DrawRect(Flip and 8 or 4, Size.h - 4, BarWidth / 2, (-Size.h + 8) * (LP:GetNW2Int("UsedRequisition", 0) / MaxReq))

			surface.SetDrawColor(255, 100, 0)
			surface.DrawRect((Flip and 8 or 4) + BarWidth / 2, Size.h - 4, BarWidth / 2, (-Size.h + 8) * (LP:GetNW2Int("AAS.LoadoutCost", 0) / MaxReq))

			local MaxStackSize	= Size.h - 0
			local StackPos	= {x = (Flip and 8 or 4) + BarWidth / 2, y = MaxStackSize - math.Clamp(MaxStackSize * ReqPerc, 40, MaxStackSize - 4)}
			draw.SimpleTextOutlined(tostring(LP:GetNW2Int("Requisition", 0)), "BasicFont14", StackPos.x, StackPos.y, Color(0,255,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
			draw.SimpleTextOutlined(tostring(LP:GetNW2Int("UsedRequisition", 0)), "BasicFont14", StackPos.x, StackPos.y + 12, Color(200,0,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
			draw.SimpleTextOutlined(tostring(LP:GetNW2Int("AAS.LoadoutCost", 0)), "BasicFont14", StackPos.x, StackPos.y + 24, Color(255,100,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)

			cam.PopModelMatrix()
			DisableClipping(ClipState)
		end

		-- Teammate markers
		local HighlightEnemyDist	= 4096 ^ 2
		local Red					= Color(255, 0, 0)

		local function DoTeam()
			draw.NoTexture()

			if not IsValid(LocalPlayer()) then return end
			local LP = LocalPlayer()
			local TN = LP:Team()
			local OTN	= TN == 1 and 2 or 1

			local TC = team.GetColor(TN)
			surface.SetDrawColor(Color(TC.r, TC.g, TC.b, 92))

			for _,ply in ipairs(team.GetPlayers(TN)) do
				if ply == LP then continue end
				local SPos = LerpVector(0.75, ply:GetPos(), ply:GetShootPos()):ToScreen()
				surface.DrawTexturedRectRotated(SPos.x, SPos.y, UU * 0.175, UU * 0.175, 45)
				draw.SimpleTextOutlined(ply:Nick(), "BasicFont14", SPos.x, SPos.y, TC, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
			end

			if AAS.State.Alias then
				local Spawn = AAS.State.Alias[TN == 1 and "SpawnA" or "SpawnB"]
				if (Spawn == NULL) or (not IsValid(Spawn)) then return end

				local SpawnPos	= Spawn:GetPos()
				local TC2	= team.GetColor(OTN)

				local THROB	= math.abs(TimedCos(1, 0, 16, 0))
				for _, ply in ipairs(team.GetPlayers(OTN)) do
					if (not IsValid(ply)) or (ply == NULL) then continue end
					if ply:GetShootPos():DistToSqr(SpawnPos) > HighlightEnemyDist then continue end

					local SPos = LerpVector(0.75, ply:GetPos(), ply:GetShootPos()):ToScreen()

					local MarkSize	= UU * 0.2
					surface.SetDrawColor(Red)
					surface.DrawTexturedRectRotated(SPos.x, SPos.y, MarkSize + THROB, MarkSize + THROB, 45)

					surface.SetDrawColor(color_black)
					surface.DrawTexturedRectRotated(SPos.x, SPos.y, MarkSize, MarkSize, 45)

					surface.SetDrawColor(TC2)
					surface.DrawTexturedRectRotated(SPos.x, SPos.y, MarkSize * 0.9, MarkSize * 0.9, 45)

					draw.SimpleTextOutlined(ply:Nick(), "BasicFont14", SPos.x, SPos.y, TC2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				end
			end
		end

		-- Classy, I know.
		local Bearing2Text = {
			["0"]	= "N",
			["45"]	= "NE",
			["90"]	= "E",
			["135"]	= "SE",
			["180"]	= "S",
			["225"]	= "SW",
			["270"]	= "W",
			["315"]	= "NW",
		}

		local Arrow	= {
			{x = 0, y = UU * 0.15},
			{x = UU * 0.1, y = UU * 0.25},
			{x = 0, y = UU * 0.2},
			{x = UU * -0.1, y = UU * 0.25}
		}

		local function DoCompass()
			draw.NoTexture()
			surface.SetDrawColor(255,255,255,255)

			local Yaw = EyeA().yaw
			local matrix = Matrix()
			matrix:SetTranslation(Vector(SW * 0.5, UU * 0.2, 0))

			cam.PushModelMatrix(matrix)
			local ClipState = DisableClipping(true)

			local Bearing = GetBearing(Yaw)
			draw.SimpleTextOutlined(tostring(math.Round(Bearing)), "BasicFontLarge", 0, UU * 0.25, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)

			surface.DrawPoly(Arrow)

			local perc = ((Bearing + 5) % 5) / 5
			local Spacing	= UU * 1.5
			local Shift		= Spacing * -3

			for I = 1, 6 do
				local Ang = GetBearing(math.NormalizeAngle(Yaw + 15 + (-I * 5)))
				local Text = tostring(math.floor(Ang / 5) * 5)
				surface.SetDrawColor(color_white)

				local XPos = Shift + (Spacing * I) + (-Spacing * perc) - 1

				if Bearing2Text[Text] then
					Text = Bearing2Text[Text]

					draw.SimpleTextOutlined(Text, "BasicFontLarge", XPos, -1, Red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				else
					surface.DrawRect(XPos, 0, 2, UU * 0.1)

					draw.SimpleTextOutlined(Text, "BasicFont14", XPos, -1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
				end
			end

			cam.PopModelMatrix()
			DisableClipping(ClipState)
		end

		local PointScale = 12
		-- Point markers, with progress diamonds
		local function DoPoints()
			draw.NoTexture()

			if not AAS.State.Alias then return end

			local LP = LocalPlayer()
			local PlyPos = LP:GetPos()

			for _,v in pairs(AAS.State.FullLine) do
				if (not IsValid(v)) or (v == NULL) then continue end

				local Pos = v:GetPos()
				local Dist = PlyPos:DistToSqr(Pos)
				local Dist2 = math.max(Dist - 20000,0)
				local Pos2 = (Pos + Vector(0,0,256 + 32 + math.min(1200,Dist2 / 60000))):ToScreen()

				local PointName = v:GetPointName()
				if AAS.LocalAlias[PointName] then PointName = AAS.LocalAlias[PointName] .. " Spawn" end

				local Poly = {}

				for I = 1,6 do
					local Ang = math.rad(60 * I)
					Poly[I] = {x = Pos2.x + (math.cos(Ang) * PointScale), y = Pos2.y + (math.sin(Ang) * PointScale)}
				end

				surface.SetDrawColor(v:GetCapColor())
				surface.DrawPoly(Poly)
				draw.SimpleTextOutlined(PointName, "BasicFont14", Pos2.x, Pos2.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
			end
		end

		local function DoHUD()

			surface.SetDrawColor(color_white)

			DoPoints()
			DoTeam()

			if not scoreboard.visible then
				DoMinimap()
				DoRequisition()
			end

			DoCompass()

		end

		hook.Add("HUDPaint", "AAS.MainUI", DoHUD)
	end

	do	-- 3D Rendering
		local function DoPoints(drawDepth, drawSkybox, draw3DSkybox)
			if draw3DSkybox then return end

			if AAS.Funcs.GetSetting("Non-linear", false) == true then return end
			if not AAS.State.FullLine then return end
			for I = 2, #AAS.State.FullLine do
				local P1 = AAS.State.FullLine[I - 1]
				local P2 = AAS.State.FullLine[I]
				if (not IsValid(P1)) or (P1 == NULL) then continue end
				if (not IsValid(P2)) or (P2 == NULL) then continue end

				render.DrawLine(P1:GetPos() + Vector(0, 0, 256), P2:GetPos() + Vector(0, 0, 256), P1:GetCapColor():Lerp(P2:GetCapColor(), 0.5), false)
			end
		end

		local FriendlySpawnDist	= 2048 ^ 2
		local EnemySpawnDist	= 8192 ^ 2
		local function DoSafezones(drawDepth, drawSkybox, draw3DSkybox)
			if draw3DSkybox then return end

			local LP	= LocalPlayer()
			if (not IsValid(LP)) or (LP == NULL) then return end
			local TN	= LP:Team()
			local OTN	= TN == 1 and 2 or 1

			if not AAS.State.Alias then return end

			local Spawn	= AAS.State.Alias[TN == 1 and "SpawnA" or "SpawnB"]
			local OpSpawn	= AAS.State.Alias[TN == 1 and "SpawnB" or "SpawnA"]
			if (Spawn == NULL) or (not IsValid(Spawn)) then return end

			render.SetColorMaterial()

			local EP	= EyePos()

			local SpawnPos	= Spawn:GetPos()
			if IsValid(Spawn) and (EP:DistToSqr(SpawnPos) < FriendlySpawnDist) then
				local TeamInfo	= AAS.Funcs.GetTeamInfo(TN)

				render.DrawWireframeBox(SpawnPos,Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,color_white,false)

				local R,G,B = TeamInfo.Color:Unpack()
				local BoxCol = Color(R,G,B,32)

				render.DrawBox(SpawnPos, Angle(), AAS.ExtendedBoundsA, AAS.ExtendedBoundsB, BoxCol)
				render.DrawBox(SpawnPos, Angle(), AAS.ExtendedBoundsA * Vector(-1,1,1), AAS.ExtendedBoundsB * Vector(-1,1,1), BoxCol)
			end

			if (OpSpawn == NULL) or (not IsValid(OpSpawn)) then return end
			local OpSpawnDist = EP:DistToSqr(OpSpawn:GetPos())
			if IsValid(OpSpawn) and (OpSpawnDist < EnemySpawnDist) then
				local TeamInfo	= AAS.Funcs.GetTeamInfo(OTN)
				local R, G, B	= TeamInfo.Color:Unpack()

				render.OverrideDepthEnable(true,true)
				render.DrawBox(OpSpawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB, Color(R, G, B, 255))

				if OpSpawnDist < (EnemySpawnDist / 2) then
					render.DrawBox(OpSpawn:GetPos(),Angle(),AAS.ExtendedBoundsA,AAS.ExtendedBoundsB, Color(R, G, B, 255))
				else
					local Alpha = (1 - ((OpSpawnDist - (EnemySpawnDist / 2)) / (EnemySpawnDist / 2))) * 255
					render.DrawBox(OpSpawn:GetPos(),Angle(),AAS.ExtendedBoundsA,AAS.ExtendedBoundsB, Color(R, G, B, Alpha))
				end
				render.OverrideDepthEnable(false,false)
			end
		end

		local function TimeToColor(Mult, Offset)
			return HSVToColor(((CurTime() + Offset) * Mult) % 360, 1, 1)
		end

		local function DoEditMode(drawDepth, drawSkybox, draw3DSkybox)
			if draw3DSkybox then return end
			render.SetColorMaterial()

			render.OverrideDepthEnable(true, true)
			for ind, spawn in ipairs(ents.FindByClass("aas_spawnpoint")) do
				local Pos = spawn:GetPos()

				render.DrawBox(Pos + Vector(0, 0, 36), spawn:GetAngles(), Vector(16,-16,-36), Vector(-16,16,36), TimeToColor(4, ind * 5))
				render.DrawLine(Pos + Vector(0, 0, 36), Pos + Vector(0, 0, 36) + spawn:GetForward() * 36, color_white, true)
			end

			for ind, point in ipairs(ents.FindByClass("aas_point")) do
				local Pos = point:GetPos()
				render.DrawLine(Pos, Pos + point:GetUp() * 256, color_white, true)
			end
			render.OverrideDepthEnable(false, false)
		end

		local function Do3D(drawDepth, drawSkybox, draw3DSkybox)
			DoPoints(drawDepth, drawSkybox, draw3DSkybox)
			DoSafezones(drawDepth, drawSkybox, draw3DSkybox)

			if GetGlobalBool("EditMode", false) then DoEditMode(drawDepth, drawSkybox, draw3DSkybox) end
		end

		hook.Add("PostDrawOpaqueRenderables", "AAS.PostDrawOpaqueRenderables", Do3D)
	end

	do	-- Hookage

		local HUDHide = {["CHudHealth"] = true, ["CHUDQuickInfo"] = true, ["CHudBattery"] = true, ["CHudChat"] = false}
		-- Just hides HUD elements
		hook.Add("HUDShouldDraw","HideHUD",function(label)
			if HUDHide[label] then return false end
		end)

		-- Blanks out the screen when the player is dead, or fades it with red when below 25% health
		-- While dead the player can see a time until they can respawn, a hint for the gamemode, and a warning if their karma is too low (extends respawn time)
		hook.Add("PostDrawHUD","AAS.DeathUI",function()
			local LP = LocalPlayer()
			if not IsValid(LP) then return end

			local Health = LP:Health()
			draw.NoTexture()

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
	end
end

--[[
		-- Draws all of the points the player can see, info about the game (tickets, requisition), any friendlies on the map, and the dupe cost of a recently spawned dupe
		local FriendlyScale = 10
		local PointScale = 20
		hook.Add("HUDPaint","GameHUD",function()
			local LP = LocalPlayer()
			if not IsValid(LP) then return end
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
		local FriendlyBaseBoxDist	= 2048 ^ 2
		local EnemyBaseBoxDist		= 8192 ^ 2
		hook.Add("PostDrawOpaqueRenderables","EditMode3D",function(depth,skybox,skybox3D)
			local LP = LocalPlayer()

			if AAS.RAASFinished then
				if not IsValid(AAS.RAASLine[1]) then AAS.RAASFinished = false return end
				local CanIgnoreDraw = GetGlobalBool("EditMode")

				render.SetColorMaterial()

				local Team = LP:Team()
				local OpTeam = (Team == 1 and 2 or 1)

				local Spawn = AAS.PointAlias[Team == 1 and "SpawnA" or "SpawnB"]
				local OpSpawn = AAS.PointAlias[Team == 1 and "SpawnB" or "SpawnA"]

				if (LP:GetPos():DistToSqr(Spawn:GetPos()) < FriendlyBaseBoxDist) and not skybox3D then
					render.DrawWireframeBox(Spawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,Colors.White,false)
					local R,G,B = AAS.TeamData[Team].Color:Unpack()
					local BoxCol = Color(R,G,B,32)
					render.DrawBox(Spawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,BoxCol)
					render.DrawBox(Spawn:GetPos(),Angle(),AAS.SpawnBoundA * Vector(-1,1,1),AAS.SpawnBoundB * Vector(-1,1,1),BoxCol)
				end

				local OpSpawnDist = LP:GetPos():DistToSqr(OpSpawn:GetPos())
				--print(OpSpawnDist)
				if (OpSpawnDist < EnemyBaseBoxDist) and not skybox3D then
					local R,G,B = AAS.TeamData[OpTeam].Color:Unpack()
					local BoxCol = Color(R,G,B,255)

					render.OverrideDepthEnable(true,true)
					if OpSpawnDist < (EnemyBaseBoxDist / 2) then
						render.DrawBox(OpSpawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,BoxCol)
					else
						local Alpha = (1 - ((OpSpawnDist - (EnemyBaseBoxDist / 2)) / (EnemyBaseBoxDist / 2))) * 255
						render.DrawBox(OpSpawn:GetPos(),Angle(),AAS.SpawnBoundA,AAS.SpawnBoundB,Color(BoxCol.r, BoxCol.g, BoxCol.b, Alpha))
					end
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
		]]