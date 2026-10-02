dofile(arg[1])
local t = ASCENSION_LOCAL_COA_TALENT_TAB_ALIASES or {}
for class, map in pairs(t) do for from, to in pairs(map) do print(class .. "\t" .. from .. "\t" .. to) end end
