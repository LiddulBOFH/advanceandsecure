include("shared.lua")

local function mixColor(ColorA,ColorB,Mix)
    local CA = ColorA:ToVector()
    local CB = ColorB:ToVector()
    return (CB * (1 - Mix) + CA * Mix):ToColor()
end

local BaseColor         = Color(65,65,65)
local SegLength         = 16
local RenderDistance    = 1536 ^ 2

function ENT:Draw()
    self:DrawModel()

    local Capture = self:GetCapture()

    if not self.InterpCapture then self.InterpCapture = 0 end

    self.InterpCapture = self.InterpCapture + (Capture - self.InterpCapture) * RealFrameTime() * 2.5

    local EyeDist = self:GetPos():DistToSqr(EyePos())

    local FlagCol
    if Capture > 0 then FlagCol = mixColor(AAS.TeamData[1]["Color"],BaseColor,self.InterpCapture / 100) else FlagCol = mixColor(AAS.TeamData[2]["Color"],BaseColor,-self.InterpCapture / 100) end

    render.SetColorMaterial()

    render.OverrideDepthEnable(true,true)

    local Time = self:GetCreationTime()
    local SegDir = self:GetAngles()
    local Up = self:GetUp()

    render.DrawSphere(self:GetPos() + (self:GetUp() * 256),8,8,8,FlagCol)

    if EyeDist > RenderDistance then
        SegDir = SegDir + Angle(0,TimedCos(0.0005,-600,600,Time),0)

        local ShortSegPos = self:GetPos() + (Up * (64 + (math.abs(self.InterpCapture) * 160 / 100))) + (SegDir:Forward() * 12)

        render.DrawBox(ShortSegPos + (SegDir:Forward() * SegLength * 3), SegDir, Vector(-SegLength * 3, - 0.3, -22), Vector(SegLength * 3, 0.3, 22), FlagCol)

        render.OverrideDepthEnable(false,false)
        return
    end

    SegDir = SegDir + Angle(TimedCos(0.2,-2,2,Time) + 2,(TimedCos(0.5,-4,4,Time) + 4) + TimedCos(0.0005,-600,600,Time),TimedCos(0.24,-4,4,Time) + 4)

    local SegPos = self:GetPos() + (Up * (64 + (math.abs(self.InterpCapture) * 160 / 100))) + (SegDir:Forward() * (12 + TimedCos(0.2,0,2,0)))

    render.DrawBeam(SegPos + (SegDir:Up() * 22) + ((SegDir:Forward() - SegDir:Up()) * 0.5),self:GetPos() + (SegDir:Forward() * 6) + Vector(0,0,250),0.5,-2,2,color_black)
    render.DrawBeam(SegPos + (SegDir:Up() * -22) + ((SegDir:Forward() + SegDir:Up()) * 0.5),self:GetPos()  + (SegDir:Forward() * 6) + Vector(0,0,30),0.5,-2,2,color_black)

    SegDir = SegDir + Angle(0,TimedCos(0.5,-4,4,Time) + 4,0)

    for I = 1, 6 do
        render.DrawBox(SegPos + (SegDir:Forward() * SegLength / 2),SegDir,Vector(-SegLength / 2,-0.3,-22),Vector(SegLength / 2,0.3,22),FlagCol)
        SegPos = SegPos + (SegDir:Forward() * (SegLength - 0.2))
        local A = TimedSin(0.4 + math.sin(I * 0.2),-7,7,Time + (I * 3)) + 7
        SegDir = SegDir + Angle(0,A,0)
    end

    render.OverrideDepthEnable(false,false)
end
