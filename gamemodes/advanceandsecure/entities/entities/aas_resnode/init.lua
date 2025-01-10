AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel("")
	self:PhysicsInitStatic(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetUseType(SIMPLE_USE)

	self.CPPIOwner = game.GetWorld()
	self:SetOwner(game.GetWorld())
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

end

function ENT:Think()
	if AAS.State.Active == false then self:NextThink(CurTime() + 5) return end
end