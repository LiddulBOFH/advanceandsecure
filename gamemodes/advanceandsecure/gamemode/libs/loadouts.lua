-- Since the default playerclass stuff is so asinine and 90% not documented, I'm just going to make my own system :)
AddCSLuaFile()
MsgN("+ Class system loaded")

NewPlyManager = NewPlyManager or {Classes = {}}

--[[
    Decided to move away from actual "classes"
    Armor is determined by the suit type that the player chooses

    Movespeed is affected by WU, or Weight Units
    Armor as well as weapon choice dictates how much WU the player has
]]--

NewPlyManager.Weapons = { -- If it ain't here, you can't have it
    -- RIFFLES
    weapon_acf_ak47         = {Name = "AK47",Cost = 0, Type = "Rifle", WU = 3.5},
    weapon_acf_aug          = {Name = "AUG",Cost = 6, Type = "Rifle", WU = 4},
    weapon_acf_famas        = {Name = "Famas",Cost = 5, Type = "Rifle", WU = 4},
    weapon_acf_galil        = {Name = "Galil",Cost = 7, Type = "Rifle", WU = 5},
    weapon_acf_garand       = {Name = "M1 Garand",Cost = 5, Type = "Rifle", WU = 5.5},
    weapon_acf_kar98k       = {Name = "Kar98K",Cost = 6, Type = "Rifle", WU = 4},
    weapon_acf_m1carbine    = {Name = "M1 Carbine",Cost = 5, Type = "Rifle", WU = 2.5},
    weapon_acf_m4a1         = {Name = "M4A1",Cost = 0, Type = "Rifle", WU = 3},
    weapon_acf_mp40         = {Name = "MP40",Cost = 0, Type = "Rifle", WU = 5},
    weapon_acf_mp44         = {Name = "MP44",Cost = 6, Type = "Rifle", WU = 4},
    weapon_acf_sg552        = {Name = "SG552",Cost = 10, Type = "Rifle", WU = 4.5},

    -- ELL EMM GEES
    weapon_acf_bar          = {Name = "M1918 BAR",Cost = 10, Type = "LMG", WU = 6},
    weapon_acf_m249         = {Name = "M249",Cost = 12, Type = "LMG", WU = 6},
    weapon_acf_30cal        = {Name = "M1919 Browning LMG",Cost = 14, Type = "LMG", WU = 8},
    weapon_acf_mg42         = {Name = "MG42",Cost = 16, Type = "LMG", WU = 8},

    -- SMIGS
    weapon_acf_m1thompson   = {Name = "M1 Thompson",Cost = 4, Type = "SMG", WU = 3},
    weapon_acf_mp5          = {Name = "MP5",Cost = 4, Type = "SMG", WU = 3},
    weapon_acf_p90          = {Name = "P90",Cost = 6, Type = "SMG", WU = 4.5},
    weapon_acf_ump45        = {Name = "UMP45",Cost = 4, Type = "SMG", WU = 3.5},

    -- PISTOLOS
    weapon_acf_c96          = {Name = "C96",Cost = 4, Type = "Pistol", WU = 2.5},
    weapon_acf_deagle       = {Name = "Desert Eagle",Cost = 8, Type = "Pistol", WU = 3},
    weapon_acf_57           = {Name = "Five-SeveN",Cost = 0, Type = "Pistol", WU = 0.5},
    weapon_acf_glock        = {Name = "Glock 18",Cost = 5, Type = "Pistol", WU = 1.5},
    weapon_acf_colt         = {Name = "M1911",Cost = 3, Type = "Pistol", WU = 1.5},
    weapon_acf_p38          = {Name = "P38",Cost = 0, Type = "Pistol", WU = 1},
    weapon_acf_usp          = {Name = "USP",Cost = 0, Type = "Pistol", WU = 1},
    weapon_acf_357magnum    = {Name = ".357 Magnum",Cost = 4, Type = "Pistol", WU = 2.5},

    -- SNOIPAHS
    weapon_acf_g3sg1        = {Name = "G3SG1",Cost = 12, Type = "Sniper", WU = 6},
    weapon_acf_sg550        = {Name = "SG550",Cost = 12, Type = "Sniper", WU = 6},
    weapon_acf_scout        = {Name = "Scout",Cost = 10, Type = "Sniper", WU = 3},
    weapon_acf_amr          = {Name = "Anti-Material Rifle",Cost = 35, Type = "Sniper", WU = 15},
    weapon_acf_kar98kscoped = {Name = "Kar98K (Scoped)",Cost = 8, Type = "Sniper", WU = 6},
    weapon_acf_lapua        = {Name = "Lapua",Cost = 20, Type = "Sniper", WU = 7.5},
    weapon_acf_springfield  = {Name = "M1903 Springfield",Cost = 8, Type = "Sniper", WU = 6},
    weapon_acf_crossbow     = {Name = "Rebar Crossbow",Cost = 15, Type = "Sniper", WU = 4},
}
NewPlyManager.Gadgets = {
    -- ROGGETS
    weapon_acf_bazooka      = {Name = "M3 Bazooka",Cost = 25, Type = "Launcher", WU = 12},
    weapon_acf_panzerschreck = {Name = "Panzerschrek",Cost = 40, Type = "Launcher", WU = 18},

    toolkit                 = {Name = "Toolkit",Cost = 25,Type = "Kit", WU = 5},
    medkit                  = {Name = "Medkit",Cost = 0,Type = "Kit", WU = 5},

    acf_torch               = {Name = "ACF Torch",Cost = 10,Type = "Torch", WU = 2}
}
NewPlyManager.KitList = {
    toolkit                 = {"gmod_tool","weapon_physgun"},
    medkit                  = {"weapon_medkit"}
}

-- name = {max = 7 (default, full magazines)
NewPlyManager.AmmoExceptions = {
    -- Special requirements
    weapon_acf_30cal = {max = 2},
    weapon_acf_mg42 = {max = 2},
    weapon_acf_m249 = {max = 4},

    weapon_acf_grenadelauncher = {max = 3},
    weapon_acf_panzerschreck = {max = 2},
    weapon_acf_bazooka = {max = 2},

    weapon_acf_amr = {max = 9},
    weapon_acf_crossbow = {max = 9},
}

NewPlyManager.AmmoCost = { -- Points per bullet (will be rounded up)
    SMG1 = 0.05,
    AR2 = 0.1,
    Pistol = 0.05,
    ["357"] = 0.25,
    Buckshot = 0.25,
    XBowBolt = 2.5,
    SMG1_Grenade = 5,
    RPG_Round = 10
}

NewPlyManager.DefaultLoadout = {
    Armor = 25,
    Primary = "weapon_acf_m4a1",
    Sidearm = "weapon_acf_usp",
    Gadget1 = "",
    Gadget2 = ""
}

NewPlyManager.BaseMoveSpeed = 275
NewPlyManager.MinMoveSpeed = 100

local function AmmoDiff(ply,weapon)
    if not IsValid(weapon) then return 0 end
    if not weapon.Primary then return 0 end
    local spareMags = 7
    local ClipSize = weapon.Primary.ClipSize
    local AmmoType = weapon.Primary.Ammo

    if NewPlyManager.AmmoExceptions[weapon:GetClass()] then spareMags = NewPlyManager.AmmoExceptions[weapon:GetClass()].max or spareMags end

    local max = ClipSize + spareMags * weapon.Primary.ClipSize

    local current = weapon:Clip1() + ply:GetAmmoCount(AmmoType)

    return math.max(max - current,0)
end

local function AmmoCost(Diff,AmmoType)
    return (NewPlyManager.AmmoCost[AmmoType] or 0.1) * Diff
end

function NewPlyManager.ChargeAmmo(Ply,Free,Quiet)
    local maxlist = {}
    local Weapons = Ply:GetWeapons()

    local curwep = Ply:GetActiveWeapon()
    local curwepAmmoDiff = AmmoDiff(Ply,curwep)
    if IsValid(curwep) and (not Free) and curwep:GetPrimaryAmmoType() ~= -1 and curwepAmmoDiff > 0 then -- give ammo to max out this weapon only
        local cost = math.ceil(AmmoCost(curwepAmmoDiff,curwep.Primary.Ammo))

        local Pass = ChargeRequisition(Ply,cost,"Refilling (" .. curwep.PrintName .. ") ammo")
        if Pass then
            if not Quiet then aasMsg({Colors.BasicCol,"(" .. curwep.PrintName .. ") has been refilled. Press E again to refill everything!"},Ply) end
            Ply:GiveAmmo(curwepAmmoDiff,curwep.Primary.Ammo)
        else
            if not Quiet then aasMsg({Colors.ErrorCol,"You can't afford to refill ammo for (" .. curwep.PrintName .. ") (" .. cost .. ")!"},Ply) end
        end
    else -- fill ALL of the weapons according to the max overall allowed
        for k,v in ipairs(Weapons) do
            if v:GetPrimaryAmmoType() == -1 then continue end
            maxlist[v.Primary.Ammo] = math.max(maxlist[v.Primary.Ammo] or 0, AmmoDiff(Ply,v))
        end

        if Free == true then
            if not Quiet then aasMsg({Colors.BasicCol,"All of your ammo has been refilled for free."},Ply) end
            for k,v in pairs(maxlist) do
                Ply:GiveAmmo(v,k)
            end
            return
        end

        local cost = 0
        for k,v in pairs(maxlist) do
            cost = cost + AmmoCost(v,k)
        end
        cost = math.ceil(cost)

        if cost ~= 0 then
            local Pass = ChargeRequisition(Ply,cost,"Refilling all ammo")
            if Pass then
                if not Quiet then aasMsg({Colors.BasicCol,"All of your ammo has been refilled."},Ply) end
                for k,v in pairs(maxlist) do
                    Ply:GiveAmmo(v,k)
                end
            else
                if not Quiet then aasMsg({Colors.ErrorCol,"You can't afford to refill all of your ammo! (" .. cost .. ")"},Ply) end
            end
        else
            if not Quiet then aasMsg({Colors.BasicCol,"All of your ammo is already full!"},Ply) end
        end
    end
end

function NewPlyManager.BuildLoadout(OldLoadout,Loadout)
    local Cost = 0
    local WU = -12.5 -- Starting armor of 25 has no speed penalty, call it conditioning
    local Movespeed = NewPlyManager.BaseMoveSpeed
    local SWEPList = {}

    if Loadout.Primary ~= "" then
        local Wep = NewPlyManager.Weapons[Loadout.Primary]
        Cost = Cost + (OldLoadout.Primary ~= Loadout.Primary and Wep.Cost or 0)
        WU = WU + Wep.WU

        SWEPList[#SWEPList + 1] = Loadout.Primary
    end

    if Loadout.Sidearm ~= "" then
        local Wep = NewPlyManager.Weapons[Loadout.Sidearm]
        Cost = Cost + (OldLoadout.Sidearm ~= Loadout.Sidearm and Wep.Cost or 0)
        WU = WU + Wep.WU

        SWEPList[#SWEPList + 1] = Loadout.Sidearm
    end

    if Loadout.Gadget1 ~= "" then
        local Gdgt = NewPlyManager.Gadgets[Loadout.Gadget1]
        Cost = Cost + (OldLoadout.Gadget1 ~= Loadout.Gadget1 and Gdgt.Cost or 0)
        WU = WU + Gdgt.WU

        if Gdgt.Type == "Kit" then
            for k,v in pairs(NewPlyManager.KitList[Loadout.Gadget1]) do
                SWEPList[#SWEPList + 1] = v
            end
        else
            SWEPList[#SWEPList + 1] = Loadout.Gadget1
        end
    end

    if Loadout.Gadget2 ~= "" then
        local Gdgt = NewPlyManager.Gadgets[Loadout.Gadget2]
        Cost = Cost + (OldLoadout.Gadget2 ~= Loadout.Gadget2 and Gdgt.Cost or 0)
        WU = WU + Gdgt.WU

        if Gdgt.Type == "Kit" then
            for k,v in pairs(NewPlyManager.KitList[Loadout.Gadget2]) do
                SWEPList[#SWEPList + 1] = v
            end
        else
            SWEPList[#SWEPList + 1] = Loadout.Gadget2
        end
    end

    local Armor = math.floor(Loadout.Armor)

    WU = math.max(WU + (Armor / 3),0)
    Cost = Cost + math.ceil(math.max(0,Armor - 25) / 2)

    Cost = math.ceil(Cost)
    WU = math.Round(WU,1)
    Movespeed = math.Clamp(math.ceil(Movespeed - (WU * 2.5)),NewPlyManager.MinMoveSpeed,Movespeed)

    return {cost = Cost,speed = Movespeed,armor = Armor,give = SWEPList,flags = {}}
end

if SERVER then
    function NewPlyManager.OpenLoadout(ply)
        if not ply.PlayerLoadout then ply.PlayerLoadout = table.Copy(NewPlyManager.DefaultLoadout) end
        net.Start("aas_openloadout")
            net.WriteTable(ply.PlayerLoadout)
        net.Send(ply)
    end

    net.Receive("aas_receiveplayerloadout",function(_,ply)
        local Loadout = net.ReadTable()

        Loadout.Armor = math.Clamp(math.Round(Loadout.Armor),0,100)

        if (Loadout.Primary ~= "") and ((not NewPlyManager.Weapons[Loadout.Primary]) or (NewPlyManager.Weapons[Loadout.Primary].Type == "Pistol")) then
            Loadout.Primary = NewPlyManager.DefaultLoadout.Primary -- Something wasn't right, so they get the default freebie
        end

        if (Loadout.Sidearm ~= "") and ((not NewPlyManager.Weapons[Loadout.Sidearm]) or (NewPlyManager.Weapons[Loadout.Sidearm].Type ~= "Pistol")) then
            Loadout.Sidearm = NewPlyManager.DefaultLoadout.Sidearm -- Something wasn't right, so they get the default freebie
        end

        local UsedGadgetType = ""
        if (Loadout.Gadget1 ~= "") and (not NewPlyManager.Gadgets[Loadout.Gadget1]) then
            Loadout.Gadget1 = NewPlyManager.DefaultLoadout.Gadget1 -- Something wasn't right, so they get the default gadget
        end
        if (Loadout.Gadget1 ~= "") and NewPlyManager.Gadgets[Loadout.Gadget1] then UsedGadgetType = NewPlyManager.Gadgets[Loadout.Gadget1].Type end

        if (Loadout.Gadget2 ~= "") and ((not NewPlyManager.Gadgets[Loadout.Gadget2]) or (NewPlyManager.Gadgets[Loadout.Gadget2].Type == UsedGadgetType)) then
            Loadout.Gadget2 = NewPlyManager.DefaultLoadout.Gadget2 -- Something wasn't right, so they get the default gadget
        end

        ply.OldLoadout = table.Copy(ply.PlayerLoadout)
        ply.PlayerLoadout = Loadout

        if PlyInSafezone(ply,ply:GetPos()) then
            aasMsg({Colors.BasicCol,"Your loadout has been saved!"},ply)
            ply.FirstSpawn = true
            ply:Spawn()
        else
            aasMsg({Colors.BasicCol,"Your loadout has been saved, but you aren't in a safezone!"},ply)
        end
    end)
end

local PLAYER = FindMetaTable("Player")

function PLAYER:ApplyLoadout()
    if not self.PlayerLoadout then self.PlayerLoadout = table.Copy(NewPlyManager.DefaultLoadout) self.OldLoadout = {} end

    -- Odds are they are also getting a new loadout
    self:StripAmmo()
    self:StripWeapons()

    self:SetNoCollideWithTeammates(true)
    self:ShouldDropWeapon(false)

    self:SetMaxHealth(100)
    self:SetHealth(100)

    local LoadoutData = NewPlyManager.BuildLoadout(self.OldLoadout,self.PlayerLoadout)

    local Pass = ChargeRequisition(self,LoadoutData.cost,"Loadout cost")

    if not Pass then
        aasMsg({Colors.BadCol,"You can't afford your loadout! Giving default loadout... (your loadout is still saved)"},self)
        LoadoutData = NewPlyManager.BuildLoadout(table.Copy(NewPlyManager.DefaultLoadout),table.Copy(NewPlyManager.DefaultLoadout))
    end

    for k,v in pairs(LoadoutData.give) do
        self:Give(v)
    end

    NewPlyManager.ChargeAmmo(self,true,true)

    self:SetRunSpeed(math.ceil(LoadoutData.speed * 1.5))
    self:SetWalkSpeed(LoadoutData.speed)
    self:SetSlowWalkSpeed(math.floor(LoadoutData.speed * 0.5))

    self:SetMaxArmor(LoadoutData.armor)
    self:SetArmor(LoadoutData.armor)
end

local ModelList = {
    [1] = "models/player/group03/male_01.mdl",
    [2] = "models/player/Group03/male_02.mdl",
    [3] = "models/player/Group03/male_03.mdl",
    [4] = "models/player/Group03/male_04.mdl",
    [5] = "models/player/Group03/male_05.mdl",
    [6] = "models/player/Group03/male_06.mdl",
    [7] = "models/player/Group03/male_07.mdl",
    [8] = "models/player/Group03/male_08.mdl",
    [9] = "models/player/Group03/male_09.mdl",
    [10] = "models/player/Group03/female_01.mdl",
    [11] = "models/player/Group03/female_02.mdl",
    [12] = "models/player/Group03/female_03.mdl",
    [13] = "models/player/Group03/female_04.mdl",
    [14] = "models/player/Group03/female_05.mdl",
    [15] = "models/player/Group03/female_06.mdl",
}

function GM:PlayerSetModel(ply)
   local mdl = ModelList[math.random(#ModelList)] or "models/player/Group03/male_02.mdl"
   util.PrecacheModel(mdl)
   ply:SetModel(mdl)

   ply:SetColor(Color(255,255,255))
end

function GM:PlayerSetHandsModel(pl,ent)
   local simplemodel = player_manager.TranslateToPlayerModelName(pl:GetModel())
   local info = player_manager.TranslatePlayerHands(simplemodel)
   if info then
      ent:SetModel(info.model)
      ent:SetSkin(info.skin)
      ent:SetBodyGroups(info.body)
   end
end