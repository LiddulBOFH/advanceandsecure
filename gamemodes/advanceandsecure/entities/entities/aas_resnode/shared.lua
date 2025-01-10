ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category = "Gamemode"
ENT.Author = "LiddulBOFH"
ENT.PrintName = "Resource Node"
ENT.Purpose = "A resource node for a gamemode"

ENT.DisableDuplicator = true
ENT.AdminOnly = true

ENT.Editable = true

function ENT:CanTool(ply)
	return GetGlobalBool("EditMode",false)
end

function ENT:CanProperty(ply)
	return GetGlobalBool("EditMode",false)
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ResourceInt", {KeyName = "resourceint", Edit = {title = "Resource per interval", category = "Basic", order = 1, min = 1, max = 100}})
	self:NetworkVar("Int", 1, "ResourceMax", {KeyName = "resourcemax", Edit = {title = "Maximum held resources", category = "Basic", order = 2, min = 50, max = 1000}})

	self:NetworkVar("Float", 1, "NextUpdate")	-- Next time that the node increments the amount held

	-- Initial values that get set on first spawn, to be overridden by the server if loaded in
	if SERVER then
		self:SetResourceInt(25)
		self:SetResourceMax(250)
		self:SetNextUpdate(CurTime())
	end
end