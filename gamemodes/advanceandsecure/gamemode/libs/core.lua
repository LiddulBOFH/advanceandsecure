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
		-- Serverside
		util.AddNetworkString("aas_msg")
		util.AddNetworkString("aas_raasline")
		util.AddNetworkString("aas_send_updateproperties")
		util.AddNetworkString("aas_pointstatechange")
		util.AddNetworkString("aas_UpdateTeamData")
		util.AddNetworkString("aas_opensettings")
		util.AddNetworkString("aas_openloadout")
		util.AddNetworkString("aas_openvotes")

		util.AddNetworkString("aas_requestcostscript")

		util.AddNetworkString("aas_requestdupes")
		util.AddNetworkString("aas_choosedupe")

		-- Clientside
		util.AddNetworkString("aas_requestteam")
		util.AddNetworkString("aas_playerinit")
		util.AddNetworkString("aas_edit_updateproperties")
		util.AddNetworkString("aas_UpdateServerSettings")
		util.AddNetworkString("aas_receiveplayerloadout")
		util.AddNetworkString("aas_receivevote")

		util.AddNetworkString("aas_createE2")
		util.AddNetworkString("aas_notifycost")

		util.AddNetworkString("aas_dupelist")
		util.AddNetworkString("aas_receivedupe")
		util.AddNetworkString("aas_ReceiveFile")
	end

	function aasMsg(msg,ply)
		net.Start("aas_msg")
			net.WriteTable(msg)
		if ply == nil then net.Broadcast() else net.Send(ply) end
	end

	function aas_PointStateChange(point,oldstatus,newstatus)
		net.Start("aas_pointstatechange")
			net.WriteEntity(point)
			net.WriteInt(oldstatus,3)
			net.WriteInt(newstatus,3)
		net.Broadcast()
	end
end