include("shared.lua")

-- Default values for point names, to be overridden when RAAS info is received
AAS.State			= {
	Mode	= {},
	Active	= false,
	Data	= {},	-- Mode relevant info
	Team	= {},	-- Info about teams
	Settings	= {},	-- Settings for the mode
	Flags	= {}	-- Static settings for the mode (non-linear, etc)
}

AAS.LocalAlias	= {
	["SpawnA"]	= "SpawnA",
	["SpawnB"]	= "SpawnB"
}

AAS.GM	= {
	Settings	= {},
	Flags		= {}
}

do  -- Stuff to organize

	do	-- Net
		net.Receive("AAS.UpdateState", function()
			local State	= AAS.State
			State.Mode		= net.ReadTable()
			State.Active	= net.ReadBool()
			State.Data		= net.ReadTable()
			State.Team		= util.JSONToTable(net.ReadString())
			AAS.GM.Settings	= util.JSONToTable(net.ReadString())
			AAS.GM.Flags	= util.JSONToTable(net.ReadString())
			State.Alias		= net.ReadTable()

			State.LineLookup	= {}
			State.ClientPointLine	= {}
			State.FullLine		= {}

			if not AAS.State.Team["BLUFOR"] then return end

			AAS.LocalAlias	= {
				["SpawnA"]	= AAS.State.Team["BLUFOR"].Name,
				["SpawnB"]	= AAS.State.Team["OPFOR"].Name
			}

			if State.Data.Line then
				for k,v in ipairs(State.Data.Line) do
					local Point = State.Alias[v]
					if not IsValid(Point) then print("Failed to get point alias!") timer.Simple(1, function() AAS.Funcs.InitPlayer() end) return end

					local Name = Point:GetPointName()
					if (Name ~= "SpawnA") and (Name ~= "SpawnB") then table.insert(State.ClientPointLine, Point) end
					table.insert(State.FullLine, Point)

					State.LineLookup[State.Alias[v]] = k
				end

				if LocalPlayer():Team() == 2 then
					State.FullLine			= table.Reverse(State.FullLine)
					State.ClientPointLine	= table.Reverse(State.ClientPointLine)
				end
			else
				if State.Alias and IsValid(LocalPlayer()) and (LocalPlayer():Team() == 1 or LocalPlayer():Team() == 2) then
					local PreSortPoints = {}
					for k,v in pairs(State.Alias) do
						if not IsValid(v) then ErrorNoHalt("Failed to get point alias!") timer.Simple(1, function() AAS.Funcs.InitPlayer() end) return end

						table.insert(PreSortPoints, v)
					end

					local HomePoint = State.Alias[LocalPlayer():Team() == 1 and "SpawnA" or "SpawnB"]
					table.sort(PreSortPoints, function(a, b)
						return HomePoint:GetPos():DistToSqr(a:GetPos()) < HomePoint:GetPos():DistToSqr(b:GetPos())
					end)

					for k,v in ipairs(PreSortPoints) do
						local Name = v:GetPointName()
						if (Name ~= "SpawnA") and (Name ~= "SpawnB") then table.insert(State.ClientPointLine, v) end
						table.insert(State.FullLine, v)

						State.LineLookup[v] = k
					end
				end
			end
		end)

		net.Receive("AAS.UpdateTickets", function()
			if not AAS.State.Team["BLUFOR"] then timer.Simple(1, function() AAS.Funcs.InitPlayer() end) return end

			AAS.State.Team["BLUFOR"].Tickets = net.ReadUInt(11)
			AAS.State.Team["OPFOR"].Tickets = net.ReadUInt(11)
		end)
	end

	do	-- Hooks
		-- Requests information about the running game, like the points and how they are connected

		hook.Add("InitPostEntity","PlyInit",function()
			AAS.Funcs.InitPlayer()

			AAS.Funcs.CheckMap()	-- Checks if the player has the current map PNG saved, and if not, requests it
		end)

		AAS.Funcs.InitPlayer()
		AAS.Funcs.CheckMap()
	end
end