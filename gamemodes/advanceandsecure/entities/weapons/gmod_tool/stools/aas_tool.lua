
TOOL.Category 	= "Advance and Secure"
TOOL.Name 		= "#tool.aas_tool.name"

TOOL.Information = {
	{name = "left_0", op = 0, icon = "gui/lmb.png"},
	{name = "info_0", op = 0, icon = "gui/info.png"},

	{name = "left_1", op = 1, icon = "gui/lmb.png"},
	{name = "info_1", op = 1, stage = 0, icon = "gui/info.png"},
	{name = "info_1_1", op = 1, stage = 1, icon = "gui/info.png"},
	{name = "clear_manuallink", op = 1, stage = 0, icon = "gui/r.png"},
	{name = "clear_manuallink2", op = 1, stage = 1, icon = "gui/r.png"},

	{name = "left_2", op = 2, icon = "gui/lmb.png"},
	{name = "info_2", op = 2, icon = "gui/info.png"},
	{name = "radial_spawns", op = 2, icon = "gui/r.png"},

	{name = "left_3", op = 3, icon = "gui/lmb.png"},
	{name = "info_3", op = 3, icon = "gui/info.png"},
	{name = "clear_spawns", op = 3, icon = "gui/r.png"},

	{name = "left_4", op = 4, icon = "gui/lmb.png"},
	{name = "info_4", op = 4, icon = "gui/info.png"},
	{name = "prop_warning", op = 4, icon = "gui/info.png"},
	{name = "copy_model", op = 4, icon = "gui/r.png"},

	{name = "left_5", op = 5, icon = "gui/lmb.png"},
	{name = "info_5", op = 5, icon = "gui/info.png"},
	{name = "prop_warning", op = 5, icon = "gui/info.png"},

	{name = "right"}, -- Advances toolmode

	{name = "open_settings", icon = "gui/r.png", icon2 = "gui/e.png"} -- Option menu
}

TOOL.LastModeChange = 0
TOOL.ManualLink		= {}
TOOL.PropModel		= "models/hunter/blocks/cube1x1x1.mdl" -- Default model for AAS prop

if CLIENT then
	language.Add("tool.aas_tool.name", "Map Tool")
	language.Add("tool.aas_tool.desc", "Aids in setting up maps for use with AAS")
	language.Add("tool.aas_tool.right", "Advance toolmode")
	language.Add("tool.aas_tool.open_settings", "Open settings (Recommend to save for last, as it saves and resets the map)")

	language.Add("tool.aas_tool.left_0", "[1] Spawn capture points")
	language.Add("tool.aas_tool.info_0", "Make sure to edit properties of 2 of the points to mark a team base!")

	language.Add("tool.aas_tool.left_1", "[2] Link capture points (forces AAS)")
	language.Add("tool.aas_tool.info_1",  "Select SpawnA")
	language.Add("tool.aas_tool.info_1_1",  "Now select all of the points leading to SpawnB, and finish with SpawnB")
	language.Add("tool.aas_tool.clear_manuallink", "Dump the manual link list for the map")
	language.Add("tool.aas_tool.clear_manuallink2", "Dump the manual link list on the tool")

	language.Add("tool.aas_tool.left_2", "[3] Add spawnpoints")
	language.Add("tool.aas_tool.info_2", "Spawnpoints automatically link to the nearest team base")
	language.Add("tool.aas_tool.radial_spawns", "Clears all spawnpoints, and puts 8 of them around both team spawns")

	language.Add("tool.aas_tool.left_3", "[4] Delete spawnpoints")
	language.Add("tool.aas_tool.info_3", "Look near a spawnpoint and click to delete")
	language.Add("tool.aas_tool.clear_spawns", "Clears all spawnpoints on the map")

	language.Add("tool.aas_tool.left_4", "[5] Spawn map prop")
	language.Add("tool.aas_tool.info_4", "Spawns a prop that is unmoveable and undamageable during play")
	language.Add("tool.aas_tool.copy_model", "Copy the model of a prop you are looking at")
	language.Add("tool.aas_tool.prop_warning", "Be wary of letting go, props will phase through the world if editmode is on")

	language.Add("tool.aas_tool.left_5", "[6] Convert to map prop")
	language.Add("tool.aas_tool.info_5", "Converts the prop you are looking at into an AAS map prop, undamageable and unmoveable")
	language.Add("tool.aas_tool.prop_warning", "Be wary of letting go, props will phase through the world if editmode is on")
end

--[[
	1: Add points (remove by clicking?)
		- Should dump links if any made
	2: Link points (must go from spawn A to spawn B, with points in between)
	3: Add spawnpoints
	4: Delete spawnpoints
	5: Map props (not damageable, used for altering map in some manner)
	6: Mode that can convert existing props into AAS props
]]--

local Colors = {
	red = Color(255,0,0),
	green = Color(0,255,0),
	black = Color(0,0,0),
	white = Color(255,255,255)
}

function TOOL:CanUseTool()
	local owner = self:GetOwner()

	if not owner:IsSuperAdmin() then if CLIENT then chat.AddText(Colors.red,"You aren't allowed to use this tool!") end return false end
	if GetGlobalBool("EditMode",false) == false then if CLIENT then chat.AddText(Colors.red,"Edit mode is not enabled!") end return false end

	return true
end

function TOOL:Allowed()
	return self:GetOwner():IsSuperAdmin() and (GetGlobalBool("EditMode",false) == true)
end

local ToolFuncs = {
	[1] = function(tool) -- Spawn points
		if CLIENT then return end

		local ply = tool:GetOwner()
		local point = ents.Create("aas_point")
		point:SetPos(ply:GetEyeTrace().HitPos - Vector(0,0,12))
		point:SetAngles(Angle(0,math.Round(ply:EyeAngles().y / 45) * 45,0))
		point:Spawn()
	end,
	[2] = function(tool) -- Link points (AAS)
		local ply = tool:GetOwner()
		local ent = ply:GetEyeTrace().Entity

		local stage = tool:GetStage()

		if (not IsValid(ent)) or (ent:GetClass() ~= "aas_point") then return end

		if stage == 0 then
			if ent:GetIsSpawn() == true and ent:GetTeamSpawn() == 1 then
				if CLIENT then chat.AddText(Colors.white,"Now, click on all of the points leading to SpawnB, and finish with SpawnB.") end
				tool.ManualLink[1] = ent
				tool:SetStage(1)
			else
				if CLIENT then chat.AddText(Colors.red,"This isn't the correct starting point!") end
			end
		elseif stage == 1 then
			if not (ent:GetIsSpawn() == true and ent:GetTeamSpawn() == 2) then
				for k,v in ipairs(tool.ManualLink) do
					if ent == v then if CLIENT then chat.AddText(Colors.red,"This point is already in the list!") end return end
				end
			end

			if ent:GetIsSpawn() == true and ent:GetTeamSpawn() == 2 then
				if CLIENT then chat.AddText(Colors.white,"Manually linked points are now setup!") end
				tool.ManualLink[#tool.ManualLink + 1] = ent

				if SERVER then
					AAS.State.Data["Line"] = {}
					for k,v in ipairs(tool.ManualLink) do
						AAS.State.Data["Line"][k] = v:GetPointName()
					end
				end

				tool.ManualLink = {}
				tool:SetStage(0)
			else
				if CLIENT then chat.AddText(Colors.white,"Added " .. ent:GetPointName()) end
				tool.ManualLink[#tool.ManualLink + 1] = ent
			end
		end
	end,
	[3] = function(tool) -- Add spawnpoints
		if CLIENT then return end

		local ply = tool:GetOwner()
		local point = ents.Create("aas_spawnpoint")
		point:SetPos(ply:GetEyeTrace().HitPos + Vector(0,0,12))
		point:SetAngles(Angle(0,math.Round(ply:EyeAngles().y / 45) * 45,0))
		point:Spawn()
	end,
	[4] = function(tool) -- Delete spawnpoints
		if CLIENT then return end

		local ply = tool:GetOwner()
		local pos = ply:GetEyeTrace().HitPos
		local entlist = ents.FindInBox(pos - Vector(64,64,32),pos + Vector(64,64,128))
		for k,v in ipairs(entlist) do
			if v:GetClass() == "aas_spawnpoint" then v:Remove() end
		end
	end,
	[5] = function(tool) -- Add map props
		if CLIENT then return end

		local ply = tool:GetOwner()
		local prop = ents.Create("aas_prop")
		prop:SetPos(ply:GetEyeTrace().HitPos)
		prop:SetAngles(Angle(0,ply:EyeAngles().y,0))
		prop:Spawn()
		prop:SetModel(tool.PropModel)
	end,
	[6] = function(tool) -- Convert to map prop
		if CLIENT then return end

		local ply = tool:GetOwner()
		local eyetr = ply:GetEyeTrace()
		local oldent = eyetr.Entity

		if not IsValid(oldent) then return end
		if oldent:GetClass() ~= "prop_physics" then return end

		local prop = ents.Create("aas_prop")
		prop:SetPos(oldent:GetPos())
		prop:SetAngles(oldent:GetAngles())
		prop:Spawn()
		prop:SetModel(oldent:GetModel())

		oldent:Remove()
	end,
}

function TOOL:LeftClick()
	if not IsFirstTimePredicted() then return end
	if not self:CanUseTool() then return end

	local op = self:GetOperation()

	local pass,varg = pcall(ToolFuncs[op + 1],self)
	if not pass then print(varg) end

	return true
end

function TOOL:RightClick()
	if not IsFirstTimePredicted() then return end
	if not self:CanUseTool() then return end

	if (SysTime() < (self.LastModeChange + 3)) then
		local op = self:GetOperation()

		self:SetStage(0)
		if op == 1 then self.ManualLink = {} end -- Clears manual link on tool

		if op == 5 then op = 0 else op = op + 1 end

		self:SetOperation(op)
	end

	self.LastModeChange = SysTime()
end

function TOOL:Reload()
	if not IsFirstTimePredicted() then return end
	if not self:CanUseTool() then return end
	local owner = self:GetOwner()
	local eyetr = owner:GetEyeTrace()

	if owner:KeyDown(IN_USE) then if CLIENT then RunConsoleCommand("aas_opensettings") end return end

	local op = self:GetOperation()
	local stage = self:GetStage()

	if op == 0 then
		return
	elseif op == 1 then
		if stage > 0 then
			if SERVER then aasMsg({Colors.white,"Cleared the manual link list on the tool."}) end
			self:SetStage(0)
			self.ManualLink = {}
		else
			if SERVER then
				aasMsg({Colors.white,"Cleared the manual link list on the map."})
				if AAS.State.Data["Line"] then AAS.State.Data["Line"] = nil end
			end
		end
	elseif op == 2 then
		if CLIENT then return true end
		local points = ents.FindByClass("aas_point")
		local spawns = ents.FindByClass("aas_spawnpoint")

		for k,v in ipairs(spawns) do v:Remove() end

		local SpawnA,SpawnB

		for k,v in ipairs(points) do
			if v:GetIsSpawn() then
				if v:GetTeamSpawn() == 1 then SpawnA = v elseif v:GetTeamSpawn() == 2 then SpawnB = v end
			end
		end

		for I = 1,8 do
			local Ang = math.rad(45 * I)
			local Pos = SpawnA:GetPos() + Vector(math.cos(Ang) * 80,math.sin(Ang) * 80,64)

			local point = ents.Create("aas_spawnpoint")
			point:SetPos(Pos)
			point:SetAngles(Angle(0,45 * I,0))
		end

		for I = 1,8 do
			local Ang = math.rad(45 * I)
			local Pos = SpawnB:GetPos() + Vector(math.cos(Ang) * 80,math.sin(Ang) * 80,64)

			local point = ents.Create("aas_spawnpoint")
			point:SetPos(Pos)
			point:SetAngles(Angle(0,45 * I,0))
		end

	elseif op == 3 then
		if CLIENT then return true end
		local spawns = ents.FindByClass("aas_spawnpoint")

		for k,v in ipairs(spawns) do v:Remove() end
	elseif op == 4 then
		if CLIENT then return true end

		if IsValid(eyetr.Entity) then
			self.PropModel = eyetr.Entity:GetModel()
			owner:ChatPrint("Model updated to " .. self.PropModel)
		else
			self.PropModel = "models/hunter/blocks/cube1x1x1.mdl"
			owner:ChatPrint("Model reset to " .. self.PropModel)
		end
	end

	return true
end

function TOOL:Deploy()
	self.ManualLink = {}
	self:SetStage(0)
end

function TOOL:Holster()
	self.ManualLink = {}
	self:SetStage(0)
end

function TOOL:DrawToolScreen(w,h)
	if GetGlobalBool("EditMode",false) == false then
		render.Clear(127,0,0,255)
		draw.SimpleText("NOT IN EDIT MODE","ChatFont",w / 2,(h / 2) - 12,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		draw.SimpleText("'aas_editmode 1'","ChatFont",w / 2,(h / 2) + 12,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		return
	end

	render.Clear(0,0,0,255)
	local op = self:GetOperation()
	local owner = self:GetOwner()

	local tr = owner:GetEyeTrace()

	if SysTime() < (self.LastModeChange + 3) then
		surface.SetDrawColor(Color(0,127,0))
		surface.DrawRect(0,24 * op,w,24)
		draw.SimpleText("Add Capture Points","ChatFont",w / 2,0,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		draw.SimpleText("Link Capture Points","ChatFont",w / 2,24,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		draw.SimpleText("Add Spawn Points","ChatFont",w / 2,48,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		draw.SimpleText("Remove Spawn Points","ChatFont",w / 2,72,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		draw.SimpleText("Spawn Map Props","ChatFont",w / 2,96,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
		draw.SimpleText("Convert Map Props","ChatFont",w / 2,120,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
	else
		if op == 0 then
			draw.SimpleText("Add Capture Points","ChatFont",w / 2,4,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			local points = ents.FindByClass("aas_point")
			draw.SimpleText("Points: " .. #points,"ChatFont",4,24,Colors.white)

			if IsValid(tr.Entity) and tr.Entity:GetClass() == "aas_point" then
				local point = tr.Entity
				draw.SimpleText("Name: " .. point:GetPointName(),"ChatFont",4,48,Colors.white)
				local IsSpawn = point:GetIsSpawn()
				if IsSpawn then
					draw.SimpleText("Team Spawn for: " .. point:GetTeamSpawn(),"ChatFont",4,72,Colors.white)
				end
			end
		elseif op == 1 then
			draw.SimpleText("Link Capture Points","ChatFont",w / 2,4,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)

			for k,v in ipairs(self.ManualLink) do
				if not IsValid(v) then continue end
				draw.SimpleText(v:GetPointName(),"ChatFont",4,24 + ((k-1) * 24),Colors.white,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP)
			end
		elseif op == 2 then
			draw.SimpleText("Add Spawn Points","ChatFont",w / 2,4,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)

			local points = ents.FindByClass("aas_spawnpoint")
			draw.SimpleText("Spawnpoints: " .. #points,"ChatFont",4,24,Colors.white)
		elseif op == 3 then
			draw.SimpleText("Remove Spawn Points","ChatFont",w / 2,4,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)

			local points = ents.FindByClass("aas_spawnpoint")
			draw.SimpleText("Spawnpoints: " .. #points,"ChatFont",4,24,Colors.white)
		elseif op == 4 then
			draw.SimpleText("Spawn Map Props","ChatFont",w / 2,4,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)

			local props = ents.FindByClass("aas_prop")
			draw.SimpleText("AAS Props: " .. #props,"ChatFont",4,24,Colors.white)
		elseif op == 5 then
			draw.SimpleText("Convert Map Props","ChatFont",w / 2,4,Colors.white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)

			local props = ents.FindByClass("aas_prop")
			draw.SimpleText("AAS Props: " .. #props,"ChatFont",4,24,Colors.white)
		end
	end
end
