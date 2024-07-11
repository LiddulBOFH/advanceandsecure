ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category = "Gamemode"
ENT.Author = "LiddulBOFH"
ENT.PrintName = "Capture Point"
ENT.Purpose = "A capture point for a gamemode"

ENT.DisableDuplicator = true
ENT.AdminOnly = true

ENT.Editable = true

ENT.Spawnable = false

function ENT:CanTool(ply)
    return GetGlobalBool("EditMode",false)
end

function ENT:CanProperty(ply)
    return GetGlobalBool("EditMode",false)
end

function ENT:SetupDataTables()
    -- The name of the actual point
    self:NetworkVar("String",0,"PointName",{KeyName = "pointname",Edit = {title = "Point Name",category = "Basic",waitforenter = true,type = "String",order = 1}})
    self:NetworkVar("Int",1,"Capture") -- Capture amount, -100 is OPFOR, 100 is BLUFOR

    -- If IsSpawn is true, then only 1 connection is needed
    self:NetworkVar("Bool",0,"IsSpawn",{KeyName = "isspawn",Edit = {title = "Is spawn?",category = "Spawn",type = "Boolean",order = 2}})
    self:NetworkVar("Int",2,"TeamSpawn",{KeyName = "teamspawn",Edit = {title = "Spawn for who?",category = "Spawn",type = "Combo",order = 3,text = "A",values = {A = 1,B = 2}}})

    self:NetworkVar("Bool",1,"ForceUpdate")

    if SERVER then
        self:SetPointName(tostring(math.random(100000)))
        self:SetTeamSpawn(1)
        self:SetIsSpawn(false)
        self:SetCapture(0)
    end

    if CLIENT then
        self.InterpCapture = 0

        self:NetworkVarNotify("ForceUpdate",function(ent,_,old,new) print(ent,"name",old,new) end)
    end
end
