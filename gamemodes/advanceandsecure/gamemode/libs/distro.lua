MsgN("+ Distribution loaded")

if SERVER then
	local DupeList = nil
	local function BuildDupeList()
		local Dupes,_ = file.Find("aas/dupes/*.txt","DATA")

		DupeList = {}

		for k,v in pairs(Dupes) do
			local FileSize = file.Size("aas/dupes/" .. v,"DATA")
			DupeList[string.StripExtension(v)] = {txt = v,size = FileSize,strsize = math.Round(FileSize / 1024,2) .. "kB"}
		end
	end
	BuildDupeList()

	local FileQueue = {}
	local function SendChunk(ply)
		if not FileQueue[ply] then return end
		local PlyFile = FileQueue[ply]

		PlyFile.OpenFile = file.Open("aas/dupes/" .. PlyFile.file .. ".txt","rb","DATA")

		local ReadData = PlyFile.OpenFile:Read(PlyFile.OpenFile:Size())
		PlyFile.OpenFile:Close()
		local _,dupe,_,_ = AdvDupe2.Decode(ReadData)

		net.Start("AAS.ReceiveDupe")
			net.WriteString(PlyFile.file)
		net.Send(ply)

		net.Start("AdvDupe2_SetDupeInfo")
			net.WriteString(PlyFile.file)
			net.WriteString(ply:Nick())
			net.WriteString(os.date("%d %B %Y"))
			net.WriteString(os.date("%I:%M %p"))
			net.WriteString("")
			net.WriteString("Public dupe saved from AAS Gamemode.")
			net.WriteString(table.Count(dupe.Entities))
			net.WriteString(#dupe.Constraints)
		net.Send(ply)

		dupe.Description = "Public dupe saved from AAS Gamemode."

		AdvDupe2.Encode(dupe,AdvDupe2.GenerateDupeStamp(ply),function(data)
			if not IsValid(ply) then return end
			ply.AdvDupe2.Downloading = true

			net.Start("AAS.ReceiveFile")
				net.WriteStream(data, function()
					ply.AdvDupe2.Downloading = false
				end)
			net.Send(ply)
		end)
	end

	do
		do	-- Network

			-- Sends the client the generic cost calculator, which is then further updated using the current cost metrics
			net.Receive("AAS.RequestCostScript",function(_,ply)
				local Script = file.Read(engine.ActiveGamemode() .. "/distributables/expression2/aas_costcalc.txt","LUA")

				net.Start("AAS.ReceiveCostScript")
					net.WriteString(Script)
					net.WriteTable(AAS.RequisitionCosts)
				net.Send(ply)
			end)

			-- Sends the client all of the dupes on the server
			net.Receive("AAS.RequestDupeList",function(_,ply)
				if not DupeList then BuildDupeList() end

				net.Start("AAS.ReceiveDupeList")
					net.WriteTable(DupeList)
				net.Send(ply)
			end)

			-- Sends dupe info to the client when they want to download it
			net.Receive("AAS.RequestDupe",function(_,ply)
				local ChosenDupe = net.ReadString()
				if not DupeList[ChosenDupe] then aasMsg({Colors.ErrorCol,"Invalid dupe! Try again!"},ply) return end

				aasMsg({Colors.BasicCol,"Attempting to download " .. ChosenDupe .. "..."},ply)
				FileQueue[ply] = {file = ChosenDupe,state = "pending",step = 0,size = DupeList[ChosenDupe].size}

				SendChunk(ply)
			end)
		end
	end

else	-- Client

	concommand.Add("aas_requestcostscript",function()
		net.Start("AAS.RequestCostScript")
		net.SendToServer()
	end)

	local Dupes = {}
	local function DupeMenu()
		if DupeMenuBase then DupeMenuBase:Remove() end

		DupeMenuBase = vgui.Create("DFrame")
		DupeMenuBase:SetSize(400,500)
		DupeMenuBase:SetPos(0,0)
		DupeMenuBase.Paint = function(self,w,h)
			surface.SetDrawColor(127,127,127,255)
			surface.DrawRect(0,0,w,h)

			surface.SetDrawColor(75,75,75)
			surface.DrawRect(0,0,w,24)
		end
		DupeMenuBase:Center()
		DupeMenuBase:MakePopup()
		DupeMenuBase:SetDraggable(false)
		DupeMenuBase:ShowCloseButton(false)
		DupeMenuBase:SetTitle("Dupe Menu")

		local CloseDupeMenu = vgui.Create("DButton",DupeMenuBase)
		CloseDupeMenu:SetPos(400 - 24,0)
		CloseDupeMenu:SetSize(24,24)
		CloseDupeMenu:SetText("")
		CloseDupeMenu.Paint = function(self,w,h)
			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,255) else surface.SetDrawColor(127,0,0,255) end
			surface.DrawRect(0,0,w,h)
		end
		CloseDupeMenu.DoClick = function(self)
			DupeMenuBase:Remove()
		end

		local Allow = false
		local Data = {}
		DupeList = vgui.Create("DListView",DupeMenuBase)
		DupeList:SetPos(8,32)
		DupeList:SetSize(400 - 16,380)
		DupeList:AddColumn("Name",1)
		DupeList:SetMultiSelect(false)
		DupeList:SetSortable(false)
		DupeList.Index = {}
		local C = DupeList:AddColumn("Size",2)
		C:SetFixedWidth(96)

		DupeList.Populate = function(self)
			self:Clear()

			for k,v in pairs(Dupes) do
				local Line = self:AddLine(string.StripExtension(v.txt),v.strsize)
				Line.Data = v
			end

			self:SortByColumns(2,false,1,false)
			self:SetSortable(false)
		end
		DupeList:Populate()

		SelectedFileLabel = vgui.Create("DLabel",DupeMenuBase)
		SelectedFileLabel:SetFont("BasicFont14")
		SelectedFileLabel:SetSize(400,20)
		SelectedFileLabel:SetPos(12,416)
		SelectedFileLabel:SetText("SELECTED: NONE")

		DupeList.OnRowSelected = function(self,index,line)
			Allow = true
			Data = line.Data
			SelectedFileLabel:SetText("SELECTED: " .. Data.txt)
		end


		local DownloadButton = vgui.Create("DButton",DupeMenuBase)
		DownloadButton:SetPos(200,436)
		DownloadButton:SetSize(200 - 8,58)
		DownloadButton:SetText("")
		DownloadButton.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if Allow then
				if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(0,255,0,127) else surface.SetDrawColor(0,127,0,127) end
				surface.DrawRect(4, 4, w - 8, h - 8)

				draw.SimpleText("DOWNLOAD","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			else
				surface.SetDrawColor(255,0,0,127)
				surface.DrawRect(4, 4, w - 8, h - 8)

				draw.SimpleText("SELECT FIRST","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			end
		end
		DownloadButton.DoClick = function(self)
			if Allow then
				net.Start("AAS.RequestDupe")
					net.WriteString(string.StripExtension(Data.txt))
				net.SendToServer()
				DupeMenuBase:Remove()
			end
		end

		local Cancel = vgui.Create("DButton",DupeMenuBase)
		Cancel:SetPos(8,436)
		Cancel:SetSize(200 - 8,58)
		Cancel:SetText("")
		Cancel.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75,255)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() and not self:IsDown() then surface.SetDrawColor(255,0,0,127) else surface.SetDrawColor(127,0,0,127) end
			surface.DrawRect(4, 4, w - 8, h - 8)

			draw.SimpleText("CANCEL","BasicFontLarge",w / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
		Cancel.DoClick = function(self)
			DupeMenuBase:Remove()
		end
	end
	if DupeMenuBase then DupeMenuBase:Remove() end

	local function AAS_ReceiveFile(len, ply) -- A little hijacking here and there from AdvDupe2 and we've now got an ez-dupe system for people to get public dupes from the server
		net.ReadStream(nil, function(data)

			if not data then
				chat.AddText(Color(255,0,0),"File was not saved!")
				return
			end

			local dupefile = file.Open(AdvDupe2.SavePath .. ".txt", "wb", "DATA")
			if not dupefile then
				chat.AddText(Color(255,0,0),"File was not saved!")
				return
			end

			dupefile:Write(data)
			dupefile:Close()

			chat.AddText(Color(200,200,200),"Dupe saved to >" .. AdvDupe2.SavePath .. "!")
		end)
	end

	do	-- Net
		-- Provides a list of all of the dupes available on the server for the player to download one at a time
		net.Receive("AAS.ReceiveDupeList",function()
			Dupes = net.ReadTable()
			if ScoreboardBase then ScoreboardBase:Remove() end
			DupeMenu()

			if not file.Exists("advdupe2/aas","DATA") then file.CreateDir("advdupe2/aas") end
		end)

		-- Start of the dupe saving process
		net.Receive("AAS.ReceiveDupe",function()
			local FileName = net.ReadString()

			AdvDupe2.SavePath = "advdupe2/aas/" .. FileName
		end)

		-- Actually saving the dupe
		net.Receive("AAS.ReceiveFile", AAS_ReceiveFile)

		-- Handles inserting data into the generic cost calculator E2 script thats sent, populates it with current info about any costs on the server
		net.Receive("AAS.ReceiveCostScript",function()
			local E2Code = net.ReadString()
			local CostInfo = net.ReadTable()

			local CostBreakdown = {}

			for k,v in pairs(CostInfo.CalcSingleFilter) do
				local Str = "\"" .. k .. "\""
				if not CostBreakdown.FilterList then
					CostBreakdown.FilterList = Str
				else
					CostBreakdown.FilterList = CostBreakdown.FilterList .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.CalcSingleFilter) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.CalcSingleFilter then
					CostBreakdown.CalcSingleFilter = Str
				else
					CostBreakdown.CalcSingleFilter = CostBreakdown.CalcSingleFilter .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFGunCost) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFGunCost then
					CostBreakdown.ACFGunCost = Str
				else
					CostBreakdown.ACFGunCost = CostBreakdown.ACFGunCost .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFAmmoModifier) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFAmmoModifier then
					CostBreakdown.ACFAmmoModifier = Str
				else
					CostBreakdown.ACFAmmoModifier = CostBreakdown.ACFAmmoModifier .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFMissileModifier) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFMissileModifier then
					CostBreakdown.ACFMissileModifier = Str
				else
					CostBreakdown.ACFMissileModifier = CostBreakdown.ACFMissileModifier .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.SpecialModelFilter) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.SpecialModelFilter then
					CostBreakdown.SpecialModelFilter = Str
				else
					CostBreakdown.SpecialModelFilter = CostBreakdown.SpecialModelFilter .. "," .. Str
				end
			end

			for k,v in pairs(CostInfo.ACFRadars) do
				local Str = "\"" .. k .. "\"=" .. v
				if not CostBreakdown.ACFRadars then
					CostBreakdown.ACFRadars = Str
				else
					CostBreakdown.ACFRadars = CostBreakdown.ACFRadars .. "," .. Str
				end
			end

			local FinalCode = string.format(E2Code,
				util.DateStamp(),
				CostBreakdown.FilterList,
				CostBreakdown.CalcSingleFilter,
				CostBreakdown.ACFGunCost,
				CostBreakdown.ACFAmmoModifier,
				CostBreakdown.ACFMissileModifier,
				CostBreakdown.SpecialModelFilter,
				CostBreakdown.ACFRadars)

			if not file.Exists("expression2/AAS","DATA") then file.CreateDir("expression2/AAS") end
			file.Write("expression2/AAS/aas_costcalc.txt",FinalCode)

			chat.AddText(Color(200,200,200),"AAS Cost script has been saved to >expression2/AAS/aas_costcalc.txt!")
		end)
	end
end