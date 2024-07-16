MsgN("+ Hints loaded")

local HintList = {}
--HintList[#HintList + 1] = {time = 5,text = ""}
HintList[#HintList + 1] = {time = 7.5,text = "You gain or lose karma depending on how you play.\nCapturing points gives you GOOD karma (but only if you aren't sitting!).\nTeamkilling or being in the enemy safezone gives you BAD karma."}
HintList[#HintList + 1] = {time = 5,text = "Spawning will give you ammo for free.\nThat involves dying though..."}
HintList[#HintList + 1] = {time = 5,text = "Press E on a captured point to get ammo, for a price!"}
HintList[#HintList + 1] = {time = 5,text = "You will regularly gain Requisition, which is adjusted by karma."}
HintList[#HintList + 1] = {time = 5,text = "You can noclip, but only inside of your own safezone."}
HintList[#HintList + 1] = {time = 7.5,text = "Press E on your home flag to change loadout!\nAmmo is also free from here."}
HintList[#HintList + 1] = {time = 5,text = "That armor might be beneficial to your survival..."}
HintList[#HintList + 1] = {time = 7.5,text = "Capturing points gives your team tickets!\nKilling enemies makes them lose tickets!"}
HintList[#HintList + 1] = {time = 7.5,text = "Points are considered 'captured' at 25%, but capturing more is always better!"}

local HintTime = CurTime()
local HintIndex
local function GetHint()
	if CurTime() <= HintTime then
		return HintList[HintIndex].text
	else
		local pickHintIndex = math.random(1,#HintList)
		if pickHintIndex == HintIndex then
			return ""
		else
			HintIndex = pickHintIndex
			HintTime = CurTime() + HintList[HintIndex].time
			return HintList[HintIndex].text
		end
	end
end
AAS.Funcs.getHint = GetHint