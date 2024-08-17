MsgN("+ Core loaded")

AAS.Funcs = {}

-- Default alias, if not set
AAS.TeamData = {
	[1] = {
		Name    = "BLUFOR",
		Color   = Color(3, 94, 252),
		Tickets = 300,
		Seats   = {}
	},
	[2] = {
		Name    = "OPFOR",
		Color   = Color(255, 87, 87),
		Tickets = 300,
		Seats   = {}
	}
}

AAS.DefaultProperties = {
	MaxRequisition = 500,
	RequisitionGain = 50,
	NonLinear = false,
	ChangedAlias = false,
	Alias = {[1] = {Name = "BLUFOR",Color = Color(3, 94, 252)},[2] = {Name = "OPFOR",Color = Color(255, 87, 87)}},
	StartTickets = 500,
}

AAS.RAASFinished = false
AAS.NonLinear = false
AAS.SpawnBoundA = Vector(-1024,-1024,-256)
AAS.SpawnBoundB = Vector(1024,1024,512 + 256)
AAS.PointAlias = nil

AAS.CapRange = 256 ^ 2
AAS.CapInfoRange = 512 ^ 2

-- Dandy collection of commonly used colors
Colors = {
	ErrorCol = Color(255,0,0),
	BasicCol = Color(200,200,200),
	GoodCol = Color(65,255,65),
	BadCol = Color(255,65,65),
	White = Color(255,255,255),
	Black = Color(0,0,0)
}

if SERVER then
	do	-- Network strings
		-- Serverside -> Client
		util.AddNetworkString("AAS.Message")
		util.AddNetworkString("AAS.RAASLine")
		util.AddNetworkString("AAS.UpdatePointState")
		util.AddNetworkString("AAS.UpdateTeamData")
		util.AddNetworkString("AAS.OpenSettings")
		util.AddNetworkString("AAS.OpenLoadout")
		util.AddNetworkString("AAS.OpenVotes")

		util.AddNetworkString("AAS.RequestCostScript")

		util.AddNetworkString("AAS.RequestDupeList")
		util.AddNetworkString("AAS.RequestDupe")

		-- Clientside -> Server
		util.AddNetworkString("AAS.RequestTeamSwap")
		util.AddNetworkString("AAS.PlayerInit")
		util.AddNetworkString("AAS.UpdateServerSettings")
		util.AddNetworkString("AAS.ReceivePlayerLoadout")
		util.AddNetworkString("AAS.ReceiveVote")

		util.AddNetworkString("AAS.ReceiveCostScript")
		util.AddNetworkString("AAS.CostPanel")

		util.AddNetworkString("AAS.ReceiveDupeList")
		util.AddNetworkString("AAS.ReceiveDupe")
		util.AddNetworkString("AAS.ReceiveFile")
	end
else
	do	-- Network

		-- Generic message handler
		net.Receive("AAS.Message",function()
			local msg = net.ReadTable()
			chat.AddText(unpack(msg))
		end)
	end
end