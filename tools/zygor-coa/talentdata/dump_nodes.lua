-- Dump CoA's tree-node table (ID -> name, class, tab, spells) as tab-separated lines.
dofile(arg[1])
local out = io.open(arg[2], "w")
local count = 0
local function walk(t, depth)
  if depth > 6 or type(t) ~= "table" then return end
  if t.ID and t.Name and t.Spells then
    local sp = {}
    for _, s in ipairs(t.Spells) do sp[#sp + 1] = tostring(s) end
    out:write(("%d\t%s\t%s\t%s\t%s\t%s\n"):format(t.ID, t.Name, tostring(t.Class), tostring(t.Tab), table.concat(sp, ","), tostring(t.NodeType)))
    count = count + 1
    return
  end
  for _, v in pairs(t) do walk(v, depth + 1) end
end
for k, v in pairs(_G) do if type(k) == "string" and k:match("^ASCENSION_LOCAL_COA") and type(v) == "table" then walk(v, 0) end end
out:close()
print("nodes", count)
