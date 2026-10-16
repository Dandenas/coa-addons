-- Regression for the Gear Advisor on Conquest of Azeroth.
-- 1. Item-Upgrades.lua: the upgrade popup holds a secure Equip button, so hiding it in combat was blocked
--    ("AddOn 'ZygorGuidesViewerRM' prevented the call of the secure function 'ZygorItemPopup:Hide()'"). In combat
--    it now stays up and is hidden when combat ends.
-- 2. Item-ItemScore.lua: ZygorItemDB is a stock AzerothCore export, so on CoA every custom item was reported as
--    "equippable item IDs not present in database". Ascension/CoA clients don't get that warning.
-- Usage: lua test_zygor_gear_coa.lua <ZygorGuidesViewerRM directory>
local root = arg[1] or "ZygorGuidesViewerRM"

local Stub = setmetatable({}, {})
getmetatable(Stub).__index = function() return Stub end
getmetatable(Stub).__call = function() return Stub end

-- Loads one of the addon's files in a fresh environment; everything not given resolves to a do-nothing stub.
local function Load(file, globals)
	local env = setmetatable({}, { __index = function(_, k)
		if globals[k] ~= nil then return globals[k] end
		if _G[k] ~= nil then return _G[k] end
		return Stub
	end })
	env._G = env
	local chunk = assert(loadfile(root .. "/" .. file))
	setfenv(chunk, env)
	local ok, err = pcall(chunk, "ZygorGuidesViewerRM", {})
	assert(ok, file .. " loads: " .. tostring(err))
	return env
end

---------------------------------------------------------------------------
-- 1. The popup is hidden only out of combat; in combat the hide waits.
---------------------------------------------------------------------------
do
	local ItemScore = {}
	local ZGV = setmetatable({ ItemScore = ItemScore }, { __index = function() return Stub end })
	local inCombat = false
	Load("Item-Upgrades.lua", { ZygorGuidesViewer = ZGV, InCombatLockdown = function() return inCombat end })
	local Upgrades = ItemScore.Upgrades
	assert(Upgrades and Upgrades.HideEquipPopup, "Item-Upgrades.lua defines Upgrades:HideEquipPopup")
	local hides = 0
	Upgrades.EquipPopup = { Hide = function() hides = hides + 1 end }

	inCombat = true
	Upgrades:HideEquipPopup()
	assert(hides == 0, "the protected popup is not hidden during combat")
	assert(Upgrades.EquipPopup.hideAfterCombat, "the hide is remembered for after combat")
	inCombat = false
	Upgrades:HideEquipPopup()
	assert(hides == 1 and not Upgrades.EquipPopup.hideAfterCombat, "out of combat the popup is hidden")

	-- every place that closed the popup goes through the helper (direct :Hide() calls were blocked in combat)
	local src = assert(io.open(root .. "/Item-Upgrades.lua")):read("*a")
	local _, directHides = src:gsub("\n%s*F:Hide%(%)", "")
	assert(not src:find("EquipPopup:Hide%(%)") and directHides == 1, "no direct popup hides remain outside the helper")
	assert(src:find('F.declinebutton:SetScript%("OnClick"'), "the decline button no longer uses the generic hide")
	local score = assert(io.open(root .. "/Item-ItemScore.lua")):read("*a")
	local regen = score:match('event == "PLAYER_REGEN_ENABLED" then(.-)elseif')
	assert(regen and regen:find("hideAfterCombat", 1, true), "combat end performs the pending hide")
	assert(not score:find("EquipPopup:Hide%(%)"), "combat start goes through the helper too")
end

---------------------------------------------------------------------------
-- 2. A custom CoA item that isn't in ZygorItemDB is not reported on the Ascension client.
---------------------------------------------------------------------------
local function MissingWarnings(ascensionClient)
	local ItemScore = {}
	local printed = {}
	local ZGV = setmetatable({ ItemScore = ItemScore, ItemLink = { GetItemID = function(link) return tonumber(link:match("item:(%d+)")) end },
		GetItemInfo = function() return nil end,                 -- not cached yet: the case that warns
		Print = function(_, msg) printed[#printed + 1] = msg end,
		ScheduleTimer = function(_, f) f() end },
		{ __index = function() return Stub end })
	local env = Load("Item-ItemScore.lua", {
		ZygorGuidesViewer = ZGV,
		ZygorItemDB = { items = {} },
		C_CharacterAdvancement = ascensionClient and {} or false,   -- false, not nil: unknown globals resolve to a stub
		GetItemInfo = function() return "Balanced Spell Staff", nil, 2, 13, 0, "Weapon", "Staves", 1, "INVTYPE_2HWEAPON" end,
		LibStub = function() return setmetatable({ SetHyperlink = function() end }, { __index = function() return Stub end }) end,
	})
	assert(ItemScore.GetItemDetailsQueued, "Item-ItemScore.lua defines ItemScore:GetItemDetailsQueued")
	local okq, errq = pcall(ItemScore.GetItemDetailsQueued, ItemScore, "item:60219:0:0:0:0:0:0:0")
	if not okq then print("GetItemDetailsQueued: " .. tostring(errq)) end
	return ItemScore.DBStats.missing or 0, printed
end
local missing, printed = MissingWarnings(false)
assert(missing == 1 and printed[1] and printed[1]:find("60219"), "a stock client still reports an item missing from the DB")
missing, printed = MissingWarnings(true)
assert(missing == 0 and #printed == 0, "the CoA client does not report custom items missing from the stock DB")

print("Gear Advisor CoA regression passed (popup combat hide, missing-item warning)")
