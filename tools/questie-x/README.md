# Questie-X for Conquest of Azeroth

Tools behind the CoA support for [Questie-X](https://github.com/Xurkon/Questie-X).

| What | How it's made |
|---|---|
| Detection patch (Questie-X + AscensionDB) | In the re-apply kit (`tools\zygor-coa\kit`, targets `questie` / `questiedb`), tested by `test_questie_coa.lua` |
| `Questie-X-AscensionDB\Zones\CoAExtraZones.lua` | `python gen_coa_maps.py`. Map sizes for 26 CoA open-world sub-maps from the client's `WorldMapArea.dbc`. Copy into the plugin's `Zones\`; it's in the kit too |
| `Questie-X-CoADB` (the CoA quest plugin) | `coadb\build_coadb.py` from the server's quest export (see below) |

## Rebuilding Questie-X-CoADB after server updates

1. Ask the server session to run `COA/tools/questie-export.py` (read-only). Copy the resulting `coa-questie-export-<date>.json.gz` to this PC.
2. `cd coadb` and refresh the stock index if Questie-X-WotLKDB or AscensionDB were updated:
   `lua5.1 dump_stock.lua "<AddOns>\Questie-X-WotLKDB" "<AddOns>\Questie-X-AscensionDB" > stock_index.tsv`
3. `python build_coadb.py <export.json.gz>` writes `coadb\Questie-X-CoADB` and prints a report.
4. `lua5.1 test_coadb.lua Questie-X-CoADB` is the load test.
5. Copy `coadb\Questie-X-CoADB` over `Interface\AddOns\Questie-X-CoADB`, then restart the game.

## What the plugin contains

Only what differs from Questie's stock data:
- **New quests:** full records.
- **Changed quests:** only the differing fields (givers, turn-ins, levels, name).
- **NPCs / objects / items** the new quests need.
- **Updated giver / turn-in lists.**

Spawn positions are converted to zone map percentages with the client's map data (`coords.py`). This matches Questie's stock zone for about 87% of NPCs; the rest are at zone borders and still map to the right world position.

Zone maps overlap at borders. There, a spawn goes in the zone of its own quests (ones it gives, takes, is an objective of, or drops a quest item for) when it's on that zone's map, as Questie's stock data does (the Rebel Camp is on the Stranglethorn map, not Duskwood's). Otherwise it goes in the zone it is furthest inside. Capital cities are left out of this: a spawn inside a city stays there, and a city's quests don't pull mobs from outside the walls onto the city map. The build report counts the positions moved this way.

CoA's own areas (ids 10000 and up) are mostly caves and starting valleys, which are folded into the zone around them as in Questie's stock data. Areas whose world map is at least 3,000 yards wide are whole zones with their own map (Pale Reach, Druk'Thar) and keep it; the largest CoA sub-map is about 1,800 yards. Their map sizes come from `CoAExtraZones.lua`, so Questie draws their pins on their own map.

A quest the server marks "any race" but which is given only by Alliance-friendly (or only Horde-friendly) NPCs is marked for that faction, from the client's `FactionTemplate.dbc`.

The CoA values are re-applied over the Ascension plugin's, because Questie otherwise lets Ascension-live data win.

Not handled yet: holiday quests whose givers only appear during events (left to Questie's stock data), and spawns inside instances.
