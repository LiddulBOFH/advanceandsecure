AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_trainstation/trainstation_column001.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:PhysicsInitStatic(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    self.CPPIOwner = game.GetWorld()
    self:SetOwner(game.GetWorld())

    self.LastHeld = 0
    self.LastTeamHeld = 0
    self.Interactive = false
    self.PrevCaptured = false

    self.UseList = {}

    self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
end

-- These should -always- exist on the client
function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

-- Special function that ACF will check, usually has DmgResult and DmgInfo passed, but we are just flat denying any damage
function ENT:ACF_PreDamage() return false end

function ENT:PhysgunPickup()
    return GetGlobalBool("EditMode",false)
end

function ENT:Use(activator,caller) -- activator and caller are usually the same, except for proxies (wire_user)
    if activator ~= caller then aasMsg({Color(255,0,0),"You aren't allowed to remotely use this!"},activator) return end
    if CapStatus(self) ~= activator:Team() then aasMsg({Color(255,0,0),"This is not your point!"},activator) return end
    if self:GetIsSpawn() == true then
        NewPlyManager.ChargeAmmo(activator,true)
        NewPlyManager.OpenLoadout(activator)
    else
        NewPlyManager.ChargeAmmo(activator,false)
    end
end

function ENT:Think()
    if not IsValid(self) then return end
    local Capture = self:GetCapture()
    local LastHeld = self.LastHeld

    if self:GetIsSpawn() == true then
        if Capture == ((self:GetTeamSpawn() == 1) and 100 or -100) then self:NextThink(CurTime() + 10) return true end
        if self:GetTeamSpawn() == 1 then
            self:SetIsSpawn(true)
            self:SetCapture(100)
            self:SetPointName("SpawnA")
        else
            self:SetIsSpawn(true)
            self:SetCapture(-100)
            self:SetPointName("SpawnB")
        end
        self.HoldStatus = self:GetTeamSpawn()
        return
    end

    local Players = player.GetAll()
    local Cap1 = 0
    local Cap2 = 0

    for k,v in ipairs(Players) do
        local Team = v:Team()
        local Seated = v:InVehicle()
        local Dist2Point = (self:GetPos() + Vector(0,0,64)):DistToSqr(v:GetPos())
        local PointMod = Seated and 0.25 or 1
        if Dist2Point < AAS.CapRange and checkConnection(self,AAS.RAASLine,AAS.RAASLookup,Team) then
            if Team == 1 then Cap1 = Cap1 + PointMod elseif Team == 2 then Cap2 = Cap2 + PointMod end
            if not Seated then AdjustKarma(v,1) end
        end
    end

    local TotalCap = ((Cap1 ^ 1.2) - (Cap2 ^ 1.2)) * 2
    if TotalCap ~= 0 then
        if TotalCap > 0 then TotalCap = math.ceil(TotalCap)
        else TotalCap = math.floor(TotalCap) end
    end

    self:SetCapture(math.Clamp(Capture + math.Clamp(TotalCap,-20,20),-100,100))
    local HoldStatus = CapStatus(self)
    if HoldStatus ~= LastHeld then
        aas_PointStateChange(self,self.LastHeld,HoldStatus)

        if not self.PrevCaptured and (HoldStatus ~= 0) then
            self.PrevCaptured = true
            DoTicketChange(HoldStatus,20,false)
        elseif self.PrevCaptured and HoldStatus ~= 0 and (self.LastTeamHeld ~= HoldStatus) then
            DoTicketChange(HoldStatus,30,false)
            DoTicketChange(self.LastTeamHeld,-10,true)
        end
        if HoldStatus ~= 0 then self.LastTeamHeld = HoldStatus end
        self.LastHeld = HoldStatus
    end

    self:NextThink(CurTime() + 1)
    return true
end
