include("shared.lua")

local BaseColor         = Color(65,65,65)
local SegLength         = 9
local RenderDistance    = 1536 ^ 2

function ENT:Initialize()
	self.InterpCapture	= 0
end

function ENT:GetCapColor()
	local FlagCol	= BaseColor

	if AAS.State.Alias then
		local Capture = self:GetCapture()

		if Capture > 0 then
			local TeamColor	= AAS.Funcs.GetTeamInfo(1).Color
			FlagCol = BaseColor:Lerp(Color(TeamColor.r, TeamColor.g, TeamColor.b), self.InterpCapture / 100)
		else
			local TeamColor	= AAS.Funcs.GetTeamInfo(2).Color
			FlagCol = BaseColor:Lerp(Color(TeamColor.r, TeamColor.g, TeamColor.b), -self.InterpCapture / 100)
		end
	end

	return FlagCol
end

--[[
	1 --- 2
	|     |
	3 --- 4
]]
local function DrawQuad(V1, V2, V3, V4, Col)
	render.DrawQuad(V1, V2, V3, V4, Col)
	render.DrawQuad(V4, V3, V2, V1, Col)
end

local function DrawFlag(Pole, Pos, Ang, Col)
	local Mag = math.abs(Pole.InterpCapture) / 100
	local WindMag	= Mag ^ 2

	local LastP1 = Pos
	local LastP2 = Pos
	local StartAng	= Ang
	local LastAng	= Ang
	local DroopShift	= TimedSin(0.1, 0, 0.5, 0)

	for I = 1, 9 do
		local Droop = (1 - Mag) ^ 4
		local Flap	= TimedCos(-4,0,1,I) * 1.5 * I
		local CounterFlap	= TimedSin(-5,0,1,I) * 1.5 * I

		local P1 = LerpVector(Droop,
			LastP1 + ((Ang:Right() * CounterFlap) * WindMag),
			LastP1 + (StartAng:Forward() * (DroopShift + -7.5 + (-I / 2) + (CounterFlap * WindMag * 2))) + (StartAng:Up() * (-2.75 + (-I / 3) + (CounterFlap * WindMag * 4))) + (StartAng:Right() * (0.75 + DroopShift + (CounterFlap * 4 * WindMag))))
		local P2 = LerpVector(Droop,
			LastP2 + ((LastAng:Right() * Flap) * WindMag),
			LastP2 + (StartAng:Forward() * (-3 + (-I / 2) + (DroopShift * 2))) + (StartAng:Up() * (-1.75 + (-I / 4) + (Flap * 2 * WindMag))) + (StartAng:Right() * (0.75 + (DroopShift * 2) + (Flap * 4 * WindMag))))

		LastAng	= Ang
		Ang = Ang + Angle(TimedCos(1,0,2,I) * WindMag, TimedCos(2,0,2,I) * WindMag, TimedCos(4,0,1,I) * WindMag)
		Ang = LerpAngle(0.1 * (1 - Mag), Ang, Angle(45,Ang.y,Ang.r))

		DrawQuad(
			LastP1 + (LastAng:Up() * 22),
			P1 + (Ang:Forward() * SegLength) + (Ang:Up() * 22),
			LastP2 + (LastAng:Up() * -22),
			P2 + (Ang:Forward() * SegLength) + (Ang:Up() * -22),
			Col
		)

		LastP1 = P1 + (Ang:Forward() * SegLength)
		LastP2 = P2 + (Ang:Forward() * SegLength)
	end
end

function ENT:Think()
	local Capture = self:GetCapture()

	self.InterpCapture	= Lerp(RealFrameTime() * 2.5, self.InterpCapture, Capture)
end

local function InRange(point, pos)
	local PointPos = point:GetPos()
	return (PointPos:Distance2DSqr(pos) < AAS.CapRange) and (pos.z > (PointPos.z - 64)) and (pos.z < (PointPos.z + 256))
end

function ENT:Draw()
	self:DrawModel()
	self:CreateShadow()

	render.SetColorMaterial()

	render.OverrideDepthEnable(true, true)

	local Mag		= math.abs(self.InterpCapture) / 100
	local Time		= self:GetCreationTime()
	local SegDir	= self:GetAngles()
	local Up		= self:GetUp()
	local Pos		= self:GetPos()
	local Raise		= 84 + (Mag * 140)
	local EyeDist	= Pos:DistToSqr(EyePos())
	local FlagCol	= self:GetCapColor()

	render.DrawSphere(Pos + (Up * 256), 8, 8, 8, FlagCol)

	SegDir = SegDir + Angle(0, (TimedCos(0.5,-4,4,Time) + 4) + TimedCos(0.0005,-600,600,Time), 0)
	if EyeDist > RenderDistance then

		local P1 = Pos + (Up * Raise)

		SegDir = SegDir + Angle(45 * (1 - Mag), 0, 0)
		local P2 = Pos + (Up * Raise) + (SegDir:Forward() * SegLength * 9 * math.Clamp(Mag, 0.5, 1))

		DrawQuad(P1 + (Up * 22), P2 + (Up * 22 * math.max(0.5, Mag)), P1 - (Up * 22), P2 + (SegDir:Up() * -22), FlagCol)

		render.OverrideDepthEnable(false, false)
		return
	end

	SegDir = SegDir + Angle(TimedCos(0.2,-2,2,Time) + 2, 0, TimedCos(0.24,-4,4,Time) + 4)

	local SegPos = Pos + (Up * Raise) + (SegDir:Forward() * (12 + TimedCos(0.2,0,2,0) + ((Mag ^ 3) * 6)))

	render.DrawBeam(SegPos + (SegDir:Up() * 22) + ((SegDir:Forward() - SegDir:Up()) * 0.5), Pos + (SegDir:Forward() * 6) + Vector(0,0,250), 0.5, -2, 2, color_black)
	render.DrawBeam(SegPos + (SegDir:Up() * -22) + ((SegDir:Forward() + SegDir:Up()) * 0.5), Pos  + (SegDir:Forward() * 6) + Vector(0,0,30), 0.5, -2, 2, color_black)

	DrawFlag(self, SegPos, SegDir, FlagCol)

	render.OverrideDepthEnable(false, false)

	local EP	= EyePos()
	if InRange(self, EP) then
		local LP	= LocalPlayer()
		if (not IsValid(LP)) or (LP == NULL) then return end
		local TN	= LP:Team()
		local UseText	= string.upper(input.LookupBinding("+use"))

		local Dir2Player	= ((EP - Pos) * Vector(1, 1, 0)):GetNormalized()

		cam.Start3D2D((Dir2Player * 20) + Vector(Pos.x, Pos.y, EP.z + TimedCos(0.2, 0, 1, 0)), Dir2Player:Angle() + Angle(0, 90, 90), 0.05)
			draw.NoTexture()
			surface.SetDrawColor(color_black)

			if self:GetIsSpawn() and (self:GetTeamSpawn() == TN) then
				draw.SimpleTextOutlined("Press " .. UseText .. " to change loadout", "BasicFontExtraLarge", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
			else
				draw.RoundedBox(8, -160, -90, 320, 50, color_black)
				draw.RoundedBox(8, -158, -88, 316 * Mag, 46, FlagCol)
				draw.SimpleTextOutlined(tostring(math.abs(self:GetCapture())) .. "%", "BasicFontExtraLarge", 0, -65, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)

				draw.SimpleTextOutlined(self:GetPointName(), "BasicFontExtraLarge", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)

				if CapStatus(self) == TN then
					draw.SimpleTextOutlined("Press " .. UseText .. " to refill ammo", "BasicFontExtraLarge", 0, 64, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
				end
			end
		cam.End3D2D()
	end
end