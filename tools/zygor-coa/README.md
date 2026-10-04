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
| 49 "Error loading" lines at startup | Drop empty `GuideNN` / `buildNN` placeholder entries | `Guides/Autoload.xml`, `ZygorTalentAdvisor/Builds/Autoload.xml` |
| TomTom crashed on right-click in CoA zones (area ID looked up as a zone index) | Area-ID lookups above, plus a guard against a missing map name | `TomTom.lua` |
| Button Forge never finished starting up (`ButtonForgeSave` nil, errors from every bar/config button): its companion cache aborted on the first nameless companion, and Ascension's collections have some (21 of 861 mounts) | Skip nameless companions; still wait for a retry while most names are missing (data not loaded yet) | Button Forge: `Util.lua` (original in `ButtonForge\_CoA_original\`) |
| HealBot keys its class tables by the class's first four letters; CoA classes (Chronomancer = `CHRO`, ...) are in none, so it failed at login and on CoA party members (class colours, ignored class debuffs) | CoA classes get the Warrior's HoT-watch defaults, the client's own `RAID_CLASS_COLORS`, and empty buff / cure-spell / ignored-debuff lists. CoA heal spells themselves are not known to HealBot | HealBot: `HealBot.lua`, `HealBot_Action.lua`, `HealBot_Options.lua` (originals in `HealBot\_CoA_original\`) |

## Files here

- `Apply-ZygorCoA.bat`, `kit\apply_coa_patch.py`: re-apply the changes.
- `kit\hunks.json`, `kit\files\`: the changes themselves. Regenerate them with `kit\make_kit.py` from the clean download and the patched install.
- `test_*.lua`, `fixtures\`: regression tests, using real position samples from the client (Sunstrider Isle and Human start area). `test_healbot_coa.lua` and `test_buttonforge_coa.lua` load those addons' own files with stand-ins for the game API.
- `mpq.py`, `gen.py`, `gen2.py`, `gen3.py`: rebuild `AstrolabeCoAData.lua` from the client's MPQ archives if CoA changes its maps. They need `wms.csv` and `probe_zones.csv`, exported from Astrolabe.lua and a `/coaprobe` dump.
- `Migrate-RealmName.bat`, `realm_migrate.py`: after a realm rename ("Conquest of Azeroth" → "Nozdormu", 2026-10-03), move saved addon settings to the new realm name (copies the per-character folders, renames the realm inside the account-wide SavedVariables and Config.wtf). Dry run by default; `--apply` with the game closed and before the first login on the new name.
- Lua 5.1 for the tests: `C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe`.
