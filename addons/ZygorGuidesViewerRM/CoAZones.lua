-- Conquest of Azeroth zone support.
--
-- CoA split starting areas, caves and mines off into maps and top-level areas of their own,
-- so the client reports "Northshire Valley" or "Sunstrider Isle" as the zone where the guides
-- (written for the stock client) say "Elwynn Forest" or "Eversong Woods". Its native C_Map
-- also numbers maps with its own IDs rather than the ones LibRover's data uses.
--
-- This file folds those sub-maps back into their parent zone for the guide engine and gives
-- LibRover a player position in its own map IDs. The parent table (ZygorCoAZoneParents) and
-- the sub-map sizes come from Libs\Astrolabe\AstrolabeCoAData.lua. On other clients nothing
-- here resolves and every caller keeps its stock behaviour.

local ZGV = ZygorGuidesViewer
if not ZGV then return end

local Astrolabe = DongleStub and select(2, pcall(DongleStub, "Astrolabe-0.4-Zygor"))
if type(Astrolabe) ~= "table" then Astrolabe = nil end

local parentZoneName  -- [sub-map zone name] = parent zone name
local parentIndex     -- [continent][zone index] = parent zone index

local function Build()
	parentZoneName, parentIndex = {}, {}
	local parents = ZygorCoAZoneParents
	if not (parents and Astrolabe and Astrolabe.ContinentList) then return end
	for c = 1, 4 do
		local files, coa = Astrolabe.ContinentList[c], parents[c]
		if type(files) == "table" and coa then
			local names = { GetMapZones(c) }
			local byFile = {}
			for z, f in ipairs(files) do
				if type(f) == "string" then byFile[f:lower()] = z end
			end
			for z, f in ipairs(files) do
				local parentFile = type(f) == "string" and coa[f:lower()]
				local pz = parentFile and byFile[parentFile]
				if pz then
					parentIndex[c] = parentIndex[c] or {}
					parentIndex[c][z] = pz
					if names[z] and names[pz] then parentZoneName[names[z]] = names[pz] end
				end
			end
		end
	end
end

-- True on a client whose map list needed the CoA data (see Astrolabe.lua).
function ZGV.IsCoAClient()
	return Astrolabe and Astrolabe.UsesCoAZoneData and true or false
end

-- Parent zone of a CoA sub-map zone name, or nil when the name is an ordinary zone.
function ZGV.GetCoAParentZone(zoneName)
	if not zoneName then return nil end
	if not parentZoneName then Build() end
	return parentZoneName[zoneName]
end

-- GetRealZoneText(), with CoA sub-maps folded into the zone the guides use.
function ZGV.GetPlayerZoneText()
	local zone = GetRealZoneText()
	return ZGV.GetCoAParentZone(zone) or zone
end

-- Player position in LibRover's map IDs, for CoA clients whose C_Map uses other IDs.
-- Returns nil when not on such a client (callers keep using C_Map), false when the
-- position cannot be placed on a known zone, or mapID, x, y (0-1).
function ZGV.GetCoAPlayerMapPosition()
	if not ZGV.IsCoAClient() then return nil end
	local c, z, x, y = Astrolabe:GetCurrentPlayerPosition()
	if not (c and z and x and y) or c < 1 or c > 4 or z == 0 then return false end
	if not parentIndex then Build() end
	local pz = parentIndex[c] and parentIndex[c][z]
	if pz then
		local px, py = Astrolabe:TranslateWorldMapPosition(c, z, x, y, c, pz)
		if not px then return false end
		x, y, z = px, py, pz
	end
	local name = select(z, GetMapZones(c))
	local byName = LibRover and LibRover.data and LibRover.data.MapIDsByName
	if not (name and byName) then return false end
	local ids = byName[name] or (ZGV.BZR and ZGV.BZR[name] and byName[ZGV.BZR[name]])
	local mapID = ids and ids[0]
	if not mapID then return false end
	return mapID, x, y
end
