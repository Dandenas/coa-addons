-- "Load build": puts the panel's build into the CoA talent window as unsaved changes, to be
-- reviewed there and then saved (Save Changes) or undone. It never saves anything itself.
--
-- The build becomes a CoA build link (":<node>t<rank>:...", the format of the in-game Import Build
-- box and of Ascension Sidekick's build codes) for C_CharacterAdvancement.ImportPendingBuild, which
-- checks the whole build and changes nothing when it doesn't fit. The builds go to level 60, so the
-- link is trimmed to the talent points the character has: both trees are cut back together, each
-- keeping the start of its own order, until the game accepts the link, and then each tree is
-- topped up with further picks while they still fit (the trees have separate point pools).
-- Trimming one tree on its own doesn't work: talents the game grants by itself depend on picks in
-- both (Time's Aeon of Resilience needs the class talent Accelerated Recovery).
-- Ascension Sidekick's per-pick levels are not used here: they are not learning requirements and
-- don't follow the build's order (Time's spec root Ripple is marked 48 but is its first pick), so
-- filtering by them leaves talents without the talent they hang from. Only the talents the game
-- grants automatically are limited to their grant level.
-- A build for another spec first switches the window to that spec, unsaved, as picking it in the
-- window does; if nothing can be loaded that switch is undone.

local ZTAC = ZygorTalentAdvisorCOA
if not ZTAC then return end

local PREFIX = "|cffffbb00Zygor CoA Talent Advisor:|r "

local function API() return C_CharacterAdvancement end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
end

local function Say(text) print(PREFIX .. text) end

-- One tree's picks in the build's order, and the talents the game grants automatically that the
-- character has reached the grant level (rl) of.
local function Picks(path, level)
	local picks, auto = {}, {}
	for _, pick in ipairs(path or {}) do
		if not pick.auto then
			picks[#picks + 1] = pick
		elseif (pick.rl or 1) <= level then
			auto[#auto + 1] = pick
		end
	end
	return picks, auto
end

-- Both trees cut back together: step k keeps the first c class and s spec picks with c + s = k,
-- shared in proportion to the trees' sizes, so neither tree is ever dropped entirely.
local function Timeline(classCount, specCount)
	local total, counts = classCount + specCount, {}
	for k = 1, total do
		local c = math.floor(k * classCount / total + 0.5)
		counts[k] = { c, k - c }
	end
	return counts
end

local function CountPicks(build)
	local n = 0
	for _, path in ipairs({ build.classPath or {}, build.specPath or {} }) do
		for _, pick in ipairs(path) do if not pick.auto then n = n + 1 end end
	end
	return n
end

-- A build link from the first `count` picks of each part: one token per node at the highest rank
-- asked for, sorted by node ID like the links Ascension Sidekick makes. nil when empty.
function ZTAC:MakeBuildLink(parts)
	local rank, nodes = {}, {}
	for _, part in ipairs(parts) do
		for i = 1, part.count or #part.picks do
			local pick = part.picks[i]
			local r = pick.rank or 1
			if not rank[pick.node] then nodes[#nodes + 1] = pick.node end
			if (rank[pick.node] or 0) < r then rank[pick.node] = r end
		end
	end
	if #nodes == 0 then return nil end
	table.sort(nodes)
	local tokens = {}
	for i, node in ipairs(nodes) do tokens[i] = node .. "t" .. rank[node] end
	return ":" .. table.concat(tokens, ":") .. ":"
end

-- The game's refusal as text, worded like its own Import Build box.
local function Reason(refusal)
	if not refusal or not refusal.reason then return "the game gave no reason." end
	local text = _G[refusal.reason] or refusal.reason
	local name = refusal.id
	local entry = refusal.id and Call(API().GetEntryByInternalID, refusal.id)
	if type(entry) == "table" and entry.Name then name = entry.Name end
	local ok, formatted = pcall(string.format, text, name or "", refusal.rank or "")
	text = ok and formatted or text
	if refusal.id and not tostring(text):find(tostring(name), 1, true) then
		text = text .. " (" .. tostring(name) .. ")"
	end
	return text
end

function ZTAC:LoadBuild()
	local api = API()
	if not (self:IsActive() and api and type(api.ImportPendingBuild) == "function") then
		Say("this client can't load builds into the talent window.")
		return false
	end
	local cls = self:GetClassData()
	local spec = self:GetSelectedSpec()
	local build = cls and spec and cls.specs[spec]
	if not build then return false end
	local level = UnitLevel("player") or 1
	local classPicks, classAuto = Picks(build.classPath, level)
	local specPicks, specAuto = Picks(build.specPath, level)
	local autos = {}
	for _, list in ipairs({ classAuto, specAuto }) do for _, pick in ipairs(list) do autos[#autos + 1] = pick end end
	if #classPicks + #specPicks == 0 then
		Say("the " .. spec .. " build has no picks to load.")
		return false
	end

	self.loading = true -- no panel/tree refreshes for every attempt; one at the end

	-- A build for another spec: switch the window to it first (unsaved).
	local switched
	local target = self:GetSpecIDFor(spec)
	if target and Call(api.GetActiveChrSpec) ~= target then
		local frame = _G.CoATalentFrame
		if frame and type(frame.ChangeSpecID) == "function" then
			pcall(frame.ChangeSpecID, frame, target) -- also lets the window redraw for the new spec
		else
			Call(api.SwitchActiveChrSpec, target)
		end
		switched = true
	end

	-- One attempt: the first c class and s spec picks. The spec's automatic talents normally come
	-- from the window's current build; after a switch they may be missing, so a refused link is
	-- tried once more with them included.
	-- Every attempt is recorded for /ztacoa debug.
	local log = { spec = spec, level = level, switched = switched, attempts = {} }
	self.lastLoad = log
	local refusal
	local function Try(c, s)
		local parts = { { picks = classPicks, count = c }, { picks = specPicks, count = s } }
		for attempt = 1, (#autos > 0 and 2 or 1) do
			if attempt == 2 then parts[3] = { picks = autos } end
			local link = self:MakeBuildLink(parts)
			if link then
				local ok, accepted, reason, id, rank = pcall(api.ImportPendingBuild, link)
				local entry = { c = c, s = s, auto = attempt == 2, ok = ok and accepted and true or false }
				log.attempts[#log.attempts + 1] = entry
				if entry.ok then return true end
				refusal = ok and { reason = reason, id = id, rank = rank } or { reason = tostring(accepted) }
				entry.refusal = refusal
			end
		end
		return false
	end

	-- The most of both trees together that fits...
	local c, s, loaded = 0, 0, false
	local timeline = Timeline(#classPicks, #specPicks)
	for k = #timeline, 1, -1 do
		if Try(timeline[k][1], timeline[k][2]) then
			c, s, loaded = timeline[k][1], timeline[k][2], true
			break
		end
	end
	-- ...then each tree topped up while its next pick still fits. The last accepted attempt is what
	-- the window holds, so the counts always match it.
	if loaded then
		while c < #classPicks and Try(c + 1, s) do c = c + 1 end
		while s < #specPicks and Try(c, s + 1) do s = s + 1 end
	end
	log.loaded, log.c, log.s = loaded, c, s

	if not loaded and switched then Call(api.CancelPendingBuild) end -- back to where it was
	self.loading = nil
	self:Refresh()

	if not loaded then
		Say("|cffff4040couldn't load the " .. spec .. " build:|r " .. Reason(refusal))
		return false
	end
	local available = #classPicks + #specPicks
	local msg = ("loaded %d of the %s build's %d picks (level %d)"):format(c + s, spec, CountPicks(build), level)
	if c + s < available then
		msg = msg .. (", the other %d need more talent points"):format(available - (c + s))
	end
	Say(msg .. ". Review the talent window, then |cff5fb85fSave Changes|r or Undo.")
	return true, c + s
end

-- The last load, for troubleshooting (/ztacoa debug): what was tried and what the game said.
function ZTAC:DescribeLastLoad()
	local log = self.lastLoad
	if not log then return { "no build loaded yet this session" } end
	local lines = {}
	local accepted = 0
	for _, a in ipairs(log.attempts) do if a.ok then accepted = accepted + 1 end end
	lines[1] = ("last load: %s at level %d%s - %d attempts, %d accepted, %s"):format(log.spec, log.level,
		log.switched and " (switched spec)" or "", #log.attempts, accepted,
		log.loaded and ("ended with %d class + %d spec picks"):format(log.c, log.s) or "nothing loaded")
	local first, last
	for _, a in ipairs(log.attempts) do
		if a.refusal then first = first or a; last = a end
	end
	local function Line(label, a)
		return ("%s %d class + %d spec%s: %s %s"):format(label, a.c, a.s, a.auto and " + automatic" or "",
			tostring(a.refusal.reason), a.refusal.id and ("(entry " .. tostring(a.refusal.id) .. " rank " .. tostring(a.refusal.rank) .. ")") or "")
	end
	if first then lines[#lines + 1] = Line("first refused:", first) end
	if last and last ~= first then lines[#lines + 1] = Line("last refused:", last) end
	return lines
end

StaticPopupDialogs["ZYGORTALENTADVISORCOA_LOAD_BUILD"] = {
	text = "%s",
	button1 = "Load",
	button2 = CANCEL or "Cancel",
	OnAccept = function() ZTAC:LoadBuild() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

-- Asks first; the talent window has to be open so the result can be reviewed there.
function ZTAC:ConfirmLoadBuild()
	if not self:IsActive() then return end
	local frame = _G.CoATalentFrame
	if not (frame and frame:IsShown()) then
		Say("open the talent window first, so you can review the build before saving it.")
		return
	end
	local spec = self:GetSelectedSpec()
	if not spec then return end
	local text = ("Load the %s leveling build into the talent window?\n\nNothing is saved until you press Save Changes. Talents you have that aren't in the build will show as removed."):format(spec)
	if Call(API().IsPending) then
		text = text .. "\n\n|cffff4040Your unsaved changes in the talent window will be replaced.|r"
	end
	StaticPopup_Show("ZYGORTALENTADVISORCOA_LOAD_BUILD", text)
end
