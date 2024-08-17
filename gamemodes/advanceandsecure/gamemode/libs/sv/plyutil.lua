MsgN("+ PlyUtils loaded")

function AAS.Funcs.SetKarma(Ply, Amount)
	if not Ply:IsPlayer() then return end
	Ply:SetNW2Int("Karma", math.Clamp(Amount, -100, 100))
end

-- This adjusts how much requisition the player gets per interval
function AAS.Funcs.AdjustKarma(Ply, Amount)
	if not Ply:IsPlayer() then return end
	local OldKarma = Ply:GetNW2Int("Karma", 0)
	Ply:SetNW2Int("Karma", math.Clamp(OldKarma + Amount, -100, 100))
end

function aasMsg(msg,ply)
	net.Start("AAS.Message")
		net.WriteTable(msg)
	if ply == nil then net.Broadcast() else net.Send(ply) end
end