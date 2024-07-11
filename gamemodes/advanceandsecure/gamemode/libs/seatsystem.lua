-- Provides team-based seating systems
AddCSLuaFile()
print("SEAT SYSTEM LOADED")

AAS.SeatManager	= {}
local SeatMan		= AAS.SeatManager
SeatMan.MaxDistance	= 256^2	-- Maximum range to let someone warp into a seat
SeatMan.MinDistance	= 96^2	-- Minimum range for this to function, if a seat is found under this distance stop it altogether

if CLIENT then
	local Time		= 0.75 -- Time to hold IN_USE
	local Check		= false
	local Holding	= false
	local HoldTime	= 0
	local Seats		= {} -- Populated after client requests from server
	local BestChoice	= NULL

	local SobelMat	= Material("pp/sobel")
	SobelMat:SetTexture("$fbtexture", render.GetScreenEffectTexture())
	SobelMat:SetFloat("$threshold", 0.00001)

	local SW,SH = ScrW(),ScrH()
	local SM = {x = SW / 2, y = SH / 2}
	local UU = ((SW > SH) and SH or SW) / 12

	net.Receive("aas_requestSeats", function()
		Seats = net.ReadTable(true)
	end)

	local function CheckTick()
		if not Check then hook.Remove("Tick", "AAS_SeatSystem") end

		BestChoice	= NULL
		local BestChoiceDot = 0

		local Pos = EyePos()
		local EyeDir = EyeVector()

		for _,Ent in ipairs(Seats) do
			if IsValid(Ent) and (Ent:GetPos():DistToSqr(EyePos()) < SeatMan.MaxDistance) then
				local SeatDir = (Ent:LocalToWorld(Ent:OBBCenter()) - Pos):GetNormalized()
				local SeatDot = SeatDir:Dot(EyeDir)

				if (SeatDot > 0.985) and (SeatDot > BestChoiceDot) then BestChoice = Ent BestChoiceDot = SeatDot end
			end
		end
	end

	local function CheckTimer()
		timer.Remove("AAS_SeatCheck")

		timer.Create("AAS_SeatCheck", Time, 1, function() -- somethings fucky here, its not actually starting correctly if it is not infinite
			if not LocalPlayer():KeyDown( IN_USE ) then Holding = false return end -- seems to stop here, maybe timer is starting too fast
			if LocalPlayer():InVehicle() == true then Holding = false return end

			Check	= true

			Seats	= {}

			net.Start("aas_requestSeats")
			net.SendToServer()

			hook.Add("Tick", "AAS_SeatSystem", CheckTick)
		end)
	end

	hook.Add("KeyPress", "AAS_SeatSystem", function(Ply, Key)
		if Key ~= IN_USE then return end
		if Ply:InVehicle() == true then return end
		-- prevent this from running if there is a seat within 96u?
		HoldTime	= CurTime()
		Holding = true

		CheckTimer()
	end)

	hook.Add("KeyRelease", "AAS_SeatSystem", function(Ply, Key)
		if Key ~= IN_USE then return end
		timer.Remove("AAS_SeatCheck")
		Holding	= false

		if Ply:InVehicle() == true then return end
		if not Check then return end

		Check = false

		if IsValid(BestChoice) then
			net.Start("aas_requestEnterSeat")
				net.WriteEntity(BestChoice)
			net.SendToServer()
		end
	end)

	local Base	= Color(75,75,75)
	local Bar	= Color(65,200,65)
	hook.Add("HUDPaint", "AAS_SeatSystem", function()
		if not (Holding or Check) then return end

		if Holding and not Check then
			local PercTime = math.Clamp((CurTime() - HoldTime) / Time,0,1)

			surface.SetDrawColor(Base)
			surface.DrawRect(SM.x - (UU * 1.4 / 2),SM.y + UU, UU * 1.4, 24)

			surface.SetDrawColor(Bar)
			surface.DrawRect(SM.x - (UU * 1.4 / 2) + 2,SM.y + UU + 2, ((UU * 1.4) - 4) * PercTime, 20)

			draw.SimpleTextOutlined("Remote enter seat","BasicFontLarge",SM.x, SM.y + UU + 12,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
		elseif Check then
			surface.SetDrawColor(Base)

			if IsValid(BestChoice) then
				surface.DrawRect(SM.x - (UU * 1.85 / 2),SM.y + UU, UU * 1.85, 24)
				draw.SimpleTextOutlined("Release to enter this seat","BasicFontLarge",SM.x, SM.y + UU + 12,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
			else
				surface.DrawRect(SM.x - (UU * 1.35 / 2),SM.y + UU, UU * 1.35, 24)
				draw.SimpleTextOutlined("Release to cancel","BasicFontLarge",SM.x, SM.y + UU + 12,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
			end
		end
	end)

	local GreenVec = Vector(0,255,0)
	local function RenderOverlay(Entity, Highlight)
		cam.Start3D()
			render.ClearStencil()
			render.SetStencilEnable(true)
			render.SetStencilReferenceValue(1)

			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilFailOperation(STENCIL_REPLACE)
			render.SetStencilZFailOperation(STENCIL_REPLACE)

			Entity:DrawModel()

			render.SetStencilCompareFunction(STENCIL_EQUAL)

			local ECol = Entity:GetColor()
			cam.Start2D()
				if Highlight then
					Col = LerpVector(TimedCos(0.75,0,1,0) + 0.5,GreenVec,Vector(ECol.r, ECol.g, ECol.b))

					surface.SetDrawColor(Col.r, Col.g, Col.b) -- Draw back over it with color, above 0 but below the model
				else
					surface.SetDrawColor(ECol.r, ECol.g, ECol.b)
				end

				surface.DrawRect(0,0,SW,SH)
			cam.End2D()

			render.SetStencilEnable(false)
		cam.End3D()
	end

	local Red = Color(255,0,0)
	hook.Add("PostDrawEffects","AAS_SeatSystem",function()
		if not Check then return end

		for _,Ent in ipairs(Seats) do
			if IsValid(Ent) and (Ent:GetPos():DistToSqr(EyePos()) < SeatMan.MaxDistance) and (Ent ~= BestChoice) then
				RenderOverlay(Ent,false)
			end
		end

		if IsValid(BestChoice) then
			RenderOverlay(BestChoice,true)

			cam.Start3D()
				render.SetColorMaterial()
				render.DrawWireframeSphere(BestChoice:LocalToWorld(BestChoice:OBBCenter()), BestChoice:BoundingRadius() * (1 + (TimedCos(0.75,0,1,0) * -0.125)), 8, 8, Red, false)
			cam.End3D()
		end

		render.ClearStencil()
	end)
else
	util.AddNetworkString("aas_requestSeats")
	util.AddNetworkString("aas_requestEnterSeat")

	SeatMan.Seats	= {}
	SeatMan.SeatOwnedBy	= {}

	function SeatMan.SeatsByTeam(Team)
		local SeatList	= {}

		for ply,seats in pairs(SeatMan.Seats) do
			if not IsValid(ply) then continue end

			for seat,plyTeam in pairs(seats) do
				if IsValid(seat) and (plyTeam == Team) then
					table.insert(SeatList, seat)
				end
			end
		end

		return SeatList
	end

	function SeatMan.AddSeat(Ply, Seat)
		local plyTeam = Ply:Team()
		if SeatMan.Seats[Ply] == nil then SeatMan.Seats[Ply] = {} end

		SeatMan.Seats[Ply][Seat] = plyTeam
		SeatMan.SeatOwnedBy[Seat] = Ply
	end

	net.Receive("aas_requestSeats",function(_,Ply)
		net.Start("aas_requestSeats")
			net.WriteTable(SeatMan.SeatsByTeam(Ply:Team()), true)
		net.Send(Ply)
	end)

	hook.Add("PlayerSpawnedVehicle", "AAS_SeatSystem", function(Ply, Seat)
		SeatMan.AddSeat(Ply, Seat)
	end)

	net.Receive("aas_requestEnterSeat",function(_,Ply)
		local Seat = net.ReadEntity()

		if not IsValid(Seat) then return end
		if (Seat:GetPos():DistToSqr(Ply:GetShootPos()) > (SeatMan.MaxDistance * 1.05)) then return end
		if SeatMan.SeatOwnedBy[Seat]:Team() ~= Ply:Team() then return end

		if IsValid(Seat:GetDriver()) and (SeatMan.SeatOwnedBy[Seat] == Ply) and (Seat:GetDriver() ~= Ply) then -- Give the seat owner priority to sit
			Seat:GetDriver():ExitVehicle()
		end

		Ply:EnterVehicle(Seat)
	end)

	hook.Add("CanPlayerEnterVehicle", "AAS_SeatSystem", function(Ply, Seat)
		if not SeatMan.SeatOwnedBy[Seat] then SeatMan.AddSeat(Ply, Seat) return true end -- Spawning seats by other means doesn't use the normal spawn hook, e.g. SitAnywhere
		if Ply:GetShootPos():DistToSqr(Seat:GetPos()) > SeatMan.MaxDistance then return false end
		if SeatMan.SeatOwnedBy[Seat]:Team() ~= Ply:Team() then return false end
		return true
	end)

	hook.Add("PlayerEnteredVehicle", "AAS_SeatSystem", function(Ply, Seat)
		if SeatMan.SeatOwnedBy[Seat]:Team() ~= Ply:Team() then
			Ply:ExitVehicle()
		end
	end)
end

--[[ Neat, saving until its separated, has an outline from Sobel shader that I want to further refine and make colorable, somehow
local GreenVec = Vector(0,255,0)
local function RenderOutline(Entity)
	cam.Start3D()
		render.ClearStencil()
		render.SetStencilEnable(true)

		render.SetStencilWriteMask(255)
		render.SetStencilTestMask(255)
		render.SetStencilReferenceValue(2)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilFailOperation(STENCIL_REPLACE)
		render.SetStencilZFailOperation(STENCIL_REPLACE)

		Entity:DrawModel() -- Initial "punch" for stencil layer

		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilCompareFunction(STENCIL_LESS)
		render.SetStencilWriteMask(0xFF)
		render.SetStencilReferenceValue(1)

		cam.Start2D()
			ECol = Entity:GetColor()
			Col = LerpVector(TimedCos(0.5,0,1,0) + 0.5,GreenVec,Vector(ECol.r, ECol.g, ECol.b))

			surface.SetDrawColor(Col.r, Col.g, Col.b) -- Draw back over it with color, above 0 but below the model
			surface.DrawRect(0,0,SW,SH)
		cam.End2D()

		render.SetStencilWriteMask(255)
		render.SetStencilReferenceValue(2)
		render.SetStencilCompareFunction(STENCIL_EQUAL) -- Wrap a sobel effect (outline, as with current settings) around the initial model punch

		render.UpdateScreenEffectTexture()
		render.SetMaterial(SobelMat)
		render.DrawScreenQuad()

		render.SetStencilEnable(false)
	cam.End3D()
end]]