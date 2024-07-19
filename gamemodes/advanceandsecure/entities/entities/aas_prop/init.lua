AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/hunter/blocks/cube1x1x1.mdl")

	self:SetEditable(GetGlobalBool("EditMode",false))

	self.CPPIOwner = game.GetWorld()
	self:SetOwner(game.GetWorld())
end

function ENT:SetEditable(Bool)
	if Bool then
		self:PhysicsInit(SOLID_VPHYSICS)
	else
		self:PhysicsInitStatic(SOLID_VPHYSICS)
	end

	self:SetMoveType(MOVETYPE_NONE)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)

	local physobj = self:GetPhysicsObject()

	if IsValid(physobj) then
		physobj:SetMass(50000) -- Mass helps with physics, and these props are supposed to be static
		physobj:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC)
		physobj:RecheckCollisionFilter()
	end
end

-- Special function that ACF will check, usually has DmgResult and DmgInfo passed, but we are just flat denying any damage
function ENT:ACF_PreDamage() return false end

function ENT:PhysgunPickup()
	return GetGlobalBool("EditMode",false)
end