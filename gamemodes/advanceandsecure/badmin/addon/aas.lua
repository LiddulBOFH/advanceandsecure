function callfunc(ply,args) -- Editmode
	AAS.Funcs.SetEditMode(tobool(args[1]))

	return true
end

cmdSettings = {
	["Help"] = "<true/false> Enables/Disables editmode for AAS.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("aas_editmode",callfunc,cmdSettings)


function callfunc(ply,args) -- Reload
	AAS.Funcs.deepReset()
	AAS.Funcs.setupMap()

	return true
end

cmdSettings = {
	["Help"] = "Loads the current save for the map.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("aas_load",callfunc,cmdSettings)


function callfunc(ply,args) -- Save
	AAS.Funcs.saveMap()

	return true
end

cmdSettings = {
	["Help"] = "Saves the map in it]s current state.",
	["MinimumPrivilege"] = 2,
	["RCONCanUse"] = true
}
BAdmin.Utilities.addCommand("aas_save",callfunc,cmdSettings)