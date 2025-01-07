MsgN("+ Settings system loaded")

if SERVER then

	-- Handles any updates to the server settings, with a myriad of checks to block any unwanted changes
	net.Receive("AAS.UpdateServerSettings",function(_,ply)
		local Settings = net.ReadTable()
		if ply == nil then print("how?") return end
		if not ply:IsSuperAdmin() then print(ply:Nick() .. " attempted to update server settings.") return end
		if not GetGlobalBool("EditMode",false) then print(ply:Nick() .. " attempted to update server settings.") return end

		--PrintTable(Settings)

		for k,v in pairs(Settings) do
			if not AAS.GM.Settings[k] then print("Skipped " .. k .. " as it is not a valid setting.") continue end
			if type(v.value) ~= type(AAS.GM.Settings[k].value) then print("Skipped " .. k .. " as it is a type mismatch.") continue end
			local OldSetting = AAS.GM.Settings[k]

			if v.value ~= OldSetting.value then
				print("== " .. k .. " was changed!\n| Old value: " .. tostring(AAS.GM.Settings[k].value) .. "\n| New value: " .. tostring(v.value))



				if OldSetting.type == "number" then
					AAS.GM.Settings[k].value = math.Clamp(v.value, OldSetting.min, OldSetting.max)
				else
					AAS.GM.Settings[k].value = v.value
				end
			end
		end

		AAS.Funcs.SaveMap()

		AAS.SuppressReload = true
		AAS.Funcs.SetEditMode(false)

		AAS.Funcs.FullReload()
	end)

else
	local Settings = {}

	local PropertyLookup = {
		string	= "Generic",
		color	= "VectorColor",
		bool	= "Boolean",
		number	= "Int"
	}

	-- Since there seems to be NO WAY to acquire the color from a fucking color property when used in this menu, we have to decipher the even more retarded way that color is stored as a fucking string
	local function UnfuckulateGarryCode(RetardedStringColor)
		local FuckedArray = string.Explode(" ", RetardedStringColor, false)
		return Vector(FuckedArray[1], FuckedArray[2], FuckedArray[3])
	end

	local function SettingsMenu(SV_Settings)
		local LP = LocalPlayer()
		if GetGlobalBool("EditMode",false) == false then LP:PrintMessage(HUD_PRINTTALK,"The server is not in edit mode!") return end

		-- Copy SV_Settings

		SettingsBase = vgui.Create("DFrame")
		SettingsBase:SetSize(400,400)
		SettingsBase:SetTitle("Game Settings")
		SettingsBase:Center()
		SettingsBase:MakePopup()
		SettingsBase:SetDraggable(false)

		local InfoLabel = vgui.Create("DLabel", SettingsBase)
		InfoLabel:SetText("Info: Hover over each item for more info")
		InfoLabel:Dock(TOP)
		InfoLabel:DockMargin(0,0,0,0)

		local FinishButton = vgui.Create("DButton", SettingsBase)
		FinishButton:SetSize(1,24)
		FinishButton:SetText("Apply")
		FinishButton:DockMargin(0,2,0,2)
		FinishButton:Dock(BOTTOM)

		local PropertiesBase = vgui.Create("DProperties", SettingsBase)
		PropertiesBase:Dock(FILL)

		local sorted_settings = {}
		for k,v in pairs(SV_Settings) do
			table.insert(sorted_settings, {
				index	= k,
				order	= v.order
			})
		end

		table.SortByMember(sorted_settings, "order", true)

		-- Redo to follow order!
		for _,setting in ipairs(sorted_settings) do
			local v = SV_Settings[setting.index]
			local k = setting.index

			local Item = PropertiesBase:CreateRow( k, v.name )
			Item:SetTooltip( v.desc or "" )
			Item:SetTooltipDelay(0.5)

			Item.index	= k

			-- I'd do this in a better way, but Setup is unique to each type of property
			local PropertyType = PropertyLookup[v.type]
			if v.type == "string" then
				Item:Setup(PropertyType)
				Item:SetValue( v.value )

				Item.DataChanged	= function(self, data)
					Settings[Item.index].value = data
				end
			elseif v.type == "bool" then
				Item:Setup(PropertyType)
				Item:SetValue( v.value )

				Item.DataChanged	= function(self, data)
					Settings[Item.index].value = tobool(data)
				end
			elseif v.type == "number" then
				Item:Setup(PropertyType, {min = v.min, max = v.max})
				Item:SetValue( v.value )

				Item.DataChanged	= function(self, data)
					Settings[Item.index].value = math.Clamp(math.ceil(data), Settings[Item.index].min, Settings[Item.index].max)
				end
			elseif v.type == "color" then
				Item:Setup(PropertyType)
				Item:SetValue( v.value / 255 )

				Item.DataChanged	= function(self, data)
					local val =	UnfuckulateGarryCode(data)
					Item:SetValue(val)

					Settings[Item.index].value = val * 255
				end
			else
				ErrorNoHalt("Attempted to create setting with type " .. v.type)
			end
		end

		FinishButton.DoClick = function()
			net.Start("AAS.UpdateServerSettings")
				net.WriteTable(Settings)
			net.SendToServer()

			SettingsBase:Remove()
		end
	end
	if SettingsBase then SettingsBase:Remove() end

	net.Receive("AAS.OpenSettings",function()
		Settings = net.ReadTable()
		SettingsMenu(Settings)
	end)

end