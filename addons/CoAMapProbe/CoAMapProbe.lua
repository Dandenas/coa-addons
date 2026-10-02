-- CoA Map Probe: records how this client numbers and names its world maps,
-- what its native C_Map offers, and where the player sits on every map that
-- contains them. Read-only; restores the map to the player's zone when done.
--   /coaprobe        full dump (map list + a position sample)
--   /coaprobe pos    add one more position sample (take 2-3 in different spots)

local function Shallow(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do
		local tv = type(v)
		if tv == "table" then
			local inner = {}
			for k2, v2 in pairs(v) do
				if type(v2) ~= "function" and type(v2) ~= "userdata" and type(v2) ~= "table" then inner[k2] = v2 end
			end
			out[k] = inner
		elseif tv ~= "function" and tv ~= "userdata" then
			out[k] = v
		end
	end
	return out
end

local function Pack(...) return { n = select("#", ...), ... } end

local function Try(f, ...)
	if type(f) ~= "function" then return nil end
	local r = Pack(pcall(f, ...))
	if not r[1] then return { error = tostring(r[2]) } end
	local out = {}
	for i = 2, r.n do out[i - 1] = Shallow(r[i]) end
	return out
end

local function CurrentMapRecord()
	return {
		continent = GetCurrentMapContinent(),
		zone = GetCurrentMapZone(),
		areaID = GetCurrentMapAreaID and GetCurrentMapAreaID(),
		mapInfo = Pack(GetMapInfo()),
		level = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel(),
		numLevels = GetNumDungeonMapLevels and GetNumDungeonMapLevels(),
	}
end

-- Every map (continent overviews and zones) that currently contains the player.
local function PositionSample()
	local sample = {
		time = date("%H:%M:%S"),
		realZone = GetRealZoneText(), zone = GetZoneText(),
		subZone = GetSubZoneText(), minimapZone = GetMinimapZoneText(),
		onMaps = {},
	}
	SetMapToCurrentZone()
	sample.current = CurrentMapRecord()
	sample.current.pos = Pack(GetPlayerMapPosition("player"))
	if C_Map then
		sample.cmapBest = Try(C_Map.GetBestMapForUnit, "player")
		local best = sample.cmapBest and sample.cmapBest[1]
		if type(best) == "number" then
			sample.cmapPos = Try(C_Map.GetPlayerMapPosition, best, "player")
		end
	end
	if UnitPosition then sample.unitPosition = Try(UnitPosition, "player") end

	local conts = { GetMapContinents() }
	for c = 1, #conts do
		local zones = { GetMapZones(c) }
		for z = 0, #zones do
			SetMapZoom(c, z)
			local x, y = GetPlayerMapPosition("player")
			if x and y and (x > 0 or y > 0) then
				local rec = CurrentMapRecord()
				rec.name = (z == 0) and conts[c] or zones[z]
				rec.x, rec.y = x, y
				table.insert(sample.onMaps, rec)
			end
		end
	end
	SetMapToCurrentZone()
	return sample
end

local function FullDump()
	local db = { version = 1, time = date("%Y-%m-%d %H:%M:%S"), build = Pack(GetBuildInfo()) }

	-- What the native C_Map table offers.
	db.cmapType = type(C_Map)
	if type(C_Map) == "table" then
		db.cmapKeys = {}
		for k, v in pairs(C_Map) do db.cmapKeys[tostring(k)] = type(v) end
	end
	db.hasUnitPosition = UnitPosition ~= nil
	db.hasGetCurrentMapAreaID = GetCurrentMapAreaID ~= nil

	-- Every continent and zone the client lists.
	db.continents = {}
	local conts = { GetMapContinents() }
	for c = 1, #conts do
		local cont = { index = c, name = conts[c], zones = {} }
		SetMapZoom(c, 0)
		cont.map = CurrentMapRecord()
		local zones = { GetMapZones(c) }
		for z = 1, #zones do
			SetMapZoom(c, z)
			local rec = CurrentMapRecord()
			rec.index, rec.name = z, zones[z]
			if C_Map and rec.areaID then
				rec.cmapInfo = Try(C_Map.GetMapInfo, rec.areaID)
				rec.cmapWorldTL = Try(C_Map.GetWorldPosFromMapPos, rec.areaID, { x = 0, y = 0 })
				rec.cmapWorldBR = Try(C_Map.GetWorldPosFromMapPos, rec.areaID, { x = 1, y = 1 })
				rec.cmapParent = Try(C_Map.GetMapParentInfo, rec.areaID)
			end
			cont.zones[z] = rec
		end
		db.continents[c] = cont
	end
	SetMapToCurrentZone()

	db.samples = { PositionSample() }
	CoAMapProbeDB = db
	print(("|cff88ccffCoA Map Probe|r: %d continents recorded, sample 1 taken in %s. Use |cffffff00/coaprobe pos|r in 1-2 other spots, then /reload or log out to save."):format(#conts, GetRealZoneText() or "?"))
end

SLASH_COAMAPPROBE1 = "/coaprobe"
SlashCmdList.COAMAPPROBE = function(msg)
	if WorldMapFrame and WorldMapFrame:IsShown() then
		print("|cff88ccffCoA Map Probe|r: close the world map first.")
		return
	end
	msg = (msg or ""):lower()
	if msg == "pos" then
		if type(CoAMapProbeDB) ~= "table" or not CoAMapProbeDB.samples then
			print("|cff88ccffCoA Map Probe|r: run /coaprobe first.")
			return
		end
		table.insert(CoAMapProbeDB.samples, PositionSample())
		print(("|cff88ccffCoA Map Probe|r: sample %d taken in %s / %s."):format(#CoAMapProbeDB.samples, GetRealZoneText() or "?", GetSubZoneText() or ""))
	else
		FullDump()
	end
end
