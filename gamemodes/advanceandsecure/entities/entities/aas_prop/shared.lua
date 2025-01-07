ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category = "Gamemode"
ENT.Author = "LiddulBOFH"
ENT.PrintName = "AAS Prop"
ENT.Purpose = "Something to decorate the scene"

ENT.DisableDuplicator = true
ENT.AdminOnly = true

ENT.Spawnable = false

function ENT:CanTool(ply)
    return GetGlobalBool("EditMode",false)
end

function ENT:CanProperty(ply)
    return GetGlobalBool("EditMode",false)
end

if CLIENT then
    function ENT:ContextMenuEnabled()
        return GetGlobalBool("EditMode",false)
    end
end