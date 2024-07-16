MsgN("+ Vote system loaded")

if SERVER then
	AAS.Voting = false
	AAS.RTV = false
	AAS.RoundCounter = 1
	AAS.TeamWins = {0,0}

	local PreMapList = {}
	local CurrentVoteList = {}
	local VoteData = {}

	local function UpdateVotes()
		local Counts = {}
		for k,v in pairs(VoteData) do
			Counts[tostring(v)] = (Counts[tostring(v)] or 0) + 1
		end

		for i = 1,5,1 do
			SetGlobalInt("vote_" .. i,0)
		end

		for k,v in pairs(Counts) do
			SetGlobalInt("vote_" .. k,v or 0)
		end
	end

	local Maps = {}
	local function OpenVotes()
		if table.IsEmpty(PreMapList) then
			PreMapList = file.Find("aas/maps/*.txt","DATA")

			for k,v in ipairs(PreMapList) do
				local str = string.StripExtension(v)
				if str == game.GetMap() then continue end
				Maps[k] = str
			end

			if #Maps == 0 then AAS.Funcs.finishVote(5) return end
		end

		local Choices = {}

		print(math.min(#Maps,3))
		for i = 1,math.min(#Maps,3),1 do
			local Pick = math.random(1,#Maps)
			Choices[i] = Maps[Pick]
			table.remove(Maps,Pick)
		end

		AAS.Voting = true
		SetGlobalBool("AAS.Voting",AAS.Voting)

		AAS.RTV = (#Maps > 0)
		print(AAS.RTV)

		local CheckTime = 30

		CurrentVoteList = table.Copy(Choices)

		--[[
		print("================= MAPS")
		PrintTable(Maps)
		print("================= CHOICES")
		PrintTable(Choices)
		]]--

		net.Start("AAS.OpenVotes")
			net.WriteFloat(ST() + CheckTime)
			net.WriteBool(AAS.RTV)
			net.WriteTable(Choices)
		net.Broadcast()

		VoteData = {}

		UpdateVotes()

		timer.Simple(CheckTime,AAS.Funcs.countVotes)
	end
	AAS.Funcs.openVotes = OpenVotes

	local function FinishVote(Choice)
		if Choice <= 3 then
			if #CurrentVoteList == 0 then AAS.Funcs.finishVote(5) return end -- Just more insurance, if somehow we managed to get this vote here, we'll safely restart the map
			RunConsoleCommand("changelevel",CurrentVoteList[math.min(Choice,#CurrentVoteList)])
		elseif Choice == 4 then
			aasMsg({Colors.BasicCol,"Refreshing the vote, old choices are no longer available!"})
			OpenVotes()
		elseif Choice == 5 then
			ScrambleTeams()
			AAS.Funcs.deepReset()
			AAS.Funcs.setupMap()
		end
	end
	AAS.Funcs.finishVote = FinishVote

	local function CountVotes()
		AAS.Voting = false
		SetGlobalBool("AAS.Voting",AAS.Voting)

		print("Counting votes!")
		local Count = {}

		if table.Count(VoteData) == 0 then
			if #CurrentVoteList == 0 then
				AAS.Funcs.finishVote(5) -- just refresh the map, dunno how we got here
			else
				AAS.Funcs.finishVote(math.random(1,3))
				return
			end
		end

		for k,v in pairs(VoteData) do
			Count[v] = (Count[v] or 0) + 1
		end

		local Highest = Count[table.GetWinningKey(Count)]
		local Ties = table.KeysFromValue(Count, Highest)

		AAS.Funcs.finishVote(Ties[math.random(1,#Ties)])
	end
	AAS.Funcs.countVotes = CountVotes

	do
		do	-- Network

			-- Receives vote info and updates clients about that, otherwise will send a rude message to anyone thats trying to circumvent it
			net.Receive("AAS.ReceiveVote",function(_,ply)
				if not AAS.Voting then aasMsg({Colors.ErrorCol,"Bugger off"},ply) return end
				local Choice = net.ReadUInt(3)

				VoteData[ply] = Choice

				UpdateVotes()
			end)
		end
	end

else	-- Cient
	local Choices = {}
	local RTV = false
	local Time = SysTime() + 0

	local function SendVote(choice)
		net.Start("AAS.ReceiveVote")
			net.WriteUInt(choice,3)
		net.SendToServer()
	end

	local function VoteMenu()
		if VotePanel then VotePanel:Remove() end

		VotePanel = vgui.Create("DFrame")
		VotePanel:SetSize(300,300)
		VotePanel:Center()
		VotePanel:SetDraggable(false)
		VotePanel:ShowCloseButton(false)
		VotePanel:MakePopup()
		VotePanel.Paint = function(self,w,h)
			surface.SetDrawColor(75,75,75)
			surface.DrawRect(0,0,w,h)

			surface.SetDrawColor(25,25,25)
			surface.DrawRect(0,0,w,36)

			draw.SimpleText("MAP VOTING","BasicFontLarge",w / 2,10,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			local TimeLeft = math.Clamp(math.Round(Time - SysTime(),1),0,30)

			if TimeLeft < 10 then surface.SetDrawColor(127,0,0) else surface.SetDrawColor(0,127,0) end
			surface.DrawRect(0,h - 12,w * (TimeLeft / 30),12)
			draw.SimpleText("TIME REMAINING: " .. tostring(TimeLeft),"BasicFont",w / 2,h,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM)
		end
		VotePanel:SetTitle("")

		local shift = 0
		local selected = 0
		for k,v in ipairs(Choices) do
			local button = vgui.Create("DButton",VotePanel)
			button:SetSize(250,30)
			button:SetPos(25,60 + shift)
			button.ID = v
			button.Index = k
			button:SetText("")
			button.Paint = function(self,w,h)
				surface.SetDrawColor(25,25,25)
				surface.DrawRect(0,0,w,h)

				if self:IsHovered() then
					surface.SetDrawColor(0,65,0)
					surface.DrawRect(4,4,w - 8,h - 8)
				end

				if selected == self.Index then surface.SetDrawColor(0,127,0) else surface.SetDrawColor(100,100,100) end
				surface.DrawRect(0,0,h,h)

				draw.SimpleText(tostring(GetGlobalInt("vote_" .. self.Index,0)),"BasicFontLarge",h / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

				draw.SimpleText(self.ID,"BasicFont14",h + 4,h / 2,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
			end
			button.DoClick = function(self)
				if not GetGlobalBool("AAS.Voting",false) then return end
				selected = self.Index
				SendVote(self.Index)
			end

			shift = shift + 40
		end

		if RTV then -- allow rock the vote
			local button = vgui.Create("DButton",VotePanel)
			button:SetSize(250,30)
			button:SetPos(25,60 + shift)
			button.ID = "Refresh the vote"
			button.Index = 4
			button:SetText("")
			button.Paint = function(self,w,h)
				surface.SetDrawColor(25,25,25)
				surface.DrawRect(0,0,w,h)

				if self:IsHovered() then
					surface.SetDrawColor(0,65,0)
					surface.DrawRect(4,4,w - 8,h - 8)
				end

				if selected == self.Index then surface.SetDrawColor(0,127,0) else surface.SetDrawColor(100,100,100) end
				surface.DrawRect(0,0,h,h)

				draw.SimpleText(tostring(GetGlobalInt("vote_" .. self.Index,0)),"BasicFontLarge",h / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

				draw.SimpleText(self.ID,"BasicFont14",h + 4,h / 2,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
			end
			button.DoClick = function(self)
				if not GetGlobalBool("AAS.Voting",false) then return end
				selected = self.Index
				SendVote(self.Index)
			end

			shift = shift + 40
		end

		local button = vgui.Create("DButton",VotePanel)
		button:SetSize(250,30)
		button:SetPos(25,60 + shift)
		button.ID = "Reuse Current Map"
		button.Index = 5
		button:SetText("")
		button.Paint = function(self,w,h)
			surface.SetDrawColor(25,25,25)
			surface.DrawRect(0,0,w,h)

			if self:IsHovered() then
				surface.SetDrawColor(0,65,0)
				surface.DrawRect(4,4,w - 8,h - 8)
			end

			if selected == self.Index then surface.SetDrawColor(0,127,0) else surface.SetDrawColor(100,100,100) end
			surface.DrawRect(0,0,h,h)

			draw.SimpleText(tostring(GetGlobalInt("vote_" .. self.Index,0)),"BasicFontLarge",h / 2,h / 2,Colors.White,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

			draw.SimpleText(self.ID,"BasicFont14",h + 4,h / 2,Colors.White,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
		end
		button.DoClick = function(self)
			if not GetGlobalBool("AAS.Voting",false) then return end
			selected = self.Index
			SendVote(self.Index)
		end
	end

	-- Opens the vote menu, with a timer as well as if "rock the vote" can occur
	net.Receive("AAS.OpenVotes",function()
		Time = net.ReadFloat()
		RTV = net.ReadBool()
		Choices = net.ReadTable()
		VoteMenu()
	end)
end