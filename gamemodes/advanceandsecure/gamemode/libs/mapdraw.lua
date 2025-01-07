MsgN("+ Mapdraw system loaded")

local res = 256		-- Resolution in pixels, 256 is recommended max since any higher would require networking to be rewritten to handle the extra data
local topographicSliceHeight	= 262.46 * 3 -- Units per topography slice, 262.46 = 5m

if SERVER then

	local Queued	= {}

	local MatTypeOverride = {
		[MAT_CONCRETE]	= Color(65, 65, 65),
		[MAT_SAND]		= Color(255, 252, 99),
		[MAT_METAL]		= Color(133, 149, 163),
		[MAT_SNOW]		= Color(226, 254, 255),
		[MAT_WOOD]		= Color(117, 89, 37),
		[MAT_TILE]		= Color(151, 48, 81)
	}

	local ScanState	= {
		x	= 1,
		y	= 1,
		z	= 0,

		Running		= false,
		Finished	= false,
		Data		= {},
		State		= 1,

		LowestZ		= 16384,
		Output		= {}
	}

	local trmask	= bit.bor(MASK_SOLID, MASK_WATER)
	local gridsize	= 32768 / res

	local function getIndex(x, y)
		return (x - 1) + ((y - 1) * res)
	end

	local function getPixel(x, y)
		return ScanState.Data[getIndex(x, y)]
	end

	local function tryTrace(tracedata)
		local breakloop = 0
		local start = tracedata.start
		local z = 16384
		local dig = false

		while breakloop < 25 do
			if dig then
				start.z = z
				if util.IsInWorld(start) then
					dig = false

					tracedata.start = start
					tracedata.endpos = start - Vector(0, 0, 32768)
				else
					if z <= -16384 then return false end
					z = z - 128
				end
			else
				local tr = util.TraceLine(tracedata)
				z = tr.HitPos.z

				if tr.HitPos.z < -16384 then return false end

				if util.IsInWorld(tr.HitPos) and util.IsInWorld(tr.StartPos) then return tr end

				if tr.AllSolid then return false end

				if not util.IsInWorld(tr.HitPos) then
					dig = true
					z = z - 128
				end
			end

			breakloop = breakloop + 1
		end

		return false
	end

	local function getNeighboringPixels(x, y)
		local pixels = {}
		if x > 1 then table.insert(pixels, getPixel(x - 1, y)) end
		if x < res then table.insert(pixels, getPixel(x + 1, y)) end
		if y > 1 then table.insert(pixels, getPixel(x, y - 1)) end
		if y < res then table.insert(pixels, getPixel(x, y + 1)) end

		return pixels
	end

	local function getTopoSlice(pd)
		return math.floor((pd.trace.HitPos.z - ScanState.LowestZ) / topographicSliceHeight)
	end

	-- Returns a string for color, converted to digital space, losing some depth but makes it easier to transmit
	local function color2digi(color)
		return tostring(math.floor(color.r / 26)) .. tostring(math.floor(color.g / 26)) .. tostring(math.floor(color.b / 26))
	end

	local Water = Color(0,0,255)
	local DeepWater = Color(0,0,52)

	local TopoBorder = color2digi(Color(255,127,0))

	local DefaultGround	= Color(55,182,0)

	local iterState = {
		[1] = function()	-- Initial scan
			local pos	= Vector((ScanState.x * gridsize) - (gridsize / 2) - 16384, -((ScanState.y * gridsize) - (gridsize / 2) - 16384), 16383)

			local tr	= tryTrace({start = pos, endpos = pos - Vector(0, 0, 32768), mask = trmask, collisiongroup = COLLISION_GROUP_NONE})

			local index = getIndex(ScanState.x, ScanState.y)

			local data	= {}

			if tr == false then
				data.valid = false
				ScanState.Data[index] = data
				return
			else
				if (not tr.HitWorld) or tr.AllSolid or (tr.HitNormal:Dot(Vector(0,0,1)) == 0) then	-- Fill the void with the void
					data.valid = false
				else
					if tr.HitSky or (not util.IsInWorld(tr.HitPos)) then	-- Not a valid surface we want to draw, so make it invisible
						data.valid = false
					else
						data.valid = true

						if tr.HitPos.z < ScanState.LowestZ then
							ScanState.LowestZ = tr.HitPos.z
						end

						if tr.MatType == MAT_SLOSH then
							data.type = "water"

							local depthtrace = util.TraceLine({start = tr.HitPos, endpos = tr.HitPos - Vector(0, 0, 32768), mask = MASK_SOLID_BRUSHONLY, collisiongroup = COLLISION_GROUP_NONE})

							data.depth = math.abs(depthtrace.HitPos.z - tr.HitPos.z)
						end

						data.trace = tr

						ScanState.Data[index] = data
					end
				end
			end

			ScanState.Data[index] = data
		end,
		[2] = function()	-- Post processing (topography, borders, etc)
			local index = getIndex(ScanState.x, ScanState.y)
			local pixelData = getPixel(ScanState.x, ScanState.y)

			if not pixelData.valid then
				return -- Simply don't write anything
			else
				if pixelData.type == "water" then
					ScanState.Output[index] = color2digi(Water:Lerp(DeepWater, math.min(1, pixelData.depth / 1024)))

					return
				else
					local pixels = getNeighboringPixels(ScanState.x, ScanState.y)
					local slice = getTopoSlice(pixelData)

					local skip = false
					for _, pd2 in ipairs(pixels) do
						if not pd2.valid then continue end

						if slice > getTopoSlice(pd2) then
							ScanState.Output[index] = TopoBorder
							skip = true

							break
						end
					end

					if skip then return end

					local VertNormal = math.min(pixelData.trace.HitNormal:Dot(Vector(0,0,1)) ^ 3, 1)

					local col = DefaultGround

					if MatTypeOverride[pixelData.trace.MatType] then
						col = MatTypeOverride[pixelData.trace.MatType]
					end

					local postcol = col:ToVector() * VertNormal

					ScanState.Output[index] = color2digi(postcol:ToColor())
				end
			end
		end
	}

	local function iter()

		if iterState[ScanState.State] then iterState[ScanState.State]() else ScanState.Running = false return end

		if ScanState.x < res then
			ScanState.x = ScanState.x + 1
		else
			ScanState.x = 0
			ScanState.y = ScanState.y + 1

			if ScanState.y > res then

				if iterState[ScanState.State + 1] then
					print("[AAS Mapscan] Finished state " .. ScanState.State)

					ScanState.State = ScanState.State + 1

					ScanState.x = 1
					ScanState.y = 1
				else
					print("[AAS Mapscan] Finished map processing!")
					ScanState.Running	= false
					ScanState.Finished	= true

					--PrintTable(ScanState.Output)

					hook.Remove("Tick", "AAS.ScanTick")

					for ply, _ in pairs(Queued) do
						AAS.Funcs.SendMap(ply)
					end
				end
			end
		end
	end

	local function Scan()
		for _ = 1, 2048 do
			if not ScanState.Running then break end

			iter()
		end
	end

	AAS.Funcs.StartScan	= function()

		ScanState.x			= 1
		ScanState.y			= 1

		ScanState.Running	= true
		ScanState.State		= 1
		ScanState.LowestZ	= 16384
		ScanState.Data		= {}
		ScanState.Output	= {}

		hook.Remove("Tick", "AAS.ScanTick")
		hook.Add("Tick", "AAS.ScanTick", Scan)
	end

	AAS.Funcs.SendMap	= function(ply)
		if not ScanState.Finished then Queued[ply] = true if not ScanState.Running then AAS.Funcs.StartScan() end return end

		local CompressedData = util.Compress(util.TableToJSON(ScanState.Output))

		net.Start("AAS.SendMapScan")
			net.WriteData(CompressedData, #CompressedData)
		net.Send(ply)
	end
	hook.Remove("Tick", "AAS.ScanTick")

	net.Receive("AAS.RequestMapScan", function(_, ply) AAS.Funcs.SendMap(ply) end)
else
	local encode	= include(engine.ActiveGamemode() .. "/gamemode/libs/cl/png.lua")
	local blocksize	= res ^ 2
	local heapsize	= res ^ 2 * 4

	local MapData	= {
		decompressed	= {},
		pointer			= 0
	}

	local function save()
		local chunk = tostring(MapData.png.output[MapData.pointer + 1])

		for i = 2, 16384 do
			local index = MapData.pointer + i

			chunk = chunk .. tostring(MapData.png.output[index])
		end

		MapData.openfile:Write(chunk)

		MapData.openfile:Flush()

		if MapData.pointer < heapsize then
			MapData.pointer = MapData.pointer + 16384
		else
			MapData.openfile:Close()

			AAS.Funcs.CheckMap()

			hook.Remove("Think", "AAS.SavePNG")
		end
	end

	local function digi2color(digi)
		return Color(tonumber(digi[1]) * 26, tonumber(digi[2]) * 26, tonumber(digi[3]) * 26)
	end

	local function generate()
		for i = 1, 512 do
			if MapData.png.done == true then break end
			local index = MapData.pointer + i

			local data	= MapData.decompressed[index] or 0

			local color	= Color(0, 0, 0, 0)
			if data ~= 0 then
				color	= digi2color(data)
			end

			MapData.png:write(color:ToTable())
		end

		if not MapData.png.done and (MapData.pointer < blocksize) then
			MapData.pointer = MapData.pointer + 512
		else
			MapData.pointer = 0

			file.Write(MapData.file, "")
			MapData.openfile = file.Open(MapData.file, "ab", "DATA")

			hook.Remove("Think", "AAS.GeneratePNG")
			hook.Add("Think", "AAS.SavePNG", save)
		end
	end

	AAS.Funcs.GeneratePNG	= function(ScanData)
		if not file.Exists("aas/pngs", "DATA") then
			file.CreateDir("aas/pngs")
		end

		MapData.file	= "aas/pngs/" .. string.lower(game.GetMap()) .. ".png"

		MapData.decompressed	= ScanData
		MapData.png	= encode(res, res, "rgba")

		hook.Add("Think", "AAS.GeneratePNG", generate)
	end

	AAS.ValidMap	= false
	AAS.Funcs.CheckMap		= function()
		AAS.ValidMap = file.Exists("aas/pngs/" .. string.lower(game.GetMap()) .. ".png", "DATA")

		if AAS.ValidMap then
			AAS.MapPNG	= Material("data/aas/pngs/" .. string.lower(game.GetMap()) .. ".png", "")
		else
			-- request map from server
			net.Start("AAS.RequestMapScan")
			net.SendToServer()
		end
	end

	net.Receive("AAS.SendMapScan", function(len)
		local CompressedData	= net.ReadData(len)

		AAS.Funcs.GeneratePNG(util.JSONToTable(util.Decompress(CompressedData), true))
	end)

	hook.Remove("Think", "AAS.GeneratePNG")
	hook.Remove("Think", "AAS.SavePNG")
end