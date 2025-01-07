AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_trainstation/trainstation_column001.mdl")
	self:PhysicsInitStatic(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetUseType(SIMPLE_USE)

	self.CPPIOwner = game.GetWorld()
	self:SetOwner(game.GetWorld())

	self.LastHeld = 0
	self.LastTeamHeld = 0
	self.Interactive = false
	self.PrevCaptured = false

	self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
	self:AddEFlags(EFL_IN_SKYBOX)
	self:SetRenderMode(RENDERMODE_NORMAL)
end

-- These should -always- exist on the client
function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end

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

		local AmmoCrates = ents.FindByClass("acf_ammo")
		local ValidCrates = {}

		for _,crate in ipairs(AmmoCrates) do
			if not IsValid(crate.Owner) then continue end
			if crate.Owner ~= activator then continue end

			if AAS.Funcs.EntInPlayerSafezone(crate, activator) then table.insert(ValidCrates, crate) end
		end

		if #AmmoCrates > 0 then
			for _, crate in ipairs(AmmoCrates) do
				crate.Ammo = crate.Capacity
			end

			aasMsg({Colors.BasicCol, "All nearby (" .. #AmmoCrates .. ") ammo crates have been refilled for free."}, activator)
		end
	else
		NewPlyManager.ChargeAmmo(activator,false)
	end
end

local function aas_PointStateChange(point,oldstatus,newstatus)
	net.Start("AAS.UpdatePointState")
		net.WriteString(point:GetPointName())
		net.WriteInt(oldstatus,3)
		net.WriteInt(newstatus,3)
	net.Broadcast()
end

local function InRange(point, pos)
	local PointPos = point:GetPos()
	return (PointPos:Distance2DSqr(pos) < AAS.CapRange) and (pos.z > (PointPos.z - 64)) and (pos.z < (PointPos.z + 256))
end

local DoTicketChange	= AAS.Funcs.DoTicketChange
function ENT:Think()
	if not IsValid(self) then return end
	local Capture = self:GetCapture()
	local LastHeld = self.LastHeld

	if self:GetIsSpawn() == true then
		if Capture == ((self:GetTeamSpawn() == 1) and 100 or -100) then self:NextThink(CurTime() + 10) self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT) return true end

		self:SetIsSpawn(true)
		self:SetLocked(true)

		if self:GetTeamSpawn() == 1 then
			self:SetCapture(100)
			self:SetPointName("SpawnA")
		else
			self:SetCapture(-100)
			self:SetPointName("SpawnB")
		end

		self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

		self.HoldStatus = self:GetTeamSpawn()
		self:NextThink(CurTime())
		return true
	end

	if AAS.State.Active == false then self:NextThink(CurTime() + 5) return true end

	local Cap1 = 0
	local Cap2 = 0

	for k,v in player.Iterator() do
		if (not IsValid(v)) or (v == NULL) then continue end

		local Team = v:Team()
		local Seated = v:InVehicle()
		local PointMod = Seated and 0.25 or 1

		if InRange(self, v:GetPos()) and checkConnection(self, AAS.State.Alias, AAS.State.Data["Line"], AAS.State.LineLookup, Team) then
			if Team == 1 then Cap1 = Cap1 + PointMod elseif Team == 2 then Cap2 = Cap2 + PointMod end
			if (not Seated) and (Capture ~= (Team == 1 and 100 or -100)) then AAS.Funcs.AdjustKarma(v, 1) AAS.Funcs.AddPlayerXP(v, 1) end
		end
	end

	local TotalCap = ((Cap1 ^ 1.2) - (Cap2 ^ 1.2)) * 2
	if TotalCap ~= 0 then
		if TotalCap > 0 then
			TotalCap = math.ceil(TotalCap)
		else
			TotalCap = math.floor(TotalCap)
		end
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
