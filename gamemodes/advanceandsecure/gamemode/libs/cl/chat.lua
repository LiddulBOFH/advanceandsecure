MsgN("+ Chat system loaded")

local SW,SH = ScrW(),ScrH()
local UU = ((SW > SH) and SH or SW) / 12

local Chat	= {}
Chat.SuppressMenu	= false
local modecolors = {
	[1]	= Color(0,100,200,100),
	[2] = Color(0,200,0,100),
	[3]	= Color(200,100,0,100)
}

Chat.build	= function()
	if Chat.frame then Chat.frame:Remove() end
	local frame = vgui.Create("EditablePanel")
	Chat.frame	= frame

	frame.open	= true
	frame:SetSize(UU * 5, UU * 2.5)
	frame:SetPos(UU * 0.25,ScrH() - (UU * 6.5))
	frame:MakePopup()
	frame.Paint	= function(self, w, h)
		draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 200))
	end
	frame.Think	= function()
		if input.IsKeyDown( KEY_ESCAPE ) then Chat.hide() end
	end
	Chat.OriginalFramePaint	= frame.Paint

	local entrybar	= vgui.Create("Panel", frame)
	entrybar:SetSize(frame:GetWide(), 20)
	entrybar:Dock(TOP)

	local entry	= vgui.Create("DTextEntry", entrybar)
	Chat.entry = entry
	entry:SetSize(frame:GetWide(), 20)
	entry:Dock(FILL)
	entry:SetTextColor(Color(255,255,255,255))
	entry:SetFont("BasicChatFont")
	entry:SetPaintBackground(false)
	entry:SetPaintBorderEnabled(false)
	entry:SetHighlightColor(color_black)
	entry:SetCursorColor(color_white)
	entry.mode	= 1
	entry.Paint	= function(self, w, h)
		derma.SkinHook("Paint", "TextEntry", self, w, h)
	end

	entrybar.Paint	= function(panel, w, h)
		draw.RoundedBoxEx(8, 0, 0, w, h, modecolors[Chat.entry.mode] or Color(80,80,80,100), true, true, false, false)
	end

	entry.OnTextChanged	= function(self)
		if self and self.GetText then
			gamemode.Call("ChatTextChanged", self:GetText() or "")
		end
	end

	entry.OnKeyCodeTyped	= function(self, code)
		if code == KEY_ESCAPE then
			Chat.hide()
		elseif code == KEY_TAB then
			entry.mode = entry.mode + 1
			if entry.mode > 3 then entry.mode = 1 end

			timer.Simple(0.01, function() entry:RequestFocus() end)
		elseif code == KEY_ENTER then
			if string.Trim(self:GetText()) ~= "" then
				if entry.mode == 2 then		-- team
					LocalPlayer():ConCommand("say_team \"" .. (self:GetText() or "") .. "\"")
				elseif entry.mode == 3 then	-- console
					LocalPlayer():ConCommand(self:GetText() or "")
				else	-- default
					LocalPlayer():ConCommand("say \"" .. (self:GetText() or "") .. "\"")
				end
			end

			Chat.hide()
		end
	end

	local log	= vgui.Create("RichText", frame)
	Chat.log = log
	log:SetPos(5, 30)
	log:DockMargin(4, 4, 4, 4)
	log:Dock(FILL)
	log.Paint	= function() end
	log.Think	= function(self)
		if Chat.lastmsg and not Chat.frame.open then
			self:SetVisible(CurTime() - Chat.lastmsg < 10)

			if self:GetParent() ~= Chat.frame then self:Remove() end
		end
	end
	log.PerformLayout	= function(self)
		self:SetFontInternal("BasicChatFontLog")
		self:SetFGColor(color_white)
		self:SetBGColor(Color(30, 30, 30, 100))
	end
	Chat.OriginalLogPaint	= log.Paint

	local text = "Say :"

	local say = vgui.Create("DLabel", entrybar)
	Chat.say	= say
	say:SetText("")
	surface.SetFont("BasicChatFont")
	local tw,_ = surface.GetTextSize(text)
	say:SetSize(tw + 5, 20)
	say:Dock(LEFT)
	say:DockMargin(0, 0, 2, 0)
	say:SetPos(0,0)

	say.Paint	= function(self, w, h)
		draw.RoundedBoxEx(8, 0, 0, w, h, Color(30, 30, 30, 100), true, false, false, false)
		draw.SimpleText(text, "BasicChatFont", 2, Chat.entry:GetTall() / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	say.Think	= function(self)
		local chattype = 1
		if Chat.entry then chattype = Chat.entry.mode or 1 end

		local size = {
			pw	= self:GetWide() + 10,
			sw	= Chat.frame:GetWide() - self:GetWide() - 15
		}

		if chattype == 2 then
			text = "Say (TEAM) :"
		elseif chattype == 3 then
			text = "Console :"
		else
			text = "Say :"
			size.pw = 45
			size.sw = Chat.frame:GetWide() - 50
		end

		local tw2,_ = surface.GetTextSize(text)
		self:SetSize(tw2 + 4, 20)
	end

	Chat.hide()
end

Chat.hide	= function()
	timer.Simple(0.1, function() Chat.SuppressMenu = false end)
	local frame = Chat.frame
	frame.open	= false
	Chat.frame.Paint = function() end
	Chat.log.Paint	= function() end

	Chat.log:SetVerticalScrollbarEnabled(false)
	Chat.log:GotoTextEnd()

	Chat.lastmsg = Chat.lastmsg or CurTime() - 5

	for _, panel in pairs(frame:GetChildren()) do
		if panel == frame.btnMaxim or panel == frame.btnClose or panel == frame.btnMinim then continue end

		if panel ~= Chat.log then
			panel:SetVisible(false)
		end
	end

	frame:SetMouseInputEnabled(false)
	frame:SetKeyboardInputEnabled(false)
	gui.EnableScreenClicker(false)

	gamemode.Call("FinishChat")

	Chat.entry:SetText("")
	gamemode.Call("ChatTextChanged", "")
end

Chat.show	= function()
	Chat.SuppressMenu	= true
	local frame = Chat.frame
	frame.open	= true
	Chat.frame.Paint	= Chat.OriginalFramePaint
	Chat.log.Paint		= Chat.OriginalLogPaint

	Chat.log:SetVerticalScrollbarEnabled(true)
	Chat.lastmsg	= nil

	for _, panel in pairs(frame:GetChildren()) do
		if panel == frame.btnMaxim or panel == frame.btnClose or panel == frame.btnMinim then continue end

		panel:SetVisible(true)
	end

	frame:MakePopup()
	Chat.entry:RequestFocus()

	gamemode.Call("StartChat")
end

function chat.AddText(...)
	if not Chat.log then
		Chat.build()
	end

	for _, obj in pairs({...}) do
		if type(obj) == "table" then
			Chat.log:InsertColorChange(obj.r, obj.g, obj.b, 255)
		elseif type(obj) == "string" then
			Chat.log:AppendText(obj)
		elseif IsValid(obj) and obj:IsPlayer() then
			local col = GAMEMODE:GetTeamColor(obj)
			Chat.log:InsertColorChange(col.r, col.g, col.b, 255)
			Chat.log:AppendText(obj:Nick())
		end
	end

	Chat.log:AppendText("\n")

	Chat.log:SetVisible(true)
	Chat.lastmsg	= CurTime()
	Chat.log:InsertColorChange(255,255,255,255)
end

function chat.GetChatBoxPos()
	if not Chat.frame then Chat.build() end

	return Chat.frame:GetPos()
end

hook.Remove("ChatText", "AAS.Chat.JoinLeave")
hook.Add("ChatText", "AAS.Chat.JoinLeave", function(_, _, text, msgtype)
	if not Chat.log then Chat.build() end

	if msgtype ~= "chat" then
		Chat.log:InsertColorChange(0,128,255,255)
		Chat.log:AppendText(text .. "\n")
		Chat.log:SetVisible(true)
		Chat.lastmsg	= CurTime()
		return true
	end
end)

hook.Remove("PlayerBindPress", "AAS.Chat.BindHijack")
hook.Add("PlayerBindPress", "AAS.Chat.BindHijack", function(ply, bind, pressed)
	if string.sub(bind, 1, 11) == "messagemode" then
		if not Chat.entry then Chat.build() end

		if bind == "messagemode2" then
			Chat.entry.mode = 2
		else
			Chat.entry.mode = 1
		end

		if IsValid(Chat.frame) then
			Chat.show()
		else
			Chat.build()
			Chat.show()
		end

		return true
	end
end)

hook.Add("OnPauseMenuShow", "AAS.Chat.SuppressMenu", function()
	if Chat.SuppressMenu then Chat.SuppressMenu	= false return false end
end)

hook.Add("ChatTextChanged", "AAS.Chat.TextChanged", function(text)
	if not Chat.entry then Chat.build() end

	Chat.entry.addtext = text or ""
end)