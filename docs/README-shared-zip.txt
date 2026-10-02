Zygor Guides Viewer Remaster + TomTom, adapted for Conquest of Azeroth
=====================================================================

Contents
  ZygorGuidesViewerRM   Zygor Guides Viewer Remaster 3.0.253 (github.com/ErebusAres/ZygorGuidesRemaster-3.3.5a_WOTLK) with CoA changes
  TomTom                TomTom (2010 release) with CoA changes

Install
  1. Close the game.
  2. Delete any existing ZygorGuidesViewerRM and TomTom folders in Interface\AddOns
     (mixing old and new files causes problems).
  3. Extract both folders into Interface\AddOns.
  4. Start the game fully (a /reload is not enough the first time).

Use both folders together: Zygor hands waypoints to TomTom in the zone numbering the
changed TomTom expects. Your Zygor/TomTom settings are not included - set them in game.

What was changed for CoA
  - Arrow works on CoA's extra maps (starting areas, caves, mines, CoA zones).
  - Starting areas such as Northshire Valley or Sunstrider Isle count as their parent zone,
    so "go to" steps complete and the arrow is not sent on needless travel.
  - The route planner places the player correctly on CoA's maps.
  - Gear Advisor knows the 21 CoA classes and their specs, and only suggests armor and
    weapons the character can use.
  - Weapon DPS is no longer ignored by the Gear Advisor (bug in the original, all classes).
  - No "Error loading" lines at startup.
  - TomTom: works with the client's built-in map library (zone area IDs), no right-click
    crash, and the arrow no longer disappears while moving.

Built against the CoA client of 2026-09-30. If CoA later adds or redraws maps, the new ones
may need updated map data. On non-CoA clients the changes stay inactive.
