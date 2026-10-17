# Zygor / TomTom / HealBot for Conquest of Azeroth

Changes that make **ZygorGuidesViewerRM** (Zygor Guides Viewer Remaster 3.3.5a), **TomTom** and **HealBot** (3.3.5.4) work on the Conquest of Azeroth (Ascension-based) client, plus the tools to re-apply and test them.

## After updating Zygor, TomTom or HealBot

1. Close the game and install the new addon version as usual.
2. Run **`Apply-ZygorCoA.bat`**. It re-applies every change, saves the files it changes in `<addon>\_CoA_backup_<date-time>\`, and runs the tests.
   - `Apply-ZygorCoA.bat --dry-run` only reports what it would do.
   - Running it twice is harmless: anything already applied is skipped.
3. Fully restart the game (not `/reload`).

If it says a change **"no longer fits"**, the addon's author changed code that edit depends on. Nothing is written in that case. The kit needs updating for the new version: adjust the patched install by hand, then run `kit\make_kit.py`.

## What the changes do

| Problem on CoA | Fix | Files |
|---|---|---|
| ~50 extra maps (starting areas, caves, CoA zones) had no size data in Zygor's Astrolabe, so the arrow had nothing to aim with | Sizes from the client's own `WorldMapArea.dbc`, and case-insensitive names | Zygor: `Libs/Astrolabe/AstrolabeCoAData.lua`, `Astrolabe.lua` |
| The client ships its own `Astrolabe-0.4` (Interface\LibraryXML, version = infinity) that numbers zones by **area ID** (Sunstrider Isle = 1241). It replaces TomTom's copy, so 2010 TomTom mixed area IDs with zone indexes | TomTom translates between the two (`TomTom:ZoneID`, `TomTom:CurrentCZ`). Zygor's copy is registered separately and unaffected, but its `GetCurrentMapContinentAndZone()` also accepts an area ID defensively | `TomTom.lua`, `TomTom_Corpse.lua`, `TomTom_POIIntegration.lua`; Zygor `Astrolabe.lua` |
| Starting areas and caves report as their own zone ("Northshire Valley" instead of "Elwynn Forest"), so "go to" steps never completed and local steps were treated as travel | Fold them into the parent zone (parents from the stock `AreaTable.dbc`) | `CoAZones.lua`, one line in Waypoints/Goal/Pointer/MapSpotSet/Parser |
| Route planner got CoA's native `C_Map` IDs instead of its own | Position from Zygor's own map data | `LibRover-1.0.lua`, `MapCoords.lua` |
| Gear Advisor rejected all armor for CoA classes and used generic weights | CoA class specs (from Kui_Nameplates' coa-db data); usability from the character's skills | `Data-WOTLK/CoA-ClassSpecs.lua`, `Item-ItemScore.lua` |
| Weapon DPS weights erased for every class (upstream bug) | Rename only when the short key is used | `Item-ItemScore.lua` |
| "prevented the call of the secure function 'ZygorItemPopup:Hide()'" (upstream bug): the gear popup's secure Equip button makes it protected, but it was hidden in combat (combat start, bag scans, Equip/Decline clicks) | `Upgrades:HideEquipPopup()` defers the hide until `PLAYER_REGEN_ENABLED`; the decline button no longer uses the generic popup's direct hide | `Item-Upgrades.lua`, `Item-ItemScore.lua` |
| "equippable item IDs not present in database" for CoA's custom gear (ZygorItemDB is a stock AzerothCore export; CoA has ~437k custom equippable entries) | No warning when `C_CharacterAdvancement` exists; live stats from GetItemStats/tooltip are used for scoring anyway | `Item-ItemScore.lua` |
| 49 "Error loading" lines at startup | Drop empty `GuideNN` / `buildNN` placeholder entries | `Guides/Autoload.xml`, `ZygorTalentAdvisor/Builds/Autoload.xml` |
| TomTom crashed on right-click in CoA zones (area ID looked up as a zone index) | Area-ID lookups above, plus a guard against a missing map name | `TomTom.lua` |
| Button Forge never finished starting up (`ButtonForgeSave` nil, errors from every bar/config button): its companion cache aborted on the first nameless companion, and Ascension's collections have some (21 of 861 mounts) | Skip nameless companions; still wait for a retry while most names are missing (data not loaded yet) | Button Forge: `Util.lua` (original in `ButtonForge\_CoA_original\`) |
| Questie-X (v1.6.4) and its Ascension plugin recognised Ascension only by **realm name** (Area 52, Bronzebeard, …), so CoA realms named anything else (Nozdormu, Felstorm) got neither the Ascension data nor its zone handling | The Ascension client's own API (`C_CharacterAdvancement`) counts too; stock 3.3.5 clients are unaffected. Also needs `Questie-X-WotLKDB` (install the folder under that exact name) | Questie-X: `Modules/QuestieServer.lua`, `Compat/Compat.lua`; Questie-X-AscensionDB: `AscensionLoader.lua`, `Zones/AscensionUiMapData.lua`, `Zones/AscensionZoneTables.lua` (originals in each addon's `_CoA_original\`) |
| Questie-X upstream bugs (all servers): stale map pins after objective/turn-in; tracker frozen at 0 until `/reload` after Questie rebuilt a quest copy; "Runtime mode: Learner" forced because plugin-supplied base tables counted as missing; same-name quest chains resolving the turned-in quest to its follow-up; "attempt to call field 'QueryNPC' (a table value)" at login while the database is built; "attempt to compare number with table" for kill-credit objectives with nested NPC id lists; a stutter every second from the quest arrow re-converting and sorting every objective spawn | Recycled pin frames get their global name back; the tracker re-links to the current quest copy (old pins removed first); plugin overrides count as a present base table; title lookups at turn-in only match a complete quest; the DB lookups are published only once all four are built; kill-credit id lists are flattened to numbers; the arrow remembers spawn world positions and keeps only the nearest 3 targets, and the player position is cached for 0.1 s | Questie-X: `Modules/FramePool/QuestieFramePool.lua`, `Modules/Quest/QuestieQuest.lua`, `Modules/QuestieInit.lua`, `Compat/Compat.lua`, `Database/QuestieDB.lua`, `Modules/QuestieLearner.lua`, `Modules/Quest/QuestieQuestPrivates.lua`, `Modules/Arrow/QuestieArrow.lua`, `Compat/HBD.lua` |
| AzerothAdmin (GM panel) quality of life: the main window re-centred every session, there was no lock, no scale setting and no color presets | One new file hooks `AzerothAdmin:CreateFrames`: drag by the top bar, position saved (centre offset, survives scale changes), Lock / Reset position, Window Scale 50–150%, color presets plus a "My colors" slot on the Misc page (presets fill the swatches; Update Changes applies) | AzerothAdmin: `Modules/CoAQoL.lua` (new), `AzerothAdmin.toc` (original in `AzerothAdmin\_CoA_original\`) |
| HealBot keys its class tables by the class's first four letters; CoA classes (Chronomancer = `CHRO`, ...) are in none, so it failed at login and on CoA party members (class colours, ignored class debuffs) | CoA classes get the Warrior's HoT-watch defaults, the client's own `RAID_CLASS_COLORS`, and empty buff / cure-spell / ignored-debuff lists. CoA heal spells themselves are not known to HealBot | HealBot: `HealBot.lua`, `HealBot_Action.lua`, `HealBot_Options.lua` (originals in `HealBot\_CoA_original\`) |

## Files here

- `Apply-ZygorCoA.bat`, `kit\apply_coa_patch.py`: re-apply the changes.
- `kit\hunks.json`, `kit\files\`: the changes themselves. Regenerate them with `kit\make_kit.py` from the clean download and the patched install.
- `test_*.lua`, `fixtures\`: regression tests, using real position samples from the client (Sunstrider Isle and Human start area). `test_healbot_coa.lua`, `test_buttonforge_coa.lua`, `test_questie_coa.lua`, `test_zygor_gear_coa.lua` and `test_azerothadmin_coa.lua` load those addons' own files with stand-ins for the game API.
- `client_snapshot.py`: before/after snapshots of the client for comparing client updates (`snap <name>`, `diff <old> <new>`).
- `mpq.py`, `gen.py`, `gen2.py`, `gen3.py`: rebuild `AstrolabeCoAData.lua` from the client's MPQ archives if CoA changes its maps. They need `wms.csv` and `probe_zones.csv`, exported from Astrolabe.lua and a `/coaprobe` dump.
- `Migrate-RealmName.bat`, `realm_migrate.py`: after a realm rename ("Conquest of Azeroth" → "Nozdormu", 2026-10-03), move saved addon settings to the new realm name (copies the per-character folders, renames the realm inside the account-wide SavedVariables and Config.wtf). Dry run by default; `--apply` with the game closed and before the first login on the new name.
- Lua 5.1 for the tests: `C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe`.
