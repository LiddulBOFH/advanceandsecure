MsgN("+ CostDraw system loaded")

local DupeCost = {Draw = false}

hook.Remove("HUDPaint", "AAS.DupeCostDraw")

local function StopDraw()
	DupeCost = {Draw = false}

	hook.Remove("HUDPaint", "AAS.DupeCostDraw")
end

local function DrawDupeCost()
	if DupeCost.Draw == false then StopDraw() end

	local DupePos = (DupeCost.HighCenter + Vector(0,0,32)):ToScreen()
	local DupeRPos = DupeCost.HighCenter:ToScreen()

	surface.SetDrawColor(100,100,100)
	surface.DrawLine(DupePos.x,DupePos.y,DupeRPos.x,DupeRPos.y)

	surface.DrawRect(DupePos.x,DupePos.y,128,20)
	draw.SimpleTextOutlined("COST: ","BasicFontLarge",DupePos.x + 4,DupePos.y + 10,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,color_black)
	draw.SimpleTextOutlined(tostring(DupeCost.Cost),"BasicFontLarge",DupePos.x + 124,DupePos.y + 10,Color(255,0,0),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER,1,color_black)

	surface.DrawRect(DupePos.x,DupePos.y - DupeCost.BreakdownCount * 16,4,DupeCost.BreakdownCount * 16)

	local int = 0
	for k,v in pairs(DupeCost.CostBreakdown) do
		int = int + 1
		draw.SimpleTextOutlined(k .. ": " .. math.Round(v,2),"BasicFont14",DupePos.x + 8,DupePos.y - (16 * int) + 6,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,color_black)
	end

	if SysTime() >= DupeCost.Time then StopDraw() end
end

local function StartDraw()
	hook.Add("HUDPaint", "AAS.DupeCostDraw", DrawDupeCost)
end

-- Sent whenever the player spawns a dupe, provides information about the cost of everything in the dupe
net.Receive("AAS.CostPanel",function()
	local DupeCenter = net.ReadVector()
	local CostBreakdown = net.ReadTable()
	local Cost = net.ReadUInt(16)
	local Highest = net.ReadUInt(12)

	DupeCost.DupeCenter = DupeCenter
	DupeCost.HighCenter = Vector(DupeCenter.x,DupeCenter.y,Highest)
	DupeCost.CostBreakdown = CostBreakdown
	DupeCost.BreakdownCount = table.Count(CostBreakdown)
	DupeCost.Cost = Cost
	DupeCost.Time = SysTime() + math.min(table.Count(CostBreakdown) * 4,15)
	DupeCost.Draw = true

	StartDraw()
end)