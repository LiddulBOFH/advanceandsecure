-- Since the default playerclass stuff is so asinine and 90% not documented, I'm just going to make my own system :)
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

if SERVER then
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
else
	local Loadout = {}

	local function LoadoutMenu()
		if LoadoutBase then LoadoutBase:Remove() end
		if not PlyInSafezone(LP,LP:GetPos()) then return end -- Somehow they set this off, we're gonna prevent it if we can

		local SelectedTab = "Primary"

		LoadoutBase = vgui.Create("DFrame")
		LoadoutBase:SetSize(800,344)
		LoadoutBase:SetPos(0,0)
		LoadoutBase.Paint = function(self,w,h)
			surface.SetDrawColor(127,127,127,255)
			surface.DrawRect(0,0,w,h)

			surface.SetDrawColor(75,75,75)
			surface.DrawRect(0,0,w,24)
		end
		LoadoutBase:Center()
		LoadoutBase:MakePopup()
		LoadoutBase:SetDraggable(false)
		LoadoutBase:ShowCloseButton(false)
		LoadoutBase:SetTitle("Player Loadout")

		local LoadoutList

		local PrimaryLoadoutButton = vgui.Create("DButton",LoadoutBase) -- Primary Weapon
		PrimaryLoadoutButton.Slot = "Primary"
		PrimaryLoadoutButton:SetPos(8,32)
		PrimaryLoadoutButton:SetSize(240,56)
		PrimaryLoadoutButton:SetText("")
		PrimaryLoadoutButton.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
				if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
				surface.DrawRect(4, 4, w - 8, h - 8)
			end

			surface.SetDrawColor(25,25,25,255)
			surface.DrawRect(0,h / 2,w,h / 2)

			draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

			local Text = "EMPTY"
			if Loadout.Primary ~= "" then Text = NewPlyManager.Weapons[Loadout.Primary].Name end
			draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
		end
		PrimaryLoadoutButton.DoClick = function(self)
			SelectedTab = self.Slot
			LoadoutList:Populate()
		end

		local SecondaryLoadoutButton = vgui.Create("DButton",LoadoutBase) -- Sidearm
		SecondaryLoadoutButton.Slot = "Sidearm"
		SecondaryLoadoutButton:SetPos(8,32 + 60)
		SecondaryLoadoutButton:SetSize(240,56)
		SecondaryLoadoutButton:SetText("")
		SecondaryLoadoutButton.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
				if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
				surface.DrawRect(4, 4, w - 8, h - 8)
			end

			surface.SetDrawColor(25,25,25,255)
			surface.DrawRect(0,h / 2,w,h / 2)

			draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

			local Text = "EMPTY"
			if Loadout.Sidearm ~= "" then Text = NewPlyManager.Weapons[Loadout.Sidearm].Name end
			draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
		end
		SecondaryLoadoutButton.DoClick = function(self)
			SelectedTab = self.Slot
			LoadoutList:Populate()
		end

		local Gad1LoadoutButton = vgui.Create("DButton",LoadoutBase) -- Gadget 1
		Gad1LoadoutButton.Slot = "Gadget 1"
		Gad1LoadoutButton:SetPos(8,32 + 120)
		Gad1LoadoutButton:SetSize(240,56)
		Gad1LoadoutButton:SetText("")
		Gad1LoadoutButton.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
				if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
				surface.DrawRect(4, 4, w - 8, h - 8)
			end

			surface.SetDrawColor(25,25,25,255)
			surface.DrawRect(0,h / 2,w,h / 2)

			draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

			local Text = "EMPTY"
			if Loadout.Gadget1 ~= "" then Text = NewPlyManager.Gadgets[Loadout.Gadget1].Name end
			draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
		end
		Gad1LoadoutButton.DoClick = function(self)
			SelectedTab = self.Slot
			LoadoutList:Populate()
		end

		local Gad2LoadoutButton = vgui.Create("DButton",LoadoutBase) -- Gadget 2
		Gad2LoadoutButton.Slot = "Gadget 2"
		Gad2LoadoutButton:SetPos(8,32 + 180)
		Gad2LoadoutButton:SetSize(240,56)
		Gad2LoadoutButton:SetText("")
		Gad2LoadoutButton.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsDown() or self:IsHovered() or SelectedTab == self.Slot then
				if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
				surface.DrawRect(4, 4, w - 8, h - 8)
			end

			surface.SetDrawColor(25,25,25,255)
			surface.DrawRect(0,h / 2,w,h / 2)

			draw.SimpleTextOutlined(string.upper(self.Slot),"BasicFontLarge",4,4,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP,1,color_black)

			local Text = "EMPTY"
			if Loadout.Gadget2 ~= "" then Text = NewPlyManager.Gadgets[Loadout.Gadget2].Name end
			draw.SimpleTextOutlined(string.upper(Text),"BasicFontLarge",w / 2,h - (h / 4),Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
		end
		Gad2LoadoutButton.DoClick = function(self)
			SelectedTab = self.Slot
			LoadoutList:Populate()
		end

		LoadoutList = vgui.Create("DListView",LoadoutBase)
		LoadoutList:SetPos(256,32)
		LoadoutList:SetSize(280,400-96)
		LoadoutList:AddColumn("Name",1)
		LoadoutList:SetMultiSelect(false)
		LoadoutList:SetSortable(false)
		LoadoutList.Index = {}
		local C1 = LoadoutList:AddColumn("Type",2)
		C1:SetFixedWidth(60)
		local C2 = LoadoutList:AddColumn("Cost",3)
		C2:SetFixedWidth(28)
		local C3 = LoadoutList:AddColumn("WU",4)
		C3:SetFixedWidth(24)

		local T = vgui.Create("DLabel",LoadoutBase)
		T:SetPos(12,32 + 240)
		T:SetText("Armor Slider (DEFAULT: " .. NewPlyManager.DefaultLoadout.Armor .. ")")
		T:SizeToContents()

		ArmorSlider = vgui.Create("DNumSlider",LoadoutBase)
		ArmorSlider:SetPos(-140,32 + 260)
		ArmorSlider:SetSize(400,25)
		ArmorSlider:SetDecimals(0)
		ArmorSlider:SetMinMax(0,100)
		ArmorSlider:SetValue(Loadout.Armor)
		ArmorSlider.OnValueChanged = function(self,val)
			Loadout.Armor = math.Clamp(math.Round(val),0,100) -- just extra insurance
			ArmorSlider:SetValue(math.Clamp(math.Round(val),0,100))
			InfoPanel:CalcInfo()
		end

		InfoPanel = vgui.Create("DPanel",LoadoutBase)
		InfoPanel:SetPos(256 + 280 + 8,32)
		InfoPanel:SetSize(248,110)

		InfoPanel.Cost = 0
		InfoPanel.Movespeed = 0
		InfoPanel.WU = 0

		InfoPanel.CalcInfo = function()
			local Cost = 0
			local WU = -12.5 -- Starting armor of 25 has no speed penalty, call it conditioning
			local Movespeed = NewPlyManager.BaseMoveSpeed

			if Loadout.Primary ~= "" then
				local Wep = NewPlyManager.Weapons[Loadout.Primary]
				Cost = Cost + Wep.Cost
				WU = WU + Wep.WU
			end

			if Loadout.Sidearm ~= "" then
				local Wep = NewPlyManager.Weapons[Loadout.Sidearm]
				Cost = Cost + Wep.Cost
				WU = WU + Wep.WU
			end

			if Loadout.Gadget1 ~= "" then
				local Gdgt = NewPlyManager.Gadgets[Loadout.Gadget1]
				Cost = Cost + Gdgt.Cost
				WU = WU + Gdgt.WU
			end

			if Loadout.Gadget2 ~= "" then
				local Gdgt = NewPlyManager.Gadgets[Loadout.Gadget2]
				Cost = Cost + Gdgt.Cost
				WU = WU + Gdgt.WU
			end

			local Armor = math.floor(Loadout.Armor)

			WU = math.max(WU + (Armor / 3),0)
			Cost = Cost + math.ceil(math.max(0,Armor - 25) / 2)

			InfoPanel.Cost = Cost
			InfoPanel.WU = math.Round(WU,1)
			InfoPanel.Movespeed = math.Clamp(math.ceil(Movespeed - (WU * 2.5)),NewPlyManager.MinMoveSpeed,Movespeed)

			--print(InfoPanel.Cost,InfoPanel.WU,InfoPanel.Movespeed)
		end
		InfoPanel:CalcInfo()

		local MovespeedDiff = NewPlyManager.BaseMoveSpeed - NewPlyManager.MinMoveSpeed
		InfoPanel.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			draw.SimpleText("COST: " .. self.Cost,"BasicFont14",4,21,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)
			draw.SimpleText("CURRENT: " .. LP:GetNW2Int("Requisition",0),"BasicFont14",w / 2,21,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)
			draw.SimpleText("WEIGHT: " .. self.WU,"BasicFont14",4,57,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)
			draw.SimpleText("MOVESPEED: " .. self.Movespeed,"BasicFont14",4,93,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_BOTTOM)

			surface.SetDrawColor(25,25,25,255)
			surface.DrawRect(0,21,w,16)
			surface.DrawRect(0,57,w,16)
			surface.DrawRect(0,93,w,16)

			surface.SetDrawColor(0,255,0,255)
			surface.DrawRect(1,21,(w - 2) * (LP:GetNW2Int("Requisition",0) / AAS.MaxRequisition),14)
			surface.SetDrawColor(255,0,0,255)
			surface.DrawRect(1,28,(w - 2) * (self.Cost / AAS.MaxRequisition),7)

			local Mix = math.max(0,self.Movespeed - NewPlyManager.MinMoveSpeed) / MovespeedDiff
			local Color1 = Vector(255,0,0)
			local Color2 = Vector(0,255,0)
			local ColMix = Lerp(Mix, Color1, Color2)
			surface.SetDrawColor(ColMix.x, ColMix.y, ColMix.z, 255)

			surface.DrawRect(1,94,(w - 2) * Mix,14)
		end

		local ApplyLoadout = vgui.Create("DButton",LoadoutBase) -- Sends the selected loadout to the server, subject to one last legal check (those pesky clients can't be trusted!)
		ApplyLoadout:SetPos(544 + 126, 252)
		ApplyLoadout:SetSize(122,84)
		ApplyLoadout:SetText("")
		ApplyLoadout.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)

			draw.SimpleText("APPLY","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
		ApplyLoadout.DoClick = function(self)
			net.Start("aas_receiveplayerloadout")
				net.WriteTable(Loadout)
			net.SendToServer()

			LoadoutBase:Remove()
		end

		local Cancel = vgui.Create("DButton",LoadoutBase)
		Cancel:SetPos(544,296)
		Cancel:SetSize(122,40)
		Cancel:SetText("")
		Cancel.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,127) else surface.SetDrawColor(127,0,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)

			draw.SimpleText("CANCEL","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
		Cancel.DoClick = function(self)
			LoadoutBase:Remove()
		end

		local Default = vgui.Create("DButton",LoadoutBase)
		Default:SetPos(544,252)
		Default:SetSize(122,40)
		Default:SetText("")
		Default.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,127,0,127) else surface.SetDrawColor(127,65,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)

			draw.SimpleText("DEFAULT","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
		Default.DoClick = function(self)
			Loadout = table.Copy(NewPlyManager.DefaultLoadout)
			ArmorSlider:SetValue(Loadout.Armor)
			LoadoutList:Populate()
		end

		local AltCancel = vgui.Create("DButton",LoadoutBase)
		AltCancel:SetPos(800 - 24,0)
		AltCancel:SetSize(24,24)
		AltCancel:SetText("")
		AltCancel.Paint = function(self,w,h)
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,255) else surface.SetDrawColor(127,0,0,255) end
			surface.DrawRect(0,0,w,h)
		end
		AltCancel.DoClick = function(self)
			LoadoutBase:Remove()
		end

		LoadoutList.Populate = function(self)
			self:Clear()

			local Select
			local Empty = self:AddLine("Empty","Empty",0,0)
			Empty.ID = ""

			if SelectedTab == "Primary" then
				for k,v in pairs(NewPlyManager.Weapons) do
					if v.Type ~= "Pistol" then
						local Line = self:AddLine(v.Name,v.Type,v.Cost,v.WU)
						Line.ID = k
						if k == Loadout.Primary then Select = Line end
					end
				end
			elseif SelectedTab == "Sidearm" then
				for k,v in pairs(NewPlyManager.Weapons) do
					if v.Type == "Pistol" then
						local Line = self:AddLine(v.Name,v.Type,v.Cost,v.WU)
						Line.ID = k
						if k == Loadout.Sidearm then Select = Line end
					end
				end
			else -- Gadget1/2
				local Block = ""
				if (SelectedTab == "Gadget 2") and Loadout.Gadget1 ~= "" then Block = NewPlyManager.Gadgets[Loadout.Gadget1].Type
				elseif (SelectedTab == "Gadget 1") and Loadout.Gadget2 ~= "" then Block = NewPlyManager.Gadgets[Loadout.Gadget2].Type end

				for k,v in pairs(NewPlyManager.Gadgets) do
					if v.Type == Block then continue end
					local Line = self:AddLine(v.Name,v.Type,v.Cost,v.WU)
					Line.ID = k
					if (k == Loadout.Gadget1) or (k == Loadout.Gadget2) then Select = Line end
				end
			end

			if Select then self:SelectItem(Select) else self:SelectItem(Empty) end

			self:SortByColumns(3,false,4,false,1,false)
			self:SetSortable(false)
		end

		LoadoutList.OnRowSelected = function(self,index,line)
			if SelectedTab == "Primary" then
				Loadout.Primary = line.ID
			elseif SelectedTab == "Sidearm" then
				Loadout.Sidearm = line.ID
			elseif SelectedTab == "Gadget 1" then
				Loadout.Gadget1 = line.ID
			else -- Gadget 2
				Loadout.Gadget2 = line.ID
			end

			InfoPanel:CalcInfo()
		end

		LoadoutList:Populate()

		local DescPanel = vgui.Create("DPanel",LoadoutBase)
		DescPanel:SetPos(544,146)
		DescPanel:SetSize(248,100)

		DescPanel.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(50,50,50,255)

			draw.SimpleText("The buttons on the left are for selecting slots","BasicFont",4,4,Colors.White)
			draw.SimpleText("Tab selected: " .. SelectedTab,"BasicFont14",4,18,Colors.White)

			surface.DrawRect(0,33,w,2)

			draw.SimpleText("WU means Weight Units, they slow you down","BasicFont",4,36,Colors.White)
			draw.SimpleText("Weapons and armor both have WU","BasicFont",4,52,Colors.White)

			surface.DrawRect(0,65,w,2)

			draw.SimpleText("This loadout will cost you each time you apply","BasicFont",4,68,Colors.White)
			draw.SimpleText("It will cost each time you respawn too","BasicFont",4,84,Colors.White)
		end
	end
	if LoadoutBase then LoadoutBase:Remove() end

	-- Opens the loadout menu, and provides the player's current loadout
	net.Receive("aas_openloadout",function()
		Loadout = net.ReadTable()
		LoadoutMenu()
	end)
end