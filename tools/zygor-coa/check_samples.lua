-- For each probe sample, compare the player's position on every map that contains them,
-- using the patched Astrolabe data, and report the spread in yards.
local root, probeFile = arg[1], arg[2]
local function slurp(p) local f=assert(io.open(p,"rb")) local s=f:read("*a") f:close() return s end
local astro = slurp(root.."/Libs/Astrolabe/Astrolabe.lua")
dofile(probeFile)
local probe = CoAMapProbeDB
local names, files = {}, {}
for c, cont in ipairs(probe.continents) do names[c], files[c] = {}, {} for z, r in ipairs(cont.zones) do names[c][z], files[c][z] = r.name, r.mapInfo[1] end end
function GetMapZones(c) return unpack(names[c] or {}) end
ChatFrame1 = { AddMessage = function() end }
dofile(root.."/Libs/Astrolabe/AstrolabeCoAData.lua")
local function block(a1, b1) local a=assert(astro:find(a1,1,true)) local b=assert(astro:find(b1,a,true)) return astro:sub(a,b-1) end
Astrolabe = { ContinentList = {} }
for c = 1, #names do Astrolabe.ContinentList[c] = files[c] end
Astrolabe.ContinentList[5] = { "ScarletEnclave" }
local chunk = assert(loadstring("local sqrt=math.sqrt\n"..block("local function getContPosition","function Astrolabe:TranslateWorldMapPosition")..block("WorldMapSize = {","-- register this library with AstrolabeMapMonitor")))
chunk()
for i, s in ipairs(probe.samples) do
  local cur = s.current
  local line = ("#%d %-16s sub=%-18s current=%s(%d)"):format(i, s.realZone, s.subZone or "", tostring(cur.mapInfo[1]), cur.zone)
  local worst = 0
  local parts = {}
  for _, on in ipairs(s.onMaps) do
    if on.zone > 0 and not (on.zone == cur.zone) then
      local d = Astrolabe:ComputeDistance(cur.continent, cur.zone, cur.pos[1], cur.pos[2], on.continent, on.zone, on.x, on.y)
      parts[#parts+1] = ("%s=%.1fyd"):format(tostring(on.mapInfo[1]), d or -1)
      if d and d > worst then worst = d end
    end
  end
  print(line.."  vs "..(#parts > 0 and table.concat(parts, ", ") or "(only one zone map)"))
end
print("missing zone data:", table.concat(Astrolabe.MissingZoneData, ", "))
