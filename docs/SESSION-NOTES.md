# Session notes: CoA client and addon work

Resume notes for Claude sessions. Last updated **2026-10-26**: Questie-X tracker crash fixed for v1.4 (installed and tested offline; in-game test, sync and release pending). Two server builds are waiting to be applied, and one needs a client Lua decision. See "Waiting on the user", item 0.

**To resume in a new session:**
> Read `C:\Users\dotyt\Documents\GitHub\coa-addons\docs\SESSION-NOTES.md` and the memory index.

The memory folder (`C:\Users\dotyt\.claude\projects\C--Users-dotyt-Desktop-Stream-Launcher-app\memory\`) loads automatically only for sessions started in `Desktop\Stream Launcher app`. From any other folder, ask the session to read `MEMORY.md` there.

## Working rules

- Lay out the plan and wait for the user's go-ahead before editing or creating files. The user reviews every diff and command.
- Show any script before running it.
- Ask before downloading anything, and give the size.
- "Research only" / "review only" means don't build.
- Keep this repo private, and keep the re-apply kit on this PC only. Scan anything going public for personal info first.
- Sidekick data: the user chose (10/04) to publish it in the public `coa-zygor` repo. Sidekick couldn't be reached, so the README invites them to ask for removal or credit.
- The user launches `Ascension.exe` themselves.
- Discord write-ups: one copy-paste block under 2,000 characters, in `~~~markdown` fences.

## Done

| Item | Notes |
|---|---|
| CoA Talent Advisor (`ZygorTalentAdvisorCOA`) | Preview another spec's tree, "Load build" (unsaved changes in the talent window; timeline-based, proportional two-tree trimming), point-based panel statuses, own tab in Zygor's options (opacity etc.) |
| HealBot 3.3.5.4 | CoA classes no longer crash it. In repo and kit, `test_healbot_coa.lua` |
| SexyMap | `Libs\AceGUI-3.0-SharedMediaWidgets` copied from Omen. **Not in the repo**: redo if SexyMap is reinstalled |
| Button Forge 0.9.4 | `Util.CacheCompanions` skips nameless companions (21 of 861 Ascension mounts), so start-up completes and `ButtonForgeSave` exists. In repo and kit, `test_buttonforge_coa.lua` |
| Realm rename | "Conquest of Azeroth" → **Nozdormu**, plus **Felstorm**. WTF backed up and migrated (`Migrate-RealmName.bat`); old folders kept |
| Extensions.dll | **Official launcher build since 10/05** (release 2026-10-05-01, firstoni a1d7f83). Our earlier 5197e75 build is in `coa-snapshots\before-update\files\` for rollback. Don't run `Restore-CoA-UI.bat` any more (it would restore the old 9/28 DLL and loose addons) |
| dbc_clientset | Item / ItemDisplayInfo / CreatureDisplayInfo.dbc from patch-M, in `C:\Users\dotyt\tools\dbc_clientset\`, copied to the server |
| Realm cards, spec slots | Realm cards per realm. Spec slots and Tomes II–XX work since server #6244/#6297 |
| Client update 2026-10-04 | Launcher release **2026-10-03-01** installed and compared (see "Client update" below) |
| Zygor taint fix (10/06) | `ZygorTalentAdvisorCOA\Load.lua` no longer re-assigns `StaticPopupDialogs`; that had blocked bind-on-use confirmations (Stones of Retreat). In coa-addons and coa-zygor. `Sync-ToRepo.bat` now refuses to run outside the repo root |
| Questie-X on CoA (10/08) | Detection patch (realm name → Ascension client API), map sizes for 26 CoA sub-maps (`CoAExtraZones.lua`), and **Questie-X-CoADB**, generated from the server's world DB. Confirmed in game. Tools and rebuild steps: `C:\Users\dotyt\tools\questie-x\README.md`. Kit targets `questie` / `questiedb` |
| Public **coa-questie** releases | **1.1** stale pins; **1.2** tracker re-link, Runtime mode Auto, same-name chains (thanks Yarnaros); **v1.3 (10/16)** arrow stutter (34 → 3 ms per refresh, thanks Wandering Fox), "QueryNPC (a table value)" at login, "compare number with table" (nested kill-credit ids), CoADB rebuilt from export 2026-10-16 (core 60db142d: 403 new + 528 changed quests). All confirmed in game. 10 Questie-X files patched; originals in `Questie-X\_CoA_original\`. Previous CoADB build in `tools\questie-x\coadb\_previous-2026-10-08\` |
| Public **coa-zygor 1.2.3** hotfix (10/16) | Gear popup no longer hidden during combat ("prevented the call of ZygorItemPopup:Hide()"; `Item-Upgrades.lua` `Upgrades:HideEquipPopup()`), and no "item IDs not present in database" warning on CoA (ZygorItemDB is a stock export; scoring uses live stats anyway). Confirmed in game. `test_zygor_gear_coa.lua` |
| Client update 2026-10-16 | Snapshots `before-20261016` / `after-update-20261016`; only 2 files changed. **New official Extensions.dll** (6,959,104 bytes, sha256 c4ca8f6d…, firstoni build of 10/15, ≈ reconstruction 3c8f196; adds 32-bit quest log quest IDs, measured callback order, item-use detour, BuildCreator filter fix) and **new `Data\patch-ZG.MPQ`** (ItemDisplayInfo.dbc +1 record for the Groot Coin, plus its icon). `dbc_clientset` refreshed (ItemDisplayInfo from patch-ZG; zip sha256 5a2e6185…, old files `.20261004`) and installed on the server; it takes effect at the next restart (boot line "ItemDisplayInfo" 5 → 4). Realmlist untouched. In-game test passed. **dbc_clientset now comes from the highest patch holding each DBC (patch-ZG for ItemDisplayInfo)** |
| AzerothAdmin v24 + QoL (10/16) | GM admin panel (`/aa`): `AzerothAdmin` + `AzerothAdmin_Models` (load-on-demand); zip in `C:\Users\dotyt\tools\azerothadmin\zip\` (sha256 17bf49c3…). Our additions are all in `Modules\CoAQoL.lua` (hooks `AzerothAdmin:CreateFrames`), plus its `.toc` line:<br>• drag by the top bar or the tab strip above it (`ma_menubgframe`), position saved, Lock / Reset position on the Misc page; the mini menu drags without Left Ctrl, and the Lock covers it too;<br>• Window Scale 50–150%, applied on release (scaling live moved the slider under the cursor and ran it to 50/150%);<br>• color presets and a "My colors" slot (they fill the swatches; Update Changes applies).<br>Kit target `azerothadmin`, `test_azerothadmin_coa.lua`. Synced to coa-addons and to a new public repo **coa-azerothadmin** (README: as-is, not maintained). That repo is a local `git init` until the user publishes it in GitHub Desktop. **All confirmed in game 10/16.** That includes the follow-up fixes: slider applied on release, tab strip handle, mini menu without Ctrl, and the `HasScript("OnClick")` fix (asking a plain Frame for OnClick raises an error, which had stopped the Misc controls from being built). Each setup step now runs in its own `pcall` and reports errors through `geterrorhandler()`. The test's stand-in frames model which handlers each widget type has |
| Progression V1 (Nozdormu) | Applied: cap 60, raid stage 2 (ZG + MC), bots 60 on maps 0,1, realm card expansion 0. See `docs\PROGRESSION-PLAN.md` |
| Client updates 10/19 and 10/22 | **10/19:** new Extensions.dll (sha256 a33273f8…, interface hot-patch channel; our server sends no hot patches) and 4 Manastorm UI files in patch-B. **10/22:** snapshots `before-20261022` / `after-update-20261022`; only Extensions.dll changed (sha256 3451a91b…, built 2026-10-21 19:11 UTC); the diff is in the snapshot folder. No DBC changes either time, so `dbc_clientset` is unaffected. The in-game test of the 10/22 DLL hasn't been reported |
| Questie-X tracker crash, **for v1.4 (10/26)** | A Discord report (CertifiedHuman, Darkshore): `QuestieTracker.lua:2168: attempt to perform arithmetic on a nil value` in `UpdateHeight`. Cause, an upstream bug: two branches took a pool line but wrote no text (a finished single objective without completion text, or "minimal" colours; and a quest flagged complete with objectives but no completion text). The last line's height then became 0, which unsets it, so `GetBottom()` was nil. Fix in `Modules/Tracker/QuestieTracker.lua` (3 hunks, CRLF kept): those cases now write text, the height is never set below 1, and the resize skips a missing position. Original in `Questie-X\_CoA_original\Modules\Tracker\`. Now the kit's 11th Questie file. New test in `test_questie_coa.lua` fails on the original with the exact error; suite 31/31. **Not yet:** in-game test, `Sync-ToRepo.bat`, README/CHANGELOG, commit, release |

## Client update (2026-10-04)

- **Snapshots:** made with `C:\Users\dotyt\tools\zygor-coa\client_snapshot.py`:
  - `snap <name>`: SHA-256 list of the client, plus copies of our customised files;
  - `diff <old> <new>`.
  They are in `C:\Users\dotyt\tools\coa-snapshots\`: `before-update` and `after-update-20261003-01`. `before-update\files\` has our Extensions.dll, d3d9.dll, the old patch-B/T/M, realmlist, renderer .ini files, WTF and the 28 removed `Ascension*` addon folders.
- **What changed:**
  - **patch-B (8 → 229 MB):** +289 `Interface\GLUES` art files, identical to the loose ones we already had. AccountLogin.lua and DressUpFrame.lua changed only in line endings. No GlueXML/FrameXML/addon code changed.
  - **patch-M:** only `CreatureDisplayInfo.dbc` changed (+13 records).
  - **patch-T, Ascension.exe:** unchanged.
  - **README.txt:** updated.
- **Addons removed by the launcher:**
  - the 28 loose `Ascension*` folders: 27 are built into patch-B; **AscensionRaidLootCompanion is not**, and it's backed up in the snapshot;
  - also **ProfessionMenu, Refactor, VanillaGuide and YABB** (not backed up; the launcher can reinstall them). It's not yet confirmed whether the user removed these.
- **Still on our builds:** our **Extensions.dll (5197e75)** and the **Modern Renderer d3d9.dll**.
  - The launcher wants to replace our DLL with the official one (6,865,920 bytes, sha256 b7760201…). That step fails on this PC: D: is **exFAT**, and the launcher's hard-link check throws `EISDIR`, which isn't in its fallback list.
  - Patching `app.asar` locally doesn't work: the launcher checks its own files and won't start. That was reverted; the backup is `app.asar.bak-20261004`.
  - No manual download exists, so **wait for a launcher hotfix**. Then snapshot again and compare their DLL with ours.
  - **Resolved 10/05.** The launcher's self-update added `EISDIR` to its fallback list. Release **2026-10-05-01** then installed the official Extensions.dll (6,878,208 bytes, sha256 28dce11b…).
    - The snapshot `after-official-dll` shows only the DLL changed.
    - It's firstoni's build of the reconstruction repo at **a1d7f83**. Its only code change over our 5197e75 is d9fcd12: cast-check and aura-removal callback order now match the original DLL.
    - The user kept the official DLL; an in-game test is pending.
    - The realmlist was not rewritten this time.
- **The launcher rewrites `Data\enUS\realmlist.wtf`** to `logon.coa-development.org` after every client update and every Play click. It was restored to `set realmlist 192.168.1.23` on 10/04. The user launches `Ascension.exe` directly, so it sticks until the next launcher update.
- **dbc_clientset:** refreshed 10/04 with the new CreatureDisplayInfo.dbc (sha256 225b019e…); the zip was rebuilt. The user copies it to the server.
- **Server update 10/04:** the server session checked the incoming commits (b392d4a5, e7c0ccab, 4c71515a, af8f4650): **no wire change, and nothing needs a DLL newer than 5197e75.** Item rows now also arrive after login, on demand.

## Waiting on the user

0. **Current (10/26):** the user is starting the CoA server in the morning to test.
   - **Questie v1.4, tracker fix in-game test** (fresh game start, not `/reload`):
     1. On a character with few tracked quests, run `.quest add 5321` (*The Sleeper Has Awakened*, Darkshore) and `.additem 13536` (Horn of Awakening). The objective shows 1/1, but the quest stays incomplete until the escort.
     2. Turn on Questie → Tracker → **Hide Blizzard Completion Text**, then `/reload`. Expected: "Horn of Awakening: 1/1" and no error. On the original this was the 2168 crash.
     3. Turn the option off. Expected: the green "Escort Kerlonian…" text.
     4. Clean up: `.quest remove 5321`.
     Also do one normal quest from accept to turn-in. Note: this client has no `GetQuestLogCompletionText`, so completion text falls back to the objective summary and is nil only with that option, "minimal" colours, or a failed quest. After the test: sync, README/CHANGELOG, commit, then the user releases v1.4.
   - **Discord reply** (CertifiedHuman / Konferge / Uncle Bone) was drafted on 10/26. Uncle Bone's list: the 29 level-60 dailies from the Hero's Call Board (402000) and the Warchief's Command Board (402001), taken from the 10/16 export.
   - **Konferge (not investigated):** "when I start killing things for a quest, it stops tracking spawn points and only tracks locations I've killed things". Suspect the Learner replacing DB spawns instead of adding to them. Asked for the quest and mob; the optional in-game check is to compare pins before and after a kill, and after `/reload`.
   - **Side finding:** `tools\questie-x\coadb\coords.py` places the Felwood board-daily mobs (Deadwood, Jadefire, Irontree) in **Darkshore**, because the zone rectangles overlap at the border. CoADB NPCs placed that way would show their pins on the Darkshore map. Check this later.
   - **Server builds waiting (CoA stopped):** core **774322d6** (10/24) and then **8b8d0ed4** (10/25), +102 commits on the running 95499527. Bots are at 272c350b. They apply at the first 04:30 run while CoA is running; starting CoA runs the old build.
     - **After they apply, check in game:** spec switch / action bars (#8750, 1221b742): log in, swap spec, relog, and confirm the bars and talent window stay right.
     - **Flying is back** in Outland and Northrend (d28f234c, new `CoA.LegacyMountFlight` = 0). This probably makes the planned Nozdormu "flying back on" local patch unnecessary. The user decides.
     - **Client Lua decision:** c0279ac6 (#9004) ships `client/Interface/FrameXML/CoASpecBuildMemory.lua`. It wraps `C_CharacterAdvancement.SwitchActiveChrSpec` and calls `CancelPendingBuild` + `RefreshFromCancel` when you switch back to the saved spec. It fixes an empty tree after inspecting another spec; the workaround until then is Discard before Apply. It is installed into patch-B by `tools/package_hotspot_client.py` (docs `docs/coa/client-spec-build-memory.md`).
       - **Risk:** our `ZygorTalentAdvisorCOA\Load.lua:131` also calls `SwitchActiveChrSpec` before `ImportPendingBuild`. A deferred cancel could wipe a build Load just imported.
       - Launcher updates can replace patch-B, so a separate small addon might be better.
       - Offered: get the file from the server and review it against Load.lua first. The user hasn't answered.
     - **No client change needed:** 0x0777/0x076D hit-bonus statistics plus `.hitchance` (no addon of ours reads `CR_DYNAMIC_STATS`), and item scaling level keys plus reborn armor (#8446).
   Open decisions from 10/16:
   - **Progression:** the daily timer cron isn't installed yet. Install it only when the user says so, after they've reviewed the progression.sh diff. The per-realm module (Outland gate + original BE/Draenei starts) is built only on request.
   - **HealBot CoA class data:** plan given; it waits on the user's choices (scope incl. incoming heals, which classes first, Felstorm Heroes). Don't build until asked.
   - **Questie (optional):** `QuestieCompat.GetCurrentPlayerPosition` (`SetMapToCurrentZone` on every call) is now Questie's largest cost, ~5 ms a second. The arrow's zone lookups bypass the 0.1 s cache. This could be cut further later.
   - **Mystic Enchants:** the server doesn't handle CMSG 0x60A (apply item to slot) or 0x60E (reforge slot). The server session offered to draft an upstream issue; the user hasn't decided. Mystic Enchanting is off on our realms.
   - **Exit crash (10/16): resolved.** It was a Windows popup and a `STACK_OVERFLOW` in `clr.dll` at shutdown. It started after the .NET security update KB5127690. `DivxTac.dll`, Ascension's .NET component, loads the CLR. **It stopped with the new official Extensions.dll from the 10/16 client update**: no crash reports since. So the old DLL's shutdown handling was involved. If it ever returns, check `D:\COA Client\Errors\`.
   - **Not CoA:** AnyPS5 is cloned to `Documents\GitHub\AnyPS5` (with submodules, 748 MB). The build needs WinLibs GCC 15.2.0 r7 (267.6 MB zip, not downloaded). Alternatively, the prebuilt v0.1.1 release is ~14 MB. The user hasn't picked one.

1. **First play after the 10/04 client update.** Wait for the server session's "live and stable" message and copy `dbc_clientset.zip` to the server first. Then check:
   - items seen for the first time this session show an icon and name, not a red "?" (re-hover once);
   - Button Forge (`/reload`, bars, Create Bar, Advanced tools);
   - the talent advisor (panel, preview, Load build);
   - no UI errors at login.
   Button Forge is already committed. Sync and commit `client_snapshot.py` and these notes next time.
   **Result (10/04):** all fine. The only UI error was from TSM (a missing locale string in the launcher's customised TSM, harmless), and the user disabled TSM.
   Addons: the launcher removed ProfessionMenu, Refactor, VanillaGuide and YABB on its own; the user doesn't use them, so they stay removed. AscensionRaidLootCompanion is **not** built in (not in any MPQ); it's an optional addon in the launcher's catalog, and a backup is in the snapshot.
2. **Realm cards:** when convenient, ask the server session to change the RealmCards expansion from 2 to 0 for realm 1 (Nozdormu) and realm 2 (Felstorm), then restart the authserver.
   - Both realms are capped at 60, so "Vanilla (Progressive)" matches Ascension and is accurate.
   - The client only uses the card's expansion for display; the account's expansion stays at Wrath.
   - It also removes the "WotLK Alpha Bundle" notice (backlog item 4; kept in the backlog until done).
3. **Talent advisor "switch to spec slot + load build":** planned and reviewed; **don't build until the user says go**. Checks before building:
   - whether the talent window closes on a slot swap;
   - event timing after the swap;
   - loading into an empty slot;
   - whether `GetInspectedBuild` works on other slots.

## On the next client update (launcher)

1. Close the game and launcher, then run `python client_snapshot.py snap <name>`. The script is approved; running it still needs the user's go.
2. The user updates in the launcher. Don't start the game.
3. Snapshot again and `diff` the two. Diff the MPQ members of patch-B/M/T against the copies in the old snapshot.
4. Re-check the realmlist, and refresh `dbc_clientset` if Item / ItemDisplayInfo / CreatureDisplayInfo changed. patch-M is their only Data MPQ.
5. If the official Extensions.dll arrives, compare it with ours and with the reconstruction repo. Re-test the advisor and Zygor map data.

Details: memories `coa-client-patch-compare.md` and `coa-launcher.md`.

## Backlog (parked)

Retail-style character select (outline only), HealBot CoA spell gaps, the realm-card "WotLK" notice, the VanillaGuide error on new characters, TSM on Felstorm (C_Hook overflow, disabled), High Elf race (server says it doesn't fit as-is). Details: memory `coa-ideas-backlog.md`.

## Key paths

| What | Where |
|---|---|
| Client | `D:\COA Client` (addons in `Interface\AddOns`; originals of patched files in `<addon>\_CoA_original\`) |
| This repo | `C:\Users\dotyt\Documents\GitHub\coa-addons`: `Sync-ToRepo.bat` copies the live folders in; commit with GitHub Desktop |
| Public repos | `coa-zygor`, `coa-tomtom`, `coa-healbot`, `coa-buttonforge` (published 10/04), `coa-questie` (10/08) and `coa-azerothadmin` (10/16, not yet published) in `Documents\GitHub\` (GitHub user Dandenas). `Sync-ToRepo.bat` also updates them; commit each one that shows changes |
| Re-apply kit | `C:\Users\dotyt\tools\zygor-coa\Apply-ZygorCoA.bat` (`--dry-run` to preview): zygor, tomtom, healbot, buttonforge, questie, questiedb, azerothadmin. Regenerate with `kit\make_kit.py` |
| Tests | `C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe`, 31 tests (run by the kit). Each fix's test fails on the original file |
| Questie CoADB rebuild | Ask the server to run `COA/tools/questie-export.py` (read-only), copy the `.json.gz` to Downloads, then `python build_coadb.py <export>` (not `python -I`: it imports `coords.py`), then `lua5.1 test_coadb.lua Questie-X-CoADB`, then copy the folder to AddOns |
| Extensions.dll source | `C:\Users\dotyt\tools\ascension-extensions-reconstruction` |
| Client snapshots | `C:\Users\dotyt\tools\zygor-coa\client_snapshot.py` → `C:\Users\dotyt\tools\coa-snapshots\` |
| CoA launcher | `%LOCALAPPDATA%\Programs\ConquestOfAzeroth\` (settings in `%APPDATA%\Conquest of AzerothCore\settings.json`, state in `D:\COA Client\.coa-launcher\`) |

## Server

- **Repo:** jealous-sound/azerothcore-wotlk-coa at 192.168.1.23, updated nightly (04:30). Core **95499527** running as of 10/25, with **8b8d0ed4** built and waiting (see "Waiting on the user", item 0). Core was 60db142d on 10/16. Since 10/08 the server has added the Hero Architect build board, PvP reward info (0x53E/0x925), rated solo queues and the AH deposit rate (#7569). Their opcodes were all checked against the official DLL, and nothing needs a newer DLL.
- **Realms:** **Nozdormu** (id 1, port 8086, CoA) and **Felstorm** (id 2, port 8087, Wildcard / Hero). They share `acore_auth` / `acore_world` and have separate characters / playerbots databases.
- **Server Claude session:** since the 10/23 host reboot it's at `bridge:session_015gcJbz3ZV3HmMCoPPQ6fht` ("media-stack-85"; its title showed as "Test server swap to 0.05"). It was "media-stack-79" at `bridge:session_01XvVTiHQZy6CicyaQUC1w8J` from 10/18, and "media-stack-fa" before that. The address changes when that session is recreated, so always reply to the latest `from`, and resend anything from the hour before a reboot.
- **Watcher:** runs at 5:47 and 8:47 AM Phoenix time. It was still reporting nightly updates on 10/16, so it's been renewed. Its messages arrive only while a session here runs with Remote Control on.
