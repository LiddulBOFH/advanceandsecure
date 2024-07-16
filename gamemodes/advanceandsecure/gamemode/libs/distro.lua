MsgN("+ Distribution loaded")

if SERVER then
	local DupeList = nil
	local function BuildDupeList()
		local Dupes,_ = file.Find(engine.ActiveGamemode() .. "/distributables/advdupe2/*.txt","LUA")

		DupeList = {}

		for k,v in pairs(Dupes) do
			local FileSize = file.Size(engine.ActiveGamemode() .. "/distributables/advdupe2/" .. v,"LUA")
			DupeList[string.StripExtension(v)] = {txt = v,size = FileSize,strsize = math.Round(FileSize / 1024,2) .. "kB"}
		end
	end
	BuildDupeList()

	local FileQueue = {}
	local function SendChunk(ply)
		if not FileQueue[ply] then print("No file queued for player") return end
		local PlyFile = FileQueue[ply]

		PlyFile.OpenFile = file.Open(engine.ActiveGamemode() .. "/distributables/advdupe2/" .. PlyFile.file .. ".txt","rb","LUA")

		local ReadData = PlyFile.OpenFile:Read(PlyFile.OpenFile:Size())
		local _,dupe,_,_ = AdvDupe2.Decode(ReadData)

		net.Start("aas_receivedupe")
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

			net.Start("aas_ReceiveFile")
				net.WriteStream(data, function()
					ply.AdvDupe2.Downloading = false
				end)
			net.Send(ply)
		end)
	end

	do
		do	-- Network

			-- Sends the client the generic cost calculator, which is then further updated using the current cost metrics
			net.Receive("aas_requestcostscript",function(_,ply)
				local Script = file.Read(engine.ActiveGamemode() .. "/distributables/expression2/aas_costcalc.txt","LUA")

				net.Start("aas_createE2")
					net.WriteString(Script)
					net.WriteTable(AAS.RequisitionCosts)
				net.Send(ply)
			end)

			-- Sends the client all of the dupes on the server
			net.Receive("aas_requestdupes",function(_,ply)
				if not DupeList then BuildDupeList() end

				net.Start("aas_dupelist")
					net.WriteTable(DupeList)
				net.Send(ply)
			end)

			-- Sends dupe info to the client when they want to download it
			net.Receive("aas_choosedupe",function(_,ply)
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
		net.Start("aas_requestcostscript")
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
				net.Start("aas_choosedupe")
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

			if data then
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
		net.Receive("aas_dupelist",function()
			Dupes = net.ReadTable()
			if ScoreboardBase then ScoreboardBase:Remove() end
			DupeMenu()

			if not file.Exists("advdupe2/aas","DATA") then file.CreateDir("advdupe2/aas") end
		end)

		-- Start of the dupe saving process
		net.Receive("aas_receivedupe",function()
			local FileName = net.ReadString()

			AdvDupe2.SavePath = "advdupe2/aas/" .. FileName
		end)

		-- Actually saving the dupe
		net.Receive("aas_ReceiveFile", AAS_ReceiveFile)
	end
end