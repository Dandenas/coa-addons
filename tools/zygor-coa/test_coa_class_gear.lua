-- Regression for Conquest of Azeroth class support in the Gear Advisor.
-- Usage: lua test_coa_class_gear.lua <addon directory>
local root = arg[1] or "ZygorGuidesViewerRM"
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

---------------------------------------------------------------------------
-- 1. CoA-ClassSpecs.lua turns the CUSTOM builds into the class's specs.
---------------------------------------------------------------------------
local function LoadSpecs(token, className, primaryStatName)
	ZygorGuidesViewer = { ItemScore = {}, SpecByNumber = { CUSTOM = { "Custom Spec 1", "Custom Spec 2", "Custom Spec 3" } } }
	local IS = ZygorGuidesViewer.ItemScore
	IS.rules = { WARRIOR = { [1] = {} }, CUSTOM = { [1] = { name = "Custom Spec 1" } } }
	IS.RuleSources = { CUSTOM = {} }
	UnitClass = function() return className, token end
	C_PrimaryStat = primaryStatName and {
		GetActivePrimaryStat = function(self) return 7 end,
		GetPrimaryStatInfo = function(self, id) assert(id == 7) return 1, 2, 3, primaryStatName end,
	} or nil
	dofile(root.."/Data-WOTLK/CoA-ClassSpecs.lua")
	return IS
end

local IS = LoadSpecs("CHRONOMANCER", "Chronomancer", "Spirit")
assert(IS.CoAClass and IS.CoAClass.name == "Chronomancer", "Chronomancer not recognised")
local r = IS.rules.CUSTOM
assert(#r == 3 and r[1].name == "Infinite" and r[2].name == "Time" and r[3].name == "Artificer", "specs not applied")
assert(r[1].stats.SPIRIT == 1 and r[1].stats.SPELL_POWER == 0.8 and r[1].stats.HIT == 0.7, "caster weights not mapped")
assert(r[2].stats.MANA_REGENERATION == 0.5, "Mp5 not mapped to MANA_REGENERATION")
assert(r[3].stats.RANGED_ATTACK_POWER == 0.5 and r[3].stats.DAMAGE_PER_SECOND == 3, "ranged spec lacks weapon DPS")
assert(r[1].stats.DAMAGE_PER_SECOND == nil, "caster spec should not value weapon DPS")
assert(r[1].stats.STAMINA == 0.001, "stamina tie-breaker missing")
assert(r[1].itemtypes.JEWELERY == 1 and r[1].itemtypes.PLATE == 1, "item types not permissive")
assert(ZygorGuidesViewer.SpecByNumber.CUSTOM[2] == "Time", "spec names not published")
for _, rule in ipairs(r) do for k in pairs(rule.stats) do assert(k:match("^[A-Z_]+$"), "unmapped stat key "..k) end end
assert(IS:GetCoADefaultBuild() == 1, "Spirit Chronomancer should start on Infinite")
assert(IS:GetCoARoleBuild("heal") == 2, "healer role should pick Time")
assert(IS:GetCoARoleBuild("tank") == nil, "Chronomancer has no tank spec")
assert(IS:GetCoARoleBuild("dps") == 1, "dps role should prefer the primary-stat spec")

-- Primary stat picks the matching spec (Witch Doctor: Agility / Intellect / Spirit).
IS = LoadSpecs("WITCHDOCTOR", "Witch Doctor", "Intellect")
assert(IS.rules.CUSTOM[IS:GetCoADefaultBuild()].name == "Voodoo", "Intellect Witch Doctor should start on Voodoo")
assert(IS:GetCoARoleBuild("heal") == 3, "Witch Doctor healer should be Brewing")
-- Four-spec class keeps all four.
IS = LoadSpecs("WITCHHUNTER", "Witch Hunter", nil)
assert(#IS.rules.CUSTOM == 4 and IS.rules.CUSTOM[4].name == "Black Knight", "fourth spec dropped")
assert(IS:GetCoADefaultBuild() == 1, "no primary stat chosen should fall back to the first spec")
assert(IS:GetCoARoleBuild("tank") == 4, "Witch Hunter tank should be Black Knight")
-- Stock classes are untouched.
IS = LoadSpecs("WARRIOR", "Warrior", nil)
assert(IS.CoAClass == nil and IS.rules.CUSTOM[1].name == "Custom Spec 1", "stock class must keep the generic CUSTOM builds")

---------------------------------------------------------------------------
-- 2. Armor/weapon usability for unknown classes comes from the character's skills.
---------------------------------------------------------------------------
local src = slurp(root.."/Item-ItemScore.lua")
local a = assert(src:find("local ARMOR_FAMILY_ORDER", 1, true), "ARMOR_FAMILY_ORDER not found")
local b = assert(src:find("local function get_item_slot_info", a, true))
local chunk = assert(loadstring("local ItemScore = ...\n"..src:sub(a, b - 1).."\nreturn class_can_use_standard_family"))
local skillsIS = { SkillNames = {}, Skills = {} }
for _, tag in ipairs({ "CLOTH", "LEATHER", "MAIL", "PLATE", "SHIELD", "MACE", "TH_STAFF", "DAGGER", "WAND", "SWORD", "TH_SWORD", "BOW" }) do
	skillsIS.SkillNames[tag] = tag
end
local canUse = chunk(skillsIS)
assert(canUse("CUSTOM", "CLOTH", 20) == nil, "unread skill list must stay undecided")
-- Alorann's skills from the saved variables: Cloth, Maces, Staves, Daggers, Wands.
skillsIS.Skills = { CLOTH = 1, MACE = 55, TH_STAFF = 55, DAGGER = 55, WAND = 55 }
assert(canUse("CUSTOM", "CLOTH", 20) == true, "cloth should be usable")
assert(canUse("CUSTOM", "LEATHER", 20) == false, "leather is not a known skill")
assert(canUse("CUSTOM", "PLATE", 50) == false, "plate is not a known skill")
assert(canUse("CUSTOM", "TH_STAFF", 20) == true and canUse("CUSTOM", "SWORD", 20) == false, "weapon skills not honoured")
assert(canUse("CUSTOM", "JEWELERY", 20) == nil, "non-skill families stay undecided")
-- Stock classes keep the class tables.
assert(canUse("WARRIOR", "PLATE", 50) == true and canUse("MAGE", "LEATHER", 50) == false, "stock class rules changed")

---------------------------------------------------------------------------
-- 3. Weapon DPS weights survive Initialise's DPS -> DAMAGE_PER_SECOND rename.
---------------------------------------------------------------------------
assert(src:find("if stats.DPS ~= nil then stats.DAMAGE_PER_SECOND = stats.DPS stats.DPS = nil end", 1, true),
	"DPS rename still overwrites DAMAGE_PER_SECOND")

print("CoA class Gear Advisor regression passed")
