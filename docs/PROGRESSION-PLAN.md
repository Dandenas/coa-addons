# Progression plan: Vanilla first, then TBC and WotLK

Draft for review, 2026-10-07. Decisions filled in by the user on 10/07. **Nothing is applied until the user approves the script and the V1 changes.**

**User decisions (10/07):**
- **Nozdormu only** for now. Felstorm (Wildcard) joins later, once the kinks are worked out, and stays on today's setup until then.
- **Start at raid stage 2** (Zul'Gurub + Molten Core).
- **On a timer:** a new raid every **2 weeks**, then a new expansion every **month**. "When I ask" can also move a phase at any time.
- **Outland/Northrend:** a soft gate for now. The server session researches a per-realm lock (a module or method) and sends the plan here for the user to read.

**Script review decisions (10/07):** the script is `COA/progression/progression.sh` on the server, with `schedule-nozdormu.conf`.
- **V2–V6:** a short Nozdormu restart, only once no real players are online.
- **Bots:** `AiPlayerbot.RandomBotMaps` becomes a 5th phase setting: `0,1` during Vanilla, `+530` at T1, all maps at W1. Today 239 Nozdormu bots are on map 530.
- **Timer:** the daily cron (06:47) is installed only after V1 has run once successfully.
- **V1:** applied by hand on the user's go, after the 10/08 update verifies.
- **Fixes requested before any real run:**
  - check for environment-variable overrides, and verify the live values after the restart;
  - compare RestartCount before and after instead of requiring 0;
  - confirm the updater uses the same flock lock;
  - make failed database queries stop with a clear error.
- Per-realm Outland/Northrend lock: the server proposes a small local module, `RealmGate.MaxExpansion`. It would block Northrend and TBC/WotLK instances by map and Outland **by zone**, because map 530 also holds the Blood Elf and Draenei starting zones. It's about half a day of work; whether to build it is still undecided. The server session ("media-stack-fa") makes the server-side changes. Every config file is backed up before it's edited, and every script is shown to the user before it runs.

## Goal

Both realms start as **Vanilla**: level cap 60, Classic raids opening in stages. Later they open **TBC** (cap 70), then **WotLK** (cap 80), either on a timer or when the user asks. Each realm can be at a different point.

## Building blocks

All of these are per worldserver, so Nozdormu and Felstorm can differ.

| Setting | File | Phases |
|---|---|---|
| `MaxPlayerLevel` | worldserver.conf (per realm) | 60 → 70 → 80 |
| `Ascension.CallboardCache.ReleaseStage` | coa.conf (per realm); from upstream #6771, **arrives with the 10/08 04:30 update** | Classic raids: 1 ZG, 2 MC, 3 Onyxia, 4 BWL, 5 AQ20, 6 AQ40, 7 Naxx. Read on `.reload config`; GMs bypass; closed raids say "Instance is closed" |
| `AiPlayerbot.RandomBotMaxLevel` | playerbots.conf (per realm) | 60 → 70 → 80, so bots match the cap |
| `RealmCards.Expansion.<id>` (+ label) | authserver.conf (our local realm-card patch) | 0 "Vanilla (Progressive)" → 1 TBC → 2 WotLK; needs an authserver restart |

**Left alone:**
- `Expansion = 2` in worldserver.conf and the accounts' expansion (all 2). Lowering either risks locking out characters of TBC/WotLK races and classes, and CoA already treats Blood Elves and Draenei as Classic races (Deathknell / Shadowglen starts).
- `Ascension.PrestigiousCache.ReleaseStage` (default 6).

## Phases

Schedule for **Nozdormu**. Dates assume V1 goes live on 10/08, after that night's update verifies; each later date is relative to the one before, so they all shift if V1 starts later.

| Phase | Date | Level cap | Raid stage | Bots max | Realm card | Notes |
|---|---|---|---|---|---|---|
| **V1: Vanilla launch** | 2026-10-08 | 60 | **2** (ZG + MC) | 60 | 0, "Vanilla (Progressive)" | Applied after the 10/08 update verifies and the user approves |
| V2 | 2026-10-22 | 60 | 3 (+ Onyxia) | 60 | 0 | `.reload config`, no restart |
| V3 | 2026-11-05 | 60 | 4 (+ BWL) | 60 | 0 | 〃 |
| V4 | 2026-11-19 | 60 | 5 (+ AQ20) | 60 | 0 | 〃 |
| V5 | 2026-12-03 | 60 | 6 (+ AQ40) | 60 | 0 | 〃 |
| V6 | 2026-12-17 | 60 | 7 (+ Naxx) | 60 | 0 | 〃 |
| **T1: TBC opens** | 2027-01-17 | 70 | 7 | 70 | 1, "The Burning Crusade" | One month after Naxx; worldserver + authserver restart |
| **W1: WotLK opens** | 2027-02-17 | 80 | 7 | 80 | 2, "Wrath of the Lich King" | One month after TBC; the same as today's stock setup |

**Felstorm:** no change for now. It gets its own schedule later, which can start at V1 or join at Nozdormu's current phase.

## Moving between phases

Two ways, and both can be used:

- **When the user asks:** tell the server session "Nozdormu: next phase" (or "set phase T1"). It applies that phase's settings to that realm and reports back.
- **On a timer:** a small schedule file on the server lists realm, phase and date. A daily check (alongside the existing updater, outside its update window) applies any phase whose date has passed, then logs it in the update summary so the watcher reports it here. Dates can be added, moved or removed at any time, and "when I ask" still overrides.

The server session would write one script, for example `progression.sh status|next|set <phase> [realm]`, that both paths use. It backs up the configs, edits the keys above, then runs `.reload config` or restarts as needed. **The script is shown to the user for approval before first use.**

## Before V1

1. **Alermes Bot** (RNDBOT12, level 61, a random bot on Nozdormu): with the bot offline, bring it to 60 (`.character level Alermes 60`), or let the bot system re-randomise it. It's the only character above 60.
2. Confirm the 10/08 update applied #6771 (the `ReleaseStage` key exists and works).
3. Back up Nozdormu's worldserver.conf, coa.conf and playerbots.conf, plus authserver.conf.
4. The server session sends here, for the user to review: the progression script, the schedule file and the exact V1 config changes. **They're applied only after the user's go.**

## Open question: Outland and Northrend access during Vanilla

A level cap doesn't stop a level-60 character walking through the Dark Portal or taking the Northrend boats. The obvious hard locks don't work per realm:
- `disables` rows live in the **shared** world DB, so they would hit both realms;
- account expansion is per account, so it would also hit both realms.

**Decision (10/07):** use **a) a soft gate** for now: cap 60, and Outland/Northrend are simply "too high". The server session researches a **per-realm lock** (a module or method), research only, and sends the plan here for the user to read. Options to look at:
- **b)** A small per-realm config check, for example a CoA option or a tiny script blocking map 530/571 entry below a phase, if the core offers a hook.
- **c)** Use `disables` only while **both** realms are in Vanilla (not useful while Felstorm stays open).

## To do: original Blood Elf / Draenei starts at T1 (user decision 10/08)

Upstream #6397 (6216ed16, from 10/03) moved new Blood Elves to Deathknell and new Draenei to Shadowglen. It only changed the `playercreateinfo` start rows (races 10/11, all classes except DK). The Sunstrider Isle and Ammen Vale quests and NPCs are untouched, and the Travel Permit still goes there.

When **TBC opens (T1)**, Nozdormu should use the **original** starts again:
- Blood Elves: Sunstrider Isle, map 530 zone 3431 (10349.6, -6357.29, 33.4026), o 5.31605.
- Draenei: Ammen Vale, map 530 zone 3526 (-3961.64, -13931.2, 100.615), o 2.08364.

**How:** option A from the server's research.
- A per-realm setting `RealmStart.ClassicTbcRaceStarts` in a small **local module**. At startup it swaps the start rows **in memory**: no database writes, Felstorm unaffected, and CoA updates can't overwrite it.
- It lives in the same module as the per-realm Outland/Northrend gate.
- The progression script gets a `RACESTARTS` column: V1–V6 `0`, T1/W1 `1`.
- Existing characters aren't moved. New random bots also start at the original zones, which fits bot maps `0,1,530` at T1.

**Effort:** about half a day together with the gate module. **Build only when the user asks.**

Test after switching it on:
- a new BE starts at Sunstrider Isle and a new Draenei at Ammen Vale, with the hearthstone bound there;
- a BE/Draenei Death Knight still starts at Ebon Hold;
- new BE/Draenei on Felstorm are unchanged;
- the Travel Permit still works.

## Rollback

Restore the backed-up configs and restart. No character data is changed by any phase, apart from Alermes Bot's level. Raising a cap later is always safe; lowering it again would strand characters above the new cap.
