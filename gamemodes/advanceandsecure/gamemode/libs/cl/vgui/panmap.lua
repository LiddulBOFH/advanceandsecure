local PANEL	= {}

AccessorFunc(PANEL, "canvas", "Canvas")
local NoMap	= Material("materials/gui/noicon.png", "")
function PANEL:Init()
	local canvas = vgui.Create("Panel", self)
	self.canvas	= canvas
	canvas.zoom	= 3
	canvas.Tracking	= false

	canvas.PerformLayout	= function(panel)
		self:PerformLayout()
		self:InvalidateParent()
	end

	function canvas:Paint(w, h)
		surface.SetDrawColor(65, 65, 65)
		surface.SetMaterial(NoMap)
		surface.DrawTexturedRect(0, 0, w, h)

		if AAS.ValidMap then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(AAS.MapPNG)

			surface.DrawTexturedRect(0, 0, w, h)
		end

		if self.StoredPos then
			local Pos = self.StoredPos
			local UU = w / 12
			surface.SetDrawColor(255, 0, 0, 200)
			draw.NoTexture()
			render.SetColorMaterial()

			surface.DrawTexturedRectRotated(Pos.x * self.zoom, Pos.y * self.zoom, UU * 0.1, UU * 0.01, 0)
			surface.DrawTexturedRectRotated(Pos.x * self.zoom, Pos.y * self.zoom, UU * 0.1, UU * 0.01, 90)
		end
	end

	function canvas:Think()
		if self.Dragging then
			self:SetCursor("sizeall")

			local mx, my = math.Clamp(gui.MouseX(), 1, ScrW() - 1), math.Clamp(gui.MouseY(), 1, ScrH() - 1)
			local x = mx - self.Dragging[1]
			local y = my - self.Dragging[2]

			self.Tracking	= false
			self:SetPos(x, y)
			self:PerformLayout()

			return
		end

		if self.Tracking then
			if IsValid(self.TrackTarget) then
				local tx, ty = self.TrackTarget:GetPos()
				local sx, sy = self:GetSize()
				self:SetPos(-tx + (sx / 2 / self.zoom), -ty + (sy / 2 / self.zoom))
				self:PerformLayout()
			else
				self.Tracking = false
			end
		end

		self:SetCursor("arrow")
	end

	function canvas:OnMousePressed(code)
		if code == MOUSE_RIGHT then	-- Could be used for broadcasting a position to other players, but that can wait for later
			--local Menu = DermaMenu()
			--Menu:Open()

			--local mx, my = self:LocalCursorPos()
			--self.StoredPos	= {x = mx / self.zoom, y = my / self.zoom}
			--Menu:AddOption("Poop", function() print("broadcast a position?") end)

			return
		end

		self.Dragging	= {gui.MouseX() - self.x, gui.MouseY() - self.y}
		self:MouseCapture(true)
	end

	function canvas:OnMouseReleased()
		self.Dragging	= nil
		self.Sizing		= nil

		self:MouseCapture(false)
		self:InvalidateParent()
	end

	-- "good enough"
	function canvas:OnMouseWheeled(scroll)
		self.zoom	= math.Clamp(self.zoom + (scroll / 2), 1, 8)

		if not self.Tracking then
			local MousePos		= {self:LocalCursorPos()}
			local sx, sy	= self:GetSize()
			self:SetPos(-MousePos[1] + (sx / 2 / self.zoom), -MousePos[2] + (sy / 2 / self.zoom))
		end

		self:PerformLayout()
	end

	function canvas:StartTrack(panel)
		if not IsValid(panel) then return end
		if not self:IsOurChild(panel) then return end
		self.Tracking		= true
		self.TrackTarget	= panel
	end

	canvas:SetMouseInputEnabled(true)
	self:SetMouseInputEnabled(true)

	self:SetPaintBackground(false)
	self:SetPaintBorderEnabled(false)
	self:SetPaintBackgroundEnabled(false)
end

function PANEL:Think()
	if self.Hovered then
		self:SetCursor("sizeall")
	end

	self:SetCursor("arrow")
end

function PANEL:Paint(w, h)
	local clip = DisableClipping(true)
	local TC	= team.GetColor(LocalPlayer():Team())

	surface.SetDrawColor(TC)
	surface.DrawOutlinedRect(0, 0, w, h, -4)

	DisableClipping(clip)
end

function PANEL:OnMousePressed(...)
	self.canvas:OnMousePressed(...)
end

function PANEL:OnMouseReleased(...)
	self.canvas:OnMouseReleased(...)
end

function PANEL:AddItem(panel)
	panel:SetParent(self:GetCanvas())
end

function PANEL:PerformLayout()
	local canvas	= self:GetCanvas()

	local _, _, pw, ph = self:GetBounds()

	canvas:SetSize(pw * canvas.zoom, ph * canvas.zoom)
	local x, y, w, h = canvas:GetBounds()

	if w > pw then
		if x > 0 then
			canvas:SetPos(0, y)
			x = 0
		end

		if (x + w) < pw then
			local nx = pw - w
			canvas:SetPos(nx, y)
			x = nx
		end
	end

	if w <= pw then
		if x < 0 then
			canvas:SetPos(0, y)
			x = 0
		end

		if (x + w) > pw then
			local nx = pw - w
			canvas:SetPos(nx, y)
			x = nx
		end
	end

	if h >= ph then
		if y > 0 then
			canvas:SetPos(x, 0)
			y = 0
		end

		if (y + h) < ph then
			local ny = ph - h
			canvas:SetPos(x, ny)
			y = ny
		end
	end

	if h < ph then
		if h < 0 then
			canvas:SetPos(x, 0)
			y = 0
		end

		if (y + h) > ph then
			local ny = ph - h
			canvas:SetPos(x, ny)
			y = ny
		end
	end
end

derma.DefineControl("MapPanel", "AAS Map Panel", PANEL, "DPanel")