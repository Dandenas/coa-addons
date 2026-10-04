# CoA addons

Personal, private repository for the addon work done for a **Conquest of Azeroth** (Ascension-based 3.3.5a) client running against a home AzerothCore-CoA server.

## What's here

| Folder | Contents |
|---|---|
| `addons/ZygorGuidesViewerRM` | Zygor Guides Viewer Remaster 3.0.253 ([ErebusAres/ZygorGuidesRemaster-3.3.5a_WOTLK](https://github.com/ErebusAres/ZygorGuidesRemaster-3.3.5a_WOTLK)) with the CoA changes, exactly as it runs in the client |
| `addons/TomTom` | TomTom (2010 release) with the CoA changes |
| `addons/CoAMapProbe` | Small diagnostic addon (`/coaprobe`) that records the client's map list and player positions |
| `addons/HealBot` | HealBot 3.3.5.4 with the CoA changes |
| `addons/ButtonForge` | Button Forge 0.9.4 with the CoA change |
| `tools/zygor-coa` | Re-apply kit, regression tests, map-data and talent-data generators, MPQ reader |
| `tools/ascension-extensions-reconstruction-build.bat` | Builds `Extensions.dll` from [firstoni-dev/ascension-extensions-reconstruction](https://github.com/firstoni-dev/ascension-extensions-reconstruction) (source cloned separately to `C:\Users\dotyt\tools\ascension-extensions-reconstruction`) |
| `client-scripts` | `Restore-CoA-UI.bat` (undo the Extensions.dll / original-UI switch) and `Uninstall-ModernRenderer.bat` |
| `docs` | Handoffs (server ↔ client sessions, skill-card pack idea) and the install note for shared copies |

## The CoA changes, in short

- **Map arrow / Astrolabe:** sizes for ~50 CoA-only maps (starting areas, caves, CoA zones), taken from the client's own DBCs.
- **Zone folding:** CoA reports sub-maps such as "Northshire Valley" as zones; they are folded into the parent zone so "go to" steps complete and travel planning works (`CoAZones.lua`).
- **Route planner:** LibRover uses Zygor's own map data instead of CoA's native `C_Map` IDs.
- **Gear Advisor:** CoA classes and specs, armor/weapon usability from the character's skills, and an upstream weapon-DPS fix.
- **CoA Talent Advisor** (`ZygorTalentAdvisorCOA`): leveling builds for 21 classes and 70 specs (data from [Ascension Sidekick](https://ascensionsidekick.com)), a panel beside the CoA talent window, and points/order numbers drawn on the talent trees. It can preview another spec's tree, load a build into the talent window as unsaved changes ("Load build"), and has its own tab in Zygor's options.
- **TomTom:** works with the client's built-in area-ID Astrolabe, no right-click crash, and the arrow no longer vanishes while moving.
- **HealBot:** no longer fails for CoA classes, whether you play one or have one in your group (class colours come from the client).
- **Button Forge:** starts up again. Ascension's mount collection has nameless entries, which stopped its start-up, so every bar/config button errored (`ButtonForgeSave` nil).

`tools/zygor-coa/README.md` has the full table of problems and fixes.

## Workflow

1. Make changes in the live client (`D:\COA Client\Interface\AddOns\...`) or tools folder (`C:\Users\dotyt\tools\...`) as before.
2. Run **`Sync-ToRepo.bat`** to copy the current state into this repository.
3. Review and commit in GitHub Desktop, then push.

After installing a new Zygor, TomTom, HealBot or Button Forge version: close the game and run `C:\Users\dotyt\tools\zygor-coa\Apply-ZygorCoA.bat`, which re-applies the changes and runs the tests. Then sync and commit.

To refresh the talent builds from Ascension Sidekick, run `C:\Users\dotyt\tools\zygor-coa\Refresh-CoATalentData.bat`.

## Third-party content

This repository is private because it contains other people's work: Zygor's guides and viewer, TomTom, HealBot, Button Forge, Ascension Sidekick's build data (permission to redistribute not yet asked), and reference copies of Ascension client code and Blizzard data files extracted for analysis. Don't make it public as-is.
