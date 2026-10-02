local function load(path) WorldMapSize=nil dofile(path) return WorldMapSize end
local A = load(arg[1]) ; local B = load(arg[2])
for c = 0, 5 do
  local a, b = A[c], B[c]
  if a and b then
    local d = 0
    for _, k in ipairs({"width","height","xOffset","yOffset"}) do d = math.max(d, math.abs((a[k] or 0)-(b[k] or 0))) end
    local same, diff, onlyB = 0, {}, {}
    for name, z in pairs(b.zoneData or {}) do
      local o = a.zoneData and a.zoneData[name]
      if o then
        local m = 0 for _, k in ipairs({"width","height","xOffset","yOffset"}) do m = math.max(m, math.abs(o[k]-z[k])) end
        if m < 0.5 then same = same + 1 else diff[#diff+1] = name..string.format("(%.0f)", m) end
      else onlyB[#onlyB+1] = name end
    end
    print(("cont %d: continent diff %.2f | zones same %d, differ %d %s | only in Zygor: %s"):format(c, d, same, #diff, table.concat(diff, " "), table.concat(onlyB, " ")))
  else print("cont", c, a and "tomtom" or "-", b and "zygor" or "-") end
end
